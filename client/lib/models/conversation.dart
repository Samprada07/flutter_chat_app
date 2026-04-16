// Represents a summary of a direct message conversation
// shown in the Chats tab (like WhatsApp's main screen)
class Conversation {
  final int userId; // The other user's ID
  final String username; // The other user's username
  final String lastMessage; // Preview of the last message sent
  final String lastMessageAt;
  final int unreadCount; // Number of unread messages

  Conversation({
    required this.userId,
    required this.username,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      userId: json['user_id'],
      username: json['username'],
      lastMessage: json['last_message'] ?? '',
      lastMessageAt: json['last_message_at'] ?? '',
      unreadCount: int.parse(json['unread_count'].toString()),
    );
  }
}
