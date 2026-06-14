import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/mqtt_service.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../services/api_service.dart';

class MqttController extends ChangeNotifier {
  final MqttService mqttService = MqttService();
  final ApiService apiService = ApiService();
  io.Socket? _socket;

  List<Map<String, dynamic>> rooms = [];
  MqttConnectionStatus connectionStatus = MqttConnectionStatus.disconnected;
  bool _useMockData = false;
  Timer? _mockDataTimer;

  // MQTT Topics
  static const String sensorTopicPrefix = 'smartac/sensor/';
  static const String controlTopicPrefix = 'smartac/control/';
  static const String statusTopicPrefix = 'smartac/status/';

  bool get isConnected => connectionStatus == MqttConnectionStatus.connected;
  bool get isConnecting => connectionStatus == MqttConnectionStatus.connecting;

  Future<void> init() async {
    _updateConnectionStatus(MqttConnectionStatus.connecting);

    try {
      await apiService.loadSavedToken();

      // Auto login opsional via dart-define agar mudah setup di development.
      const email = String.fromEnvironment('API_EMAIL', defaultValue: '');
      const password = String.fromEnvironment('API_PASSWORD', defaultValue: '');
      if (email.isNotEmpty && password.isNotEmpty) {
        await apiService.login(email: email, password: password);
      }

      // Hentikan mock data timer jika ada sebelumnya
      _mockDataTimer?.cancel();
      _mockDataTimer = null;
      _useMockData = false;

      await loadRoomsFromBackend();
      _connectRealtimeSocket();
      _updateConnectionStatus(MqttConnectionStatus.connected);
    } catch (e) {
        debugPrint('Backend integration unavailable, fallback to mock data: $e');
      _useMockData = true;
      _startMockData();
    }
  }

  void _updateConnectionStatus(MqttConnectionStatus status) {
    connectionStatus = status;
    notifyListeners();
  }

  Future<void> loadRoomsFromBackend() async {
    final devices = await apiService.getDevices();
    rooms = devices.map<Map<String, dynamic>>((device) => _mapBackendRoom(device)).toList();
    notifyListeners();
  }

  Map<String, dynamic> _mapBackendRoom(dynamic room) {
    final data = room as Map<String, dynamic>;
    return {
      'id': data['id'],
      'room': data['nama_ruangan']?.toString() ?? '-',
      'device_id': data['device_id']?.toString() ?? '-',
      'temperature': _toDouble(data['suhu_aktual']) ?? 0,
      'presence': (data['status_kehadiran']?.toString() ?? '').toLowerCase() == 'ada orang',
      'ac_status': data['status_ac']?.toString() ?? 'OFF',
      'mode': data['mode_kontrol']?.toString() ?? 'AUTO',
      'control_mode': (data['mode_kontrol']?.toString() ?? 'AUTO').toLowerCase(),
      'cooling_mode': data['mode_ac']?.toString() ?? 'NORMAL',
      'batas_atas': _toInt(data['batas_atas']) ?? 29,
      'batas_bawah': _toInt(data['batas_bawah']) ?? 28,
      'brand': _capitalize(data['merk_ac']?.toString() ?? 'DAIKIN'),
      'ir_learning_state': data['ir_learning_state']?.toString() ?? 'IDLE',
      'ir_learning_target': data['ir_learning_target']?.toString(),
      'ir_clone_ready': _hasIrCloneData(data),
    };
  }

  bool _hasIrCloneData(Map<String, dynamic> data) {
    return [
      data['ir_power_on_code'],
      data['ir_power_off_code'],
      data['ir_turbo_code'],
      data['ir_normal_code'],
    ].any((value) => value != null && value.toString().trim().isNotEmpty);
  }

  void _connectRealtimeSocket() {
    _socket?.dispose();

    _socket = io.io(
      apiService.socketUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
      },
    );

    _socket!.onConnect((_) {
      debugPrint('Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket!.on('sensor:update', (payload) {
      if (payload is Map) {
        _applySensorUpdate(Map<String, dynamic>.from(payload));
      }
    });

    _socket!.on('ac:update', (payload) {
      if (payload is Map) {
        _applyAcUpdate(Map<String, dynamic>.from(payload));
      }
    });

    _socket!.on('ir:update', (payload) {
      if (payload is Map) {
        _applyIrUpdate(Map<String, dynamic>.from(payload));
      }
    });

    _socket!.connect();
  }

