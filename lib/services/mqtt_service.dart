import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:async';
import 'dart:math';

enum MqttConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class MqttService {
  MqttServerClient? client;
  
  MqttConnectionStatus connectionStatus = MqttConnectionStatus.disconnected;
  Function(String topic, String message)? onMessage;
  Function(MqttConnectionStatus)? onConnectionStatusChanged;
  
  String? lastError;

  // Configuration
  static const String broker = 'broker.emqx.io';
  static const int port = 1883;
  static const String clientIdPrefix = 'smart_ac_flutter_';

  String get clientId => '$clientIdPrefix${Random().nextInt(10000)}';

  Future<bool> connect() async {
    if (connectionStatus == MqttConnectionStatus.connecting) {
      return false;
    }

    _updateStatus(MqttConnectionStatus.connecting);

    try {
      client = MqttServerClient(broker, clientId);
      client!.port = port;
      client!.keepAlivePeriod = 60;
      client!.autoReconnect = true;
      client!.resubscribeOnAutoReconnect = true;
      client!.logging(on: false);
      
      // Set connection timeout
      client!.connectTimeoutPeriod = 5000;

      // Setup connection callbacks
      client!.onConnected = _onConnected;
      client!.onDisconnected = _onDisconnected;
      client!.onAutoReconnect = _onAutoReconnect;
      client!.onAutoReconnected = _onAutoReconnected;

      // Connection message
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      client!.connectionMessage = connMessage;

      await client!.connect();

      if (client!.connectionStatus!.state == MqttConnectionState.connected) {
        _updateStatus(MqttConnectionStatus.connected);
        _setupListener();
        return true;
      } else {
        _updateStatus(MqttConnectionStatus.error);
        lastError = 'Connection failed: ${client!.connectionStatus!.state}';
        return false;
      }
    } catch (e) {
      _updateStatus(MqttConnectionStatus.error);
      lastError = 'Connection error: $e';
      debugPrint('MQTT Connection Error: $e');
      client?.disconnect();
      return false;
    }
  }

  void _onConnected() {
    debugPrint('MQTT Connected to $broker:$port');
    _updateStatus(MqttConnectionStatus.connected);
  }

  void _onDisconnected() {
    debugPrint('MQTT Disconnected');
    _updateStatus(MqttConnectionStatus.disconnected);
  }

  void _onAutoReconnect() {
    debugPrint('MQTT Auto Reconnecting...');
    _updateStatus(MqttConnectionStatus.connecting);
  }

  void _onAutoReconnected() {
    debugPrint('MQTT Auto Reconnected');
    _updateStatus(MqttConnectionStatus.connected);
  }

  void _updateStatus(MqttConnectionStatus status) {
    connectionStatus = status;
    onConnectionStatusChanged?.call(status);
  }

  void subscribe(String topic) {
    if (client == null || connectionStatus != MqttConnectionStatus.connected) {
      debugPrint('Cannot subscribe: Not connected');
      return;
    }
    
    try {
      client!.subscribe(topic, MqttQos.atLeastOnce);
      debugPrint('Subscribed to: $topic');
    } catch (e) {
      debugPrint('Subscribe error: $e');
    }
  }

  void unsubscribe(String topic) {
    if (client == null) return;
    
    try {
      client!.unsubscribe(topic);
      debugPrint('Unsubscribed from: $topic');
    } catch (e) {
      debugPrint('Unsubscribe error: $e');
    }
  }

  void publish(String topic, String message, {bool retain = false}) {
    if (client == null || connectionStatus != MqttConnectionStatus.connected) {
      debugPrint('Cannot publish: Not connected');
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      
      client!.publishMessage(
        topic, 
        MqttQos.atLeastOnce, 
        builder.payload!,
        retain: retain,
      );
      debugPrint('Published to $topic: $message');
    } catch (e) {
      debugPrint('Publish error: $e');
    }
  }

  void _setupListener() {
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (var event in events) {
        final recMess = event.payload as MqttPublishMessage;
        final topic = event.topic;
        final message = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        
        debugPrint('Received on $topic: $message');
        onMessage?.call(topic, message);
      }
    });
  }

  void disconnect() {
    if (client != null) {
      client!.disconnect();
      _updateStatus(MqttConnectionStatus.disconnected);
    }
  }

  bool get isConnected => connectionStatus == MqttConnectionStatus.connected;
}