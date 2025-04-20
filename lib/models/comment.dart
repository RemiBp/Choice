import 'package:flutter/foundation.dart';

@immutable
class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final DateTime createdAt;
  final int likes;
  final bool isLiked;
  final String? replyToId;
  final String? replyToName;

  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
    this.replyToId,
    this.replyToName,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? json['id'] ?? '',
      authorId: json['author_id'] ?? json['authorId'] ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? 'Utilisateur',
      authorAvatar: json['author_avatar'] ?? json['authorAvatar'],
      content: json['content'] ?? json['text'] ?? '',
      createdAt: json['created_at'] is DateTime 
          ? json['created_at'] 
          : (json['created_at'] is String 
              ? DateTime.parse(json['created_at']) 
              : DateTime.now()),
      likes: json['likes'] is int ? json['likes'] : 0,
      isLiked: json['isLiked'] ?? false,
      replyToId: json['replyToId'] ?? json['reply_to_id'],
      replyToName: json['replyToName'] ?? json['reply_to_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'isLiked': isLiked,
      'replyToId': replyToId,
      'replyToName': replyToName,
    };
  }

  Comment copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    DateTime? createdAt,
    int? likes,
    bool? isLiked,
    String? replyToId,
    String? replyToName,
  }) {
    return Comment(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      replyToId: replyToId ?? this.replyToId,
      replyToName: replyToName ?? this.replyToName,
    );
  }
}
