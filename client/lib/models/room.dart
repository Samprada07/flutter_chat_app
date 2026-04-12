class Room {
  final int id;
  final String name;
  final int createdBy;
  final String createdAt;
  final int memberCount;

  Room({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.memberCount,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      createdBy: json['created_by'],
      createdAt: json['created_at'],
      memberCount: int.parse(json['member_count'].toString()),
    );
  }
}
