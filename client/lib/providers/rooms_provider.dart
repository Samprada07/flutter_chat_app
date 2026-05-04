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

  // list to store joined room IDs locally
  List<int> _myRoomIds = [];

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

      // Also fetch and cache my room IDs
      final myRooms = await ApiService.getMyRooms(token);
      _myRoomIds = myRooms.map<int>((r) => r['id'] as int).toList();
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
    // Use cached list — no API call needed
    return _myRoomIds.contains(roomId);
  }
}
