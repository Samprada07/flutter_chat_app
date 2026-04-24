import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/direct_messages_provider.dart';
import '../providers/contacts_provider.dart';
import '../models/contact.dart';
import '../services/ws_service.dart';
import '../widgets/conversation_tile.dart';
import 'direct_message_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _wsService = WsService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<DirectMessagesProvider>().fetchConversations(token);

      // Listen for incoming direct messages to update conversation list
      _listenToMessages();
    });
  }

  // ─── Listen to WebSocket Messages ───────────────────────────────────────
  // Updates conversation preview in real-time when a new
  // direct message arrives even if the chat screen is not open
  void _listenToMessages() {
    _wsService.messageStream.listen((data) {
      if (!mounted) return;

      if (data['type'] == 'new_direct_message') {
        // Update conversation preview with latest message
        context
            .read<DirectMessagesProvider>()
            .updateConversationPreview(
              data['senderId'],
              data['senderName'],
              data['content'],
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dm = context.watch<DirectMessagesProvider>();
    final contactsProvider = context.watch<ContactsProvider>();

    return dm.isLoading
        ? const Center(child: CircularProgressIndicator())
        : dm.conversations.isEmpty
            ? const Center(
                child: Text(
                  'No conversations yet.\nMessage a contact!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : RefreshIndicator(
                onRefresh: () {
                  final token = auth.user?.token ?? '';
                  return dm.fetchConversations(token);
                },
                child: ListView.separated(
                  itemCount: dm.conversations.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 76,
                  ),
                  itemBuilder: (context, index) {
                    final conversation = dm.conversations[index];

                    return ConversationTile(
                      conversation: conversation,
                      onTap: () {
                        final contact = contactsProvider.contacts
                            .firstWhere(
                          (c) => c.userId == conversation.userId,
                          orElse: () => Contact(
                            contactId: 0,
                            userId: conversation.userId,
                            username: conversation.username,
                            email: '',
                            status: 'accepted',
                            createdAt: '',
                          ),
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DirectMessageScreen(contact: contact),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
  }
}
