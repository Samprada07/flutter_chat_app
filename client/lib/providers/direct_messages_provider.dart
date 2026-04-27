import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';

class DirectMessagesProvider extends ChangeNotifier {
  // List of all conversations shown in Chats tab
  List<Conversation> _conversations = [];

  // Messages for the currently open direct chat
  List<Message> _messages = [];

  bool _isLoading = false;
  bool _isLoadingMessages = false;
  String? _error;

  // WebSocket service singleton for real-time messaging
  final _wsService = WsService();

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get error => _error;

  // ─── Total Unread Count ───────────────────────────────────────────────────
  // Returns total number of conversations with unread messages
  // Used to show badge on the Chats tab icon in bottom navigation
  int get totalUnreadCount {
    return _conversations.where((c) => c.unreadCount > 0).length;
  }

  // ─── Fetch Conversations ─────────────────────────────────────────────────
  // Loads all conversation summaries for the Chats tab
  // Each conversation shows the last message and unread count
  Future<void> fetchConversations(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.getConversations(token);
      _conversations = data.map((c) => Conversation.fromJson(c)).toList();
    } catch (e) {
      _error = 'Failed to load conversations';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Load Direct Messages ────────────────────────────────────────────────
  // Loads full message history with a specific contact
  // Called when user opens a direct chat screen
  Future<void> loadMessages(String token, int contactId) async {
    _isLoadingMessages = true;
    _messages = [];
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.getConversation(token, contactId);
      _messages = data.map((m) => Message.fromJson(m)).toList();
    } catch (e) {
      _error = 'Failed to load messages';
    }

    _isLoadingMessages = false;
    notifyListeners();
  }

  // ─── Send Direct Message ─────────────────────────────────────────────────
  // Sends a direct message through WebSocket to a specific user
  // The server saves it and broadcasts it back to both users
  void sendMessage(int receiverId, String content) {
    _wsService.sendDirectMessage(receiverId, content);
  }

  // ─── Add Incoming Message ────────────────────────────────────────────────
  // Called when a new direct message arrives via WebSocket
  // Only adds the message if it belongs to the current conversation
  void addMessage(Message message, int currentContactId) {
    // Check if message belongs to the currently open conversation
    if (message.senderId == currentContactId) {
      _messages.add(message);
      notifyListeners();
    }
  }

  // ─── Update Conversation Preview ─────────────────────────────────────────
  // Updates the last message preview and increments unread count
  // when a new message arrives while the chat screen is not open
  void updateConversationPreview(
    int userId,
    String username,
    String lastMessage, {
    bool incrementUnread = true,
  }) {
    final index = _conversations.indexWhere((c) => c.userId == userId);

    if (index != -1) {
      final existing = _conversations[index];
      // Remove and re-insert at top (like WhatsApp)
      _conversations.removeAt(index);
      _conversations.insert(
        0,
        Conversation(
          userId: userId,
          username: username,
          lastMessage: lastMessage,
          lastMessageAt: DateTime.now().toIso8601String(),
          // Increment unread count only for received messages
          unreadCount: incrementUnread ? existing.unreadCount + 1 : 0,
        ),
      );
    } else {
      // Add new conversation at top if it doesn't exist yet
      _conversations.insert(
        0,
        Conversation(
          userId: userId,
          username: username,
          lastMessage: lastMessage,
          lastMessageAt: DateTime.now().toIso8601String(),
          unreadCount: incrementUnread ? 1 : 0,
        ),
      );
    }
    notifyListeners();
  }

  // ─── Clear Messages ──────────────────────────────────────────────────────
  // Clears messages when leaving a direct chat screen
  void clearMessages() {
    _messages = [];
    notifyListeners();
  }
}
