import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _error;
  bool _isLoading = false;

  User? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  // Register
  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.register(
        username: username,
        email: email,
        password: password,
      );

      if (data['error'] != null) {
        _error = data['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = User.fromJson(data['user'], data['token']);
      await _saveToken(data['token']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Connection error. Is the server running?';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.login(email: email, password: password);

      if (data['error'] != null) {
        _error = data['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = User.fromJson(data['user'], data['token']);
      await _saveToken(data['token']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Connection error. Is the server running?';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }

  // Save token locally
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
}