  void _applySensorUpdate(Map<String, dynamic> data) {
    final deviceId = data['device_id']?.toString();
    if (deviceId == null) return;

    final index = rooms.indexWhere((r) => r['device_id'] == deviceId);
    if (index == -1) return;

    rooms[index] = {
      ...rooms[index],
      'temperature': _toDouble(data['suhu_aktual']) ?? rooms[index]['temperature'],
      'presence': (data['status_kehadiran']?.toString() ?? '').toLowerCase() == 'ada orang',
      'ac_status': data['status_ac']?.toString() ?? rooms[index]['ac_status'],
      'cooling_mode': data['mode_ac']?.toString() ?? rooms[index]['cooling_mode'],
      'mode': data['mode_kontrol']?.toString() ?? rooms[index]['mode'],
      'control_mode': (data['mode_kontrol']?.toString() ?? rooms[index]['mode']).toString().toLowerCase(),
    };

    notifyListeners();
  }

  void _applyAcUpdate(Map<String, dynamic> data) {
    final deviceId = data['device_id']?.toString();
    if (deviceId == null) return;

    final index = rooms.indexWhere((r) => r['device_id'] == deviceId);
    if (index == -1) return;

    rooms[index] = {
      ...rooms[index],
      if (data['status_ac'] != null) 'ac_status': data['status_ac'].toString(),
      if (data['mode_ac'] != null) 'cooling_mode': data['mode_ac'].toString(),
    };

    notifyListeners();
  }

  void _applyIrUpdate(Map<String, dynamic> data) {
    final deviceId = data['device_id']?.toString();
    if (deviceId == null) return;

    final index = rooms.indexWhere((r) => r['device_id'] == deviceId);
    if (index == -1) return;

    rooms[index] = {
      ...rooms[index],
      if (data['learning_state'] != null) 'ir_learning_state': data['learning_state'].toString(),
      if (data['learning_target'] != null) 'ir_learning_target': data['learning_target']?.toString(),
      if (data['ir_clone_ready'] != null) 'ir_clone_ready': data['ir_clone_ready'],
    };

    notifyListeners();
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _connectMqtt() async {
    connectionStatus = MqttConnectionStatus.connecting;
    notifyListeners();

    // Setup callbacks
    mqttService.onConnectionStatusChanged = (status) {
      connectionStatus = status;
      notifyListeners();
      
      if (status == MqttConnectionStatus.connected) {
        _subscribeToTopics();
      }
    };

    mqttService.onMessage = _handleMessage;

    final connected = await mqttService.connect();
    
    if (!connected) {
      debugPrint('MQTT connection failed, falling back to mock data');
      _useMockData = true;
      _startMockData();
    }
  }

  void _subscribeToTopics() {
    // Subscribe to all sensor data
    mqttService.subscribe('$sensorTopicPrefix+');
    // Subscribe to all status updates
    mqttService.subscribe('$statusTopicPrefix+');
  }

  void _handleMessage(String topic, String message) {
    try {
      final data = jsonDecode(message);
      
      if (topic.startsWith(sensorTopicPrefix)) {
        // Sensor data received
        updateRoom(data);
      } else if (topic.startsWith(statusTopicPrefix)) {
        // Status update received
        _handleStatusUpdate(topic, data);
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
      // Try to handle non-JSON message
      _handleRawMessage(topic, message);
    }
  }

  void _handleRawMessage(String topic, String message) {
    // Handle simple text messages
    final parts = topic.split('/');
    if (parts.length >= 3) {
      final roomId = parts[2];
      final existingRoom = _findRoom(roomId);
      if (existingRoom != null && existingRoom.isNotEmpty) {
        if (message == 'ON' || message == 'OFF') {
          existingRoom['ac_status'] = message;
          notifyListeners();
        }
      }
    }
  }

  void _handleStatusUpdate(String topic, Map<String, dynamic> data) {
    final roomName = data['room'];
    if (roomName != null) {
      updateRoom(data);
    }
  }

  void _startMockData() {
    // Simulate MQTT connection
    connectionStatus = MqttConnectionStatus.connected;
    notifyListeners();

    _mockDataTimer?.cancel();
    _mockDataTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      updateRoom({
        "room": "Ruang Dosen 1",
        "temperature": 26 + (timer.tick % 5),
        "humidity": 60 + (timer.tick % 10),
        "presence": timer.tick % 2 == 0,
        "ac_status": timer.tick % 2 == 0 ? "ON" : "OFF",
        "mode": "AUTO",
        "target_temp": 24,
      });

      updateRoom({
        "room": "Ruang Kelas C301",
        "temperature": 28 + (timer.tick % 4),
        "humidity": 55 + (timer.tick % 8),
        "presence": timer.tick % 2 == 1,
        "ac_status": timer.tick % 2 == 1 ? "ON" : "OFF",
        "mode": "MANUAL",
        "target_temp": 22,
      });

      updateRoom({
        "room": "Lab Komputer A",
        "temperature": 25 + (timer.tick % 3),
        "humidity": 50 + (timer.tick % 12),
        "presence": true,
        "ac_status": "ON",
        "mode": "ECO",
        "target_temp": 25,
      });
    });
  }

