import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/choice_carousel.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/dialogic_ai_feed_service.dart';
import '../services/auth_service.dart';
import 'feed_screen_controller.dart';
import 'reels_view_screen.dart';
import 'post_detail_screen.dart';
import 'producer_screen.dart';
import 'producerLeisure_screen.dart';
import 'comments_screen.dart'; // Assume CommentsScreen exists

class ProducerFeedScreen extends StatefulWidget {
  final String userId;

  const ProducerFeedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _ProducerFeedScreenState createState() => _ProducerFeedScreenState();
}

class _ProducerFeedScreenState extends State<ProducerFeedScreen> with SingleTickerProviderStateMixin {
  late final ProducerFeedScreenController _controller;
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  // Video controllers for posts containing videos
  final Map<String, VideoPlayerController> _videoControllers = {};
  
  // Track visible posts for auto-playing videos
  String? _currentlyPlayingVideoId;
  
  // Producer type information determined during initState
  late bool _isLeisureProducer;
  late String _producerTypeString;
  
  @override
  void initState() {
    super.initState();

    // Determine producer type immediately using AuthService from context
    // Note: Accessing Provider here relies on the context being available,
    // which it is in initState.
    final authService = Provider.of<AuthService>(context, listen: false);
    final accountType = authService.accountType;

    _isLeisureProducer = accountType == 'LeisureProducer';
    // Determine the string representation for the API
    if (accountType == 'LeisureProducer') {
      _producerTypeString = 'leisure';
    } else if (accountType == 'WellnessProducer') {
      _producerTypeString = 'wellness';
    } else {
      // Default to restaurant if not leisure or wellness
      _producerTypeString = 'restaurant';
    }

    // Initialize controller with required userId and producerTypeString
    _controller = ProducerFeedScreenController(
      userId: widget.userId,
      producerTypeString: _producerTypeString, // Pass the determined type string
    );
    
    // Set up tab controller for feed filters
    _tabController = TabController(length: 4, vsync: this); // Increased length to 4
    _tabController.addListener(_handleTabChange);
    
    // Load initial feed content
    _controller.loadFeed();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_handleScroll);

    // No need for async _detectProducerType anymore
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    
    ProducerFeedContentType newFilter;
    switch (_tabController.index) {
      case 0:
        newFilter = ProducerFeedContentType.venue;
        break;
      case 1:
        newFilter = ProducerFeedContentType.interactions;
        break;
      case 2:
        newFilter = ProducerFeedContentType.localTrends;
        break;
      case 3: // New case for Followers
        newFilter = ProducerFeedContentType.followers;
        break;
      default:
        newFilter = ProducerFeedContentType.venue;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                floating: true,
                pinned: true,
                title: Row(
                  children: [
                    Icon(
                      _isLeisureProducer ? Icons.museum : Icons.restaurant,
                      color: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isLeisureProducer ? 'Feed Loisirs & Culture' : 'Feed Restaurant',
                      style: TextStyle(
                        color: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
                  labelColor: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Mon lieu'),
                    Tab(text: 'Interactions'),
                    Tab(text: 'Tendances'),
                    Tab(text: 'Followers'), // Added Followers tab
                  ],
                ),
              ),
            ];
          },
          body: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Use the state variable _isLeisureProducer for UI elements
              if (_controller.loadState == ProducerFeedLoadState.initial || 
                  _controller.loadState == ProducerFeedLoadState.loading) {
                return _buildLoadingView(); // Uses _isLeisureProducer
              }
              
              if (_controller.loadState == ProducerFeedLoadState.error) {
                return _buildErrorView(); // Uses _isLeisureProducer
              }
              
              if (_controller.feedItems.isEmpty) {
                return _buildEmptyView(); // Uses _isLeisureProducer
              }
              
