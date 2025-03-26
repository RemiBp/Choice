import 'package:flutter/foundation.dart';

@immutable
class Media {
  final String url;
  final String type; // 'image' ou 'video'
  final String? thumbnailUrl;
  final int? duration;
  final int? width;
  final int? height;

  const Media({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.duration,
    this.width,
    this.height,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      url: json['url'],
      type: json['type'],
      thumbnailUrl: json['thumbnailUrl'],
      duration: json['duration'],
      width: json['width'],
      height: json['height'],
    );
  }

  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      url: map['url'] ?? '',
      type: map['type'] ?? 'image',
      thumbnailUrl: map['thumbnailUrl'],
      duration: map['duration'],
      width: map['width'],
      height: map['height'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'width': width,
      'height': height,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'width': width,
      'height': height,
    };
  }

  bool get isVideo => type == 'video';
}