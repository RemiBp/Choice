import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';

class PostMedia extends StatelessWidget {
  final String? mediaUrl;
  final String? videoUrl;

  const PostMedia({
    Key? key,
    this.mediaUrl,
    this.videoUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (videoUrl != null) {
      return _buildVideoPlayer(videoUrl!);
    } else if (mediaUrl != null) {
      return _buildImage(mediaUrl!);
    }
    return const SizedBox();
  }

  Widget _buildImage(String url) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(url),
      child: Image.network(url, fit: BoxFit.cover),
    );
  }

  Widget _buildVideoPlayer(String url) {
    return FutureBuilder<VideoPlayerController>(
      future: _initializeVideoController(url),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return AspectRatio(
          aspectRatio: snapshot.data!.value.aspectRatio,
          child: VideoPlayer(snapshot.data!),
        );
      },
    );
  }

  Future<VideoPlayerController> _initializeVideoController(String url) async {
    final controller = VideoPlayerController.network(url);
    await controller.initialize();
    return controller;
  }

  void _showFullScreenImage(String url) {
    // Implémenter l'affichage en plein écran
  }
}
