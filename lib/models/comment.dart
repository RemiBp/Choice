class Comment {
  final String id;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      userId: json['userId'],
      username: json['username'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