  Map<String, dynamic>? _findRoom(dynamic key) {
    if (key == null) return null;
    final keyStr = key.toString();

    for (final room in rooms) {
      if ((room['device_id']?.toString() ?? '') == keyStr) {
        return room;
      }
    }

    for (final room in rooms) {
      if ((room['room']?.toString() ?? '') == keyStr) {
        return room;
      }
    }

    return null;
  }

  void updateRoom(Map<String, dynamic> data) {
    int index = rooms.indexWhere((r) => r['room'] == data['room']);

    if (index == -1) {
      rooms.add(data);
    } else {
      // Merge data to preserve existing fields
      rooms[index] = {...rooms[index], ...data};
    }

    notifyListeners();
  }

  Future<void> registerDevice(
    String deviceId,
    String roomName, {
    required String brand,
    required int batasAtas,
    required int batasBawah,
  }) async {
    if (_useMockData) {
      updateRoom({
        'id': DateTime.now().millisecondsSinceEpoch,
        'room': roomName,
        'device_id': deviceId,
        'temperature': 0,
        'presence': false,
        'ac_status': 'OFF',
        'mode': 'AUTO',
        'control_mode': 'auto',
        'cooling_mode': 'NORMAL',
        'batas_atas': batasAtas,
        'batas_bawah': batasBawah,
        'brand': brand,
      });
      return;
    }

    await apiService.createDevice(
      nama: roomName,
      deviceId: deviceId,
      batasAtas: batasAtas,
      batasBawah: batasBawah,
      merkAc: brand,
    );

    await loadRoomsFromBackend();
  }

  Future<void> deleteRoom(String roomName) async {
    final room = _findRoom(roomName);
    if (room == null) return;

    if (_useMockData) {
      rooms.removeWhere((r) => r['room'] == roomName);
      notifyListeners();
      return;
    }

    final roomId = _toInt(room['id']);
    if (roomId == null) return;

    await apiService.deleteDevice(roomId);
    rooms.removeWhere((r) => r['id'] == roomId);
    notifyListeners();
  }

  Future<void> updateRoomSettings({
    required String roomName,
    required String brand,
    required int batasAtas,
    required int batasBawah,
  }) async {
    final room = _findRoom(roomName);
    if (room == null) return;

    if (_useMockData) {
      updateRoom({
        'room': roomName,
        'brand': brand,
        'batas_atas': batasAtas,
        'batas_bawah': batasBawah,
      });
      return;
    }

    final roomId = _toInt(room['id']);
    if (roomId == null) return;

    await apiService.updateDeviceSettings(
      roomId: roomId,
      merkAc: brand,
      batasAtas: batasAtas,
      batasBawah: batasBawah,
    );

    await loadRoomsFromBackend();
  }

  Future<void> startIrCloneLearning({
    required String roomName,
    required String target,
  }) async {
    final room = _findRoom(roomName);
    if (room == null) return;

    if (_useMockData) {
      updateRoom({
        'room': roomName,
        'ir_learning_state': 'LEARNING',
        'ir_learning_target': target.toUpperCase(),
      });
      return;
    }

    final roomId = _toInt(room['id']);
    if (roomId == null) return;

    await apiService.startIrLearning(roomId: roomId, target: target);
    await loadRoomsFromBackend();
  }

  void sendCommand(String roomName, String command) {
    if (_useMockData) {
      _handleMockCommand(roomName, command);
    } else {
      unawaited(_sendCommandToBackend(roomName, command));
    }
  }

