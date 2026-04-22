import 'dart:async';
import 'dart:convert';
import '../config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsService {
  // Single instance of WsService (singleton pattern)
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  // The WebSocket channel used for sending and receiving messages
  WebSocketChannel? _channel;

  // StreamController broadcasts all incoming messages to listeners
  // We use a broadcast stream so multiple screens can listen at once
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  // Public stream that UI can listen to for incoming messages
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Whether the WebSocket is currently connected
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ─── Connect to WebSocket Server ─────────────────────────────────────────
  // Called once after login, passing the JWT token for authentication
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
          .replaceFirst('http', 'ws') // Convert http to ws
          .replaceFirst('/api', ''); // Remove /api suffix

      final uri = Uri.parse('$wsBase?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      print('WebSocket connected');

      // Listen for all incoming messages from the server
      _channel!.stream.listen(
        (data) {
          // Decode the raw JSON string into a Map
          final message = jsonDecode(data) as Map<String, dynamic>;
          print('WS received: $message');

          // Push the decoded message into the broadcast stream
          // All active listeners (chat screen, home screen) will receive it
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

  // ─── Join a Room ──────────────────────────────────────────────────────────
  // Sends a join_room event to the server so we start receiving
  // messages from that specific room
  void joinRoom(int roomId) {
    _send({'type': 'join_room', 'roomId': roomId});
  }

  // ─── Leave a Room ─────────────────────────────────────────────────────────
  // Sends a leave_room event to the server so we stop receiving
  // messages from that room
  void leaveRoom(int roomId) {
    _send({'type': 'leave_room', 'roomId': roomId});
  }

  // ─── Send a Message ───────────────────────────────────────────────────────
  // Sends a chat message to the server for a specific room
  // The server will save it to PostgreSQL and broadcast it to all room members
  void sendMessage(int roomId, String content) {
    _send({'type': 'send_message', 'roomId': roomId, 'content': content});
  }

  // ─── Internal Send Helper ─────────────────────────────────────────────────
  // Encodes any Map as JSON and sends it through the WebSocket channel
  // Always check connection before sending to avoid errors
  void _send(Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) {
      print('Cannot send message: WebSocket not connected');
      return;
    }

    // Encode Map to JSON string before sending
    final encoded = jsonEncode(data);
    print('WS sending: $encoded');
    _channel!.sink.add(encoded);
  }

  // ─── Send Direct Message ─────────────────────────────────────────────────
  // Sends a private message to a specific user through WebSocket
  // The server saves it to direct_messages table and delivers it
  void sendDirectMessage(int receiverId, String content) {
    _send({
      'type': 'send_direct_message',
      'receiverId': receiverId,
      'content': content,
    });
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
    print('WebSocket disconnected');
  }
}
