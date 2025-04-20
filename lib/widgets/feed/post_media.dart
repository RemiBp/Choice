import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../models/media.dart';
import 'video_player_widget.dart';
import '../../services/platform_service.dart';
import '../../utils.dart' show getImageProvider;

class PostMedia extends StatelessWidget {
  final Media mediaItem;
  final double? height;
  final BoxFit fit;
  final bool enableZoom;

  const PostMedia({
    Key? key,
    required this.mediaItem,
    this.height,
    this.fit = BoxFit.cover,
    this.enableZoom = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaItem.isVideo) {
      return SizedBox(
        height: height,
        child: VideoPlayerWidget(
          url: mediaItem.url,
          autoPlay: false,
          showControls: true,
        ),
      );
    } else {
      final imageProvider = getImageProvider(mediaItem.url);
      if (imageProvider != null) {
        Widget imageWidget = Image(
          image: imageProvider,
          fit: fit,
        );

        if (enableZoom) {
          return GestureDetector(
            onTap: () => _showFullScreenImage(context),
            child: imageWidget,
          );
        }

        return imageWidget;
      } else {
        return const Icon(Icons.error);
      }
    }
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PhotoView(
                imageProvider: getImageProvider(mediaItem.url),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
