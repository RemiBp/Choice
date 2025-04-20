import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../widgets/choice_carousel.dart';
import '../widgets/translatable_content.dart';
import '../widgets/translatable_rich_content.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/dialogic_ai_feed_service.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/translation_service.dart';
import '../utils/constants.dart' as constants;
import '../utils/api_config.dart';
import '../utils/translation_helper.dart';
import '../models/comment.dart';
import '../models/post_location.dart' as post_location_model;
import '../models/wellness_producer.dart';
import '../controllers/feed_controller.dart';
import 'feed_screen_controller.dart';
import 'reels_view_screen.dart';
import 'post_detail_screen.dart';
import 'producer_screen.dart';
import 'producerLeisure_screen.dart';
import 'eventLeisure_screen.dart';
import 'utils.dart';
import 'language_settings_screen.dart';
import 'messaging_screen.dart';
import 'profile_screen.dart';
import 'wellness_producer_profile_screen.dart';
import 'share_options_bottom_sheet.dart';
import '../utils.dart' show getImageProvider;

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
  final Map<String, VideoPlayerController> _videoControllers = {};
  final TextEditingController _aiResponseController = TextEditingController();
  String? _currentlyPlayingVideoId;
  bool _isLoading = false;
  String _loadingMessage = "Loading...";
  final _apiService = ApiService();
  String get _baseUrl => constants.getBaseUrl();
  
  @override
  void initState() {
    super.initState();
    // Initialize controller with required userId
    _controller = FeedScreenController(userId: widget.userId);
    
    // Set up tab controller for feed filters
    _tabController = TabController(length: 4, vsync: this); // 4 tabs: Pour toi, Restaurants, Loisirs, Bien-être
    _tabController.addListener(_handleTabChange);
    
    // Charger les préférences utilisateur et le feed personnalisé
    _initializePersonalizedFeed();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_handleScroll);
  }
  
  // Initialiser le feed personnalisé
  Future<void> _initializePersonalizedFeed() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Chargement de votre feed personnalisé...";
    });
    
    try {
      // Initialiser les préférences utilisateur basées sur l'historique
      await _controller.initializePreferences();
      
      // Charger le feed initial avec les préférences mises à jour
      await _controller.loadInitialFeed();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation du feed personnalisé: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur lors du chargement du feed. Veuillez réessayer."),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: () {
                  _initializePersonalizedFeed();
                },
              ),
            ),
          );
        });
      }
    }
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    
    int currentTabIndex = _tabController.index;
    FeedContentType newFilter;
    switch (currentTabIndex) {
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
        newFilter = FeedContentType.wellness;  // Bien-être correspond au 4ème tab (index 3)
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
    // Rechercher l'état parent CommentScreenState si disponible
    final _CommentsScreenState? commentScreenState =
        context.findAncestorStateOfType<_CommentsScreenState>();
    
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
                    Image.asset(
                      'assets/images/logo.png',
                      height: 32,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.favorite,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Choice',
                      style: GoogleFonts.poppins(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Bouton Reels avec badge indiquant du nouveau contenu
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.video_library, color: Colors.deepPurple),
                        onPressed: _navigateToReelsViewFromFirstVideo,
                        tooltip: 'Voir les reels',
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Bouton Messages
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.deepPurple),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagingScreen(userId: widget.userId),
                            ),
                          );
                        },
                        tooltip: 'Messages',
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.grey),
                    onPressed: () {
                      // Implement search
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
                    onPressed: () {
                      // Implement notifications view
                    },
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple,
                  tabs: const [
                    Tab(text: 'Pour toi'),
                    Tab(text: 'Restaurants'),
                    Tab(text: 'Loisirs'),
                    Tab(text: 'Bien-être'),
                  ],
                ),
              ),
              
              // Bandeau pour les stories et reels
              SliverToBoxAdapter(
                child: _buildStoriesRow(),
              ),
            ];
          },
          body: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (_controller.loadState == FeedLoadState.loading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                );
              }
              
              if (_controller.errorMessage != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${_controller.errorMessage}',
                        style: const TextStyle(color: Colors.red),
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
                String message = 'Aucun contenu disponible';
                String actionMessage = 'Actualisez pour découvrir de nouveaux posts';
                IconData iconData = Icons.feed;
                
                // Personnaliser le message en fonction du tab actif
                switch (_controller.currentFilter) {
                  case FeedContentType.restaurants:
                    message = 'Aucun post de restaurant disponible';
                    actionMessage = 'Suivez des restaurants pour voir leurs posts ici';
                    iconData = Icons.restaurant;
                    break;
                  case FeedContentType.leisure:
                    message = 'Aucune activité de loisir disponible';
                    actionMessage = 'Suivez des établissements de loisir pour voir leurs posts ici';
                    iconData = Icons.local_activity;
                    break;
                  case FeedContentType.wellness:
                    message = 'Aucun post bien-être disponible';
                    actionMessage = 'Suivez des établissements bien-être pour voir leurs posts ici';
                    iconData = Icons.spa;
                    break;
                  case FeedContentType.userPosts:
                    message = 'Aucun post d\'utilisateur disponible';
                    actionMessage = 'Suivez plus d\'utilisateurs pour enrichir votre feed';
                    iconData = Icons.person;
                    break;
                  default:
                    message = 'Aucun contenu disponible dans votre feed';
                    actionMessage = 'Actualisez pour découvrir de nouveaux posts';
                    iconData = Icons.feed;
                    break;
                }
                
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(iconData, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          actionMessage,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
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
                    
                    // Insérer des suggestions ou contenus variés tous les 3-4 posts
                    if (index > 0 && index % 4 == 0) {
                      // Alterner entre suggestions et contenus spéciaux
                      if ((index ~/ 4) % 3 == 0) {
                        return _buildSuggestionCard();
                      } else if ((index ~/ 4) % 3 == 1) {
                        return _buildTrendingTopicsCard();
                      } else {
                        return _buildFeaturePromoCard();
                      }
                    }
                    
                    // Handle different types of feed items
                    return _buildFeedItem(item);
                  },
                ),
              );
            },
          ),
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

  // Construire un widget pour afficher les stories et reels en haut du feed
  Widget _buildStoriesRow() {
    return Container(
      height: 110,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          // Élément pour ajouter une nouvelle story
          _buildStoryAvatar(
            isAdd: true,
            onTap: () {
              // Logique pour créer une nouvelle story
            },
          ),
          
          // Stories des utilisateurs (exemples statiques)
          _buildStoryAvatar(
            imageUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=user1',
            username: 'Vous',
            hasUnseenContent: false,
            isReels: false,
            onTap: () {
              // Ouvrir la story
            },
          ),
          
          // Reels épinglés (avec l'icône de lecteur vidéo)
          _buildStoryAvatar(
            imageUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=user2',
            username: 'Reels',
            hasUnseenContent: true, 
            isReels: true,
            onTap: () {
              _navigateToReelsViewFromFirstVideo();
            },
          ),
          
          // Plus de stories
          _buildStoryAvatar(
            imageUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=user3',
            username: 'Lara',
            hasUnseenContent: true,
            isReels: false,
            onTap: () {},
          ),
          _buildStoryAvatar(
            imageUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=user4',
            username: 'Théo',
            hasUnseenContent: true,
            isReels: false,
            onTap: () {},
          ),
          _buildStoryAvatar(
            imageUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=user5',
            username: 'Cécile',
            hasUnseenContent: true,
            isReels: true,
            onTap: () {
              _navigateToReelsViewFromFirstVideo();
            },
          ),
          _buildStoryAvatar(
            imageUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=user6',
            username: 'Marc',
            hasUnseenContent: false,
            isReels: false,
            onTap: () {},
          ),
          _buildStoryAvatar(
            imageUrl: 'https://api.dicebear.com/6.x/avataaars/png?seed=user7',
            username: 'Helena',
            hasUnseenContent: true,
            isReels: true,
            onTap: () {
              _navigateToReelsViewFromFirstVideo();
            },
          ),
        ],
      ),
    );
  }
  
  // Widget pour les avatars de stories/reels
  Widget _buildStoryAvatar({
    bool isAdd = false,
    String? imageUrl,
    String? username,
    bool hasUnseenContent = false,
    bool isReels = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            // Avatar avec bordure colorée selon le type
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnseenContent
                    ? LinearGradient(
                        colors: isReels
                            ? [Colors.purple, Colors.pink, Colors.orange]
                            : [Colors.deepPurple, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: !hasUnseenContent && !isAdd
                    ? Border.all(color: Colors.grey.shade300, width: 2)
                    : null,
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: isAdd
                    ? CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: const Icon(Icons.add, color: Colors.deepPurple),
                      )
                    : CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(imageUrl!),
                        child: isReels
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              )
                            : null,
                      ),
              ),
            ),
            
            // Nom d'utilisateur
            const SizedBox(height: 4),
            if (username != null)
              Text(
                username,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasUnseenContent ? Colors.black87 : Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
  
  // Naviguer vers la vue reels avec tous les reels disponibles
  void _navigateToReelsView() {
    // Collecter toutes les vidéos disponibles dans le feed
    List<Map<String, dynamic>> allVideos = [];
    
    // Explorer tous les posts pour extraire leurs vidéos
    for (final item in _controller.feedItems) {
      if (item is Post) {
        for (final media in item.media) {
          if (media.type == 'video') {
            allVideos.add({
              'url': media.url,
              'type': 'video',
              'post': item,
              'thumbnail': media.thumbnailUrl,
            });
          }
        }
      } else if (item is Map<String, dynamic> && item['media'] is List) {
        final mediaList = item['media'] as List;
        for (final media in mediaList) {
          if (media is Map && media['type'] == 'video' && media['url'] != null) {
            allVideos.add({
              'url': media['url'],
              'type': 'video',
              'post': item,
              'thumbnail': media['thumbnailUrl'],
            });
          }
        }
      }
    }
    
    if (allVideos.isEmpty) {
      // Si aucune vidéo trouvée, afficher un message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("URL de vidéo invalide ou inaccessible"),
          backgroundColor: Colors.red,
        )
      );
      return;
    }
    
    // Naviguer vers l'écran de reels
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelsViewScreen(
          initialIndex: 0,
          videos: allVideos,
        ),
      ),
    );
  }

  // Carte de suggestion "Vous pourriez aimer"
  Widget _buildSuggestionCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  'Vous pourriez aimer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Liste de suggestions
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: List.generate(4, (index) {
                return _buildSuggestionItem(index);
              }),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  // Élément individuel de suggestion
  Widget _buildSuggestionItem(int index) {
    // Exemples de données
    final places = [
      {'name': 'Le Bistrot Parisien', 'type': 'Restaurant', 'image': 'https://api.dicebear.com/6.x/initials/png?seed=BP'},
      {'name': 'La Galerie d\'Art', 'type': 'Loisir', 'image': 'https://api.dicebear.com/6.x/initials/png?seed=GA'},
      {'name': 'Spa Zen', 'type': 'Bien-être', 'image': 'https://api.dicebear.com/6.x/initials/png?seed=SZ'},
      {'name': 'Théâtre Moderne', 'type': 'Loisir', 'image': 'https://api.dicebear.com/6.x/initials/png?seed=TM'},
    ];
    
    final place = places[index % places.length];
    
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: place['image']!,
              height: 120,
              width: 140,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                height: 120,
                width: 140,
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                height: 120,
                width: 140,
                child: const Icon(Icons.error, color: Colors.grey),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Textes
          Text(
            place['name']!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          Text(
            place['type']!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // Carte de sujets tendance
  Widget _buildTrendingTopicsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'Tendances près de chez vous',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Liste de hashtags tendance
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTrendingChip('Restaurants italiens', 120),
                _buildTrendingChip('Musées gratuits', 89),
                _buildTrendingChip('Brunch', 240),
                _buildTrendingChip('Expositions', 67),
                _buildTrendingChip('Terrasses', 154),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Élément de tendance (chip)
  Widget _buildTrendingChip(String label, int count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // Carte de promotion de fonctionnalité
  Widget _buildFeaturePromoCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      color: Colors.deepPurple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star, color: Colors.deepPurple[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Découvrez les reels',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.deepPurple[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Explorez les meilleurs moments en vidéo',
                        style: TextStyle(
                          color: Colors.deepPurple[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _navigateToReelsViewFromFirstVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Center(
                child: Text('Explorer les reels'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeedItem(dynamic item) {
    // Vérification du type de l'item
    if (item is DialogicAIMessage) {
      return _buildAIMessageCard(item);
    } else if (item is Post) {
      return _buildPostCard(item);
    } else if (item is Map<String, dynamic>) {
      if (item['type'] == 'ai_message') {
        // Convertir en objet DialogicAIMessage si nécessaire
        final aiMessage = DialogicAIMessage.fromJson(item);
        return _buildAIMessageCard(aiMessage);
      } else {
        return _buildDynamicPostCard(item);
      }
    } else {
      // Fallback pour les autres types
      return const SizedBox.shrink();
    }
  }
  
  // Build card for AI messages in feed with enhanced styling and clickable places
  Widget _buildAIMessageCard(DialogicAIMessage message) {
    // Check if message has associated profiles to display
    final bool hasProfiles = message.profiles != null && message.profiles!.isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.deepPurple.shade200,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced AI Avatar and indicator
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.deepPurple.shade700,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.emoji_objects_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choice AI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'common.personal_assistant'.localTr(),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.deepPurple.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Copilot',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple[700],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Message content with clickable places
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TranslatableRichContent(
                  text: message.content,
                  onLinkTap: (type, id) {
                    // Navigation based on place type
                    if (type == 'restaurant') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProducerScreen(
                            producerId: id,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    } else if (type == 'leisureProducer') {
                      _fetchAndNavigateToLeisureProducer(id);
                    } else if (type == 'event') {
                      _fetchAndNavigateToEvent(id);
                    }
                  },
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ),
              
              // Recommended places if available
              if (hasProfiles) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.deepPurple.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.place,
                        color: Colors.deepPurple.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lieux recommandés',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.deepPurple.shade800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${message.profiles!.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Horizontal scrollable list of recommended places
                SizedBox(
                  height: 180,
                  child: _buildRecommendedPlacesCards(message.profiles!),
                ),
              ],
              
              // Suggestions chips if interactive, with improved styling
              if (message.isInteractive && message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: message.suggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(
                        suggestion,
                        style: TextStyle(
                          color: Colors.deepPurple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.deepPurple.shade300),
                      shadowColor: Colors.black.withOpacity(0.1),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              
              // Enhanced input field for direct response if interactive
              if (message.isInteractive) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _aiResponseController,
                    decoration: InputDecoration(
                      hintText: 'Répondre à Choice AI...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.question_answer_outlined,
                        color: Colors.deepPurple.shade300,
                        size: 20,
                      ),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple, Colors.purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
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
                    textInputAction: TextInputAction.send,
                    onSubmitted: (value) async {
                      if (value.isNotEmpty) {
                        final aiResponse = await _controller.interactWithAiMessage(value);
                        _aiResponseController.clear();
                        
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
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Build horizontal list of recommended place cards
  Widget _buildRecommendedPlacesCards(List<Map<String, dynamic>> profiles) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return _buildPlaceCard(profile);
      },
    );
  }
  
  // Build individual place card for recommendations
  Widget _buildPlaceCard(Map<String, dynamic> profile) {
    // Determine place type and styling
    final String type = profile['type'] ?? 'venue';
    final bool isRestaurant = type == 'restaurant' || type == 'producer';
    final bool isLeisure = type == 'leisure' || type == 'leisureProducer';
    final bool isEvent = type == 'event';
    
    // Get color based on type
    Color typeColor = isRestaurant ? Colors.amber : (isLeisure ? Colors.purple : (isEvent ? Colors.green : Colors.blue));
    IconData typeIcon = isRestaurant ? Icons.restaurant : (isLeisure ? Icons.local_activity : (isEvent ? Icons.event : Icons.place));
    String typeLabel = isRestaurant ? 'Restaurant' : (isLeisure ? 'Loisir' : (isEvent ? 'Événement' : 'Lieu'));
    
    // Get image URL
    String imageUrl = profile['photo'] ?? 'https://via.placeholder.com/300x200';
    
    return GestureDetector(
      onTap: () {
        String profileId = profile['targetId'] ?? profile['_id'] ?? profile['id'] ?? '';
        if (profileId.isNotEmpty) {
          if (isRestaurant) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProducerScreen(
                  producerId: profileId,
                  userId: widget.userId,
                ),
              ),
            );
          } else if (isLeisure) {
            _fetchAndNavigateToLeisureProducer(profileId);
          } else if (isEvent) {
            _fetchAndNavigateToEvent(profileId);
          }
        }
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Place image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image(
                    image: getImageProvider(imageUrl)!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      height: 100,
                      child: Center(
                        child: Icon(typeIcon, color: typeColor.withOpacity(0.6), size: 40),
                      ),
                    ),
                  ),
                ),
                // Type badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Place details
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Place name
                  Text(
                    profile['name'] ?? 'Sans nom',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Place address if available
                  if (profile['address'] != null && profile['address'].toString().isNotEmpty)
                    Text(
                      profile['address'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Rating and price level if available
                  Row(
                    children: [
                      // Rating
                      if (profile['rating'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                profile['rating'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const Spacer(),
                      
                      // Price level
                      if (profile['price_level'] != null || profile['priceLevel'] != null)
                        Text(
                          '€' * (int.tryParse(
                            (profile['price_level'] ?? profile['priceLevel'] ?? '1').toString()
                          ) ?? 1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to fetch and navigate to leisure producer profile
  Future<void> _fetchAndNavigateToLeisureProducer(String id) async {
    try {
      // Vérifier si le widget est toujours monté avant de continuer
      if (!mounted) return;
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement du lieu...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails et informations",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${_baseUrl}/api/producers/leisure/$id');
      final response = await http.get(url);
      
      // Close loading indicator
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerData: data),
          ),
        );
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      // Close loading indicator if still open
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  // Helper method to fetch and navigate to event profile
  Future<void> _fetchAndNavigateToEvent(String id) async {
    try {
      // Vérifier si le widget est toujours monté avant de continuer
      if (!mounted) return;
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement de l'événement...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails et informations",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${_baseUrl}/api/events/$id');
      final response = await http.get(url);
      
      // Close loading indicator
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(eventData: data),
          ),
        );
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      // Close loading indicator if still open
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            // Post header with author info and post type indicator
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Author avatar with enhanced clickable behavior
                  GestureDetector(
                    onTap: () {
                      // Navigate to author profile
                      if (post.isProducerPost ?? false) {
                        if (post.isLeisureProducer ?? false) {
                          _fetchAndNavigateToLeisureProducer(post.authorId ?? '');
                        } else if (post.isBeautyProducer ?? false) {
                          // Naviguer vers le profil de beauté/bien-être 
                          _navigateToBeautyProducer(post.authorId ?? '');
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProducerScreen(
                                producerId: post.authorId ?? '',
                                userId: widget.userId,
                              ),
                            ),
                          );
                        }
                      } else {
                        // Navigate to user profile
                        _onUserTap(post.authorId ?? '');
                      }
                    },
                    child: Hero(
                      tag: 'avatar-${post.authorId}',
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: post.getTypeColor().withOpacity(0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: post.authorAvatar?.isNotEmpty == true
                                ? post.authorAvatar!
                                : 'https://api.dicebear.com/6.x/adventurer/png?seed=${post.authorId}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(post.getTypeColor()),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Icon(
                                  post.getTypeIcon(),
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User name with improved display
                        GestureDetector(
                          onTap: () {
                            if (post.isProducerPost ?? false) {
                              if (post.isLeisureProducer ?? false) {
                                _fetchAndNavigateToLeisureProducer(post.authorId ?? '');
                              } else if (post.isBeautyProducer ?? false) {
                                // Naviguer vers le profil de beauté/bien-être 
                                _navigateToBeautyProducer(post.authorId ?? '');
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProducerScreen(
                                      producerId: post.authorId ?? '',
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              }
                            } else {
                              // Navigate to user profile
                              _onUserTap(post.authorId ?? '');
                            }
                          },
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  post.authorName ?? '',
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
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTimestamp(post.postedAt ?? DateTime.now()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: post.getTypeColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                post.getTypeLabel(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: post.getTypeColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Badge "Suivi" pour les établissements suivis
                            if (_isAuthorFollowed(post))
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: _buildFollowedBadge(post),
                            ),
                            // Event or target indicator
                            if (_hasReferencedEvent(post))
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _getReferencedType(post),
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
            if (post.content?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TranslatableContent(
                  text: post.content!,
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
                      _handleLike(post);
                    },
                  ),
                  
                  // Only show interest button for producer posts
                  if (post.isProducerPost ?? false)
                    _buildInteractionButton(
                      icon: Icons.star,
                      iconColor: Colors.amber,
                      label: 'Intéressé',
                      count: post.interestedCount ?? 0,
                      isActive: post.isInterested ?? false,
                      onPressed: () {
                        // Convertir en Post avant de passer à _handleInterest
                        final postObj = _convertToPost(post);
                        _handleInterestAction(postObj);
                      },
                    ),
                  
                  _buildInteractionButton(
                    icon: Icons.comment,
                    iconColor: Colors.blue,
                    label: 'Commentaires',
                    count: _getCommentsCount(post),
                    isActive: false,
                    onPressed: () => _openComments(_convertToPost(post)),
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
            if (_hasComments(post)) ...[
              Divider(color: Colors.grey[200]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _getCommentsWidgets(post, 2),
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
    
    // Déterminer le type de producteur en utilisant les mêmes règles que dans le backend
    bool isProducerPost = post['isProducerPost'] == true || post['producer_id'] != null;
    bool isLeisureProducer = post['isLeisureProducer'] == true;
    bool isBeautyProducer = post['isBeautyProducer'] == true || post['beauty_producer'] == true || 
                           post['beauty_id'] != null || post['is_beauty_post'] == true;
    bool isRestaurationProducer = post['isRestaurationProducer'] == true || post['is_restaurant_post'] == true;
    
    // Si c'est un producteur mais sans type spécifique, déterminer par post_type
    if (isProducerPost && !isLeisureProducer && !isBeautyProducer && !isRestaurationProducer) {
      if (post['post_type'] == 'beauty') {
        isBeautyProducer = true;
      } else if (post['post_type'] == 'leisure') {
        isLeisureProducer = true;
      } else if (post['post_type'] == 'restaurant') {
        isRestaurationProducer = true;
      } else {
        // Par défaut, considérer comme restaurant
        isRestaurationProducer = true;
      }
    }
    
    // Déterminer la couleur et l'icône en fonction du type
    Color typeColor = isBeautyProducer 
        ? Colors.green.shade700
        : (isLeisureProducer 
            ? Colors.purple.shade700 
            : (isRestaurationProducer ? Colors.amber.shade700 : Colors.blue.shade700));
    
    IconData typeIcon = isBeautyProducer
        ? Icons.spa
        : (isLeisureProducer
            ? Icons.local_activity
            : (isRestaurationProducer ? Icons.restaurant : Icons.person));
    
    String typeLabel = isBeautyProducer
        ? 'Bien-être'
        : (isLeisureProducer
            ? 'Loisir'
            : (isRestaurationProducer ? 'Restaurant' : 'Utilisateur'));
    
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
    
    // Handle media - traitement plus robuste des médias
    List<Map<String, dynamic>> mediaItems = [];
    if (post['media'] != null) {
      try {
        if (post['media'] is List) {
          // Si media est une liste (cas normal)
          for (var media in post['media']) {
            if (media is Map) {
              final url = media['url'] ?? '';
              final type = media['type'] ?? 'image';
              if (url.isNotEmpty) {
                mediaItems.add({
                  'url': url,
                  'type': type,
                  'width': media['width'],
                  'height': media['height']
                });
              }
            } else if (media is String) {
              // Cas où media est directement une URL
              mediaItems.add({
                'url': media,
                'type': 'image'
              });
            }
          }
        } else if (post['media'] is Map) {
          // Si media est une Map et non une liste (cas d'erreur)
          final media = post['media'] as Map;
          final url = media['url'] ?? '';
          final type = media['type'] ?? 'image';
          if (url.isNotEmpty) {
            mediaItems.add({
              'url': url,
              'type': type,
              'width': media['width'],
              'height': media['height']
            });
          }
        }
      } catch (e) {
        print('❌ Erreur lors du traitement des médias : $e');
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
            // Post header with author info and post type indicator
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Author avatar with enhanced clickable behavior
                  GestureDetector(
                    onTap: () {
                      // Navigate to author profile
                      if (isProducerPost) {
                        if (isLeisureProducer) {
                          _fetchAndNavigateToLeisureProducer(authorId);
                        } else if (isBeautyProducer) {
                          _navigateToBeautyProducer(authorId);
                        } else {
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
                        _onUserTap(authorId);
                      }
                    },
                    child: Hero(
                      tag: 'avatar-${authorId}',
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: typeColor.withOpacity(0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: authorAvatar.isNotEmpty
                                ? authorAvatar
                                : 'https://api.dicebear.com/6.x/adventurer/png?seed=${authorId}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Icon(
                                  typeIcon,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User name with improved display
                        GestureDetector(
                          onTap: () {
                            if (isProducerPost) {
                              if (isLeisureProducer) {
                                _fetchAndNavigateToLeisureProducer(authorId);
                              } else if (isBeautyProducer) {
                                _navigateToBeautyProducer(authorId);
                              } else {
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
                              _onUserTap(authorId);
                            }
                          },
                          child: Row(
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
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: typeColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Badge "Suivi" pour les établissements suivis
                            if (_isAuthorFollowed(post))
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: _buildFollowedBadge(post),
                            ),
                            // Event or target indicator
                            if (_hasReferencedEvent(post))
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _getReferencedType(post),
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
                child: TranslatableContent(
                  text: content,
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
                      // Convertir en Post avant de passer à _handleLike
                      final postObj = _convertToPost(post);
                      _handleLike(postObj);
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
                        // Convertir en Post avant de passer à _handleInterest
                        final postObj = _convertToPost(post);
                        _handleInterestAction(postObj);
                      },
                    ),
                  
                  _buildInteractionButton(
                    icon: Icons.comment,
                    iconColor: Colors.blue,
                    label: 'Commentaires',
                    count: commentsCount,
                    isActive: false,
                    onPressed: () => _openComments(_convertToPost(post)),
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
                  children: _getCommentsWidgets(post, 2),
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
  
  // Méthode pour ouvrir une vue Reels pour les vidéos
  void _openReelsView(dynamic post, String videoUrl) {
    // Vérifier si le widget est toujours monté
    if (!mounted) return;
    
    // Vérifier si l'URL est valide
    if (videoUrl.isEmpty) {
      print('❌ URL vidéo invalide: $videoUrl');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("URL de vidéo invalide ou inaccessible"),
          backgroundColor: Colors.red,
        )
      );
      return;
    }
    
    // Traiter l'URL si c'est un lien Google Maps ou Firebase Storage
    String processedUrl = videoUrl;
    
    // Vérifier si c'est une URL Google Maps qui nécessite un traitement spécial
    if (videoUrl.contains('maps.googleapis.com')) {
      print('⚠️ URL Google Maps détectée, utilisation d\'une image statique');
      // Plutôt que d'essayer de lire une vidéo à partir d'une URL d'image Google Maps,
      // nous affichons simplement l'image pour éviter les erreurs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Contenu disponible uniquement comme image, pas comme vidéo"),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }
    
    try {
      // Récupérer tous les médias pour la vue reels (vidéos uniquement)
      List<Map<String, dynamic>> videoItems = [];
      
      if (post is Post) {
        // Si c'est un Post, extraire directement les médias
        videoItems = post.media
          .where((media) => media.type == 'video')
          .map((media) => {'url': media.url, 'type': 'video'})
          .toList();
      } else if (post is Map) {
        // Si c'est un Map, trouver les médias dans la structure
        final mediaList = post['media'];
        if (mediaList is List) {
          videoItems = mediaList
            .where((media) => media is Map && media['type'] == 'video')
            .map((media) => {'url': media['url'], 'type': 'video'})
            .toList();
        }
      }
      
      // Si aucune vidéo n'a été trouvée, ajouter au moins celle spécifiée
      if (videoItems.isEmpty) {
        videoItems.add({'url': processedUrl, 'type': 'video'});
      }
      
      print('🎥 Ouverture de ${videoItems.length} vidéo(s) en mode reels');
      
      // Naviguer vers l'écran Reels avec l'index de la vidéo courante
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReelsViewScreen(
            // Trouver l'index de la vidéo sélectionnée dans la liste
            initialIndex: videoItems.indexWhere((video) => video['url'] == processedUrl),
            // Transmettre toutes les vidéos
            videos: videoItems,
          ),
        ),
      );
    } catch (e) {
      print('❌ Erreur lors de l\'ouverture de la vue Reels: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'ouvrir la vidéo: $e"),
          backgroundColor: Colors.red,
        )
      );
    }
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
  
  // Navigate to reels view with the first video from posts
  void _navigateToReelsViewFromFirstVideo() {
    try {
      // Create a list to store all videos found in feed items
      List<Map<String, dynamic>> allVideos = [];
      
      // Scan all feed items for video content
    for (final item in _controller.feedItems) {
        if (item is Post) {
          // If it's a Post object, extract videos from its media array
          for (final media in item.media) {
            if (media.type == 'video' && media.url.isNotEmpty) {
              allVideos.add({
                'url': media.url,
                'type': 'video',
                'post': item,
                'thumbnail': media.thumbnailUrl ?? '',
              });
            }
          }
      } else if (item is Map<String, dynamic>) {
          // If it's a Map (dynamic post), extract videos from its media field
          final mediaList = item['media'];
          if (mediaList is List) {
            for (final media in mediaList) {
              if (media is Map && 
                  media['type'] == 'video' && 
                  media['url'] != null && 
                  media['url'].toString().isNotEmpty) {
                allVideos.add({
                  'url': media['url'],
                  'type': 'video',
                  'post': item,
                  'thumbnail': media['thumbnailUrl'] ?? '',
                });
            }
          }
        }
      }
    }
    
      // If we found videos, open the reels view
      if (allVideos.isNotEmpty) {
        print('🎬 Found ${allVideos.length} videos for reels view');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReelsViewScreen(
              initialIndex: 0,
              videos: allVideos,
            ),
          ),
        );
      } else {
        // If no videos were found, show a message
        print('⚠️ No videos found for reels view');
    ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun contenu vidéo disponible actuellement'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // For development/debugging, create some test video data
        if (kDebugMode) {
          _createAndShowSampleReels();
        }
      }
    } catch (e) {
      // Handle any errors that might occur
      print('❌ Error navigating to reels view: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des reels: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  // Helper method to create sample reels for development/testing
  void _createAndShowSampleReels() {
    // Sample video URLs that are known to work
    final sampleVideos = [
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ];
    
    // Create sample video data
    List<Map<String, dynamic>> samplesForReels = sampleVideos.map((url) => {
      'url': url,
      'type': 'video',
      'post': {
        'id': 'sample-${DateTime.now().millisecondsSinceEpoch}',
        'content': 'Exemple de contenu vidéo pour tester les reels',
        'author_name': 'Sample Videos',
        'author_avatar': 'https://api.dicebear.com/6.x/avataaars/png?seed=sample',
      },
      'thumbnail': '',
    }).toList();
    
    // Navigate to reels view with the sample videos
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelsViewScreen(
          initialIndex: 0, 
          videos: samplesForReels,
        ),
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
  
  // Navigate to user profile
  void _onUserTap(String userId) {
    if (userId.isEmpty) return;
    
    try {
      // Utiliser MaterialPageRoute direct au lieu de pushNamed
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            userId: userId,
            viewMode: 'public',
          ),
        ),
      );
    } catch (e) {
      print('❌ Error navigating to user profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'afficher le profil utilisateur: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  // Convertir une liste de Map en liste de widgets CommentTile
  List<Widget> _buildCommentsWidgets(List<dynamic> commentsToShow, dynamic postData) {
    return commentsToShow.map<Widget>((comment) {
      Map<String, dynamic> commentMap = comment is Map<String, dynamic> ? comment : {};
      return CommentTile(
        authorName: commentMap['author_name'] ?? commentMap['authorName'] ?? 'Utilisateur',
        text: commentMap['content'] ?? commentMap['text'] ?? '',
        date: commentMap['createdAt'] is DateTime 
            ? commentMap['createdAt'] 
            : (commentMap['createdAt'] is String 
                ? DateTime.parse(commentMap['createdAt']) 
                : DateTime.now()),
        avatar: commentMap['author_avatar'] ?? commentMap['authorAvatar'] ?? '',
        likes: commentMap['likes'] is int ? commentMap['likes'] : 0,
        onReply: () {},
        onLike: () {},
      );
    }).toList();
  }

  // Fonction pour vérifier si un post a des commentaires
  bool _hasComments(dynamic post) {
    if (post is Post) {
      return post.comments.isNotEmpty;
    } else if (post is Map<String, dynamic>) {
      if (post['comments'] is List) {
        return (post['comments'] as List).isNotEmpty;
      } else if (post['comments_count'] is int) {
        return post['comments_count'] > 0;
      } else if (post['commentsCount'] is int) {
        return post['commentsCount'] > 0;
      }
    }
    return false;
  }

  // Obtenir le nombre de commentaires
  int _getCommentsCount(dynamic post) {
    if (post is Post) {
      return post.commentsCount;
    } else if (post is Map<String, dynamic>) {
      if (post['comments'] is List) {
        return (post['comments'] as List).length;
      } else if (post['commentsCount'] is int) {
        return post['commentsCount'];
      } else if (post['comments_count'] is int) {
        return post['comments_count'];
      }
    }
    return 0;
  }
  
  // Ouvrir les commentaires d'un post
  void _openComments(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          post: post,
          userId: widget.userId,
        ),
      ),
    );
  }

  void _handlePostTap(Post post) {
    // Si c'est un post référençant un événement, ouvrir la page de l'événement
    if (post.referencedEventId != null && post.referencedEventId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventLeisureScreen(
            id: post.referencedEventId!,
          ),
        ),
      );
    } else if (post.targetId != null && post.targetId!.isNotEmpty) {
      // Handle navigation to target content
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            postId: post.id,
            userId: post.userId,
          ),
        ),
      );
    } else if (post is Map<String, dynamic>) {
      final referencedEventId = post['referencedEventId'];
      final targetId = post['targetId'];
      final userId = post['userId'] ?? '';
      final postId = post['id'] ?? post['_id'] ?? '';
      
      if (referencedEventId != null && referencedEventId is String && referencedEventId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(
              id: referencedEventId,
            ),
          ),
        );
      } else if (targetId != null && targetId is String && targetId.isNotEmpty) {
        // Handle navigation to target content
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: postId,
              userId: userId,
            ),
          ),
        );
      }
    }
  }

  Widget _buildCommentTile({
    required String authorName,
    required String text,
    required DateTime date,
    required String avatar,
    required String? authorId,
    required int? likes,
    VoidCallback? onReply,
    VoidCallback? onLike,
  }) {
    return CommentTile(
      authorName: authorName,
      text: text,
      date: date,
      avatar: avatar,
      authorId: authorId,
      likes: likes,
      isLiked: false,
      onReply: onReply,
      onLike: onLike,
    );
  }

  Widget _buildCommentList(List<Map<String, dynamic>> comments) {
    if (comments.isEmpty) {
      return const Center(
        child: Text("Aucun commentaire pour le moment"),
      );
    }

    return Column(
      children: comments.map<Widget>((comment) {
        return CommentTile(
          authorName: comment['authorName'] ?? comment['author_name'] ?? 'Utilisateur',
          text: comment['content'] ?? comment['text'] ?? '',
          date: comment['createdAt'] is DateTime 
              ? comment['createdAt'] 
              : (comment['createdAt'] is String 
                  ? DateTime.parse(comment['createdAt']) 
                  : DateTime.now()),
          avatar: comment['authorAvatar'] ?? comment['author_avatar'] ?? '',
          authorId: comment['authorId'] ?? comment['author_id'] ?? '',
          likes: comment['likes'] is int ? comment['likes'] : 0,
          onReply: () {},
          onLike: () {},
        );
      }).toList(),
    );
  }

  Widget _buildPostOptions(BuildContext context, Post post) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'save':
            _handleSavePost(post);
            break;
          case 'share':
            _handleSharePost(post, 'external');
            break;
          case 'report':
            _handleReportPost(post);
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'save',
          child: Text('Enregistrer'),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Text('Partager'),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Text('Signaler'),
        ),
      ],
    );
  }

  // Convertir un objet Map<String, dynamic> en objet Post
  Post _convertToPost(dynamic postData) {
    if (postData is Post) return postData;
    
    try {
      if (postData is Map<String, dynamic>) {
        // S'assurer que les informations minimales sont présentes
        final String id = postData['id']?.toString() ?? postData['_id']?.toString() ?? '';
        final String description = postData['description']?.toString() ?? 
                                 postData['content']?.toString() ?? '';
        
        // Extraire la date de création
        DateTime createdAt;
        try {
          final dynamic createdAtValue = postData['createdAt'] ?? 
                                      postData['created_at'] ?? 
                                      postData['postedAt'] ?? 
                                      postData['posted_at'];
          if (createdAtValue is String) {
            createdAt = DateTime.parse(createdAtValue);
          } else if (createdAtValue is DateTime) {
            createdAt = createdAtValue;
          } else {
            createdAt = DateTime.now();
          }
        } catch (e) {
          print('❌ Erreur lors de la conversion de la date: $e');
          createdAt = DateTime.now();
        }
        
        // Créer un objet Post à partir des données
        return Post(
          id: id,
          userId: postData['userId']?.toString() ?? postData['user_id']?.toString() ?? '',
          userName: postData['userName']?.toString() ?? 
                   postData['user_name']?.toString() ?? 
                   postData['authorName']?.toString() ?? 
                   postData['author_name']?.toString() ?? 'Utilisateur',
          userPhotoUrl: postData['userPhotoUrl']?.toString() ?? 
                       postData['user_photo_url']?.toString() ?? 
                       postData['authorAvatar']?.toString() ?? 
                       postData['author_photo']?.toString(),
          createdAt: createdAt,
          description: description,
          likes: int.tryParse(postData['likes']?.toString() ?? '0') ?? 0,
          likesCount: int.tryParse(postData['likesCount']?.toString() ?? 
                                 postData['likes_count']?.toString() ?? '0') ?? 0,
          comments: [],  // Liste vide pour les commentaires
          commentsCount: int.tryParse(postData['commentsCount']?.toString() ?? 
                                    postData['comments_count']?.toString() ?? '0') ?? 0,
          isLiked: postData['isLiked'] == true || postData['is_liked'] == true,
          interestedCount: int.tryParse(postData['interestedCount']?.toString() ?? 
                                      postData['interested_count']?.toString() ?? '0') ?? 0,
          isInterested: postData['isInterested'] == true || postData['interested'] == true,
          isProducerPost: postData['isProducerPost'] == true || 
                         postData['is_producer_post'] == true || 
                         postData['producer_id'] != null,
          isLeisureProducer: postData['isLeisureProducer'] == true || 
                            postData['is_leisure_producer'] == true,
          isBeautyProducer: postData['isBeautyProducer'] == true || 
                           postData['is_beauty_producer'] == true,
          isRestaurationProducer: postData['isRestaurationProducer'] == true || 
                                 postData['is_restauration_producer'] == true,
          targetId: postData['targetId']?.toString() ?? postData['target_id']?.toString(),
          authorId: postData['authorId']?.toString() ?? postData['author_id']?.toString(),
          authorName: postData['authorName']?.toString() ?? postData['author_name']?.toString(),
          authorAvatar: postData['authorAvatar']?.toString() ?? postData['author_photo']?.toString(),
        );
      }
      
      // Si ce n'est pas un Map, retourner un Post vide mais valide
      return Post(
        id: 'error',
        createdAt: DateTime.now(),
        description: 'Erreur de conversion',
        comments: [],  // Liste vide pour les commentaires
      );
    } catch (e) {
      print('❌ Erreur lors de la conversion en Post: $e');
      return Post(
        id: 'error',
        createdAt: DateTime.now(),
        description: 'Erreur de conversion: $e',
        comments: [],  // Liste vide pour les commentaires
      );
    }
  }
  
  void _handleSavePost(Post post) {
    // Implémentation de la sauvegarde du post
    // TODO: Implémenter la logique de sauvegarde
  }

  Future<void> _handleSharePost(Post post, String shareType) async {
    try {
      // Enregistrer l'interaction pour l'algorithme d'apprentissage
      _controller.logShare(post);
      
      switch (shareType) {
        case 'external':
          // Partage externe (via les apps du système)
          String shareText = post.content ?? 'Découvrez ce post sur Choice App!';
          String shareUrl = post.url ?? 'https://choiceapp.fr/post/${post.id}';
          
          try {
            await Share.share('$shareText\n\n$shareUrl');
          } catch (e) {
            print('Erreur lors du partage: $e');
          }
          break;
          
        case 'internal':
          // Partage interne (repost dans l'app)
          // TODO: Implémenter le repost interne
          break;
        default:
          // Partage par défaut
          String shareText = post.content ?? 'Découvrez ce post sur Choice App!';
          String shareUrl = post.url ?? 'https://choiceapp.fr/post/${post.id}';
          
          try {
            await Share.share('$shareText\n\n$shareUrl');
          } catch (e) {
            print('Erreur lors du partage: $e');
          }
      }
    } catch (e) {
      print('❌ Erreur lors du partage: $e');
    }
  }

  Future<void> _handleSharePostWithImage(Post post) async {
    try {
      if (post.mediaUrls?.isNotEmpty == true) {
        final String imageUrl = post.mediaUrls!.first;
        final file = await DefaultCacheManager().getSingleFile(imageUrl);
        await Share.shareXFiles([XFile(file.path)], text: 'Check out this post on Choice App!');
      } else {
        await _handleSharePost(post, 'external');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing post with image: $e');
      }
    }
  }

  Future<void> _handleSharePostWithVideo(Post post) async {
    try {
      if (post.mediaUrls?.isNotEmpty == true) {
        final String videoUrl = post.mediaUrls!.first;
        final file = await DefaultCacheManager().getSingleFile(videoUrl);
        await Share.shareXFiles([XFile(file.path)], text: 'Check out this post on Choice App!');
      } else {
        await _handleSharePost(post, 'external');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing post with video: $e');
      }
    }
  }

  void _handleReportPost(Post post) {
    // Implémentation du signalement du post
    // TODO: Implémenter la logique de signalement
  }

  void _openReferencedContent(BuildContext context, dynamic post) {
    if (post is Post) {
      if (post.referencedEventId != null && post.referencedEventId!.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(
              id: post.referencedEventId!,
            ),
          ),
        );
      } else if (post.targetId != null && post.targetId!.isNotEmpty) {
        // Ouvrir la page du producteur de loisir
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerId: post.targetId!),
          ),
        );
      } else {
        // Ouvrir la page de détail du post
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: post.id,
              userId: post.userId,
            ),
          ),
        );
      }
    } else if (post is Map<String, dynamic>) {
      // Logique pour gérer les maps
    }
  }

  // Méthode wrapper pour compatibilité avec l'ancien code
  List<Widget> _getCommentsWidgets(dynamic post, int limit) {
    List<dynamic>? comments;
    
    if (post is Post) {
      // Si c'est un Post, extraire les commentaires de metadata
      comments = post.metadata?['comments'] as List<dynamic>?;
    } else if (post is Map<String, dynamic>) {
      // Si c'est une Map, extraire les commentaires directement
      comments = post['comments'] as List<dynamic>?;
    }
    
    if (comments == null || comments.isEmpty) {
      return [const SizedBox.shrink()];
    }
    
    // Limiter le nombre de commentaires affichés
    final commentsToShow = comments.length > limit ? comments.sublist(0, limit) : comments;
    
    // Convertir chaque commentaire en widget CommentTile
    return commentsToShow.map<Widget>((comment) {
      final Map<String, dynamic> commentMap = comment is Map<String, dynamic> ? comment : {};
      return CommentTile(
        authorName: commentMap['authorName'] ?? commentMap['author_name'] ?? 'Utilisateur',
        text: commentMap['content'] ?? commentMap['text'] ?? '',
        date: commentMap['createdAt'] is DateTime 
            ? commentMap['createdAt'] 
            : (commentMap['createdAt'] is String 
                ? DateTime.parse(commentMap['createdAt']) 
                : DateTime.now()),
        avatar: commentMap['authorAvatar'] ?? commentMap['author_avatar'] ?? '',
        authorId: commentMap['authorId'] ?? commentMap['author_id'] ?? '',
        likes: commentMap['likes'] is int ? commentMap['likes'] : 0,
        onReply: () {},
        onLike: () {},
      );
    }).toList();
  }

  // Vérifier si un post a un événement référencé
  bool _hasReferencedEvent(dynamic post) {
    if (post is Post) {
      return post.referencedEventId != null && post.referencedEventId!.isNotEmpty;
    } else if (post is Map<String, dynamic>) {
      final eventId = post['referencedEventId'] ?? post['referenced_event_id'] ?? post['event_id'];
      return eventId != null && eventId.toString().isNotEmpty;
    }
    return false;
  }

  // Obtenir le type de référence (événement, etc.)
  String _getReferencedType(dynamic post) {
    if (post is Post) {
      if (post.referencedEventId != null && post.referencedEventId!.isNotEmpty) {
        return 'Événement';
      } else if (post.targetId != null && post.targetId!.isNotEmpty) {
        return post.type ?? 'Lié';
      }
    } else if (post is Map<String, dynamic>) {
      final eventId = post['referencedEventId'] ?? post['referenced_event_id'] ?? post['event_id'];
      final targetId = post['targetId'] ?? post['target_id'];
      final targetType = post['targetType'] ?? post['target_type'];
      
      if (eventId != null && eventId.toString().isNotEmpty) {
        return 'Événement';
      } else if (targetId != null && targetId.toString().isNotEmpty) {
        return targetType?.toString() ?? 'Lié';
      }
    }
    return 'Lié';
  }
  
  // Gérer les likes de posts
  Future<void> _handleLike(Post post) async {
    // Appeler la méthode améliorée avec animation
    _handleLikePressed(post);
  }
  
  // Gérer les intérêts pour les posts
  Future<void> _handleInterestOriginal(Post post) async {
    // Appeler la méthode améliorée avec animation
    _handleInterestPressed(post);
  }
  
  // Fonction helper pour récupérer le token d'authentification
  Future<String> getToken() async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      return token ?? '';
    } catch (e) {
      print('❌ Erreur lors de la récupération du token: $e');
      return '';
    }
  }
  
  // Helper method to fetch and navigate to beauty producer profile
  Future<void> _navigateToBeautyProducer(String id) async {
    try {
      // Vérifier si le widget est toujours monté avant de continuer
      if (!mounted) return;
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement du profil bien-être...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails et informations",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${_baseUrl}/api/beauty_wellness/places/$id');
      final response = await http.get(url);
      
      // Close loading indicator
      if (!mounted) return;
      if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WellnessProducerProfileScreen(
              producerData: data,
            ),
          ),
        );
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      // Close loading indicator if still open
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Ajouter cette méthode à la classe _FeedScreenState
  
  // Méthode pour savoir si l'auteur d'un post est suivi par l'utilisateur
  bool _isAuthorFollowed(dynamic post) {
    // Vérifier si c'est un post d'un producteur et s'il est marqué comme suivi
    if (post is Post) {
      // On utilise la propriété isInterested si elle existe
      return post.isInterested == true;
    } else if (post is Map<String, dynamic>) {
      // Si c'est un Map, vérifier les différentes façons dont l'intérêt peut être indiqué
      return post['isInterested'] == true || 
             post['interested'] == true || 
             post['isFollowed'] == true || 
             post['followed'] == true;
    }
    return false;
  }
  
  // Méthode pour construire le badge "suivi" si l'auteur est suivi
  Widget _buildFollowedBadge(dynamic post) {
    if (_isAuthorFollowed(post)) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepPurple.shade200, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Colors.deepPurple),
            SizedBox(width: 2),
            Text(
              'Suivi',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink(); // Widget vide si pas suivi
  }

  // Méthode pour gérer l'action de like avec animation
  void _handleLikePressed(dynamic post) {
    // Vibration légère pour le feedback tactile
    HapticFeedback.lightImpact();
    
    // Identifier le post et préparer l'état
    String postId = '';
    bool isCurrentlyLiked = false;
    
    if (post is Post) {
      postId = post.id ?? '';
      isCurrentlyLiked = post.isLiked;
    } else if (post is Map<String, dynamic>) {
      postId = post['id']?.toString() ?? '';
      isCurrentlyLiked = post['isLiked'] == true;
    }
    
    if (postId.isEmpty) {
      print('Erreur: ID du post non trouvé');
      return;
    }
    
    // Inverser l'état du like
    final newLikedState = !isCurrentlyLiked;
    
    // Mettre à jour l'UI immédiatement pour feedback instantané
    setState(() {
      // Mettre à jour l'état du like dans la liste de posts
      for (int i = 0; i < _controller.posts.length; i++) {
        if (_controller.posts[i].id == postId) {
          _controller.posts[i] = _controller.posts[i].copyWith(
            isLiked: newLikedState,
            likesCount: newLikedState 
              ? (_controller.posts[i].likesCount ?? 0) + 1 
              : math.max((_controller.posts[i].likesCount ?? 1) - 1, 0),
          );
          
          // Enregistrer l'interaction pour l'algorithme d'apprentissage
          if (newLikedState) {
            _controller.logLike(_controller.posts[i]);
          }
          break;
        }
      }
    });
    
    // Appeler l'API pour synchroniser l'action
    _likePost(postId, newLikedState).then((success) {
      if (!success) {
        // En cas d'échec, revenir à l'état précédent
        setState(() {
          for (int i = 0; i < _controller.posts.length; i++) {
            if (_controller.posts[i].id == postId) {
              _controller.posts[i] = _controller.posts[i].copyWith(
                isLiked: isCurrentlyLiked,
                likesCount: isCurrentlyLiked
                  ? (_controller.posts[i].likesCount ?? 0)
                  : math.max((_controller.posts[i].likesCount ?? 1) - 1, 0),
              );
              break;
            }
          }
        });
        
        // Afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'action. Veuillez réessayer."),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
  
  // Méthode pour gérer l'action d'intérêt avec animation
  void _handleInterestPressed(dynamic post) {
    // Vibration légère pour le feedback tactile
    HapticFeedback.lightImpact();
    
    // Identifier le post et préparer l'état
    String postId = '';
    bool isCurrentlyInterested = post.isInterested ?? false;
    String producerId = post.producerId ?? '';
    String producerType = post.producerType ?? '';
    
    if (post is Post) {
      postId = post.id ?? '';
      isCurrentlyInterested = post.isInterested ?? false;
      producerId = post.producerId ?? '';
      producerType = post.producerType ?? '';
    } else if (post is Map<String, dynamic>) {
      postId = post['id']?.toString() ?? '';
      isCurrentlyInterested = post['isInterested'] == true;
      producerId = post['producerId']?.toString() ?? '';
      producerType = post['producerType']?.toString() ?? '';
    }
    
    if (postId.isEmpty) {
      print('Erreur: ID du post non trouvé');
      return;
    }
    
    // Inverser l'état de l'intérêt
    final newInterestedState = !isCurrentlyInterested;
    
    // Mettre à jour l'UI immédiatement pour feedback instantané
    setState(() {
      // Mettre à jour l'état de l'intérêt dans la liste de posts
      for (int i = 0; i < _controller.posts.length; i++) {
        if (_controller.posts[i].id == postId) {
          _controller.posts[i] = _controller.posts[i].copyWith(
            isInterested: newInterestedState,
          );
          
          // Enregistrer l'interaction pour l'algorithme d'apprentissage
          if (newInterestedState) {
            _controller.logInterest(_controller.posts[i]);
          }
          break;
        }
      }
    });
    
    // Appeler l'API pour synchroniser l'action
    _markInterest(postId, newInterestedState).then((success) {
      if (!success) {
        // En cas d'échec, revenir à l'état précédent
        setState(() {
          for (int i = 0; i < _controller.posts.length; i++) {
            if (_controller.posts[i].id == postId) {
              _controller.posts[i] = _controller.posts[i].copyWith(
                isInterested: isCurrentlyInterested,
              );
              break;
            }
          }
        });
        
        // Afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'action. Veuillez réessayer."),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
  
  // Méthode pour gérer l'envoi d'un commentaire
  void _handleCommentSubmit(String postId, String commentText) async {
    if (commentText.trim().isEmpty) return;
    
    // Trouver le post concerné
    Post? targetPost;
    for (int i = 0; i < _controller.posts.length; i++) {
      if (_controller.posts[i].id == postId) {
        targetPost = _controller.posts[i];
        break;
      }
    }
    
    if (targetPost == null) return;
    
    // Afficher un loading
    setState(() {
      _isLoading = true;
      _loadingMessage = "Envoi du commentaire...";
    });
    
    try {
      // Appeler l'API pour ajouter le commentaire
      final success = await _postComment(postId, commentText);
      
      if (success) {
        // Mise à jour de l'UI
        setState(() {
          // Incrémenter le compteur de commentaires
          for (int i = 0; i < _controller.posts.length; i++) {
            if (_controller.posts[i].id == postId) {
              _controller.posts[i] = _controller.posts[i].copyWith(
                commentsCount: (_controller.posts[i].commentsCount ?? 0) + 1,
              );
              
              // Enregistrer l'interaction pour l'algorithme d'apprentissage
              _controller.logComment(_controller.posts[i]);
              break;
            }
          }
        });
        
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Commentaire ajouté avec succès"),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'ajout du commentaire"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de l\'ajout du commentaire: $e');
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  
  // Méthode pour marquer un post comme vu après visibilité suffisante
  void _onPostViewed(Post post, double visibleFraction) {
    // Considérer un post comme "vu" s'il est visible à plus de 70% pendant au moins 2 secondes
    if (visibleFraction >= 0.7) {
      // Utiliser un timer pour s'assurer que le post reste visible suffisamment longtemps
      Future.delayed(Duration(seconds: 2), () {
        // Vérifier si le widget est toujours monté
        if (mounted) {
          // Enregistrer la vue
          _controller.logView(post);
        }
      });
    }
  }
  
  // Méthode API pour liker un post
  Future<bool> _likePost(String postId, bool isLiked) async {
    try {
      // Utiliser la fonction synchrone de constants
      final String baseUrl = constants.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/posts/$postId/like');
      final token = await getToken();
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        print('Erreur like post: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception like post: $e');
      return false;
    }
  }
  
  // Méthode API pour marquer un intérêt
  Future<bool> _markInterest(String postId, bool isInterested) async {
    try {
      // Utiliser la fonction synchrone de constants
      final String baseUrl = constants.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/posts/$postId/interest');
      final token = await getToken();
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        print('Erreur intérêt: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception intérêt: $e');
      return false;
    }
  }
  
  // Méthode API pour poster un commentaire
  Future<bool> _postComment(String postId, String commentText) async {
    try {
      // Utiliser la fonction synchrone de constants
      final String baseUrl = constants.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/posts/$postId/comment');
      final token = await getToken();
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'text': commentText,
        }),
      );
      
      if (response.statusCode == 201) {
        return true;
      } else {
        print('Erreur commentaire: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception commentaire: $e');
      return false;
    }
  }

  // Gestion de l'action "Intéressé"
  void _handleInterestAction(Post postObj) async {
    final String postId = postObj.id;
    final bool isCurrentlyInterested = postObj.isInterested ?? false;
    
    try {
      // Optimistic update
      _updatePostInterest(postId, !isCurrentlyInterested);
      
      // Make API call
      final success = await _apiService.markPostAsInterested(
        postId,
        !isCurrentlyInterested,
      );
      
      if (!success) {
        // Revert if failed
        _updatePostInterest(postId, isCurrentlyInterested);
        _showErrorSnackBar("Erreur lors de la mise à jour de l'intérêt");
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'intérêt: $e');
      _updatePostInterest(postId, isCurrentlyInterested);
      _showErrorSnackBar("Erreur lors de la mise à jour");
    }
  }
  
  // Helper pour afficher un SnackBar d'erreur
  void _showErrorSnackBar(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  

  // Méthode pour mettre à jour l'état d'intérêt d'un post
  void _updatePostInterest(String postId, bool interested) {
    setState(() {
      // Mise à jour locale pour la réactivité de l'UI
      for (int i = 0; i < _controller.feedItems.length; i++) {
        if (_controller.feedItems[i] is Post && (_controller.feedItems[i] as Post).id == postId) {
          Post post = _controller.feedItems[i] as Post;
          (_controller.feedItems[i] as Post).setIsInterested = interested;
          
          // Mettre à jour le compteur d'intérêts
          if (interested) {
            (_controller.feedItems[i] as Post).setInterestedCount = (post.interestedCount) + 1;
          } else {
            (_controller.feedItems[i] as Post).setInterestedCount = math.max((post.interestedCount) - 1, 0);
          }
        }
      }
    });
  }

  Future<void> _someMethod() async {
    try {
      // Utiliser la fonction synchrone de constants
      final String baseUrl = constants.getBaseUrl();
      // Utiliser baseUrl...
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la récupération de l\'URL de base: $e');
      }
    }
  }
} // Fin de la classe

class CommentsScreen extends StatefulWidget {
  final Post post;
  final String userId;

  const CommentsScreen({
    Key? key,
    required this.post,
    required this.userId,
  }) : super(key: key);

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Méthode pour récupérer le token
  Future<String> getToken() async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      return token ?? '';
    } catch (e) {
      print('❌ Erreur lors de la récupération du token: $e');
      return '';
    }
  }

  // Charger les commentaires du post
  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Utiliser la fonction synchrone de constants
      final String baseUrl = constants.getBaseUrl();
      final String url = '$baseUrl/api/posts/${widget.post.id}/comments';
      
      final token = await getToken(); // Garder await pour getToken()
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> commentsData = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _comments = commentsData.map((data) => Comment.fromJson(data)).toList();
        });
      } else {
        print('❌ Erreur de chargement des commentaires: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Exception lors du chargement des commentaires: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Ajouter un commentaire
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Utiliser la fonction synchrone de constants
      final String baseUrl = constants.getBaseUrl();
      final String url = '$baseUrl/api/posts/${widget.post.id}/comments';
      
      final token = await getToken();
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'content': _commentController.text,
          'userId': widget.userId,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newComment = Comment.fromJson(data);
        
        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
          _isSubmitting = false;
        });
        
        // Utiliser l'analytics pour suivre l'ajout de commentaire
        AnalyticsService().logEvent(
          name: 'comment_added',
          parameters: {
            'post_id': widget.post.id,
            'user_id': widget.userId,
          },
        );
      } else {
        print('❌ Erreur lors de l\'ajout du commentaire: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ajouter le commentaire')),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      print('❌ Exception lors de l\'ajout du commentaire: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commentaires'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('Aucun commentaire pour ce post'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return CommentTile.fromComment(
                            comment: comment,
                            onLike: () => _handleCommentLike(comment.id, index),
                            onReply: () => _handleCommentReply(comment.authorName),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.person, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                    ),
                  ),
                  _isSubmitting
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.deepPurple.shade400,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.deepPurple),
                          onPressed: _addComment,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Gérer le like d'un commentaire
  Future<void> _handleCommentLike(String commentId, int index) async {
    try {
      setState(() {
        // Mise à jour optimiste
        final bool currentlyLiked = _comments[index].isLiked;
        final int currentLikes = _comments[index].likes;
        
        // Créer une copie mise à jour du commentaire
        _comments[index] = _comments[index].copyWith(
          isLiked: !currentlyLiked,
          likes: currentlyLiked ? currentLikes - 1 : currentLikes + 1,
        );
      });
      
      
      // Utiliser la fonction getBaseUrl de la classe parente
      final String baseUrl = await getBaseUrl();
      final String url = '$baseUrl/api/comments/$commentId/like';
      
      final token = await getToken();
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'userId': widget.userId,
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Erreur lors du like du commentaire: ${response.statusCode}');
        
        // Annuler la mise à jour optimiste en cas d'erreur
        setState(() {
          final bool currentlyLiked = _comments[index].isLiked;
          final int currentLikes = _comments[index].likes;
          
          // Créer une copie mise à jour du commentaire
          _comments[index] = _comments[index].copyWith(
            isLiked: !currentlyLiked,
            likes: currentlyLiked ? currentLikes - 1 : currentLikes + 1,
          );
        });
      }
    } catch (e) {
      print('❌ Exception lors du like du commentaire: $e');
      
      // Annuler la mise à jour optimiste en cas d'erreur
      setState(() {
        final bool currentlyLiked = _comments[index].isLiked;
        final int currentLikes = _comments[index].likes;
        
        // Créer une copie mise à jour du commentaire
        _comments[index] = _comments[index].copyWith(
          isLiked: !currentlyLiked,
          likes: currentlyLiked ? currentLikes - 1 : currentLikes + 1,
        );
      });
    }
  }

  // Répondre à un commentaire
  void _handleCommentReply(String authorName) {
    _commentController.text = '@$authorName ';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    
    // Focus sur le champ de commentaire
    FocusScope.of(context).requestFocus(FocusNode());
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }
  
  // Naviguer vers le profil d'un utilisateur
  void _navigateToUserProfile(String userId) {
    if (userId.isEmpty) return;
    
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            userId: userId,
            viewMode: 'public',
          ),
        ),
      );
    } catch (e) {
      print('❌ Erreur lors de la navigation vers le profil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'afficher le profil utilisateur: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  // Ne garder qu'une seule définition de getBaseUrl ici
  Future<String> getBaseUrl() async {
    return await constants.getBaseUrl();
  }
}

class CommentTile extends StatelessWidget {
  final String authorName;
  final String text;
  final DateTime date;
  final String? avatar;
  final String? authorId;
  final int? likes;
  final bool isLiked;
  final Function()? onReply;
  final Function()? onLike;

  const CommentTile({
    Key? key,
    required this.authorName,
    required this.text,
    required this.date,
    this.avatar,
    this.authorId,
    this.likes = 0,
    this.isLiked = false,
    this.onReply,
    this.onLike,
  }) : super(key: key);
  
  // Constructeur de conversion depuis un objet Comment
  factory CommentTile.fromComment({
    required Comment comment,
    required VoidCallback onLike,
    required VoidCallback onReply,
  }) {
    return CommentTile(
      authorName: comment.authorName,
      text: comment.content,
      date: comment.createdAt,
      avatar: comment.authorAvatar,
      authorId: comment.authorId,
      likes: comment.likes,
      isLiked: comment.isLiked,
      onLike: onLike,
      onReply: onReply,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final _CommentsScreenState? commentScreenState = 
        context.findAncestorStateOfType<_CommentsScreenState>();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar de l'auteur
          GestureDetector(
            onTap: () {
              // Naviguer vers le profil de l'auteur si disponible
              if (commentScreenState != null && authorId != null) {
                // Utiliser la méthode du parent pour naviguer
                commentScreenState._navigateToUserProfile(authorId!);
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              backgroundImage: avatar != null && avatar!.isNotEmpty
                  ? CachedNetworkImageProvider(avatar!) as ImageProvider
                  : const AssetImage('assets/images/default_avatar.png'),
              child: avatar == null || avatar!.isEmpty
                  ? Icon(Icons.person, size: 20, color: Colors.grey[400])
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Naviguer vers le profil de l'auteur si disponible
                        if (commentScreenState != null && authorId != null) {
                          // Utiliser la méthode du parent pour naviguer
                          commentScreenState._navigateToUserProfile(authorId!);
                        }
                      },
                      child: Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (onLike != null)
                      InkWell(
                        onTap: onLike,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isLiked ? Colors.red : Colors.grey[600],
                              ),
                              if (likes != null && likes! > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '$likes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isLiked ? Colors.red[400] : Colors.grey[600],
                                    fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    if (onReply != null)
                      InkWell(
                        onTap: onReply,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            'Répondre',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'à l\'instant';
    } else if (difference.inHours < 1) {
      return 'il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'il y a ${difference.inDays} j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
