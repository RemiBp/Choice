import 'package:flutter/foundation.dart';

@immutable
class Media {
  final String url;
  final String type;
  final double width;
  final double height;

  const Media({
    required this.url,
    required this.type,
    this.width = 0,
    this.height = 0,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
      width: (json['width'] != null) ? json['width'].toDouble() : 0.0,
      height: (json['height'] != null) ? json['height'].toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'width': width,
      'height': height,
    };
  }
}