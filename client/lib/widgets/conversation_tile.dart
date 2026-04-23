import 'package:flutter/material.dart';
import '../models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  // ─── Format Timestamp ────────────────────────────────────────────────────
  // Converts ISO timestamp to readable format
  // Shows time if today, date if older
  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final isToday =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;

      if (isToday) {
        // Show HH:MM for today's messages
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      } else {
        // Show DD/MM for older messages
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        return '$day/$month';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // Contact avatar with first letter of username
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        radius: 26,
        child: Text(
          conversation.username[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Contact username
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            conversation.username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // Timestamp of last message
          Text(
            _formatTime(conversation.lastMessageAt),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),

      // Last message preview with unread badge
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Last message preview truncated to one line
          Expanded(
            child: Text(
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: conversation.unreadCount > 0
                    ? Colors.black87
                    : Colors.grey,
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),

          // Unread count badge
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),

      onTap: onTap,
    );
  }
}
