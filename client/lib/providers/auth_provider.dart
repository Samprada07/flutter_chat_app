import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart'; // Import WsService

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
}
