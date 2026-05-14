import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _error;
  bool _isLoading = false;

  // WsService singleton instance used throughout the app
  final _wsService = WsService();

  User? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  void _notify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // ─── Register ─────────────────────────────────────────────────────────────
  // Registers a new user and saves their token locally
  // Does NOT connect WebSocket — user must login separately
  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await ApiService.register(
        username: username,
        email: email,
        password: password,
      );

      if (data['error'] != null) {
        _error = data['error'];
        _isLoading = false;
        _notify();
        return false;
      }

      _isLoading = false;
      _notify();
      return true;
    } catch (e) {
      _error = 'Connection error. Is the server running?';
      _isLoading = false;
      _notify();
      return false;
    }
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  // Logs in the user, saves their token, and connects the WebSocket
  // so real-time messaging is ready as soon as they reach the home screen
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await ApiService.login(email: email, password: password);

      if (data['error'] != null) {
        _error = data['error'];
        _isLoading = false;
        _notify();
        return false;
      }

      // Store user info and token in memory
      _user = User.fromJson(data['user'], data['token']);

      // Persist token to SharedPreferences for auto-login later
      await _saveToken(data['token']);

      // Connect WebSocket immediately after login
      // This ensures real-time connection is ready before entering any room
      _wsService.connect(_user!.token);

      // Initialize push notifications with user's auth token
      await NotificationService().initialize(_user!.token);

      _isLoading = false;
      _notify();
      return true;
    } catch (e) {
      _error = 'Connection error. Is the server running?';
      _isLoading = false;
      _notify();
      return false;
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────────────
  // Clears user data, removes saved token, and disconnects WebSocket
  Future<void> logout() async {
    // Disconnect WebSocket cleanly before clearing user state
    _wsService.disconnect();

    _user = null;

    // Remove saved token from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    _notify();
  }

  // ─── Save Token ───────────────────────────────────────────────────────────
  // Persists the JWT token to SharedPreferences so the user
  // stays logged in even after closing the app
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // ─── Load User From Storage ──────────────────────────────────────────────
  // Checks if a token exists in SharedPreferences on app start
  // If found, validates it and logs the user in automatically
  Future<bool> loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      // Verify token is still valid by calling protected endpoint
      final response = await ApiService.validateToken(token);

      if (response['error'] != null) {
        // Token expired or invalid — clear it
        await prefs.remove('token');
        return false;
      }

      // Token valid — restore user session
      _user = User.fromJson(response['user'], token);

      // Reconnect WebSocket with saved token
      _wsService.connect(token);

      // Reinitialize push notifications
      await NotificationService().initialize(token);

      notifyListeners();
      return true;
    } catch (e) {
      print('Auto login failed: $e');
      return false;
    }
  }
}
