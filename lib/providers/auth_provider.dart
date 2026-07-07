import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Auth state management using ChangeNotifier (Provider pattern)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _authService.isLoggedIn;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _authService.currentUser;
  String? get token => _authService.token;
  AuthService get authService => _authService;

  /// Initialize — try auto-login from stored credentials
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _authService.tryAutoLogin();

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  /// Register a new account
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.register(
      name: name,
      email: email,
      password: password,
    );

    _isLoading = false;

    if (result['success'] == true) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['error'];
      notifyListeners();
      return false;
    }
  }

  /// Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.login(
      email: email,
      password: password,
    );

    _isLoading = false;

    if (result['success'] == true) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['error'];
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _authService.logout();
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
