class Message {
  final int id;
  final int senderId;
  final String senderName;
  final String content;
  final String createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      // Room messages use 'sender_name', direct messages use 'sender_name' too
      senderName: json['sender_name'] ?? json['username'] ?? 'Unknown',
      content: json['content'],
      createdAt: json['created_at'],
      isRead: json['is_read'] ?? false,
    );
  }
}