              return RefreshIndicator(
                onRefresh: () => _controller.refreshFeed(),
                color: _isLeisureProducer ? Colors.deepPurple : Colors.orange, // Use state variable
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  itemCount: _controller.feedItems.length + 
                    (_controller.loadState == ProducerFeedLoadState.loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _controller.feedItems.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            color: _isLeisureProducer ? Colors.deepPurple : Colors.orange, // Use state variable
                          ),
                        ),
                      );
                    }
                    
                    final item = _controller.feedItems[index];
                    
                    // Handle different types of feed items
                    if (item is DialogicAIMessage) {
                      return _buildAIMessageCard(item);
                    } else if (item is Map<String, dynamic>) {
                      return _buildDynamicPostCard(item);
                    } else if (item is Post) {
                      // Log the Post object we're trying to render
                      print('🔍 Post object in ListView: ${item.runtimeType} - ID: ${item.id}');
                      try {
                        return _buildPostCard(item);
                      } catch (e) {
                        print('❌ Error rendering Post: $e');
                        // Convertir en Map comme solution de secours
                        final postMap = {
                          '_id': item.id,
                          'content': item.content,
                          'time_posted': item.postedAt.toIso8601String(),
                          'author': {
                            'id': item.authorId,
                            'name': item.authorName,
                            'avatar': item.authorAvatar ?? '',
                          },
                          'isProducerPost': item.isProducerPost,
                          'isLeisureProducer': item.isLeisureProducer,
                          'likes_count': item.likesCount,
                          'comments_count': item.comments.length,
                          'comments': item.comments,
                          'isLiked': item.isLiked,
                        };
                        return _buildDynamicPostCard(postMap);
                      }
                    } else {
                      print('⚠️ Item de type non géré: ${item.runtimeType}');
                      return const SizedBox.shrink();
                    }
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show new post creation modal
          _showCreatePostModal();
        },
        backgroundColor: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement de votre feed...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Une erreur est survenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _controller.loadFeed(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyView() {
    final String emptyMessage;
    final IconData emptyIcon;
    
    switch (_tabController.index) {
      case 0: // Venue posts
        emptyMessage = _isLeisureProducer
            ? 'Vous n\'avez pas encore publié de contenu sur votre lieu culturel.'
            : 'Vous n\'avez pas encore publié de contenu sur votre restaurant.';
        emptyIcon = _isLeisureProducer ? Icons.museum : Icons.restaurant;
        break;
      case 1: // Interactions
        emptyMessage = 'Aucune interaction récente avec vos visiteurs.';
        emptyIcon = Icons.people;
        break;
      case 2: // Local trends
        emptyMessage = 'Aucune tendance locale à afficher pour le moment.';
        emptyIcon = Icons.trending_up;
        break;
      case 3: // Followers
        emptyMessage = 'Aucun post récent de vos followers.';
        emptyIcon = Icons.group;
        break;
      default:
        emptyMessage = 'Aucun contenu à afficher.';
        emptyIcon = Icons.inbox;
        break;
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              color: Colors.grey[400],
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            if (_tabController.index == 0)
              ElevatedButton.icon(
                onPressed: () => _showCreatePostModal(),
                icon: const Icon(Icons.add),
                label: const Text('Créer un post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLeisureProducer ? Colors.deepPurple : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
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
                        'Analyses locales',
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
            ],
          ),
        ),
      ),
    );
  }
  
  // Build card for regular Post objects
  Widget _buildPostCard(Post post) {
    print('📌 _buildPostCard - Post Type: ${post.runtimeType}');
    print('📌 _buildPostCard - Post ID: ${post.id}');
    print('📌 _buildPostCard - Post content: ${post.content}');
    print('📌 _buildPostCard - Post author: ${post.authorName}');
    
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
            // Post header with author info and post type indicator
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Author avatar with badge overlay for automated posts
                  Stack(
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
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getPostTypeColor(post), // Use helper function
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              post.authorAvatar.isNotEmpty
                                  ? post.authorAvatar
                                  : 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop',
                            ),
                            radius: 20,
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
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            _getVisualBadge(post), // Use helper function
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      // Automated post indicator if applicable
                      if (post.isAutomated == true)
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
                                  color: Colors.grey.withOpacity(0.3),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (post.isAutomated == true)
                              const SizedBox(width: 4),
                            if (post.isAutomated == true)
                              const Text(
                                '🤖',
                                style: TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTimestamp(post.postedAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPostTypeColor(post).withOpacity(0.9), // Use helper color
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _getPostTypeLabel(post), // Use helper function
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getPostTypeColor(post).withOpacity(0.9), // Use helper color
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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
                        : (() {
                          final imageProvider = getImageProvider(post.media.first.url);
                          if (imageProvider != null) {
                            return Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                              height: 300,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                height: 300,
                                child: const Center(child: Icon(Icons.error, color: Colors.grey)),
                              ),
                            );
                          } else {
                            return Container(
                              color: Colors.grey[200],
                              height: 300,
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            );
                          }
                        })(),
                  ),
                ),
              ] else ...[
                // Multiple media items
                ChoiceCarousel.builder(
                  itemCount: post.media.length,
                  options: ChoiceCarouselOptions(
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
                            : (() {
                              final imageProvider = getImageProvider(media.url);
                              if (imageProvider != null) {
                                return Image(
                                  image: imageProvider,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
                                );
                              } else {
                                return const Center(child: Icon(Icons.broken_image));
                              }
                            })(),
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
                  
                  // Special button for post stats for producers
                  _buildInteractionButton(
                    icon: Icons.analytics,
                    iconColor: Colors.teal,
                    label: 'Stats',
                    onPressed: () {
                      // Show post stats dialog
                      _showPostStats(post);
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
                              comment['author_avatar'] != null && comment['author_avatar'].toString().isNotEmpty
                                  ? comment['author_avatar']
                                  : 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['author_name'] ?? 'Utilisateur',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  comment['content'] ?? '',
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
    final int commentsCount = post['comments_count'] ?? post['commentsCount'] ?? 
                           (post['comments'] is List ? (post['comments'] as List).length : 0);
    
    // Check active states
    final bool isLiked = post['isLiked'] == true;
    
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
            // Post header with author info and post type indicator
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Author avatar with badge overlay for post type
                  Stack(
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
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getPostTypeColor(post), // Use helper function
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              authorAvatar.isNotEmpty
                                ? authorAvatar
                                : 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop',
                            ),
                            radius: 20,
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
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            post['visualBadge'] as String? ?? _getVisualBadge(post), // Use helper as fallback
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      // Automated post indicator
                      if (post['is_automated'] == true)
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
                                  color: Colors.grey.withOpacity(0.3),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (post['is_automated'] == true)
                              const SizedBox(width: 4),
                            if (post['is_automated'] == true)
                              const Text(
                                '🤖',
                                style: TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTimestamp(postedAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPostTypeColor(post).withOpacity(0.9), // Use helper color
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _getPostTypeLabel(post), // Use helper function
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getPostTypeColor(post).withOpacity(0.9), // Use helper color
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Event or target indicator
                            if (post['hasReferencedEvent'] == true || post['hasTarget'] == true)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  post['hasReferencedEvent'] == true 
                                      ? 'Événement' 
                                      : 'Lieu',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
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
                        : (() {
                          final imageProvider = getImageProvider(mediaItems.first['url']);
                          if (imageProvider != null) {
                            return Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                              height: 300,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                height: 300,
                                child: const Center(child: Icon(Icons.error, color: Colors.grey)),
                              ),
                            );
                          } else {
                            return Container(
                              color: Colors.grey[200],
                              height: 300,
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            );
                          }
                        })(),
                  ),
                ),
              ] else ...[
                // Multiple media items
                ChoiceCarousel.builder(
                  itemCount: mediaItems.length,
                  options: ChoiceCarouselOptions(
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
                            : (() {
                              final imageProvider = getImageProvider(media['url']);
                              if (imageProvider != null) {
                                return Image(
                                  image: imageProvider,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
                                );
                              } else {
                                return const Center(child: Icon(Icons.broken_image));
                              }
                            })(),
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
                  
                  _buildInteractionButton(
                    icon: Icons.chat_bubble_outline,
                    iconColor: Colors.blue,
                    label: 'Comment',
                    count: commentsCount,
                    onPressed: () {
                      _openComments(post); // Use new method
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
                  
                  // Special button for post stats for producers
                  _buildInteractionButton(
                    icon: Icons.analytics,
                    iconColor: Colors.teal,
                    label: 'Stats',
                    onPressed: () {
                      // Show post stats dialog
                      _showPostStats(post);
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
                                    : 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop',
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
                          _openComments(post); // Use new method
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
  
  // Open reels view in fullscreen with enhanced data
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
        'is_leisure_producer': post.isLeisureProducer,
        'is_automated': post.isAutomated,
        'producer_id': post.isProducerPost ? post.authorId : null,
        'referenced_event_id': post.referencedEventId,
        'visualBadge': post.isLeisureProducer ? '🎭' : (post.isProducerPost ? '🍽️' : '👤'),
        'hasReferencedEvent': post.referencedEventId != null,
        'hasTarget': post.targetId != null,
      };
    } else {
      // For dynamic posts, ensure all required fields are included
      postData = {...post}; // Create a copy to avoid modifying the original
      
      // Ensure all necessary fields for reels display
      if (postData['visualBadge'] == null) {
        final bool isLeisureProducer = postData['isLeisureProducer'] == true;
        final bool isProducerPost = postData['isProducerPost'] == true;
        postData['visualBadge'] = isLeisureProducer ? '🎭' : (isProducerPost ? '🍽️' : '👤');
      }
    }
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ReelsViewScreen(
          initialMediaUrl: mediaUrl,
          isVideo: mediaUrl.toLowerCase().endsWith('.mp4') ||
                 mediaUrl.contains('video'),
          postData: postData,
          userId: widget.userId,
          onLike: (postId, data) {
            _controller.likePost(data);
          },
          onInterested: (targetId, data, {isLeisureProducer = false}) {
            // Handle interest marking
            print('Marqué comme intéressé: $targetId');
          },
          onChoice: (targetId, data, {isLeisureProducer = false}) {
            // Handle choice marking
            print('Marqué comme choix: $targetId');
          },
          onComment: () {
            // Navigate to comments section
            if (post is Post) {
              _openPostDetail(post);
            } else {
              _openDynamicPostDetail(post as Map<String, dynamic>);
            }
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuart;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }
  
  // Open post detail screen
  void _openPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          postId: post.id,
          userId: widget.userId,
        ),
      ),
    );
  }
  
  // Open dynamic post detail
  void _openDynamicPostDetail(Map<String, dynamic> post) {
    _openComments(post);
    // Original SnackBar logic removed
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('Détails du post bientôt disponibles')),
    // );
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
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                // Handle edit post
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('Promouvoir'),
              onTap: () {
                Navigator.pop(context);
                // Handle promote post
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
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // Handle delete post
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Show post statistics for producers
  void _showPostStats(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.teal),
                      const SizedBox(width: 10),
                      const Text(
                        'Statistiques de publication',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[300]),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Impressions
                      _buildStatCard(
                        icon: Icons.visibility,
                        title: 'Impressions',
                        value: '1,245',
                        subtitle: '+12% vs moyenne',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      
                      // Engagement
                      _buildStatCard(
                        icon: Icons.thumb_up,
                        title: 'Engagement',
                        value: '248',
                        subtitle: '19.9% taux d\'engagement',
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 16),
                      
                      // Clics sur le profil
                      _buildStatCard(
                        icon: Icons.person,
                        title: 'Visites de profil',
                        value: '86',
                        subtitle: '6.9% des impressions',
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 16),
                      
                      // Interactions by type
                      const Text(
                        'Interactions par type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInteractionTypeItem(
                                  icon: Icons.favorite,
                                  label: 'Likes',
                                  count: '165',
                                  color: Colors.red,
                                ),
                                _buildInteractionTypeItem(
                                  icon: Icons.chat_bubble_outline,
                                  label: 'Commentaires',
                                  count: '42',
                                  color: Colors.blue,
                                ),
                                _buildInteractionTypeItem(
                                  icon: Icons.share,
                                  label: 'Partages',
                                  count: '23',
                                  color: Colors.purple,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInteractionTypeItem(
                                  icon: Icons.bookmark,
                                  label: 'Enregistrements',
                                  count: '18',
                                  color: Colors.amber,
                                ),
                                _buildInteractionTypeItem(
                                  icon: Icons.place,
                                  label: 'Vues sur carte',
                                  count: '93',
                                  color: Colors.green,
                                ),
                                _buildInteractionTypeItem(
                                  icon: Icons.timer,
                                  label: 'Temps moyen',
                                  count: '9.2s',
                                  color: Colors.teal,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Viewer demographics if available
                      const Text(
                        'Démographie des spectateurs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Genre',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 15,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 15,
                                              height: 120,
                                              decoration: BoxDecoration(
                                                color: Colors.pink,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('H 42%', style: TextStyle(fontSize: 12)),
                                          SizedBox(width: 16),
                                          Text('F 58%', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 120,
                                  color: Colors.grey[300],
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Âge',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _buildAgeBar('18-24', 60, Colors.teal),
                                          _buildAgeBar('25-34', 120, Colors.teal),
                                          _buildAgeBar('35-44', 90, Colors.teal),
                                          _buildAgeBar('45+', 40, Colors.teal),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Recommendations
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.amber.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recommendations IA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ce post performe bien! Voici comment l\'améliorer:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            _buildRecommendationItem(
                              'Publiez à nouveau ce contenu entre 18h-20h les vendredis pour un impact maximum.'
                            ),
                            _buildRecommendationItem(
                              'Créez une offre spéciale liée à ce contenu populaire pour convertir les vues en visites.'
                            ),
                            _buildRecommendationItem(
                              'Ajoutez plus de photos de ce type à votre profil pour attirer des clients similaires.'
                            ),
                          ],
                        ),
                      ),
                    ],
                        ),
                      ),
                    ],
            ),
          );
        },
                  ),
                );
              }
            
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                      Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
  Widget _buildInteractionTypeItem({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildAgeBar(String label, double height, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
  
  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
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

  // Méthode pour afficher la popup de création de post
  void _showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Poignée pour drag
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _isLeisureProducer ? 'Nouvelle publication culturelle' : 'Nouvelle publication restaurant',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Options de création selon le type de producteur
                    ..._buildCreateOptions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildCreateOptions() {
    final options = <Widget>[];
    
    if (_isLeisureProducer) {
      // Options pour un producteur culturel
      options.addAll([
        _buildCreateOption(
          icon: Icons.event,
          title: 'Promouvoir un événement',
          subtitle: 'Publiez un nouvel événement ou une exposition',
          color: Colors.deepPurple,
          onTap: () {
            Navigator.pop(context);
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => CreateEventPostScreen(userId: widget.userId),
            //   ),
            // );
          },
        ),
        _buildCreateOption(
          icon: Icons.photo_library,
          title: 'Partager des photos',
          subtitle: 'Mettez en valeur votre lieu culturel',
          color: Colors.blue,
          onTap: () {
            Navigator.pop(context);
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => CreatePhotoPostScreen(userId: widget.userId),
            //   ),
            // );
          },
        ),
        _buildCreateOption(
          icon: Icons.campaign,
          title: 'Annonce',
          subtitle: 'Informez vos visiteurs d\'une actualité importante',
          color: Colors.amber,
          onTap: () {
            Navigator.pop(context);
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => CreateAnnouncementScreen(userId: widget.userId),
            //   ),
            // );
          },
        ),
      ]);
    } else {
      // Options pour un restaurant
      options.addAll([
        _buildCreateOption(
          icon: Icons.restaurant_menu,
          title: 'Nouveau plat',
          subtitle: 'Présentez une nouvelle création culinaire',
          color: Colors.orange,
          onTap: () {
            Navigator.pop(context);
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => CreateDishPostScreen(userId: widget.userId),
            //   ),
            // );
          },
        ),
        _buildCreateOption(
          icon: Icons.local_offer,
          title: 'Promotion',
          subtitle: 'Créez une offre spéciale pour attirer plus de clients',
          color: Colors.green,
          onTap: () {
            Navigator.pop(context);
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => CreatePromotionScreen(userId: widget.userId),
            //   ),
            // );
          },
        ),
        _buildCreateOption(
          icon: Icons.event_available,
          title: 'Événement culinaire',
          subtitle: 'Annoncez un événement dans votre restaurant',
          color: Colors.red,
          onTap: () {
            Navigator.pop(context);
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => CreateCulinaryEventScreen(userId: widget.userId),
            //   ),
            // );
          },
        ),
      ]);
    }
    
    // Option commune - Post générique
    options.add(
      _buildCreateOption(
        icon: Icons.post_add,
        title: 'Post simple',
        subtitle: 'Publiez un contenu sur votre page',
        color: Colors.indigo,
        onTap: () {
          Navigator.pop(context);
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => CreateSimplePostScreen(userId: widget.userId),
          //   ),
          // );
        },
      ),
    );
    
    return options;
  }
  
  Widget _buildCreateOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Open comments screen for a post (can be Post or Map)
  void _openComments(dynamic postData) {
    String postIdToOpen;
    Post? postObject; // To pass the actual Post object if available

    if (postData is Post) {
      postIdToOpen = postData.id;
      postObject = postData;
    } else if (postData is Map<String, dynamic>) {
      postIdToOpen = postData['_id']?.toString() ?? '';
      // Optionally, try to convert Map to Post if CommentsScreen needs it
      // postObject = _convertToPost(postData); // You'd need a conversion function
    } else {
      print('❌ Cannot open comments for unknown post type');
      return;
    }

    if (postIdToOpen.isEmpty) {
        print('❌ Cannot open comments: Post ID is empty');
        return;
    }

    // Navigate to CommentsScreen instead of PostDetailScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          // Assuming CommentsScreen takes postId and userId,
          // and potentially the Post object itself
          postId: postIdToOpen,
          userId: widget.userId,
          post: postObject, // Pass the Post object if available and needed
        ),
      ),
    );
  }
  
  // Helper to get comments count robustly
  int _getCommentsCount(dynamic post) {
    if (post is Post) {
      return post.comments.length; // Assuming Post model has a comments list
    } else if (post is Map<String, dynamic>) {
      final comments = post['comments'];
      final count = post['comments_count'] ?? post['commentsCount'];
      if (comments is List) return comments.length;
      if (count is int) return count;
    }
    return 0;
  }
  
  // Helper to check if post has comments robustly
  bool _hasComments(dynamic post) {
    return _getCommentsCount(post) > 0;
  }
  
  // Helper to build comments preview robustly
  List<Widget> _getCommentsWidgets(dynamic post, int limit) {
    List<dynamic>? commentsData;
    if (post is Post) {
      commentsData = post.comments;
    } else if (post is Map<String, dynamic> && post['comments'] is List) {
      commentsData = post['comments'] as List;
    }

    if (commentsData == null || commentsData.isEmpty) {
      return [const SizedBox.shrink()];
    }

    final commentsToShow = commentsData.take(limit);

    return commentsToShow.map((comment) {
      if (comment is Map<String, dynamic>) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: CachedNetworkImageProvider(
                  comment['author_avatar']?.toString() ?? 
                  comment['authorAvatar']?.toString() ?? 
                  'https://api.dicebear.com/6.x/adventurer/png?seed=${comment['author_id'] ?? comment['authorId'] ?? 'default'}'
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['author_name']?.toString() ?? 
                      comment['authorName']?.toString() ?? 'Utilisateur',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      comment['content']?.toString() ?? 
                      comment['text']?.toString() ?? '',
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
      } else {
        return const SizedBox.shrink();
      }
    }).toList();
  }
}

