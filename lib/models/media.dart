enum MediaType { image, video }

class Media {
  final String url;
  final MediaType type;
  final String? thumbnail;

  const Media({
    required this.url,
    required this.type,
    this.thumbnail,
  });

  bool get isVideo => type == MediaType.video;

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      url: json['url'] ?? '',
      type: json['type'] == 'video' ? MediaType.video : MediaType.image,
      thumbnail: json['thumbnail'],
    );
  }
}