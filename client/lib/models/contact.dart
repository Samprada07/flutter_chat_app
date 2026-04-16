class Contact {
  final int contactId; // ID in the contacts table
  final int userId; // The other user's ID
  final String username;
  final String email;
  final String status;
  final String createdAt;

  Contact({
    required this.contactId,
    required this.userId,
    required this.username,
    required this.email,
    required this.status,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      contactId: json['contact_id'],
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      status: json['status'] ?? 'accepted',
      createdAt: json['created_at'],
    );
  }
}
