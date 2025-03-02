import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:carousel_slider/carousel_slider.dart';

class MediaViewer extends StatefulWidget {
  final List<String> mediaUrls;
  final Function() onDoubleTap;

  const MediaViewer({
    Key? key,
    required this.mediaUrls,
    required this.onDoubleTap,
  }) : super(key: key);

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  int _currentIndex = 0;
  Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeVideoControllers();
  }

  void _initializeVideoControllers() {
    for (var url in widget.mediaUrls) {
      if (_isVideoUrl(url)) {
        _videoControllers[url] = VideoPlayerController.network(url)
          ..initialize().then((_) {
            setState(() {});
          });
      }
    }
  }

  bool _isVideoUrl(String url) {
    return url.endsWith('.mp4') || url.endsWith('.mov');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            aspectRatio: 1,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          items: widget.mediaUrls.map((url) {
            return GestureDetector(
              onDoubleTap: widget.onDoubleTap,
              onTap: () => _showFullScreen(context, url),
              child: _isVideoUrl(url)
                  ? _buildVideoPlayer(url)
                  : _buildImage(url),
            );
          }).toList(),
        ),
        if (widget.mediaUrls.length > 1)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.mediaUrls.length}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => Icon(Icons.error),
    );
  }

  Widget _buildVideoPlayer(String url) {
    final controller = _videoControllers[url];
    if (controller == null || !controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        IconButton(
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 50,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            });
          },
        ),
      ],
    );
  }

  void _showFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenMedia(url: url),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class FullScreenMedia extends StatelessWidget {
  final String url;

  const FullScreenMedia({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: NetworkImage(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
