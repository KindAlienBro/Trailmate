import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// User model
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String? phone;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      phone: json['phone'],
    );
  }
}

/// Authentication Service
///
/// Handles registration, login, token storage, and auto-login.
class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  UserModel? _currentUser;

  String? get token => _token;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null;

  /// Get authorization headers
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Register a new user
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.registerEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        _token = data['token'];
        _currentUser = UserModel.fromJson(data['user']);
        await _saveCredentials();
        return {'success': true, 'user': _currentUser};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      debugPrint('Register error: $e');
      return {'success': false, 'error': 'Network error. Is the server running?'};
    }
  }

  /// Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.loginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['token'];
        _currentUser = UserModel.fromJson(data['user']);
        await _saveCredentials();
        return {'success': true, 'user': _currentUser};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return {'success': false, 'error': 'Network error. Is the server running?'};
    }
  }

  /// Try to restore session from secure storage
  Future<bool> tryAutoLogin() async {
    try {
      _token = await _storage.read(key: AppConstants.tokenKey);
      if (_token == null) return false;

      // Verify token is still valid
      final response = await http.get(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.profileEndpoint}'),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = UserModel.fromJson(data['user']);
        return true;
      } else {
        await logout();
        return false;
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
      return false;
    }
  }

  /// Logout — clear token and user data
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _storage.deleteAll();
  }

  /// Save credentials to secure storage
  Future<void> _saveCredentials() async {
    if (_token != null) {
      await _storage.write(key: AppConstants.tokenKey, value: _token);
    }
    if (_currentUser != null) {
      await _storage.write(key: AppConstants.userIdKey, value: _currentUser!.id);
      await _storage.write(key: AppConstants.userNameKey, value: _currentUser!.name);
      await _storage.write(key: AppConstants.userEmailKey, value: _currentUser!.email);
    }
  }
}
