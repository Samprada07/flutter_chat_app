import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/contact.dart';
import '../providers/auth_provider.dart';
import '../providers/direct_messages_provider.dart';
import '../services/ws_service.dart';
import '../widgets/message_bubble.dart';

class DirectMessageScreen extends StatefulWidget {
  // The contact we are chatting with
  final Contact contact;

  const DirectMessageScreen({super.key, required this.contact});

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  final _messageController = TextEditingController();

  // ScrollController to auto scroll to latest message
  final _scrollController = ScrollController();

  // WebSocket service singleton
  final _wsService = WsService();

  @override
  void initState() {
    super.initState();

    // Load message history and start listening for new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<DirectMessagesProvider>().loadMessages(
        token,
        widget.contact.userId,
      );

      // Listen for incoming WebSocket direct messages
      _listenToMessages();
    });
  }

  // ─── Listen to WebSocket Messages ───────────────────────────────────────
  // Subscribes to WebSocket stream and filters for direct messages
  // belonging to this conversation
  void _listenToMessages() {
    _wsService.messageStream.listen((data) {
      if (!mounted) return;

      // Handle incoming direct message from server
      if (data['type'] == 'new_direct_message') {
        final message = Message(
          id: data['id'],
          senderId: data['senderId'],
          senderName: data['senderName'],
          content: data['content'],
          createdAt: data['createdAt'].toString(),
        );

        // Add message only if it's from the current contact
        context.read<DirectMessagesProvider>().addMessage(
          message,
          widget.contact.userId,
        );

        // Scroll to bottom after new message arrives
        _scrollToBottom();
      }
    });
  }

  // ─── Send Message ────────────────────────────────────────────────────────
  // Sends message through WebSocket and updates conversation preview
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final auth = context.read<AuthProvider>();

    // Send through WebSocket
    context.read<DirectMessagesProvider>().sendMessage(
      widget.contact.userId,
      content,
    );

    // Add message locally so sender sees it immediately
    // without waiting for server echo
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch,
      senderId: auth.user?.id ?? 0,
      senderName: auth.user?.username ?? '',
      content: content,
      createdAt: DateTime.now().toIso8601String(),
    );

    context.read<DirectMessagesProvider>().addMessage(
      message,
      auth.user?.id ?? 0,
    );

    // Update conversation preview in the chats list
    context.read<DirectMessagesProvider>().updateConversationPreview(
      widget.contact.userId,
      widget.contact.username,
      content,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  // ─── Scroll to Bottom ────────────────────────────────────────────────────
  // Auto scrolls to latest message after it's added to the list
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
    // Clear messages when leaving the screen
    context.read<DirectMessagesProvider>().clearMessages();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dm = context.watch<DirectMessagesProvider>();
    final currentUserId = auth.user?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // Contact avatar with first letter of username
            CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Text(
                widget.contact.username[0].toUpperCase(),
                style: const TextStyle(color: Colors.green),
              ),
            ),
            const SizedBox(width: 10),
            // Contact username
            Text(widget.contact.username, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),

      body: Column(
        children: [
          // ─── Messages List ───────────────────────────────────────────
          Expanded(
            child: dm.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : dm.messages.isEmpty
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
                      itemCount: dm.messages.length,
                      itemBuilder: (context, index) {
                        final message = dm.messages[index];
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
