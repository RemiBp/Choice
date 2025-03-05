import 'package:flutter/foundation.dart';

@immutable
class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String username;
  final String authorAvatar;
  final String content;
  final DateTime postedAt;

  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.username,
    required this.authorAvatar,
    required this.content,
    required this.postedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? '',
      authorId: json['author_id'] ?? '',
      authorName: json['author_name'] ?? '',
      username: json['username'] ?? json['author_name'] ?? '',
      authorAvatar: json['author_avatar'] ?? '',
      content: json['content'] ?? '',
      postedAt: DateTime.parse(json['posted_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
