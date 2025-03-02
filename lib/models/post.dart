import 'comment.dart';

class Post {
  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
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
    required this.authorName,
    this.authorPhotoUrl,
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
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
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
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      authorId: json['author_id'] ?? '',
      authorName: json['author_name'] ?? '',
      authorPhotoUrl: json['author_photo_url'],
      mediaUrl: json['media']?.isNotEmpty == true ? json['media'][0] : null,
      videoUrl: json['video']?.isNotEmpty == true ? json['video'][0] : null,
      postedAt: DateTime.parse(json['posted_at'] ?? DateTime.now().toIso8601String()),
      isProducer: json['is_producer'] ?? false,
      isLeisureProducer: json['is_leisure_producer'] ?? false,
      isInterested: json['interested'] ?? false,
      isChoice: json['choice'] ?? false,
      interestedCount: json['interested_count'] ?? 0,
      choiceCount: json['choice_count'] ?? 0,
      comments: (json['comments'] as List?)
          ?.map((c) => Comment.fromJson(c))
          .toList() ?? [],
    );
  }
}
