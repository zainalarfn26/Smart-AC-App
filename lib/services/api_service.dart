import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _tokenStorageKey = 'auth_token';

  // Prioritas URL:
  // 1) --dart-define=BACKEND_URL=http://ip-server:3000
  // 2) Android emulator -> 10.0.2.2:3000
  // 3) lainnya -> localhost:3000
  final String baseUrl = const String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  ).isNotEmpty
      ? const String.fromEnvironment('BACKEND_URL')
      : (kIsWeb
          ? 'http://localhost:3000'
          : (defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:3000'
              : 'http://localhost:3000'));

  String get socketUrl => baseUrl;
  String? get token => _token;

  String? _token;

  Future<void> loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenStorageKey);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
  }

  Future<bool> login({required String email, required String password}) async {
    final response = await _request(
      method: 'POST',
      path: '/api/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      requiresAuth: false,
    );

    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan pada response login.');
    }

    await setToken(token);
    return true;
  }

  Future<bool> register({
    required String nama,
    required String email,
    required String password,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/api/auth/register',
      body: {
        'nama': nama,
        'email': email,
        'password': password,
      },
      requiresAuth: false,
    );

    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan pada response register.');
    }

    await setToken(token);
    return true;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    return await _request(method: 'GET', path: '/api/auth/me') as Map<String, dynamic>;
  }

  Future<bool> hasSavedToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return true;
    }

    await loadSavedToken();
    return _token != null && _token!.isNotEmpty;
  }

  Future<List<dynamic>> getDevices() async {
    return await _request(method: 'GET', path: '/api/devices') as List<dynamic>;
  }

  Future<void> createDevice({
    required String nama,
    required String deviceId,
    required int batasAtas,
    required int batasBawah,
    required String merkAc,
  }) async {
    await _request(
      method: 'POST',
      path: '/api/devices',
      body: {
        'nama': nama,
        'device_id': deviceId,
        'batas_atas': batasAtas,
        'batas_bawah': batasBawah,
        'merk_ac': merkAc.toUpperCase(),
      },
    );
  }

  Future<void> updateDeviceSettings({
    required int roomId,
    required String merkAc,
    required int batasAtas,
    required int batasBawah,
  }) async {
    await _request(
      method: 'PUT',
      path: '/api/devices/$roomId',
      body: {
        'merk_ac': merkAc.toUpperCase(),
        'batas_atas': batasAtas,
        'batas_bawah': batasBawah,
      },
    );
  }

  Future<void> deleteDevice(int roomId) async {
    await _request(method: 'DELETE', path: '/api/devices/$roomId');
  }

  Future<void> setControlMode({required int roomId, required String mode}) async {
    await _request(
      method: 'POST',
      path: '/api/devices/$roomId/mode',
      body: {'mode': mode.toUpperCase()},
    );
  }

  Future<void> setPower({required int roomId, required String status}) async {
    await _request(
      method: 'POST',
      path: '/api/devices/$roomId/power',
      body: {'status': status.toUpperCase()},
    );
  }

  Future<void> setCoolingMode({required int roomId, required String modeAc}) async {
    await _request(
      method: 'POST',
      path: '/api/devices/$roomId/mode-ac',
      body: {'mode_ac': modeAc.toUpperCase()},
    );
  }

  Future<void> startIrLearning({required int roomId, required String target}) async {
    await _request(
      method: 'POST',
      path: '/api/devices/$roomId/ir/learn',
      body: {'target': target.toUpperCase()},
    );
  }

  Future<Map<String, dynamic>> getHistory({int page = 1, int limit = 20}) async {
    return await _request(
      method: 'GET',
      path: '/api/history?page=$page&limit=$limit',
    ) as Map<String, dynamic>;
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
    };

    if (requiresAuth && (headers['Authorization'] == null || headers['Authorization']!.isEmpty)) {
      throw Exception(
        'Token auth belum tersedia. Login dulu atau set token ke ApiService.',
      );
    }

    late http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('HTTP method tidak didukung: $method');
    }

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverError = decoded is Map<String, dynamic>
          ? decoded['error']?.toString() ?? 'Request gagal'
          : 'Request gagal';
      throw Exception('[$method $path] ${response.statusCode}: $serverError');
    }

    return decoded;
  }
}