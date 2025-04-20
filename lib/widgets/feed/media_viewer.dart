import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaViewer extends StatefulWidget {
  final String url;
  final VoidCallback? onDoubleTap;

  const MediaViewer({
    Key? key, 
    required this.url,
    this.onDoubleTap,
  }) : super(key: key);

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late bool isVideo;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    isVideo = widget.url.endsWith('.mp4') || widget.url.endsWith('.mov');
    if (isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  void _showFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PhotoView(
                  imageProvider: getImageProvider(widget.url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: isVideo ? null : _showFullScreen,
      child: isVideo
          ? _buildVideoPlayer()
          : Hero(
              tag: widget.url,
              child: Image(
                image: getImageProvider(widget.url),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image)),
              ),
            ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller?.value.isInitialized != true) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        IconButton(
          icon: Icon(
            _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 50,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _controller!.value.isPlaying
                  ? _controller!.pause()
                  : _controller!.play();
            });
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
