import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReelsViewScreen extends StatefulWidget {
  final String initialMediaUrl;
  final bool isVideo;
  final Map<String, dynamic> postData;
  final String userId;
  final Function(String, Map<String, dynamic>) onLike;
  final Function(String, Map<String, dynamic>, {bool isLeisureProducer}) onInterested;
  final Function(String, Map<String, dynamic>, {bool isLeisureProducer}) onChoice;
  final Function() onComment;

  const ReelsViewScreen({
    Key? key,
    required this.initialMediaUrl,
    required this.isVideo,
    required this.postData,
    required this.userId,
    required this.onLike,
    required this.onInterested,
    required this.onChoice,
    required this.onComment,
  }) : super(key: key);

  @override
  State<ReelsViewScreen> createState() => _ReelsViewScreenState();
}

class _ReelsViewScreenState extends State<ReelsViewScreen> {
  late VideoPlayerController? _controller;
  bool _isControllerInitialized = false;
  bool _showControls = true;
  bool _showLikeAnimation = false;
  final PageController _pageController = PageController();
  final List<Map<String, dynamic>> _mediaItems = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
    _loadMoreMediaItems();
    
    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _loadMoreMediaItems() async {
    // Add the initial media
    _mediaItems.add({
      'url': widget.initialMediaUrl,
      'isVideo': widget.isVideo,
      'post': widget.postData,
    });

    // TODO: Load more media items from API
    // This would be implemented with an API call to get more posts with media
    // For now, we'll just use the current post
    
    setState(() {});
  }

  Future<void> _initializeVideoController() async {
    if (widget.isVideo) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.initialMediaUrl));
      
      try {
        await _controller!.initialize();
        _controller!.setLooping(true);
        // Enable sound by default
        _controller!.setVolume(1.0);
        _controller!.play();
        
        if (mounted) {
          setState(() {
            _isControllerInitialized = true;
          });
        }
      } catch (e) {
        print('❌ Error initializing video: $e');
      }
    }
  }

  void _handlePageChange(int index) async {
    // Pause current video
    if (_isControllerInitialized && _controller != null) {
      await _controller!.pause();
      await _controller!.dispose();
      _isControllerInitialized = false;
    }
    
    setState(() {
      _currentIndex = index;
    });
    
    // Initialize new video controller if needed
    if (_mediaItems[index]['isVideo']) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_mediaItems[index]['url'])
      );
      
      try {
        await _controller!.initialize();
        _controller!.setLooping(true);
        _controller!.setVolume(1.0); // Sound on
        _controller!.play();
        
        if (mounted) {
          setState(() {
            _isControllerInitialized = true;
          });
        }
      } catch (e) {
        print('❌ Error initializing video: $e');
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    // Auto-hide controls after 3 seconds if they are shown
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showControls) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleVideoSound() {
    if (_isControllerInitialized && _controller != null) {
      setState(() {
        if (_controller!.value.volume > 0) {
          _controller!.setVolume(0);
        } else {
          _controller!.setVolume(1.0);
        }
      });
    }
  }

  void _likeCurrentPost() {
    final currentPost = _mediaItems[_currentIndex]['post'];
    final String postId = currentPost['_id'];
    
    setState(() {
      _showLikeAnimation = true;
      currentPost['isLiked'] = true;
      currentPost['likesCount'] = (currentPost['likesCount'] ?? 0) + 1;
    });
    
    widget.onLike(postId, currentPost);
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showLikeAnimation = false;
        });
      }
    });
  }

  @override
  void dispose() {
    if (_isControllerInitialized && _controller != null) {
      _controller!.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final currentPost = _mediaItems[_currentIndex]['post'];
    final bool isLiked = currentPost['isLiked'] == true;
    final int likesCount = currentPost['likesCount'] ?? 0;
    
    final bool isProducer = currentPost['producer_id'] != null;
    final bool isLeisureProducer = currentPost['is_leisure_producer'] == true;
    final String? producerId = currentPost['producer_id'];
    final String? eventId = currentPost['event_id'];
    final String targetId = isLeisureProducer ? (eventId ?? '') : (producerId ?? '');
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTap: _likeCurrentPost,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media content with vertical swipe
            PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pageController,
              itemCount: _mediaItems.length,
              onPageChanged: _handlePageChange,
              itemBuilder: (context, index) {
                final mediaItem = _mediaItems[index];
                if (mediaItem['isVideo']) {
                  // Video display
                  if (index == _currentIndex && _isControllerInitialized && _controller != null) {
                    return Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                } else {
                  // Image display
                  return Center(
                    child: CachedNetworkImage(
                      imageUrl: mediaItem['url'],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
                    ),
                  );
                }
              },
            ),
            
            // Like animation overlay
            if (_showLikeAnimation)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: 2 - value,
                        child: const Text(
                          '❤️',
                          style: TextStyle(fontSize: 120),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Video controls overlay
            if (_showControls && _mediaItems[_currentIndex]['isVideo'] && _isControllerInitialized)
              Positioned(
                top: 16 + MediaQuery.of(context).padding.top,
                right: 16,
                child: IconButton(
                  icon: Icon(
                    _controller?.value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _toggleVideoSound,
                ),
              ),
            
            // Navigation buttons
            if (_showControls)
              Positioned(
                top: 16 + MediaQuery.of(context).padding.top,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            
            // Close button
            Positioned(
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Post info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Author name
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(currentPost['author_photo'] ?? 'https://via.placeholder.com/30'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentPost['author_name'] ?? 'Inconnu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Caption (truncated)
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: Text(
                          currentPost['content'] ?? '',
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Right side: Interaction buttons
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: () => widget.onLike(currentPost['_id'], currentPost),
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.8, end: isLiked ? 1.0 : 0.8),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Text(
                                    isLiked ? '❤️' : '🤍',
                                    style: const TextStyle(fontSize: 38),
                                  ),
                                );
                              },
                            ),
                            Text(
                              likesCount > 0 ? '$likesCount' : '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Interest button (only for producer posts)
                      if (isProducer)
                        GestureDetector(
                          onTap: () => widget.onInterested(targetId, currentPost, isLeisureProducer: isLeisureProducer),
                          child: Column(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.8, end: currentPost['interested'] == true ? 1.0 : 0.8),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Text(
                                      currentPost['interested'] == true ? '⭐' : '☆',
                                      style: const TextStyle(fontSize: 38),
                                    ),
                                  );
                                },
                              ),
                              Text(
                                '${currentPost['entity_interests_count'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      if (isProducer) const SizedBox(height: 20),
                      
                      // Choice button (only for producer posts)
                      if (isProducer)
                        GestureDetector(
                          onTap: () => widget.onChoice(targetId, currentPost, isLeisureProducer: isLeisureProducer),
                          child: Column(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.8, end: currentPost['choice'] == true ? 1.0 : 0.8),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Text(
                                      currentPost['choice'] == true ? '✅' : '⬜',
                                      style: const TextStyle(fontSize: 38),
                                    ),
                                  );
                                },
                              ),
                              Text(
                                '${currentPost['entity_choices_count'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Comment button
                      GestureDetector(
                        onTap: widget.onComment,
                        child: Column(
                          children: [
                            const Text(
                              '💬',
                              style: TextStyle(fontSize: 38),
                            ),
                            Text(
                              '${(currentPost['comments'] ?? []).length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Swipe indicator
            Positioned(
              top: MediaQuery.of(context).size.height / 2,
              right: 16,
              child: Column(
                children: [
                  const Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white70,
                  ),
                  Container(
                    height: 50,
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}