import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/platform_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final bool autoPlay;
  final bool showControls;

  const VideoPlayerWidget({
    Key? key,
    required this.url,
    this.autoPlay = false,
    this.showControls = true,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _controller.initialize();
      if (widget.autoPlay) {
        await _controller.play();
      }
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Erreur d\'initialisation vidéo: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          if (widget.showControls)
            _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, VideoPlayerValue value, child) {
        return GestureDetector(
          onTap: () {
            setState(() {
              value.isPlaying ? _controller.pause() : _controller.play();
            });
          },
          child: Container(
            color: Colors.black26,
            child: Icon(
              value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
          ),
        );
      },
    );
  }
}
