import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/media.dart';
import '../../models/comment.dart';
import 'animations/double_tap_animation.dart';
import '../../utils.dart' show getImageProvider;

class MediaDetailView extends StatefulWidget {
  final List<Media> media;
  final List<Comment> comments;
  final String postId;
  final Function(String) onCommentSubmitted;
  final bool isProducerPost;
  final int initialIndex;

  const MediaDetailView({
    Key? key,
    required this.media,
    required this.comments,
    required this.postId,
    required this.onCommentSubmitted,
    this.isProducerPost = false,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MediaDetailView> createState() => _MediaDetailViewState();
}

class _MediaDetailViewState extends State<MediaDetailView> {
  late PageController _pageController;
  late VideoPlayerController? _videoController;
  final TextEditingController _commentController = TextEditingController();
  int _currentPage = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentPage = widget.initialIndex;
    
    // Initialize video controller if first media is video
    if (widget.media.isNotEmpty && 
        widget.initialIndex < widget.media.length && 
        widget.media[widget.initialIndex].type == 'video') {
      _initializeVideoController(widget.media[widget.initialIndex].url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Barre supérieure
            _buildTopBar(),
            
            // Vue des médias
            Expanded(
              child: Stack(
                children: [
                  // PageView des médias
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.media.length,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, index) {
                      return DoubleTapAnimation(
                        onDoubleTap: () {}, // Gérer le double tap like
                        child: _buildMediaItem(widget.media[index]),
                      );
                    },
                  ),
                  
                  // Indicateur de position
                  if (widget.media.length > 1)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.media.length,
                          (index) => _buildPageIndicator(index),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Section commentaires
            _buildCommentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            '${_currentPage + 1}/${widget.media.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(Media media) {
    if (media.type == 'video') {
      return _VideoPlayerWidget(url: media.url);
    }
    final imageProvider = getImageProvider(media.url);
    if (imageProvider != null)
      return Image(
        image: imageProvider,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.error, color: Colors.white),
        ),
      );
    else
      return Container(color: Colors.grey[200], child: Icon(Icons.broken_image));
  }

  Widget _buildPageIndicator(int index) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index ? Colors.blue : Colors.grey,
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      color: Colors.black87,
      child: Column(
        children: [
          // Liste des commentaires
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: widget.comments.length,
              itemBuilder: (context, index) {
                final comment = widget.comments[index];
                return ListTile(
                  leading: GestureDetector(
                    onTap: () {}, // Navigation vers le profil
                    child: CircleAvatar(
                      backgroundImage: comment.authorAvatar != null ? 
                        getImageProvider(comment.authorAvatar!) : 
                        null,
                      child: comment.authorAvatar == null ? 
                        const Icon(Icons.person, color: Colors.grey) : 
                        null,
                    ),
                  ),
                  title: Text(
                    comment.authorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    comment.content,
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              },
            ),
          ),
          
          // Input commentaire
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un commentaire...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    if (_commentController.text.isNotEmpty) {
                      widget.onCommentSubmitted(_commentController.text);
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
      
      // Dispose previous controller if exists
      if (_videoController != null) {
        _videoController!.pause();
        _videoController!.dispose();
        _videoController = null;
        _isPlaying = false;
      }
      
      // Initialize new controller if needed
      final media = widget.media[page];
      if (media.type == 'video') {
        _initializeVideoController(media.url);
      }
    });
  }

  Future<void> _initializeVideoController(String url) async {
    _videoController = VideoPlayerController.network(url);
    await _videoController!.initialize();
    _videoController!.play();
    _videoController!.setLooping(true);
    setState(() => _isPlaying = true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;

  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.url);
    await _controller.initialize();
    setState(() => _isInitialized = true);
    _controller.play();
    _controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (!_controller.value.isPlaying)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}