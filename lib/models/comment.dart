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
      id: json['_id'] ?? json['id'] ?? '',
      authorId: json['author_id'] ?? json['authorId'] ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? '',
      username: json['username'] ?? json['author_name'] ?? json['authorName'] ?? '',
      authorAvatar: json['author_avatar'] ?? json['authorAvatar'] ?? '',
      content: json['content'] ?? '',
      postedAt: json['posted_at'] != null || json['postedAt'] != null
          ? DateTime.parse(json['posted_at'] ?? json['postedAt'])
          : DateTime.now(),
    );
  }
}
