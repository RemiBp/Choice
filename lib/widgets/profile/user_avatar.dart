import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    required this.size,
    required this.radius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.grey[200],
        border: borderColor != null && borderWidth != null
            ? Border.all(
                color: borderColor!,
                width: borderWidth!,
              )
            : null,
      ),
      child: ClipOval(
        child: imageUrl != null
            ? Image(
                image: getImageProvider(imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.person,
                  color: Colors.grey[400],
                  size: size * 0.6,
                ),
              )
            : Icon(
                Icons.person,
                color: Colors.grey[400],
                size: size * 0.6,
              ),
      ),
    );
  }
} 