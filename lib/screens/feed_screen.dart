import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../widgets/choice_carousel.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/dialogic_ai_feed_service.dart';
import '../services/ai_service.dart';
import 'feed_screen_controller.dart';
import 'reels_view_screen.dart';
import 'post_detail_screen.dart';
import 'producer_screen.dart';
import 'producerLeisure_screen.dart';
import 'eventLeisure_screen.dart';
import 'utils.dart';
import '../widgets/feed/feed_post_card.dart';
import '../widgets/profile/user_avatar.dart';
import '../widgets/feed/post_card.dart';
import '../widgets/feed/comments_sheet.dart';

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
  
  final ApiService _apiService = ApiService();
  
  @override
  void initState() {
    super.initState();
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
    _controller.dispose();
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
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text(
                      'Feed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        // TODO: Ouvrir les paramètres du feed
                        print('⚙️ Ouvrir les paramètres du feed');
                      },
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Feed content
              Expanded(
                child: Consumer<FeedScreenController>(
                  builder: (context, controller, child) {
                    if (controller.loadState == FeedLoadState.initial ||
                        controller.loadState == FeedLoadState.loading &&
                        controller.feedItems.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }
                    
                    if (controller.loadState == FeedLoadState.error) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              controller.errorMessage ?? 'Une erreur est survenue',
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => controller.loadFeed(),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return RefreshIndicator(
                      onRefresh: () => controller.loadFeed(),
                      color: Colors.deepPurple,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        itemCount: controller.feedItems.length + 
                          (controller.loadState == FeedLoadState.loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= controller.feedItems.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final item = controller.feedItems[index];
                          
                          if (item is Post) {
                            return PostCard(
                              post: item,
                              onLike: (post) => _controller.likePost(post),
                              onInterested: (post) => _controller.markInterested(post.id, post),
                              onChoice: (post) => _controller.markChoice(post.id, post),
                              onCommentTap: (post) => _showComments(context, post),
                              onUserTap: () => _onUserTap(item.userId ?? ''),
                              onShare: _handleShare,
                              onSave: _handleSave,
                            );
                          } else if (item is Map<String, dynamic>) {
                            return PostCard(
                              post: Post.fromJson(item),
                              onLike: (post) => _controller.likePost(post),
                              onInterested: (post) => _controller.markInterested(post.id, post),
                              onChoice: (post) => _controller.markChoice(post.id, post),
                              onCommentTap: (post) => _showComments(context, post),
                              onUserTap: () => _onUserTap(item['userId'] ?? ''),
                              onShare: _handleShare,
                              onSave: _handleSave,
                            );
                          }
                          
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // TODO: Implémenter la création de post
            print('➕ Créer un nouveau post');
          },
          backgroundColor: Colors.deepPurple,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
  
  void _handleInterest(String postId, Post post) async {
    try {
      // Mettre à jour localement via le controller
      _controller.markInterested(postId, post);
    } catch (e) {
      print('❌ Error handling interest: $e');
    }
  }

  void _handleChoice(String postId, Post post) async {
    try {
      // Mettre à jour localement via le controller
      _controller.markChoice(postId, post);
    } catch (e) {
      print('❌ Error handling choice: $e');
    }
  }

  void _handleLike(Post post) async {
    try {
      // Mettre à jour localement via le controller
      _controller.likePost(post);
    } catch (e) {
      print('❌ Error handling like: $e');
    }
  }

  void _handleShare(Post post) {
    // TODO: Implémenter le partage
    print('📤 Partager le post ${post.id}');
  }

  void _handleSave(Post post) async {
    try {
      final success = await _apiService.savePost(widget.userId, post.id);
      if (success) {
        _showSnackBar('Post sauvegardé avec succès');
      }
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du post: $e');
      _showSnackBar('Erreur lors de la sauvegarde du post');
    }
  }

  void _navigateToProfile(BuildContext context, String userId) {
    // TODO: Implémenter la navigation vers le profil
    print('👤 Navigation vers le profil de $userId');
  }

  void _showComments(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        post: post,
        userId: widget.userId,
        onCommentSubmitted: (comment) {
          _controller.trackInteraction('comment', post.id);
          // La mise à jour des commentaires se fait dans le CommentsSheet
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _onUserTap(String userId) {
    // TODO: Naviguer vers le profil utilisateur
    print('👤 Naviguer vers le profil $userId');
  }
}