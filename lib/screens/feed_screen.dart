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
import 'my_offers_screen.dart';

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
                  // Add the new "My Offers" button here
                  IconButton(
                    icon: const Icon(Icons.confirmation_number_outlined, color: Colors.deepPurple),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyOffersScreen()),
                      );
                    },
                    tooltip: 'Mes offres',
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
                  itemCount: getFilteredFeedItems(_controller.currentFilter).length +
                    (_controller.loadState == FeedLoadState.loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    final filteredItems = getFilteredFeedItems(_controller.currentFilter);
                    if (index >= filteredItems.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final item = filteredItems[index];
                    // Si le filtre AI est actif, n'afficher que les messages AI
                    if (_controller.currentFilter == FeedContentType.aiDialogic) {
                      if (item is DialogicAIMessage || (item is Map && item['type'] == 'ai_message')) {
                        return _buildAIMessageCard(item is DialogicAIMessage ? item : DialogicAIMessage.fromJson(item));
                      } else {
                        return const SizedBox.shrink();
                      }
                    }
                    // Sinon, comportement normal
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
    
    // Safely get rating as double?
    final ratingValue = (profile['rating'] is num) ? (profile['rating'] as num).toDouble() : null;
    // Safely get price level as int
    final priceLevelValue = int.tryParse((profile['price_level'] ?? profile['priceLevel'] ?? '1').toString()) ?? 1;
    
    return GestureDetector(
      onTap: () {
        // ... existing code ...
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
            // ... existing code ...
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ... existing code ...
                  Row(
                    children: [
                      // Rating
                      if (ratingValue != null)
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
                                ratingValue.toString(),
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
                      if (priceLevelValue > 0)
                        Text(
                          '€' * priceLevelValue,
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
    print('Stub: _fetchAndNavigateToLeisureProducer called with id: $id');
  }
  
  // Helper method to fetch and navigate to event
  Future<void> _fetchAndNavigateToEvent(String id) async {
    print('Stub: _fetchAndNavigateToEvent called with id: $id');
  }
  
  // Helper method to show AI response input
  Future<String?> _showAIResponseInput(String suggestion) async {
    print('Stub: _showAIResponseInput called with suggestion: $suggestion');
    return null;
  }
  
  // Build card for Map-based post object (dynamic structure from backend)
  Widget _buildDynamicPostCard(Map<String, dynamic> post) {
    // ... existing code ...
    List<Map<String, dynamic>> mediaItems = [];
    if (post['media'] != null) {
      try {
        if (post['media'] is List) {
          for (var media in post['media']) {
            if (media is Map) {
              final url = media['url'] ?? '';
              final type = media['type'] ?? 'image';
              if (url.isNotEmpty) {
                mediaItems.add({
                  'url': url,
                  'type': type,
                  'width': (media['width'] is num) ? (media['width'] as num).toDouble() : null,
                  'height': (media['height'] is num) ? (media['height'] as num).toDouble() : null,
                });
              }
            } else if (media is String) {
              mediaItems.add({
                'url': media,
                'type': 'image'
              });
            }
          }
        } else if (post['media'] is Map) {
          final media = post['media'] as Map;
          final url = media['url'] ?? '';
          final type = media['type'] ?? 'image';
          if (url.isNotEmpty) {
            mediaItems.add({
              'url': url,
              'type': type,
              'width': (media['width'] is num) ? (media['width'] as num).toDouble() : null,
              'height': (media['height'] is num) ? (media['height'] as num).toDouble() : null,
            });
          }
        }
      } catch (e) {
        print('❌ Erreur lors du traitement des médias : $e');
      }
    }
    
    // Get post timestamp
    // ... existing code ...
    return const SizedBox.shrink();
  }
  
  // Build interaction button with animation
  Widget _buildInteractionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    int? count,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // Animated icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isActive ? iconColor.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: Icon(
                icon,
                color: isActive ? iconColor : Colors.grey,
                size: 18,
              ),
            ),
            const SizedBox(width: 4),
            // Label
            Text(
              count != null ? '$label (${count.toString()})' : label,
              style: TextStyle(
                color: isActive ? iconColor : Colors.grey[700],
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Naviguer vers la vue reels avec tous les reels disponibles
  void _navigateToReelsViewFromFirstVideo() {
    _navigateToReelsView();
  }

  // Build card for Post objects with improved styling and interactions
  Widget _buildPostCard(Post post) {
    print('🏗️ Affichage du post: \${post.id} - \${post.authorName ?? "Sans auteur"}');

    void navigateToProfile() {
      if (post.isProducerPost ?? false) {
        if (post.isLeisureProducer ?? false) {
      Navigator.push(
        context,
        MaterialPageRoute(
              builder: (context) => ProducerLeisureScreen(
                producerId: post.authorId ?? '',
                userId: widget.userId
          ),
        ),
      );
        } else if (post.isWellnessProducer ?? false) {
    Navigator.push(
      context,
      MaterialPageRoute(
              builder: (context) => WellnessProducerProfileScreen(
                producerData: {},
            ),
          ),
        );
      } else {
    Navigator.push(
      context,
      MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: post.authorId ?? '',
                userId: widget.userId
        ),
      ),
    );
  }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: post.authorId ?? ''),
        ),
      );
    }
  }

    void navigateToPostDetail({bool openComments = false}) {
      final apiService = _apiService;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Provider<ApiService>.value(
            value: apiService,
            child: PostDetailScreen(
              postId: post.id,
              userId: widget.userId,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: OpenContainer(
        transitionDuration: const Duration(milliseconds: 500),
        closedElevation: 2.0,
        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        closedColor: Colors.white,
        openColor: Theme.of(context).cardColor,
        openShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.0)),
        closedBuilder: (BuildContext _, VoidCallback openContainer) {
          return InkWell(
            onTap: openContainer,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: navigateToProfile,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: post.authorAvatar != null && post.authorAvatar!.isNotEmpty
                              ? CachedNetworkImageProvider(post.authorAvatar!)
                              : null,
                          backgroundColor: post.authorAvatar == null || post.authorAvatar!.isEmpty
                              ? post.getTypeColor().withOpacity(0.7)
                              : post.getTypeColor(),
                          child: post.authorAvatar == null || post.authorAvatar!.isEmpty
                              ? Icon(post.getTypeIcon(), color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorName ?? 'Utilisateur Anonyme',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                post.getTypeLabel(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: post.getTypeColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    timeago.format(post.postedAt ?? DateTime.now(), locale: 'fr'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.more_vert, color: Colors.grey[500]),
                  if (post.content != null && post.content!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: TranslatableContent(
                        text: post.content!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  if (post.media.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: CachedNetworkImage(
                          imageUrl: post.media.first.url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 250,
                          placeholder: (context, url) => Container(
                            height: 250,
                            color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator(color: Colors.grey[400])),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 250,
                            color: Colors.grey[300],
                            child: Center(child: Icon(Icons.broken_image, color: Colors.grey[600])),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInteractionButton(
                          icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                          iconColor: post.isLiked ? Colors.redAccent : Colors.grey,
                          label: 'J\'aime',
                          count: post.likesCount,
                          isActive: post.isLiked,
                          onPressed: () => _controller.likePost(post),
                        ),
                        _buildInteractionButton(
                          icon: Icons.mode_comment_outlined,
                          iconColor: Colors.blueGrey,
                          label: 'Commenter',
                          count: post.commentsCount,
                          onPressed: () => navigateToPostDetail(openComments: true),
                        ),
                        _buildInteractionButton(
                          icon: post.isInterested ?? false ? Icons.star : Icons.star_border,
                          iconColor: post.isInterested ?? false ? Colors.amber[700]! : Colors.grey,
                          label: 'Intéressé',
                          isActive: post.isInterested ?? false,
                          count: post.interestedCount,
                          onPressed: () {
                            // Update optimistic UI
                            setState(() {
                              post.isInterested = !post.isInterested!;
                              post.interestedCount = (post.interestedCount ?? 0) + (post.isInterested! ? 1 : -1);
                            });
                            _controller.markInterested(
                              post,
                              'feed',
                              post.isLeisureProducer ?? false
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.share_outlined, color: Colors.grey[600]),
                          onPressed: () {
                            // TODO: Implémenter le partage
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        openBuilder: (BuildContext _, VoidCallback __) {
          final apiService = _apiService;
          return Provider<ApiService>.value(
            value: apiService,
            child: PostDetailScreen(postId: post.id, userId: widget.userId),
          );
        },
      ),
    );
  }
  
  // Ajout : fonction de filtrage des posts selon le type
  List<dynamic> getFilteredFeedItems(FeedContentType filter) {
    return _controller.feedItems.where((item) {
      if (item is Post) {
        switch (filter) {
          case FeedContentType.restaurants:
            return item.isRestaurationProducer == true;
          case FeedContentType.leisure:
            return item.isLeisureProducer == true;
          case FeedContentType.wellness:
            return item.isWellnessProducer == true || item.type == 'beauty_producer';
          case FeedContentType.userPosts:
            return !(item.isProducerPost ?? false);
          case FeedContentType.aiDialogic:
            return false;
          default:
            return true;
        }
      } else if (item is Map<String, dynamic>) {
        switch (filter) {
          case FeedContentType.restaurants:
            return item['isRestaurationProducer'] == true;
          case FeedContentType.leisure:
            return item['isLeisureProducer'] == true || item['type'] == 'event_producer';
          case FeedContentType.wellness:
            return item['isWellnessProducer'] == true || item['type'] == 'beauty_producer';
          case FeedContentType.userPosts:
            return !(item['isProducerPost'] == true);
          case FeedContentType.aiDialogic:
            return false;
          default:
            return true;
        }
      }
      return false;
    }).toList();
  }
} // Fin de la classe