// Special controller for the producer feed that only shows posts related to the producer
class ProducerFeedScreenController extends ChangeNotifier {
  final String userId;
  final String producerTypeString; // Added producer type string
  List<dynamic> _feedItems = [];
  ProducerFeedLoadState _loadState = ProducerFeedLoadState.initial;
  ProducerFeedContentType _currentFilter = ProducerFeedContentType.venue;
  String _errorMessage = '';
  bool _hasMorePosts = true;
  int _page = 1;
  final ApiService _apiService = ApiService();
  
  ProducerFeedScreenController({
    required this.userId,
    required this.producerTypeString, // Require producer type string
  });
  
  List<dynamic> get feedItems => _feedItems;
  ProducerFeedLoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;
  bool get hasMorePosts => _hasMorePosts;
  
  Future<void> loadFeed() async {
    if (_loadState == ProducerFeedLoadState.loading) return;
    
    _loadState = ProducerFeedLoadState.loading;
    _page = 1;
    notifyListeners();
    
    try {
      final response = await _fetchProducerFeed(_page, _currentFilter);
      
      _feedItems = response['items'] ?? [];
      _hasMorePosts = response['hasMore'] ?? false;
      _loadState = ProducerFeedLoadState.loaded;
    } catch (e) {
      _loadState = ProducerFeedLoadState.error;
      _errorMessage = e.toString();
      print('❌ Error loading feed: $e');
    }
    
    notifyListeners();
  }
  
