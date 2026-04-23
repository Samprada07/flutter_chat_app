import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/direct_messages_provider.dart';
import '../providers/contacts_provider.dart';
import '../models/contact.dart';
import '../widgets/conversation_tile.dart';
import 'direct_message_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  @override
  void initState() {
    super.initState();
    // Load conversations when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<DirectMessagesProvider>().fetchConversations(token);
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
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, index) {
                final conversation = dm.conversations[index];

                return ConversationTile(
                  conversation: conversation,
                  onTap: () {
                    // Find the contact object for this conversation
                    // so we can pass it to DirectMessageScreen
                    final contact = contactsProvider.contacts.firstWhere(
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
                        builder: (_) => DirectMessageScreen(contact: contact),
                      ),
                    );
                  },
                );
              },
            ),
          );
  }
}
