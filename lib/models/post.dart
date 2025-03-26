import 'package:flutter/foundation.dart';
import 'media.dart';
import 'comment.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final List<String> mediaUrls;
  final String? locationId;
  final String? locationName;
  final DateTime createdAt;
  final DateTime postedAt;
  final List<String> likes;
  final List<String> interests;
  final List<String> choices;
  final List<Map<String, dynamic>> comments;
  final Map<String, dynamic>? metadata;
  final bool isProducerPost;
  final bool isLeisureProducer;
  final bool isAutomated;
  final String? referencedEventId;
  final String? targetId;
  final String? targetType;
  final String? producerId;
  final bool hasReferencedEvent;
  final bool hasTarget;
  final String? visualBadge;
  final String? entityName;
  final List<Media> media;
  final String type;
  final String? description;
  final String? userId;
  final bool? isLiked;
  final bool? isInterested;
  final bool? isChoice;
  final int? likesCount;
  final int? interestedCount;
  final int? choiceCount;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.mediaUrls,
    this.locationId,
    this.locationName,
    required this.createdAt,
    required this.postedAt,
    required this.likes,
    required this.interests,
    required this.choices,
    required this.comments,
    this.metadata,
    this.isProducerPost = false,
    this.isLeisureProducer = false,
    this.isAutomated = false,
    this.referencedEventId,
    this.targetId,
    this.targetType,
    this.producerId,
    this.hasReferencedEvent = false,
    this.hasTarget = false,
    this.visualBadge,
    this.entityName,
    this.media = const [],
    this.type = 'post',
    this.description,
    this.userId,
    this.isLiked,
    this.isInterested,
    this.isChoice,
    this.likesCount,
    this.interestedCount,
    this.choiceCount,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as String,
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      authorAvatar: map['authorAvatar'] as String,
      content: map['content'] as String,
      mediaUrls: List<String>.from(map['mediaUrls'] as List),
      locationId: map['locationId'] as String?,
      locationName: map['locationName'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      postedAt: DateTime.parse(map['postedAt'] as String),
      likes: List<String>.from(map['likes'] as List),
      interests: List<String>.from(map['interests'] as List),
      choices: List<String>.from(map['choices'] as List),
      comments: List<Map<String, dynamic>>.from(map['comments'] as List),
      metadata: map['metadata'] as Map<String, dynamic>?,
      isProducerPost: map['isProducerPost'] as bool? ?? false,
      isLeisureProducer: map['isLeisureProducer'] as bool? ?? false,
      isAutomated: map['isAutomated'] as bool? ?? false,
      referencedEventId: map['referencedEventId'] as String?,
      targetId: map['targetId'] as String?,
      targetType: map['targetType'] as String?,
      producerId: map['producerId'] as String?,
      hasReferencedEvent: map['hasReferencedEvent'] as bool? ?? false,
      hasTarget: map['hasTarget'] as bool? ?? false,
      visualBadge: map['visualBadge'] as String?,
      entityName: map['entityName'] as String?,
      media: map['media'] != null 
          ? List<Media>.from((map['media'] as List).map((x) => Media.fromMap(x as Map<String, dynamic>)))
          : [],
      type: map['type'] as String? ?? 'post',
      description: map['description'] as String?,
      userId: map['userId'] as String?,
      isLiked: map['isLiked'] as bool?,
      isInterested: map['isInterested'] as bool?,
      isChoice: map['isChoice'] as bool?,
      likesCount: map['likesCount'] as int?,
      interestedCount: map['interestedCount'] as int?,
      choiceCount: map['choiceCount'] as int?,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? json['id'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? '',
      authorAvatar: json['authorAvatar'] ?? '',
      content: json['content'] ?? '',
      mediaUrls: json['mediaUrls'] != null ? List<String>.from(json['mediaUrls']) : [],
      locationId: json['locationId'],
      locationName: json['locationName'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      postedAt: json['postedAt'] != null 
          ? DateTime.parse(json['postedAt']) 
          : DateTime.now(),
      likes: json['likes'] != null ? List<String>.from(json['likes']) : [],
      interests: json['interests'] != null ? List<String>.from(json['interests']) : [],
      choices: json['choices'] != null ? List<String>.from(json['choices']) : [],
      comments: json['comments'] != null 
          ? List<Map<String, dynamic>>.from(json['comments'].map((x) => x)) 
          : [],
      metadata: json['metadata'],
      isProducerPost: json['isProducerPost'] ?? false,
      isLeisureProducer: json['isLeisureProducer'] ?? false,
      isAutomated: json['isAutomated'] ?? false,
      referencedEventId: json['referencedEventId'],
      targetId: json['targetId'],
      targetType: json['targetType'],
      producerId: json['producerId'],
      hasReferencedEvent: json['hasReferencedEvent'] ?? false,
      hasTarget: json['hasTarget'] ?? false,
      visualBadge: json['visualBadge'],
      entityName: json['entityName'],
      media: json['media'] != null 
          ? List<Media>.from(json['media'].map((x) => Media.fromMap(x)))
          : [],
      type: json['type'] ?? 'post',
      description: json['description'],
      userId: json['userId'],
      isLiked: json['isLiked'],
      isInterested: json['isInterested'],
      isChoice: json['isChoice'],
      likesCount: json['likesCount'],
      interestedCount: json['interestedCount'],
      choiceCount: json['choiceCount'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'mediaUrls': mediaUrls,
      'locationId': locationId,
      'locationName': locationName,
      'createdAt': createdAt.toIso8601String(),
      'postedAt': postedAt.toIso8601String(),
      'likes': likes,
      'interests': interests,
      'choices': choices,
      'comments': comments,
      'metadata': metadata,
      'isProducerPost': isProducerPost,
      'isLeisureProducer': isLeisureProducer,
      'isAutomated': isAutomated,
      'referencedEventId': referencedEventId,
      'targetId': targetId,
      'targetType': targetType,
      'producerId': producerId,
      'hasReferencedEvent': hasReferencedEvent,
      'hasTarget': hasTarget,
      'visualBadge': visualBadge,
      'entityName': entityName,
      'media': media.map((x) => x.toMap()),
      'type': type,
      'description': description,
      'userId': userId,
      'isLiked': isLiked,
      'isInterested': isInterested,
      'isChoice': isChoice,
      'likesCount': likesCount,
      'interestedCount': interestedCount,
      'choiceCount': choiceCount,
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    List<String>? mediaUrls,
    String? locationId,
    String? locationName,
    DateTime? createdAt,
    DateTime? postedAt,
    List<String>? likes,
    List<String>? interests,
    List<String>? choices,
    List<Map<String, dynamic>>? comments,
    Map<String, dynamic>? metadata,
    bool? isProducerPost,
    bool? isLeisureProducer,
    bool? isAutomated,
    String? referencedEventId,
    String? targetId,
    String? targetType,
    String? producerId,
    bool? hasReferencedEvent,
    bool? hasTarget,
    String? visualBadge,
    String? entityName,
    List<Media>? media,
    String? type,
    String? description,
    String? userId,
    bool? isLiked,
    bool? isInterested,
    bool? isChoice,
    int? likesCount,
    int? interestedCount,
    int? choiceCount,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      createdAt: createdAt ?? this.createdAt,
      postedAt: postedAt ?? this.postedAt,
      likes: likes ?? this.likes,
      interests: interests ?? this.interests,
      choices: choices ?? this.choices,
      comments: comments ?? this.comments,
      metadata: metadata ?? this.metadata,
      isProducerPost: isProducerPost ?? this.isProducerPost,
      isLeisureProducer: isLeisureProducer ?? this.isLeisureProducer,
      isAutomated: isAutomated ?? this.isAutomated,
      referencedEventId: referencedEventId ?? this.referencedEventId,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      producerId: producerId ?? this.producerId,
      hasReferencedEvent: hasReferencedEvent ?? this.hasReferencedEvent,
      hasTarget: hasTarget ?? this.hasTarget,
      visualBadge: visualBadge ?? this.visualBadge,
      entityName: entityName ?? this.entityName,
      media: media ?? this.media,
      type: type ?? this.type,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      isLiked: isLiked ?? this.isLiked,
      isInterested: isInterested ?? this.isInterested,
      isChoice: isChoice ?? this.isChoice,
      likesCount: likesCount ?? this.likesCount,
      interestedCount: interestedCount ?? this.interestedCount,
      choiceCount: choiceCount ?? this.choiceCount,
    );
  }

  bool isLikedBy(String userId) => likes.contains(userId);
  bool isInterestedBy(String userId) => interests.contains(userId);
  bool isChosenBy(String userId) => choices.contains(userId);
  int get likeCount => likes.length;
  int get interestCount => interests.length;
  int get choicesCount => choices.length;
  int get commentCount => comments.length;
}