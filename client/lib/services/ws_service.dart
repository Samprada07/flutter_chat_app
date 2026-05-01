import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

class WsService {
  // Single instance of WsService (singleton pattern)
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  // The WebSocket channel used for sending and receiving messages
  WebSocketChannel? _channel;

  // Broadcast stream for all incoming messages
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Tracks online status of users by their ID
  // { userId: true/false }
  final Map<int, bool> _onlineUsers = {};

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ─── Check if User is Online ─────────────────────────────────────────────
  // Returns true if the user is currently online
  bool isUserOnline(int userId) {
    return _onlineUsers[userId] ?? false;
  }

  // ─── Connect ─────────────────────────────────────────────────────────────
  void connect(String token) {
    // Avoid duplicate connections
    if (_isConnected) {
      print('WebSocket already connected');
      return;
    }

    try {
      // Connect to the server WebSocket endpoint with token in query string
      // Android emulator uses 10.0.2.2 to reach the host machine's localhost
      final wsBase = Config.baseUrl
          .replaceFirst('http', 'ws')
          .replaceFirst('/api', '');

      final uri = Uri.parse('$wsBase?token=$token');
      print('Connecting to WebSocket: $uri');
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      print('WebSocket connected');

      // Listen for all incoming messages from the server
      _channel!.stream.listen(
        (data) {
          // Decode the raw JSON string into a Map
          final message = jsonDecode(data) as Map<String, dynamic>;
          print('WS received: $message');

          // Handle presence updates internally
          if (message['type'] == 'presence_update') {
            _updatePresence(message);
          }

          // Handle initial online users list sent on connection
          if (message['type'] == 'online_users') {
            final userIds = List<int>.from(message['userIds']);
            for (final id in userIds) {
              _onlineUsers[id] = true;
            }
          }

          // Push all messages to broadcast stream
          _messageController.add(message);
        },

        // Called when the connection is closed by the server
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
        },

        // Called when an error occurs on the stream
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
      _isConnected = false;
    }
  }

  // ─── Update Presence ─────────────────────────────────────────────────────
  // Updates the online status map when a presence_update event arrives
  void _updatePresence(Map<String, dynamic> data) {
    final userId = data['userId'] as int;
    final isOnline = data['isOnline'] as bool;
    _onlineUsers[userId] = isOnline;
    print('Presence update: userId=$userId isOnline=$isOnline');
  }

  // ─── Join Room ────────────────────────────────────────────────────────────
  void joinRoom(int roomId) {
    _send({'type': 'join_room', 'roomId': roomId});
  }

  // ─── Leave Room ───────────────────────────────────────────────────────────
  void leaveRoom(int roomId) {
    _send({'type': 'leave_room', 'roomId': roomId});
  }

  // ─── Send Room Message ────────────────────────────────────────────────────
  void sendMessage(int roomId, String content) {
    _send({'type': 'send_message', 'roomId': roomId, 'content': content});
  }

  // ─── Send Direct Message ──────────────────────────────────────────────────
  void sendDirectMessage(int receiverId, String content) {
    _send({
      'type': 'send_direct_message',
      'receiverId': receiverId,
      'content': content,
    });
  }

  // ─── Internal Send Helper ─────────────────────────────────────────────────
  void _send(Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) {
      print('Cannot send: WebSocket not connected');
      return;
    }
    final encoded = jsonEncode(data);
    print('WS sending: $encoded');
    _channel!.sink.add(encoded);
  }

  // ─── Disconnect ───────────────────────────────────────────────────────────
  // Called on logout — closes the WebSocket connection cleanly
  // and resets the connection state
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _onlineUsers.clear();
    print('WebSocket disconnected');
  }
}
