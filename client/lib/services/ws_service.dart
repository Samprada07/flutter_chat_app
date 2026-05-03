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

  // ─── Reconnection State ───────────────────────────────────────────────────
  // Stores the token for reconnection attempts
  String? _savedToken;

  // Timer for scheduling reconnection attempts
  Timer? _reconnectTimer;

  // Current reconnection attempt count
  int _reconnectAttempts = 0;

  // Maximum number of reconnection attempts before giving up
  static const int _maxReconnectAttempts = 5;

  // Delay between reconnection attempts in seconds
  // Doubles each attempt (exponential backoff)
  static const int _reconnectDelay = 2;

  // ─── Check if User is Online ──────────────────────────────────────────────
  bool isUserOnline(int userId) => _onlineUsers[userId] ?? false;

  // ─── Connect ──────────────────────────────────────────────────────────────
  // Connects to the WebSocket server with the given token
  // Saves the token for automatic reconnection
  void connect(String token) {
    // Avoid duplicate connections
    if (_isConnected) {
      print('WebSocket already connected');
      return;
    }

    // Save token for reconnection attempts
    _savedToken = token;
    _connectInternal(token);
  }

  // ─── Internal Connect ─────────────────────────────────────────────────────
  // Handles the actual WebSocket connection logic
  // Called by connect() and reconnect()
  void _connectInternal(String token) {
    try {
      final wsBase = Config.baseUrl
          .replaceFirst('http', 'ws')
          .replaceFirst('/api', '');

      final uri = Uri.parse('$wsBase?token=$token');
      print('Connecting to WebSocket: $uri');

      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _reconnectAttempts = 0; // Reset attempts on successful connection

      print('WebSocket connected');

      // Listen for all incoming messages from the server
      _channel!.stream.listen(
        (data) {
          // Decode the raw JSON string into a Map
          final message = jsonDecode(data) as Map<String, dynamic>;
          print('WS received: $message');

          // Handle presence update internally
          if (message['type'] == 'presence_update') {
            _updatePresence(message);
          }

          // Handle initial online users list
          if (message['type'] == 'online_users') {
            final userIds = List<int>.from(message['userIds']);
            for (final id in userIds) {
              _onlineUsers[id] = true;
            }
          }

          // Push all messages to broadcast stream
          _messageController.add(message);
        },

        // ─── Connection Closed ─────────────────────────────────────────
        // Triggered when server closes the connection
        // Attempts to reconnect automatically
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },

        // ─── Connection Error ──────────────────────────────────────────
        // Triggered when a network error occurs
        // Attempts to reconnect automatically
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  // ─── Schedule Reconnect ───────────────────────────────────────────────────
  // Schedules a reconnection attempt with exponential backoff
  // Gives up after _maxReconnectAttempts attempts
  void _scheduleReconnect() {
    // Don't reconnect if no token saved (user logged out)
    if (_savedToken == null) return;

    // Give up after max attempts
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Max reconnection attempts reached. Giving up.');
      return;
    }

    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();

    // Calculate delay with exponential backoff
    // Attempt 1: 2s, Attempt 2: 4s, Attempt 3: 8s, etc.
    final delay = _reconnectDelay * (1 << _reconnectAttempts);
    _reconnectAttempts++;

    print(
      'Scheduling reconnect attempt $_reconnectAttempts '
      'in ${delay}s...',
    );

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_savedToken != null && !_isConnected) {
        print('Attempting reconnect $_reconnectAttempts...');
        _connectInternal(_savedToken!);
      }
    });
  }

  // ─── Update Presence ──────────────────────────────────────────────────────
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
  // Called on logout — cancels reconnection and clears state
  void disconnect() {
    // Cancel any scheduled reconnection
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Clear saved token so reconnection doesn't trigger
    _savedToken = null;
    _reconnectAttempts = 0;

    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }

    _isConnected = false;
    _onlineUsers.clear();
    print('WebSocket disconnected');
  }
}