  Future<void> loadMore() async {
    if (_loadState == ProducerFeedLoadState.loadingMore || 
        _loadState == ProducerFeedLoadState.loading || 
        !_hasMorePosts) {
      return;
    }
    
    _loadState = ProducerFeedLoadState.loadingMore;
    notifyListeners();
    
    try {
      final response = await _fetchProducerFeed(_page + 1, _currentFilter);
      
      final newItems = response['items'] ?? [];
      _feedItems.addAll(newItems);
      _hasMorePosts = response['hasMore'] ?? false;
      _page++;
      _loadState = ProducerFeedLoadState.loaded;
    } catch (e) {
      _loadState = ProducerFeedLoadState.error;
      _errorMessage = e.toString();
      print('❌ Error loading more feed items: $e');
    }
    
    notifyListeners();
  }
  
  Future<void> refreshFeed() async {
    await loadFeed();
  }
  
  void filterFeed(ProducerFeedContentType filter) {
    if (_currentFilter == filter) return;
    
    _currentFilter = filter;
    loadFeed();
  }
  
  Future<Map<String, dynamic>> _fetchProducerFeed(int page, ProducerFeedContentType filter) async {
    // API endpoint to get producer-specific feed
    try {
      // Determine producer type string based on _isLeisureProducer
      // TODO: Need a more robust way if Wellness producers use this screen/controller too.
      // Removed AuthService call from here - use the passed producerTypeString
      // final authService = Provider.of<AuthService>(context, listen: false);
      // final accountType = authService.accountType; // Get account type from AuthService
      // String producerTypeString = 'restaurant'; // Default
      // if (accountType == 'LeisureProducer') {
      //   producerTypeString = 'leisure';
      // } else if (accountType == 'WellnessProducer') {
      //   producerTypeString = 'wellness';
      // }

      // Utiliser la nouvelle méthode getProducerFeed pour toutes les requêtes
      return await _apiService.getProducerFeed(
        userId,
        contentType: filter, // Pass the enum value directly
        page: page,
        limit: 10,
        // Only add producerType query parameter if the filter is followers, use stored type
        producerType: filter == ProducerFeedContentType.followers ? producerTypeString : null,
      );
    } catch (e) {
      print('❌ Error in _fetchProducerFeed: $e');
      return {
        'items': [],
        'hasMore': false,
      };
    }
  }
  
