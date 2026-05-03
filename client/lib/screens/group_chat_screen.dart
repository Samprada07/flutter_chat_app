import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/ws_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/connection_banner.dart';

class GroupChatScreen extends StatefulWidget {
  final Room room;

  const GroupChatScreen({super.key, required this.room});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();

  // ScrollController to auto-scroll to latest message
  final _scrollController = ScrollController();

  // WsService singleton for real-time messaging
  final _wsService = WsService();

  @override
  void initState() {
    super.initState();

    // Load existing messages and join WebSocket room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<ChatProvider>().loadRoomMessages(token, widget.room.id);

      // Listen for incoming WebSocket messages
      _listenToMessages();
    });
  }

  // ─── Listen to WebSocket Messages ───────────────────────────────────────
  // Subscribes to the WebSocket stream and handles incoming events
  void _listenToMessages() {
    _wsService.messageStream.listen((data) {
      if (!mounted) return;

      // Handle new chat message broadcast from server
      if (data['type'] == 'new_message' && data['roomId'] == widget.room.id) {
        final message = Message(
          id: data['id'],
          senderId: data['senderId'],
          senderName: data['senderName'],
          content: data['content'],
          createdAt: data['createdAt'].toString(),
        );

        // Add message to provider and scroll to bottom
        context.read<ChatProvider>().addMessage(message);
        _scrollToBottom();
      }
    });
  }

  // ─── Send Message ────────────────────────────────────────────────────────
  // Sends the typed message through WebSocket and clears the input
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<ChatProvider>().sendRoomMessage(widget.room.id, content);
    _messageController.clear();
  }

  // ─── Scroll to Bottom ────────────────────────────────────────────────────
  // Auto-scrolls to the latest message after it's added
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    // Leave the WebSocket room when screen is closed
    context.read<ChatProvider>().leaveRoom(widget.room.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();
    final currentUserId = auth.user?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // Room avatar
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                widget.room.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room name
                Text(widget.room.name, style: const TextStyle(fontSize: 16)),
                // Member count
                Text(
                  '${widget.room.memberCount} members',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),

      // ─── Messages List ─────────────────────────────────────────────────
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: chat.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nSay hello! 👋',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Container(
                    // Light grey background like WhatsApp
                    color: Colors.grey.shade100,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, index) {
                        final message = chat.messages[index];
                        // Determine if message was sent by current user
                        final isMe = message.senderId == currentUserId;
                        return MessageBubble(message: message, isMe: isMe);
                      },
                    ),
                  ),
          ),

          // ─── Message Input Bar ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Text input field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    // Send on keyboard submit
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
