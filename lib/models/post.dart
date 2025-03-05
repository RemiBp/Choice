import 'package:flutter/foundation.dart';
import 'media.dart';
import 'comment.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime postedAt;
  final List<Media> media;
  final bool isProducerPost;
  final bool isInterested;
  final bool isChoice;
  final bool isLeisureProducer;
  final int interestedCount;
  final int choiceCount;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.postedAt,
    required this.media,
    this.isProducerPost = false,
    this.isInterested = false,
    this.isChoice = false,
    this.isLeisureProducer = false,
    this.interestedCount = 0,
    this.choiceCount = 0,
    this.comments = const [],
  });

  Post copyWith({
    bool? isLiked,
    bool? isInterested,
    bool? isChoice,
    bool? isLeisureProducer,
    int? likesCount,
    int? interestedCount,
    int? choiceCount,
    List<Comment>? comments,
  }) {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      postedAt: postedAt,
      media: media,
      isProducerPost: isProducerPost,
      isInterested: isInterested ?? this.isInterested,
      isChoice: isChoice ?? this.isChoice,
      isLeisureProducer: isLeisureProducer ?? this.isLeisureProducer,
      interestedCount: interestedCount ?? this.interestedCount,
      choiceCount: choiceCount ?? this.choiceCount,
      comments: comments ?? this.comments,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    try {
      print('🔄 Parsing post ID: ${json['_id']}');
      return Post(
        id: json['_id']?.toString() ?? '',
        authorId: json['author_id']?.toString() ?? '',
        authorName: json['author_name']?.toString() ?? '',
        authorAvatar: json['author_avatar']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        postedAt: json['posted_at'] != null 
            ? DateTime.parse(json['posted_at'].toString())
            : DateTime.now(),
        media: (json['media'] as List?)?.map((e) => Media.fromJson(e)).toList() ?? [],
        isProducerPost: json['producer_id'] != null,
        isInterested: json['is_interested'] == true,
        isChoice: json['is_choice'] == true,
      );
    } catch (e, stack) {
      print('❌ Erreur parsing post: $e');
      print('📄 Stack: $stack');
      print('📦 JSON: $json');
      rethrow;
    }
  }
}

// Comment class moved to comment.dart

class PostLocation {
  final String name;
  final String? address;
  final List<double> coordinates;

  PostLocation({
    required this.name,
    this.address,
    required this.coordinates,
  });

  factory PostLocation.fromJson(Map<String, dynamic> json) {
    return PostLocation(
      name: json['name'] ?? 'Localisation inconnue',
      address: json['address'],
      coordinates: List<double>.from(json['coordinates'] ?? []),
    );
  }
}
