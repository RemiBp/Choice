import 'package:flutter/foundation.dart';

@immutable
class Media {
  final String _url;
  final String? type;
  final String? id;
  final double? width;
  final double? height;
  final double? aspectRatio;
  final String? caption;
  final String? thumbnail;
  final bool isLoading;
  final String? thumbnailUrl;
  final int? duration;
  final Map<String, dynamic>? metadata;

  Media({
    required String url,
    this.type,
    this.id,
    this.width,
    this.height,
    this.aspectRatio,
    this.caption,
    this.thumbnail,
    this.isLoading = false,
    this.thumbnailUrl,
    this.duration,
    this.metadata,
  }) : _url = url;

  String get url => _url;

  Media copyWithUrl(String newUrl) {
    return Media(
      url: newUrl,
      type: type,
      id: id,
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      caption: caption,
      thumbnail: thumbnail,
      isLoading: isLoading,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      metadata: metadata,
    );
  }

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      url: json['url'] ?? '',
      type: json['type'],
      id: json['id'],
      width: json['width'],
      height: json['height'],
      aspectRatio: json['aspectRatio'],
      caption: json['caption'],
      thumbnail: json['thumbnail'],
      isLoading: json['isLoading'] ?? false,
      thumbnailUrl: json['thumbnailUrl'],
      duration: json['duration'],
      metadata: json['metadata'],
    );
  }

  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      url: map['url'] ?? '',
      type: map['type'],
      id: map['id'],
      width: map['width'],
      height: map['height'],
      aspectRatio: map['aspectRatio'],
      caption: map['caption'],
      thumbnail: map['thumbnail'],
      isLoading: map['isLoading'] ?? false,
      thumbnailUrl: map['thumbnailUrl'],
      duration: map['duration'],
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'id': id,
      'width': width,
      'height': height,
      'aspectRatio': aspectRatio,
      'caption': caption,
      'thumbnail': thumbnail,
      'isLoading': isLoading,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'metadata': metadata,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      'id': id,
      'width': width,
      'height': height,
      'aspectRatio': aspectRatio,
      'caption': caption,
      'thumbnail': thumbnail,
      'isLoading': isLoading,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'metadata': metadata,
    };
  }

  bool get isVideo => type == 'video';
}