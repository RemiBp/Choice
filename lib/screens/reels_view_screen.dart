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
  final List<Map<String, dynamic>>? additionalReels;

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
    this.additionalReels,
  }) : super(key: key);

  @override
  State<ReelsViewScreen> createState() => _ReelsViewScreenState();
}

class _ReelsViewScreenState extends State<ReelsViewScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController? _controller;
  bool _isControllerInitialized = false;
  bool _showControls = true;
  bool _showLikeAnimation = false;
  bool _showInterestAnimation = false;
  bool _showChoiceAnimation = false;
  final PageController _pageController = PageController();
  final List<Map<String, dynamic>> _mediaItems = [];
  int _currentIndex = 0;
  late AnimationController _swipeAnimController;

  @override
  void initState() {
    super.initState();
    // Initialize swipe animation controller
    _swipeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
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

    // Add additional reels if provided
    if (widget.additionalReels != null && widget.additionalReels!.isNotEmpty) {
      for (var item in widget.additionalReels!) {
        _mediaItems.add({
          'url': item['mediaUrl'] ?? '',
          'isVideo': item['isVideo'] ?? false,
          'post': item['postData'] ?? {},
        });
      }
    }
    
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
    final String postId = currentPost['_id'] ?? '';
    
    // Check if already liked
    final bool isAlreadyLiked = currentPost['isLiked'] == true || 
                            currentPost['is_liked'] == true;
    
    setState(() {
      // Only show animation when adding a like, not removing
      _showLikeAnimation = !isAlreadyLiked;
      
      // Toggle like state
      currentPost['isLiked'] = !isAlreadyLiked;
      currentPost['is_liked'] = !isAlreadyLiked;
      
      // Update like count
      final int currentCount = currentPost['likesCount'] ?? 
                            currentPost['likes_count'] ?? 0;
      
      if (isAlreadyLiked) {
        // Remove like
        currentPost['likesCount'] = currentCount > 0 ? currentCount - 1 : 0;
        currentPost['likes_count'] = currentCount > 0 ? currentCount - 1 : 0;
      } else {
        // Add like
        currentPost['likesCount'] = currentCount + 1;
        currentPost['likes_count'] = currentCount + 1;
      }
    });
    
    // Call API
    widget.onLike(postId, currentPost);
    
    // Show animation briefly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showLikeAnimation = false;
        });
      }
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlreadyLiked 
              ? 'Like retiré pour ce post' 
              : 'Post liké avec succès',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isAlreadyLiked ? Colors.red.shade700 : Colors.pink.shade400,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }
  
  void _markInterested() {
    final currentPost = _mediaItems[_currentIndex]['post'];
    final bool isLeisureProducer = currentPost['is_leisure_producer'] == true || 
                               currentPost['isLeisureProducer'] == true;
    
    // Handle target correctly based on post type
    String targetId;
    String targetType = '';
    if (isLeisureProducer && currentPost['referenced_event_id'] != null) {
      // For leisure producers, target the event
      targetId = currentPost['referenced_event_id'];
      targetType = 'event';
    } else {
      // For restaurant producers, target the producer
      targetId = currentPost['producer_id'] ?? currentPost['_id'];
      targetType = 'restaurant';
    }
    
    // Check if already interested
    final bool isAlreadyInterested = currentPost['interested'] == true || 
                                 currentPost['isInterested'] == true;
    
    setState(() {
      _showInterestAnimation = !isAlreadyInterested;
      currentPost['interested'] = !isAlreadyInterested;
      currentPost['isInterested'] = !isAlreadyInterested;
      
      // Update interest counts
      final int currentCount = currentPost['entity_interests_count'] ?? 
                            currentPost['interested_count'] ?? 0;
      
      if (isAlreadyInterested) {
        // Remove interest
        currentPost['entity_interests_count'] = currentCount > 0 ? currentCount - 1 : 0;
        currentPost['interested_count'] = currentCount > 0 ? currentCount - 1 : 0;
      } else {
        // Add interest
        currentPost['entity_interests_count'] = currentCount + 1;
        currentPost['interested_count'] = currentCount + 1;
      }
    });
    
    // Call the callback with detailed information
    widget.onInterested(targetId, currentPost, isLeisureProducer: isLeisureProducer);
    
    // Show animation briefly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showInterestAnimation = false;
        });
      }
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlreadyInterested 
              ? 'Intérêt retiré pour ${targetType == 'event' ? 'cet événement' : 'ce restaurant'}' 
              : 'Intérêt marqué pour ${targetType == 'event' ? 'cet événement' : 'ce restaurant'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isAlreadyInterested ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }
  
  void _markChoice() {
    final currentPost = _mediaItems[_currentIndex]['post'];
    final bool isLeisureProducer = currentPost['is_leisure_producer'] == true || 
                               currentPost['isLeisureProducer'] == true;
    
    // Handle target correctly based on post type
    String targetId;
    String targetType = '';
    if (isLeisureProducer && currentPost['referenced_event_id'] != null) {
      // For leisure producers, target the event
      targetId = currentPost['referenced_event_id'];
      targetType = 'event';
    } else {
      // For restaurant producers, target the producer
      targetId = currentPost['producer_id'] ?? currentPost['_id'];
      targetType = 'restaurant';
    }
    
    // Check if already chosen
    final bool isAlreadyChosen = currentPost['choice'] == true || 
                              currentPost['isChoice'] == true;
    
    setState(() {
      _showChoiceAnimation = !isAlreadyChosen;
      currentPost['choice'] = !isAlreadyChosen;
      currentPost['isChoice'] = !isAlreadyChosen;
      
      // Update choice counts
      final int currentCount = currentPost['entity_choices_count'] ?? 
                            currentPost['choice_count'] ?? 0;
      
      if (isAlreadyChosen) {
        // Remove choice
        currentPost['entity_choices_count'] = currentCount > 0 ? currentCount - 1 : 0;
        currentPost['choice_count'] = currentCount > 0 ? currentCount - 1 : 0;
      } else {
        // Add choice
        currentPost['entity_choices_count'] = currentCount + 1;
        currentPost['choice_count'] = currentCount + 1;
      }
    });
    
    // Call the callback with detailed information
    widget.onChoice(targetId, currentPost, isLeisureProducer: isLeisureProducer);
    
    // Show animation briefly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showChoiceAnimation = false;
        });
      }
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlreadyChosen 
              ? 'Choix retiré pour ${targetType == 'event' ? 'cet événement' : 'ce restaurant'}' 
              : 'Choix ajouté pour ${targetType == 'event' ? 'cet événement' : 'ce restaurant'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isAlreadyChosen ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isControllerInitialized && _controller != null) {
      _controller!.dispose();
    }
    _pageController.dispose();
    _swipeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaItems.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    
    final currentPost = _mediaItems[_currentIndex]['post'];
    
    // Extract post data with fallbacks for different field names
    final bool isLiked = currentPost['isLiked'] == true || currentPost['is_liked'] == true;
    final int likesCount = currentPost['likesCount'] ?? currentPost['likes_count'] ?? 0;
    
    final bool isInterested = currentPost['interested'] == true || currentPost['isInterested'] == true;
    final int interestedCount = currentPost['entity_interests_count'] ?? 
                             currentPost['interested_count'] ?? 
                             currentPost['interestedCount'] ?? 0;
    
    final bool isChoice = currentPost['choice'] == true || currentPost['isChoice'] == true;
    final int choiceCount = currentPost['entity_choices_count'] ?? 
                         currentPost['choice_count'] ?? 
                         currentPost['choiceCount'] ?? 0;
    
    // Determine post type
    final bool isProducerPost = currentPost['isProducerPost'] == true || 
                             currentPost['producer_id'] != null;
    final bool isLeisureProducer = currentPost['isLeisureProducer'] == true || 
                               currentPost['is_leisure_producer'] == true;
    
    // Determine target ID based on post type
    String targetId = '';
    if (isLeisureProducer && currentPost['referenced_event_id'] != null) {
      targetId = currentPost['referenced_event_id'];
    } else if (isProducerPost) {
      targetId = currentPost['producer_id'] ?? currentPost['_id'] ?? '';
    }
    
    // Check if post is automated
    final bool isAutomated = currentPost['is_automated'] == true || 
                          currentPost['isAutomated'] == true;
    
    // Determine visualization badge
    String visualBadge = currentPost['visualBadge'] ?? 
                        (isLeisureProducer ? '🎭' : 
                         (isProducerPost ? '🍽️' : '👤'));
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTap: _likeCurrentPost,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media content with vertical swipe and enhanced transitions
            PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pageController,
              itemCount: _mediaItems.length,
              onPageChanged: _handlePageChange,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final mediaItem = _mediaItems[index];
                
                // Animate change between pages
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: index == _currentIndex ? 1.0 : 0.8,
                  child: mediaItem['isVideo']
                      ? _buildVideoItem(index, mediaItem)
                      : _buildImageItem(mediaItem),
                );
              },
            ),
            
            // Reaction animations overlay
            if (_showLikeAnimation || _showInterestAnimation || _showChoiceAnimation)
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
                        child: Text(
                          _showInterestAnimation ? '⭐' : 
                          (_showChoiceAnimation ? '✅' : '❤️'),
                          style: const TextStyle(fontSize: 120),
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
            
            // Close button
            if (_showControls)
              Positioned(
                top: 16 + MediaQuery.of(context).padding.top,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            
            // Post type badge
            Positioned(
              top: 16 + MediaQuery.of(context).padding.top,
              left: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isLeisureProducer
                      ? Colors.purple.withOpacity(0.7)
                      : (isProducerPost
                          ? Colors.amber.withOpacity(0.7)
                          : Colors.blue.withOpacity(0.7)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      visualBadge,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLeisureProducer
                          ? 'Loisir'
                          : (isProducerPost ? 'Restaurant' : 'Utilisateur'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (isAutomated) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '🤖',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Referenced entity tag if applicable
            if ((isLeisureProducer && currentPost['referenced_event_id'] != null) ||
                (currentPost['targetId'] != null))
              Positioned(
                top: 60 + MediaQuery.of(context).padding.top,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      isLeisureProducer
                          ? const Text('🎪', style: TextStyle(fontSize: 16))
                          : const Text('📍', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        isLeisureProducer ? 'Événement' : 'Lieu',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.3,
                        ),
                        child: Text(
                          currentPost['entityName'] ?? 
                          currentPost['event_name'] ?? 
                          currentPost['target_name'] ?? 
                          'Voir détails',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Bottom content area
            Positioned(
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                padding: const EdgeInsets.only(top: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left side: Post info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Author name with badge
                          Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isLeisureProducer
                                            ? Colors.purple
                                            : (isProducerPost ? Colors.amber : Colors.blue),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: currentPost['author_photo'] ?? 
                                              currentPost['author_avatar'] ?? 
                                              'https://via.placeholder.com/40',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.person, color: Colors.white),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.person, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Post type indicator badge
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        visualBadge,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                  // Automated post indicator
                                  if (isAutomated)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              spreadRadius: 1,
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          '🤖',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        currentPost['author_name'] ?? 'Inconnu',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (isAutomated) ...[
                                        const SizedBox(width: 6),
                                        const Text(
                                          '🤖',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isLeisureProducer && currentPost['referenced_event_id'] != null)
                                    Text(
                                      'Événement: ${currentPost['event_name'] ?? ""}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Caption with improved styling
                          Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              currentPost['content'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Right side: Interaction buttons
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like button
                          _buildReactionButton(
                            emoji: isLiked ? '❤️' : '🤍',
                            count: likesCount,
                            isActive: isLiked,
                            onTap: () => widget.onLike(currentPost['_id'] ?? '', currentPost),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Interest button - always show for producer posts
                          if (isProducerPost)
                            _buildReactionButton(
                              emoji: isInterested ? '⭐' : '☆',
                              count: interestedCount,
                              isActive: isInterested,
                              onTap: _markInterested,
                            ),
                          
                          if (isProducerPost) const SizedBox(height: 16),
                          
                          // Choice button - always show for producer posts
                          if (isProducerPost)
                            _buildReactionButton(
                              emoji: isChoice ? '✅' : '⬜',
                              count: choiceCount,
                              isActive: isChoice,
                              onTap: _markChoice,
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Comment button
                          _buildReactionButton(
                            emoji: '💬',
                            count: (currentPost['comments_count'] ?? 
                                  currentPost['commentsCount'] ?? 
                                  (currentPost['comments'] is List ? 
                                    (currentPost['comments'] as List).length : 0)),
                            onTap: widget.onComment,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Share button
                          _buildReactionButton(
                            emoji: '↗️',
                            count: null,
                            onTap: () {
                              // Share functionality
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Swipe indicator
            Positioned(
              top: MediaQuery.of(context).size.height / 2,
              right: 16,
              child: AnimatedBuilder(
                animation: _swipeAnimController,
                builder: (context, child) {
                  return Column(
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white70,
                        size: 24 + (_swipeAnimController.value * 4),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 50,
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 24 + ((1 - _swipeAnimController.value) * 4),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build video widget
  Widget _buildVideoItem(int index, Map<String, dynamic> mediaItem) {
    if (index == _currentIndex && _isControllerInitialized && _controller != null) {
      return GestureDetector(
        onTap: _toggleControls,
        child: Container(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
  }
  
  // Helper method to build image widget
  Widget _buildImageItem(Map<String, dynamic> mediaItem) {
    return Container(
      color: Colors.black,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: mediaItem['url'],
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to build reaction buttons
  Widget _buildReactionButton({
    required String emoji,
    int? count,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: isActive ? 1.0 : 0.8),
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withOpacity(0.3) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              );
            },
          ),
          if (count != null) ...[
            const SizedBox(height: 4),
            Text(
              count > 0 ? count.toString() : '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}