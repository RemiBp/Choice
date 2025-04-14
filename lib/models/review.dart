class Review {
  final String id;
  final String userId;
  final String placeId;
  final String content;
  final double rating;
  final DateTime createdAt;
  final List<String> photos;
  final String? userName;
  final String? userAvatar;
  final String? placeName;
  final int likes;
  final bool isLiked;

  Review({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.content,
    required this.rating,
    required this.createdAt,
    this.photos = const [],
    this.userName,
    this.userAvatar,
    this.placeName,
    this.likes = 0,
    this.isLiked = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      placeId: json['placeId'] ?? '',
      content: json['content'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      photos: json['photos'] != null
          ? List<String>.from(json['photos'])
          : [],
      userName: json['userName'],
      userAvatar: json['userAvatar'],
      placeName: json['placeName'],
      likes: json['likes'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'placeId': placeId,
      'content': content,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
      'photos': photos,
      'userName': userName,
      'userAvatar': userAvatar,
      'placeName': placeName,
      'likes': likes,
      'isLiked': isLiked,
    };
  }

  Review copyWith({
    String? id,
    String? userId,
    String? placeId,
    String? content,
    double? rating,
    DateTime? createdAt,
    List<String>? photos,
    String? userName,
    String? userAvatar,
    String? placeName,
    int? likes,
    bool? isLiked,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      placeId: placeId ?? this.placeId,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      photos: photos ?? this.photos,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      placeName: placeName ?? this.placeName,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
    );
  }
} 