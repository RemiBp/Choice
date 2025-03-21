import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/dialogic_ai_feed_service.dart';
import 'feed_screen_controller.dart';
import 'reels_view_screen.dart';
import 'post_detail_screen.dart';
import 'producer_screen.dart';
import 'producerLeisure_screen.dart';

class FeedScreen extends StatefulWidget {
  final String userId;

  const FeedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late final FeedScreenController _controller;
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  // Video controllers for posts containing videos
  final Map<String, VideoPlayerController> _videoControllers = {};
  
  // Controller for AI message response input
  final TextEditingController _aiResponseController = TextEditingController();
  
  // Track visible posts for auto-playing videos
  String? _currentlyPlayingVideoId;
  
  @override
  void initState() {
    super.initState();
    // Initialize controller with required userId
    _controller = FeedScreenController(userId: widget.userId);
    
    // Set up tab controller for feed filters
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Load initial feed content
    _controller.loadFeed();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_handleScroll);
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    
    FeedContentType newFilter;
    switch (_tabController.index) {
      case 0:
        newFilter = FeedContentType.all;
        break;
      case 1:
        newFilter = FeedContentType.restaurants;
        break;
      case 2:
        newFilter = FeedContentType.leisure;
        break;
      case 3:
        newFilter = FeedContentType.userPosts;
        break;
      case 4:
        newFilter = FeedContentType.aiDialogic;
        break;
      default:
        newFilter = FeedContentType.all;
    }
    
