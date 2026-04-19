import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';

class ChatProvider extends ChangeNotifier {
  // List of messages currently displayed in the chat screen
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  // WebSocket service singleton for real-time messaging
  final _wsService = WsService();

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── Load Room Messages ──────────────────────────────────────────────────
  // Fetches message history from REST API when chat screen opens
  // Then joins the WebSocket room for real-time updates
  Future<void> loadRoomMessages(String token, int roomId) async {
    _isLoading = true;
    _messages = [];
    _error = null;
    notifyListeners();

    try {
      // Fetch existing messages from backend
      final data = await ApiService.getRoomMessages(token, roomId);
      _messages = data.map((m) => Message.fromJson(m)).toList();

      // Join WebSocket room for real-time new messages
      _wsService.joinRoom(roomId);
    } catch (e) {
      _error = 'Failed to load messages';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Add Incoming Message ────────────────────────────────────────────────
  // Called when a new message arrives via WebSocket
  // Adds it to the list and notifies UI to rebuild
  void addMessage(Message message) {
    _messages.add(message);
    notifyListeners();
  }

  // ─── Send Room Message ───────────────────────────────────────────────────
  // Sends a message through WebSocket to the room
  // The server broadcasts it back to all members including sender
  void sendRoomMessage(int roomId, String content) {
    _wsService.sendMessage(roomId, content);
  }

  // ─── Leave Room ──────────────────────────────────────────────────────────
  // Called when user leaves the chat screen
  // Cleans up messages and leaves the WebSocket room
  void leaveRoom(int roomId) {
    _wsService.leaveRoom(roomId);
    _messages = [];
    notifyListeners();
  }

  // ─── Clear Messages ──────────────────────────────────────────────────────
  // Resets the message list when switching rooms
  void clearMessages() {
    _messages = [];
    notifyListeners();
  }
}
