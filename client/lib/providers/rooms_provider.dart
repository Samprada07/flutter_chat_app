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

  void _notify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Fetch all rooms
  Future<void> fetchRooms(String token) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await ApiService.getRooms(token);
      _rooms = data.map((r) => Room.fromJson(r)).toList();
    } catch (e) {
      _error = 'Failed to load rooms';
    }

    _isLoading = false;
    _notify();
  }

  // Create a room
  Future<bool> createRoom(String token, String name) async {
    try {
      final data = await ApiService.createRoom(token, name);

      if (data['error'] != null) {
        _error = data['error'];
        _notify();
        return false;
      }

      await fetchRooms(token);
      return true;
    } catch (e) {
      _error = 'Failed to create room';
      _notify();
      return false;
    }
  }

  // Join a room
  Future<bool> joinRoom(String token, int roomId) async {
    try {
      final data = await ApiService.joinRoom(token, roomId);

      if (data['error'] != null) {
        _error = data['error'];
        _notify();
        return false;
      }

      await fetchRooms(token);
      return true;
    } catch (e) {
      _error = 'Failed to join room';
      _notify();
      return false;
    }
  }

  Future<bool> isRoomMember(String token, int roomId, int userId) async {
    try {
      final data = await ApiService.getMyRooms(token);
      return data.any((r) => r['id'] == roomId);
    } catch (e) {
      return false;
    }
  }
}
