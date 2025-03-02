import 'comment.dart';

class Post {
  final String id;
  final String content;
  final String authorId;
  final String? mediaUrl;
  final String? videoUrl;
  final DateTime postedAt;
  final bool isProducer;
  final bool isLeisureProducer;
  final bool isInterested;
  final bool isChoice;
  final int interestedCount;
  final int choiceCount;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.content,
    required this.authorId,
    this.mediaUrl,
    this.videoUrl,
    required this.postedAt,
    this.isProducer = false,
    this.isLeisureProducer = false,
    this.isInterested = false,
    this.isChoice = false,
    this.interestedCount = 0,
    this.choiceCount = 0,
    this.comments = const [],
  });

  Post copyWith({
    bool? isInterested,
    bool? isChoice,
    int? interestedCount,
    int? choiceCount,
    List<Comment>? comments,
  }) {
    return Post(
      id: id,
      content: content,
      authorId: authorId,
      mediaUrl: mediaUrl,
      videoUrl: videoUrl,
      postedAt: postedAt,
      isProducer: isProducer,
      isLeisureProducer: isLeisureProducer,
      isInterested: isInterested ?? this.isInterested,
      isChoice: isChoice ?? this.isChoice,
      interestedCount: interestedCount ?? this.interestedCount,
      choiceCount: choiceCount ?? this.choiceCount,
      comments: comments ?? this.comments,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      content: json['content'],
      authorId: json['authorId'],
      mediaUrl: json['mediaUrl'],
      videoUrl: json['videoUrl'],
      postedAt: DateTime.parse(json['postedAt']),
      isProducer: json['isProducer'] ?? false,
      isLeisureProducer: json['isLeisureProducer'] ?? false,
      isInterested: json['isInterested'] ?? false,
      isChoice: json['isChoice'] ?? false,
      interestedCount: json['interestedCount'] ?? 0,
      choiceCount: json['choiceCount'] ?? 0,
      comments: (json['comments'] as List?)
          ?.map((c) => Comment.fromJson(c))
          .toList() ?? [],
    );
  }
}