    _controller.filterFeed(newFilter);
  }
  
  void _handleScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 && 
        _controller.hasMorePosts) {
      _controller.loadMore();
    }
  }
  
  @override
  void dispose() {
    // Clean up video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    
    _tabController.dispose();
    _scrollController.dispose();
    _aiResponseController.dispose();
    super.dispose();
  }
  
  // Initialize video controller for a specific post
  Future<void> _initializeVideoController(String postId, String videoUrl) async {
    if (_videoControllers.containsKey(postId)) {
      return;
    }
    
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[postId] = controller;
      
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0.0); // Muted by default
      
      // Only auto-play if this post is currently visible
      if (_currentlyPlayingVideoId == postId) {
        controller.play();
      }
      
      // Ensure the widget rebuilds after controller is initialized
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error initializing video controller: $e');
    }
  }
  
  // Handle post visibility changes for auto-playing videos
  void _handlePostVisibilityChanged(String postId, double visibleFraction, String? videoUrl) {
    if (videoUrl == null) return;
    
    if (visibleFraction > 0.7) {
      // Post is mostly visible, play its video
      if (_currentlyPlayingVideoId != postId) {
        // Pause current video
        if (_currentlyPlayingVideoId != null && 
            _videoControllers.containsKey(_currentlyPlayingVideoId)) {
          _videoControllers[_currentlyPlayingVideoId]!.pause();
        }
        
        // Set new currently playing video
        _currentlyPlayingVideoId = postId;
        
        // Initialize and play the video if needed
        if (!_videoControllers.containsKey(postId)) {
          _initializeVideoController(postId, videoUrl).then((_) {
            if (_currentlyPlayingVideoId == postId && 
                _videoControllers.containsKey(postId)) {
              _videoControllers[postId]!.play();
            }
          });
        } else if (_videoControllers.containsKey(postId)) {
          _videoControllers[postId]!.play();
        }
      }
    } else if (visibleFraction < 0.2 && 
               _currentlyPlayingVideoId == postId && 
               _videoControllers.containsKey(postId)) {
      // Post is barely visible, pause its video
      _videoControllers[postId]!.pause();
      _currentlyPlayingVideoId = null;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              title: Text(
                'Choice',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.deepPurple[700],
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 2,
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: Colors.deepPurple[700]),
                  onPressed: () {
                    // Handle search
                  },
                ),
                IconButton(
                  icon: Icon(Icons.notifications_none, color: Colors.deepPurple[700]),
                  onPressed: () {
                    // Handle notifications
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.deepPurple,
                labelColor: Colors.deepPurple[700],
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'Pour vous'),
                  Tab(text: 'Restaurants'),
                  Tab(text: 'Loisirs'),
                  Tab(text: 'Amis'),
                  Tab(text: 'Découvrir'),
                ],
              ),
            ),
          ];
        },
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.loadState == FeedLoadState.initial) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (_controller.loadState == FeedLoadState.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Erreur : ${_controller.errorMessage}',
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _controller.refreshFeed(),
                      child: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            if (_controller.feedItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.feed, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun contenu disponible',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _controller.refreshFeed(),
                      child: const Text('Actualiser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            return RefreshIndicator(
              onRefresh: () => _controller.refreshFeed(),
              color: Colors.deepPurple,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                itemCount: _controller.feedItems.length + 
                  (_controller.loadState == FeedLoadState.loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _controller.feedItems.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  final item = _controller.feedItems[index];
                  
                  // Handle different types of feed items
                  if (item is DialogicAIMessage) {
                    return _buildAIMessageCard(item);
                  } else if (item is Post) {
                    return _buildPostCard(item);
                  } else if (item is Map<String, dynamic>) {
                    return _buildDynamicPostCard(item);
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle creating a new post
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  
  // Build card for AI messages in feed
  Widget _buildAIMessageCard(DialogicAIMessage message) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.deepPurple.shade100,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Avatar and indicator
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple.shade200,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.emoji_objects_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choice AI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Assistant personnel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Message content
              Text(
                message.content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              
              // Suggestions chips if interactive
              if (message.isInteractive && message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.suggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(suggestion),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.deepPurple.shade200),
                      labelStyle: TextStyle(color: Colors.deepPurple.shade700),
                      onPressed: () async {
                        // Show response input when user taps a suggestion
                        final response = await _showAIResponseInput(suggestion);
                        if (response != null && response.isNotEmpty) {
                          final aiResponse = await _controller.interactWithAiMessage(response);
                          
                          // Insert AI response in feed after this message
                          if (mounted) {
                            setState(() {
                              final index = _controller.feedItems.indexOf(message);
                              if (index != -1) {
                                _controller.feedItems.insert(index + 1, aiResponse);
                              }
                            });
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
              
              // Input field for direct response if interactive
              if (message.isInteractive) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _aiResponseController,
                  decoration: InputDecoration(
                    hintText: 'Répondre à Choice AI...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.deepPurple,
                      onPressed: () async {
                        final text = _aiResponseController.text.trim();
                        if (text.isNotEmpty) {
                          final aiResponse = await _controller.interactWithAiMessage(text);
                          _aiResponseController.clear();
                          
                          // Insert AI response in feed
                          if (mounted) {
                            setState(() {
                              final index = _controller.feedItems.indexOf(message);
                              if (index != -1) {
                                _controller.feedItems.insert(index + 1, aiResponse);
                              }
                            });
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Build card for regular Post objects
  Widget _buildPostCard(Post post) {
    final hasMedia = post.media.isNotEmpty;
    final firstMediaIsVideo = hasMedia && post.media.first.type == 'video';
    final videoUrl = firstMediaIsVideo ? post.media.first.url : null;
    
    // Track post view for AI context
    _controller.trackPostView(post);
    
    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (info) {
        if (videoUrl != null) {
          _handlePostVisibilityChanged(post.id, info.visibleFraction, videoUrl);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header with author info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate to author profile
                      if (post.isProducerPost) {
                        if (post.isLeisureProducer) {
                          // Navigate to leisure producer profile
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProducerScreen(
                                producerId: post.authorId,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        }
                      } else {
                        // Navigate to user profile
                      }
                    },
                    child: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                        post.authorAvatar.isNotEmpty
                            ? post.authorAvatar
                            : 'https://via.placeholder.com/150',
                      ),
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatTimestamp(post.postedAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: Colors.grey[700]),
                    onPressed: () {
                      // Show post options
                      _showPostOptions(post);
                    },
                  ),
                ],
              ),
            ),
            
            // Post content
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  post.content,
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),
              ),
            
            // Post media
            if (hasMedia) ...[
              if (post.media.length == 1) ...[
                // Single media item
                GestureDetector(
                  onTap: () {
                    // Open media in fullscreen
                    if (firstMediaIsVideo && videoUrl != null) {
                      _openReelsView(post, videoUrl);
                    } else {
                      _openPostDetail(post);
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 200,
                      maxHeight: 400,
                    ),
                    width: double.infinity,
                    child: firstMediaIsVideo
                        ? _buildVideoPlayer(post.id, videoUrl!)
                        : CachedNetworkImage(
                            imageUrl: post.media.first.url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                color: Colors.white,
                                height: 300,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              height: 300,
                              child: const Center(
                                child: Icon(Icons.error, color: Colors.grey),
                              ),
                            ),
                          ),
                  ),
                ),
              ] else ...[
                // Multiple media items
                CarouselSlider.builder(
                  itemCount: post.media.length,
                  options: CarouselOptions(
                    height: 350,
                    enableInfiniteScroll: false,
                    enlargeCenterPage: true,
                    viewportFraction: 1.0,
                  ),
                  itemBuilder: (context, index, _) {
                    final media = post.media[index];
                    final isVideo = media.type == 'video';
                    
                    return GestureDetector(
                      onTap: () {
                        if (isVideo) {
                          _openReelsView(post, media.url);
                        } else {
                          _openPostDetail(post);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: isVideo
                            ? _buildVideoPlayer('${post.id}-$index', media.url)
                            : CachedNetworkImage(
                                imageUrl: media.url,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => 
                                    const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => 
                                    const Center(child: Icon(Icons.error)),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ],
            
            // Interaction buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInteractionButton(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    label: 'Like',
                    count: post.likesCount ?? 0,
                    isActive: post.isLiked ?? false,
                    onPressed: () {
                      _controller.likePost(post);
                    },
                  ),
                  
                  // Only show interest button for producer posts
                  if (post.isProducerPost)
                    _buildInteractionButton(
                      icon: Icons.star,
                      iconColor: Colors.amber,
                      label: 'Intéressé',
                      count: post.interestedCount,
                      isActive: post.isInterested,
                      onPressed: () {
                        _controller.markInterested(
                          post.id, 
                          post,
                          isLeisureProducer: post.isLeisureProducer,
                        );
                      },
                    ),
                  
                  // Only show choice button for producer posts
                  if (post.isProducerPost)
                    _buildInteractionButton(
                      icon: Icons.check_box,
                      iconColor: Colors.green,
                      label: 'Choice',
                      count: post.choiceCount,
                      isActive: post.isChoice,
                      onPressed: () {
                        _controller.markChoice(
                          post.id, 
                          post,
                          isLeisureProducer: post.isLeisureProducer,
                        );
                      },
                    ),
                  
                  _buildInteractionButton(
                    icon: Icons.chat_bubble_outline,
                    iconColor: Colors.blue,
                    label: 'Comment',
                    count: post.comments.length,
                    onPressed: () {
                      _openPostDetail(post);
                    },
                  ),
                  
                  _buildInteractionButton(
                    icon: Icons.share,
                    iconColor: Colors.purple,
                    label: 'Share',
                    onPressed: () {
                      // Handle share
                    },
                  ),
                ],
              ),
            ),
            
            // Preview of comments if there are any
            if (post.comments.isNotEmpty) ...[
              Divider(color: Colors.grey[200]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commentaires récents',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...post.comments.take(2).map((comment) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: CachedNetworkImageProvider(
                              comment.authorAvatar.isNotEmpty
                                  ? comment.authorAvatar
                                  : 'https://via.placeholder.com/150',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  comment.content,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                    
                    // Show more comments button if there are more than 2
                    if (post.comments.length > 2)
                      TextButton(
                        onPressed: () {
                          _openPostDetail(post);
                        },
                        child: Text(
                          'Voir les ${post.comments.length - 2} autres commentaires',
                          style: TextStyle(
                            color: Colors.deepPurple[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Build card for Map-based post object (dynamic structure from backend)
  Widget _buildDynamicPostCard(Map<String, dynamic> post) {
    final String postId = post['_id'] ?? '';
    final String content = post['content'] ?? '';
    
    // Determine if this is a producer post
    final bool isProducerPost = post['isProducerPost'] == true || 
                              post['producer_id'] != null;
    final bool isLeisureProducer = post['isLeisureProducer'] == true;
    
    // Get author info
    String authorName = '';
    String authorAvatar = '';
    String authorId = '';
    
    if (post['author'] is Map) {
      final author = post['author'] as Map;
      authorName = author['name'] ?? '';
      authorAvatar = author['avatar'] ?? '';
      authorId = author['id'] ?? '';
    } else {
      authorName = post['author_name'] ?? '';
      authorAvatar = post['author_avatar'] ?? post['author_photo'] ?? '';
      authorId = post['author_id'] ?? post['user_id'] ?? '';
    }
    
    // Handle media
    List<Map<String, dynamic>> mediaItems = [];
    if (post['media'] is List) {
      for (var media in post['media']) {
        if (media is Map) {
          final url = media['url'] ?? '';
          final type = media['type'] ?? 'image';
          if (url.isNotEmpty) {
            mediaItems.add({
              'url': url,
              'type': type,
            });
          }
        }
      }
    }
    
    // Get post timestamp
    DateTime postedAt = DateTime.now();
    if (post['posted_at'] != null) {
      try {
        postedAt = DateTime.parse(post['posted_at'].toString());
      } catch (e) {
        print('❌ Error parsing timestamp: $e');
      }
    } else if (post['time_posted'] != null) {
      try {
        postedAt = DateTime.parse(post['time_posted'].toString());
      } catch (e) {
        print('❌ Error parsing timestamp: $e');
      }
    }
    
    // Get counts
    final int likesCount = post['likes_count'] ?? post['likesCount'] ?? 
                        (post['likes'] is List ? (post['likes'] as List).length : 0);
    final int interestedCount = post['interested_count'] ?? post['interestedCount'] ?? 0;
    final int choiceCount = post['choice_count'] ?? post['choiceCount'] ?? 0;
    final int commentsCount = post['comments_count'] ?? post['commentsCount'] ?? 
                           (post['comments'] is List ? (post['comments'] as List).length : 0);
    
    // Check active states
    final bool isLiked = post['isLiked'] == true;
    final bool isInterested = post['interested'] == true || post['isInterested'] == true;
    final bool isChoice = post['choice'] == true || post['isChoice'] == true;
    
    // Track post view for AI context
    _controller.trackPostView(post);
    
    // Get first media URL for video handling
    String? firstVideoUrl;
    if (mediaItems.isNotEmpty && mediaItems.first['type'] == 'video') {
      firstVideoUrl = mediaItems.first['url'];
    }
    
    return VisibilityDetector(
      key: Key('dynamic-post-$postId'),
      onVisibilityChanged: (info) {
        if (firstVideoUrl != null) {
          _handlePostVisibilityChanged(postId, info.visibleFraction, firstVideoUrl);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header with author info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate to author profile based on type
                      if (isProducerPost) {
                        if (isLeisureProducer) {
                          // Navigate to leisure producer profile
                        } else {
                          // Navigate to restaurant producer profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProducerScreen(
                                producerId: authorId,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        }
                      } else {
                        // Navigate to user profile
                      }
                    },
                    child: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                        authorAvatar.isNotEmpty
                            ? authorAvatar
                            : 'https://via.placeholder.com/150',
                      ),
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatTimestamp(postedAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: Colors.grey[700]),
                    onPressed: () {
                      // Show post options
                      _showPostOptions(post);
                    },
                  ),
                ],
              ),
            ),
            
            // Post content
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),
              ),
            
            // Post media
            if (mediaItems.isNotEmpty) ...[
              if (mediaItems.length == 1) ...[
                // Single media item
                GestureDetector(
                  onTap: () {
                    // Open media in fullscreen
                    if (mediaItems.first['type'] == 'video') {
                      _openReelsView(post, mediaItems.first['url']);
                    } else {
                      _openDynamicPostDetail(post);
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 200,
                      maxHeight: 400,
                    ),
                    width: double.infinity,
                    child: mediaItems.first['type'] == 'video'
                        ? _buildVideoPlayer(postId, mediaItems.first['url'])
                        : CachedNetworkImage(
                            imageUrl: mediaItems.first['url'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                color: Colors.white,
                                height: 300,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              height: 300,
                              child: const Center(
                                child: Icon(Icons.error, color: Colors.grey),
                              ),
                            ),
                          ),
                  ),
                ),
              ] else ...[
                // Multiple media items
                CarouselSlider.builder(
                  itemCount: mediaItems.length,
                  options: CarouselOptions(
                    height: 350,
                    enableInfiniteScroll: false,
                    enlargeCenterPage: true,
                    viewportFraction: 1.0,
                  ),
                  itemBuilder: (context, index, _) {
                    final media = mediaItems[index];
                    final isVideo = media['type'] == 'video';
                    
                    return GestureDetector(
                      onTap: () {
                        if (isVideo) {
                          _openReelsView(post, media['url']);
                        } else {
                          _openDynamicPostDetail(post);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: isVideo
                            ? _buildVideoPlayer('$postId-$index', media['url'])
                            : CachedNetworkImage(
                                imageUrl: media['url'],
                                fit: BoxFit.contain,
                                placeholder: (context, url) => 
                                    const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => 
                                    const Center(child: Icon(Icons.error)),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ],
            
            // Interaction buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInteractionButton(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    label: 'Like',
                    count: likesCount,
                    isActive: isLiked,
                    onPressed: () {
                      _controller.likePost(post);
                    },
                  ),
                  
                  // Only show interest button for producer posts
                  if (isProducerPost)
                    _buildInteractionButton(
                      icon: Icons.star,
                      iconColor: Colors.amber,
                      label: 'Intéressé',
                      count: interestedCount,
                      isActive: isInterested,
                      onPressed: () {
                        _controller.markInterested(
                          post['target_id'] ?? post['producer_id'] ?? '',
                          post,
                          isLeisureProducer: isLeisureProducer,
                        );
                      },
                    ),
                  
                  // Only show choice button for producer posts
                  if (isProducerPost)
                    _buildInteractionButton(
                      icon: Icons.check_box,
                      iconColor: Colors.green,
                      label: 'Choice',
                      count: choiceCount,
                      isActive: isChoice,
                      onPressed: () {
                        _controller.markChoice(
                          post['target_id'] ?? post['producer_id'] ?? '',
                          post,
                          isLeisureProducer: isLeisureProducer,
                        );
                      },
                    ),
                  
                  _buildInteractionButton(
                    icon: Icons.chat_bubble_outline,
                    iconColor: Colors.blue,
                    label: 'Comment',
                    count: commentsCount,
                    onPressed: () {
                      _openDynamicPostDetail(post);
                    },
                  ),
                  
                  _buildInteractionButton(
                    icon: Icons.share,
                    iconColor: Colors.purple,
                    label: 'Share',
                    onPressed: () {
                      // Handle share
                    },
                  ),
                ],
              ),
            ),
            
            // Preview of comments if there are any
            if (post['comments'] is List && (post['comments'] as List).isNotEmpty) ...[
              Divider(color: Colors.grey[200]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commentaires récents',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(post['comments'] as List).take(2).map((comment) {
                      final String commentContent = comment['content'] ?? '';
                      final String commentAuthor = comment['author_name'] ?? '';
                      final String commentAvatar = comment['author_avatar'] ?? '';
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: CachedNetworkImageProvider(
                                commentAvatar.isNotEmpty
                                    ? commentAvatar
                                    : 'https://via.placeholder.com/150',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    commentAuthor,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    commentContent,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    // Show more comments button if there are more than 2
                    if ((post['comments'] as List).length > 2)
                      TextButton(
                        onPressed: () {
                          _openDynamicPostDetail(post);
                        },
                        child: Text(
                          'Voir les ${(post['comments'] as List).length - 2} autres commentaires',
                          style: TextStyle(
                            color: Colors.deepPurple[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Build interaction button with animation
  Widget _buildInteractionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    int count = 0,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              transform: isActive 
                  ? Matrix4.diagonal3Values(1.1, 1.1, 1.0)
                  : Matrix4.identity(),
              child: Icon(
                icon,
                color: isActive ? iconColor : Colors.grey[600],
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count > 0 ? '$count' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? iconColor : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build video player widget
  Widget _buildVideoPlayer(String postId, String videoUrl) {
    if (!_videoControllers.containsKey(postId)) {
      _initializeVideoController(postId, videoUrl);
      
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    
    final controller = _videoControllers[postId]!;
    
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                controller.value.volume > 0 
                    ? Icons.volume_up 
                    : Icons.volume_off,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  if (controller.value.volume > 0) {
                    controller.setVolume(0);
                  } else {
                    controller.setVolume(1.0);
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }
  
  // Open reels view in fullscreen
  void _openReelsView(dynamic post, String mediaUrl) {
    // Pause any playing videos
    if (_currentlyPlayingVideoId != null && 
        _videoControllers.containsKey(_currentlyPlayingVideoId)) {
      _videoControllers[_currentlyPlayingVideoId]!.pause();
    }
    
    // Extract necessary data for reels view
    Map<String, dynamic> postData;
    if (post is Post) {
      postData = {
        '_id': post.id,
        'author_name': post.authorName,
        'author_photo': post.authorAvatar,
        'content': post.content,
        'comments': post.comments,
        'isLiked': post.isLiked,
        'likesCount': post.likesCount,
        'interested': post.isInterested,
        'entity_interests_count': post.interestedCount,
        'choice': post.isChoice,
        'entity_choices_count': post.choiceCount,
        'isProducerPost': post.isProducerPost,
        'is_leisure_producer': post.isLeisureProducer,
        'producer_id': post.isProducerPost ? post.authorId : null,
      };
    } else {
      postData = post as Map<String, dynamic>;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelsViewScreen(
          initialMediaUrl: mediaUrl,
          isVideo: mediaUrl.toLowerCase().endsWith('.mp4') ||
                 mediaUrl.contains('video'),
          postData: postData,
          userId: widget.userId,
          onLike: (postId, data) {
            _controller.likePost(data);
          },
          onInterested: (targetId, data, {isLeisureProducer = false}) {
            _controller.markInterested(targetId, data, isLeisureProducer: isLeisureProducer);
          },
          onChoice: (targetId, data, {isLeisureProducer = false}) {
            _controller.markChoice(targetId, data, isLeisureProducer: isLeisureProducer);
          },
          onComment: () {
            // Navigate to comments section
          },
        ),
      ),
    );
  }
  
  // Open post detail screen
  void _openPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: post,
          userId: widget.userId,
        ),
      ),
    );
  }
  
  // Open dynamic post detail
  void _openDynamicPostDetail(Map<String, dynamic> post) {
    // TODO: Implement post detail screen for dynamic posts
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Détails du post bientôt disponibles')),
    );
  }
  
  // Show post options
  void _showPostOptions(dynamic post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Enregistrer'),
              onTap: () {
                Navigator.pop(context);
                // Handle save post
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                // Handle share post
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Signaler'),
              onTap: () {
                Navigator.pop(context);
                // Handle report post
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Dialog to get AI response
  Future<String?> _showAIResponseInput(String suggestion) async {
    final TextEditingController controller = TextEditingController(text: suggestion);
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.shade200,
              ),
              child: const Center(
                child: Icon(
                  Icons.emoji_objects_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Interroger Choice AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Posez votre question...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
  
  // Format timestamp to readable format
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}