  Future<void> likePost(dynamic post) async {
    if (post == null) return;
    
    String postId;
    if (post is Post) {
      postId = post.id;
    } else if (post is Map<String, dynamic>) {
      postId = post['_id'] ?? '';
    } else {
      return;
    }
    
    try {
      await _apiService.toggleLike(userId, postId);
      
      // Mettre à jour l'état local
      final index = _findPostIndex(post);
      if (index >= 0) {
        if (_feedItems[index] is Map<String, dynamic>) {
          final map = _feedItems[index] as Map<String, dynamic>;
          final bool isLiked = map['isLiked'] == true;
          final int currentCount = map['likes_count'] ?? 0;
          
          map['isLiked'] = !isLiked;
          map['likes_count'] = isLiked ? currentCount - 1 : currentCount + 1;
        } else if (_feedItems[index] is Post) {
          final Post postObj = _feedItems[index] as Post;
          final bool isLiked = postObj.isLiked ?? false;
          final int currentCount = postObj.likesCount ?? 0;
          
          _feedItems[index] = postObj.copyWith(
            isLiked: !isLiked,
            likesCount: isLiked ? (currentCount > 0 ? currentCount - 1 : 0) : currentCount + 1,
          );
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error liking post: $e');
    }
  }
  
  int _findPostIndex(dynamic post) {
    if (post == null) return -1;
    
    String postId;
    if (post is Post) {
      postId = post.id;
    } else if (post is Map<String, dynamic>) {
      postId = post['_id'] ?? '';
    } else {
      return -1;
    }
    
    for (int i = 0; i < _feedItems.length; i++) {
      if (_feedItems[i] is Post && (_feedItems[i] as Post).id == postId) {
        return i;
      } else if (_feedItems[i] is Map<String, dynamic> && (_feedItems[i] as Map<String, dynamic>)['_id'] == postId) {
        return i;
      }
    }
    
    return -1;
  }
  
  // Track post view for AI recommendations
  void trackPostView(dynamic post) {
    try {
      String postId = '';
      
      if (post is Post) {
        postId = post.id;
      } else if (post is Map<String, dynamic>) {
        postId = post['_id'] ?? '';
      }
      
      if (postId.isNotEmpty) {
        _apiService.trackPostView(
          postId: postId,
          userId: userId,
        );
      }
    } catch (e) {
      print('❌ Error tracking post view: $e');
    }
  }
}

enum ProducerFeedLoadState {
  initial,
  loading,
  loaded,
  loadingMore,
  error,
}

enum ProducerFeedContentType {
  venue,
  interactions,
  localTrends,
  followers, // Added followers type
}

// Helper function to determine border color based on post type
Color _getPostTypeColor(dynamic post) {
  bool isLeisure = false;
  bool isRestaurant = false;
  bool isWellness = false;
  bool isUser = true;

  if (post is Post) {
    isLeisure = post.isLeisureProducer ?? false;
    isWellness = post.isBeautyProducer ?? false; // Check wellness/beauty flag
    isRestaurant = (post.isProducerPost ?? false) && !isLeisure && !isWellness;
    isUser = !(post.isProducerPost ?? false);
  } else if (post is Map<String, dynamic>) {
    isLeisure = post['isLeisureProducer'] == true;
    isWellness = post['isWellnessProducer'] == true || post['is_wellness_producer'] == true || post['isBeautyProducer'] == true;
    isRestaurant = (post['isProducerPost'] == true || post['producer_id'] != null) && !isLeisure && !isWellness;
    isUser = !(isLeisure || isRestaurant || isWellness);
  }

  if (isLeisure) return Colors.purple.shade300;
  if (isRestaurant) return Colors.amber.shade300;
  if (isWellness) return Colors.green.shade300; // Uncommented wellness color
  return Colors.blue.shade300; // Default for users
}

// Helper function to determine icon based on post type
IconData _getPostTypeIcon(dynamic post) {
  bool isLeisure = false;
  bool isRestaurant = false;
  bool isWellness = false;
  bool isUser = true;

  if (post is Post) {
    isLeisure = post.isLeisureProducer ?? false;
    isWellness = post.isBeautyProducer ?? false;
    isRestaurant = (post.isProducerPost ?? false) && !isLeisure && !isWellness;
    isUser = !(post.isProducerPost ?? false);
  } else if (post is Map<String, dynamic>) {
    isLeisure = post['isLeisureProducer'] == true;
    isWellness = post['isWellnessProducer'] == true || post['is_wellness_producer'] == true || post['isBeautyProducer'] == true;
    isRestaurant = (post['isProducerPost'] == true || post['producer_id'] != null) && !isLeisure && !isWellness;
    isUser = !(isLeisure || isRestaurant || isWellness);
  }

  if (isLeisure) return Icons.local_activity;
  if (isRestaurant) return Icons.restaurant;
  if (isWellness) return Icons.spa; // Uncommented wellness icon
  return Icons.person; // Default for users
}

// Helper function to determine type label based on post type
String _getPostTypeLabel(dynamic post) {
  bool isLeisure = false;
  bool isRestaurant = false;
  bool isWellness = false;
  bool isUser = true;

  if (post is Post) {
    isLeisure = post.isLeisureProducer ?? false;
    isWellness = post.isBeautyProducer ?? false;
    isRestaurant = (post.isProducerPost ?? false) && !isLeisure && !isWellness;
    isUser = !(post.isProducerPost ?? false);
  } else if (post is Map<String, dynamic>) {
    isLeisure = post['isLeisureProducer'] == true;
    isWellness = post['isWellnessProducer'] == true || post['is_wellness_producer'] == true || post['isBeautyProducer'] == true;
    isRestaurant = (post['isProducerPost'] == true || post['producer_id'] != null) && !isLeisure && !isWellness;
    isUser = !(isLeisure || isRestaurant || isWellness);
  }

  if (isLeisure) return 'Loisir';
  if (isRestaurant) return 'Restaurant';
  if (isWellness) return 'Bien-être'; // Uncommented wellness label
  return 'Utilisateur'; // Default for users
}

// Helper function to determine visual badge based on post type
String _getVisualBadge(dynamic post) {
  bool isLeisure = false;
  bool isRestaurant = false;
  bool isWellness = false;
  bool isUser = true;

  if (post is Post) {
    isLeisure = post.isLeisureProducer ?? false;
    isWellness = post.isBeautyProducer ?? false;
    isRestaurant = (post.isProducerPost ?? false) && !isLeisure && !isWellness;
    isUser = !(post.isProducerPost ?? false);
  } else if (post is Map<String, dynamic>) {
    isLeisure = post['isLeisureProducer'] == true;
    isWellness = post['isWellnessProducer'] == true || post['is_wellness_producer'] == true || post['isBeautyProducer'] == true;
    isRestaurant = (post['isProducerPost'] == true || post['producer_id'] != null) && !isLeisure && !isWellness;
    isUser = !(isLeisure || isRestaurant || isWellness);
  }

  if (isLeisure) return '🎭';
  if (isRestaurant) return '🍽️';
  if (isWellness) return '🧘'; // Uncommented wellness badge
  return '👤'; // Default for users
}

// Utility function to get ImageProvider, handling potential errors
ImageProvider? getImageProvider(String url) {
  if (url.isEmpty || !Uri.parse(url).isAbsolute) {
    print('⚠️ Invalid image URL: $url');
    return null; // Return null for invalid URLs
  }
  try {
    // Prioritize CachedNetworkImageProvider for performance and caching
    return CachedNetworkImageProvider(url);
  } catch (e) {
    print('❌ Error creating ImageProvider for $url: $e');
    // Fallback or error handling could go here, e.g., return a default image provider
    return null; // Indicate failure
  }
}
