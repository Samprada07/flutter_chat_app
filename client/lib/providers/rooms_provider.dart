import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/api_service.dart';

class RoomsProvider extends ChangeNotifier {
  List<Room> _rooms = [];
  bool _isLoading = false;
  String? _error;

  List<Room> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch all rooms
  Future<void> fetchRooms(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.getRooms(token);
      _rooms = data.map((r) => Room.fromJson(r)).toList();
    } catch (e) {
      _error = 'Failed to load rooms';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Create a room
  Future<bool> createRoom(String token, String name) async {
    try {
      final data = await ApiService.createRoom(token, name);

      if (data['error'] != null) {
        _error = data['error'];
        notifyListeners();
        return false;
      }

      await fetchRooms(token);
      return true;
    } catch (e) {
      _error = 'Failed to create room';
      notifyListeners();
      return false;
    }
  }

  // Join a room
  Future<bool> joinRoom(String token, int roomId) async {
    try {
      final data = await ApiService.joinRoom(token, roomId);

      if (data['error'] != null) {
        _error = data['error'];
        notifyListeners();
        return false;
      }

      await fetchRooms(token);
      return true;
    } catch (e) {
      _error = 'Failed to join room';
      notifyListeners();
      return false;
    }
  }
}