  Future<void> _sendCommandToBackend(String roomName, String command) async {
    final room = _findRoom(roomName);
    if (room == null) return;

    final roomId = _toInt(room['id']);
    if (roomId == null) return;

    try {
      if (command == 'ON' || command == 'OFF') {
        await apiService.setPower(roomId: roomId, status: command);
      } else if (command.startsWith('MODE:')) {
        final mode = command.split(':').last;
        await apiService.setControlMode(roomId: roomId, mode: mode);
      } else if (command.startsWith('COOLING:')) {
        final modeAc = command.split(':').last;
        await apiService.setCoolingMode(roomId: roomId, modeAc: modeAc);
      }

      await loadRoomsFromBackend();
    } catch (e) {
      debugPrint('Error sending command to backend: $e');
      rethrow;
    }
  }

  Future<List<Map<String, String>>> getHistoryViewData({int page = 1, int limit = 20}) async {
    if (_useMockData) {
      return [
        {
          'room': 'Ruang Dosen 1',
          'action': 'AC Dinyalakan',
          'mode': 'AUTO',
          'temp': '24°C',
          'time': '14:30',
          'date': 'Hari ini',
          'trigger': 'Manual',
        },
      ];
    }

    final response = await apiService.getHistory(page: page, limit: limit);
    final rows = (response['data'] as List<dynamic>? ?? []);

    return rows.map<Map<String, String>>((item) {
      final row = item as Map<String, dynamic>;
      final waktuStr = row['waktu']?.toString() ?? '';
      
      /// Parse datetime dengan handling timezone
      /// Database kirim waktu lokal tanpa timezone (UTC+7)
      /// DateTime.tryParse() anggap UTC, jadi kita perlu correction
      DateTime? waktu;
      if (waktuStr.isNotEmpty) {
        try {
          // Parse sebagai UTC (default behavior)
          final parsed = DateTime.parse(waktuStr);
          // Hitung offset timezone system saat ini
          final now = DateTime.now();
          final offsetFromUtc = now.difference(now.toUtc());
          // Kurangi offset untuk get true UTC time
          // Karena database kirim lokal tapi parsed sebagai UTC
          final trueUtc = parsed.subtract(offsetFromUtc);
          // Konversi ke lokal untuk display
          waktu = trueUtc.toLocal();
        } catch (e) {
          waktu = null;
        }
      }
      
      final action = row['action']?.toString() ?? '-';

      return {
        'room': row['nama_ruangan']?.toString() ?? '-',
        'action': action,
        'mode': _extractMode(action),
        'temp': '${row['suhu_tercatat'] ?? '-'}°C',
        'time': waktu != null
            ? '${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}'
            : '-',
        'date': _formatDateLabel(waktu),
        'trigger': row['pemicu']?.toString() ?? '-',
      };
    }).toList();
  }

  String _extractMode(String action) {
    if (action.contains('MODE TURBO')) return 'TURBO';
    if (action.contains('MODE NORMAL')) return 'NORMAL';
    if (action == 'ON' || action == 'OFF') return '-';
    return 'AUTO';
  }

  String _formatDateLabel(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  void _handleMockCommand(String roomName, String command) {
    final index = rooms.indexWhere((r) => r['room'] == roomName);
    if (index == -1) return;

    final room = rooms[index];
    
    switch (command) {
      case 'ON':
        room['ac_status'] = 'ON';
        break;
      case 'OFF':
        room['ac_status'] = 'OFF';
        break;
      case 'AUTO':
      case 'MANUAL':
      case 'ECO':
      case 'TURBO':
        room['mode'] = command;
        break;
      default:
        if (command.startsWith('SET_TEMP:')) {
          final temp = int.tryParse(command.split(':')[1]);
          if (temp != null) {
            room['target_temp'] = temp;
          }
        }
    }
    
    notifyListeners();
  }

  void toggleMqttMode() {
    _useMockData = !_useMockData;
    _mockDataTimer?.cancel();
    rooms.clear();
    
    if (_useMockData) {
      _startMockData();
    } else {
      _connectMqtt();
    }
  }

  @override
  void dispose() {
    _mockDataTimer?.cancel();
    _socket?.dispose();
    mqttService.disconnect();
    super.dispose();
  }
}