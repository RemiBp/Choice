import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:google_fonts/google_fonts.dart';

// Import Models and Services
import '../models/post.dart';
import '../models/comment.dart';
import '../models/dialogic_ai_message.dart'; // KEEP
import '../services/api_service.dart' as api_service; // KEEP
import '../services/auth_service.dart'; // KEEP

// Import Controllers
import '../controllers/producer_feed_controller.dart'; // KEEP

// Import Screens for Navigation
import 'reels_view_screen.dart';
import 'post_detail_screen.dart';
import 'producer_screen.dart';
import 'producerLeisure_screen.dart';
import 'wellness_producer_screen.dart';
import 'producer_messaging_screen.dart';
import 'profile_screen.dart';
import '../widgets/comments_widget.dart';
import '../widgets/producer_feed/producer_post_card.dart';
import '../widgets/producer_feed/ai_message_card.dart';
import '../widgets/producer_feed/producer_empty_view.dart';
import '../widgets/producer_feed/create_post_modal.dart';
import '../widgets/producer_feed/post_stats_modal.dart';
import '../utils.dart';

// --- Category Lists ---
const List<String> _restaurantCategories = [
  'Tous', 'Promotions', 'Événements', 'Plats', 'Nouveautés', 'Ambiance', 'Coulisses'
];
const List<String> _leisureCategories = [
  'Tous', 'Événements', 'Expositions', 'Spectacles', 'Promotions', 'Activités', 'Nouveautés'
];
const List<String> _wellnessCategories = [
  'Tous', 'Soins', 'Cours', 'Ateliers', 'Événements', 'Promotions', 'Conseils'
];

// --- Helper Functions (Define or Import) ---
// Moved to producer_post_card.dart, ensure they are accessible there or move to utils.dart

class ProducerFeedScreen extends StatefulWidget {
  final String userId; // Logged-in user ID

  const ProducerFeedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _ProducerFeedScreenState createState() => _ProducerFeedScreenState();
}

class _ProducerFeedScreenState extends State<ProducerFeedScreen> with SingleTickerProviderStateMixin {
  late ProducerFeedController _controller;
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  final Map<String, VideoPlayerController> _videoControllers = {};
  String? _currentlyPlayingVideoId;

  late bool _isLeisureProducer;
  late String _producerTypeString;
  late String _producerAccountId;
  late Color _primaryColor;

  late List<String> _categories;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();

    final authService = Provider.of<AuthService>(context, listen: false);
    _producerAccountId = authService.userId ?? widget.userId; // Keep this assignment
    final accountType = authService.accountType;

    // Use _producerAccountId consistently, no need for widget.userId in print anymore
    print("🔧 Producer Feed Init: AccountType=$accountType, ProducerAccountID=$_producerAccountId");

    _setupProducerType(accountType);

    _controller = ProducerFeedController(
      userId: _producerAccountId, // Use the stored producer account ID
      producerTypeString: _producerTypeString,
    );

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);

    _setupCategories();
    _selectedCategory = _categories.isNotEmpty ? _categories[0] : 'Tous';

    _controller.filterFeed(api_service.ProducerFeedContentType.localTrends);
    _scrollController.addListener(_handleScroll);
  }

  void _setupProducerType(String? accountType) {
     if (accountType == 'LeisureProducer') {
      _isLeisureProducer = true; _producerTypeString = 'leisure'; _primaryColor = Colors.deepPurple;
    } else if (accountType == 'WellnessProducer') {
      _isLeisureProducer = false; _producerTypeString = 'wellness'; _primaryColor = Colors.green;
    } else {
      _isLeisureProducer = false; _producerTypeString = 'restaurant'; _primaryColor = Colors.orange;
    }
  }

  void _setupCategories() {
     switch (_producerTypeString) {
      case 'leisure': _categories = _leisureCategories; break;
      case 'wellness': _categories = _wellnessCategories; break;
      case 'restaurant': default: _categories = _restaurantCategories; break;
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && _tabController.previousIndex == _tabController.index) return;
    if (!mounted) return;
    api_service.ProducerFeedContentType newFilter;
    switch (_tabController.index) {
      case 0: newFilter = api_service.ProducerFeedContentType.localTrends; break;
      case 1: newFilter = api_service.ProducerFeedContentType.venue; break;
      case 2: newFilter = api_service.ProducerFeedContentType.interactions; break;
      case 3: newFilter = api_service.ProducerFeedContentType.followers; break;
      default: newFilter = api_service.ProducerFeedContentType.localTrends;
    }
    print("🔄 Tab changed to: ${_tabController.index}, Filter: $newFilter");
    _controller.filterFeed(newFilter);
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
        _controller.hasMorePosts &&
        _controller.loadState != api_service.ProducerFeedLoadState.loadingMore) {
      _controller.loadMore();
    }
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) { controller.dispose(); }
    _videoControllers.clear();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- Video Handling Methods ---
   Future<void> _initializeVideoController(String postId, String videoUrl) async {
       if (_videoControllers.containsKey(postId) && _videoControllers[postId]!.value.isInitialized) return;
       if (_videoControllers.containsKey(postId)) {
          print("📹 Re-init controller: $postId");
          await _videoControllers[postId]?.dispose();
       }
       print("📹 Init video: $postId");
       try {
          final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          _videoControllers[postId] = controller;
          await controller.initialize();
          await controller.setLooping(true);
          await controller.setVolume(0.0);
          if (mounted && _currentlyPlayingVideoId == postId) await controller.play();
          if (mounted) setState(() {});
       } catch (e, stackTrace) {
         print('❌ Error init video $postId: $e\n$stackTrace');
         _videoControllers.remove(postId);
          if (mounted) setState(() {});
       }
   }

   void _handlePostVisibilityChanged(String postId, double visibleFraction, String? videoUrl) {
        if (videoUrl == null || !mounted) return;
        final controller = _videoControllers[postId];
        if (visibleFraction > 0.7) {
          if (_currentlyPlayingVideoId != postId) {
            if (_currentlyPlayingVideoId != null && _videoControllers.containsKey(_currentlyPlayingVideoId)) {
              _videoControllers[_currentlyPlayingVideoId]?.pause();
            }
            _currentlyPlayingVideoId = postId;
            print("▶️ Play: $postId");
            if (controller != null && controller.value.isInitialized) {
               controller.play();
            } else if (controller == null) {
               _initializeVideoController(postId, videoUrl);
            } else { print("📹 Wait init: $postId"); }
          }
        } else if (visibleFraction < 0.2 && _currentlyPlayingVideoId == postId) {
          print("⏸️ Pause: $postId");
          controller?.pause();
          _currentlyPlayingVideoId = null;
        }
   }

  // --- Navigation Methods ---
  void _navigateToMessaging() {
     print("Navigating to Producer Messaging...");
     Navigator.push(context, MaterialPageRoute(builder: (context) =>
        ProducerMessagingScreen(producerId: _producerAccountId, producerType: _producerTypeString)));
  }

 void _openComments(dynamic postData) {
    // ... (Extraction logic)
    String postId; Map<String, dynamic> postMap;
    if (postData is Post) { postId = postData.id; postMap = {'_id': postId, /*...*/ 'comments': postData.comments }; }
    else if (postData is Map<String, dynamic>) { postId = postData['_id'] ?? ''; postMap = postData; }
    else { /* Error handling */ return; }
    // ... (Video pausing)
    print("Navigating to Comments: $postId");
    Navigator.push(context, MaterialPageRoute(builder: (context) =>
        CommentsWidget(
            postId: postId,
            postData: postMap,
            userId: _producerAccountId, // Use the correct producer account ID for comments
            onNewComment: (c) { _controller.refreshFeed(); },
        ), fullscreenDialog: true));
  }

 void _openReelsView(dynamic post, String mediaUrl) {
    // ... (Video pausing)
    Map<String, dynamic> postData = {}; List<Map<String, dynamic>> videos = []; int initialIndex = 0;
     if (post is Post) {
       postData = { /*...*/ 'visualBadge': getVisualBadge(post), /*...*/ }; // Use helper from utils
       // ... (Media mapping)
     } else if (post is Map<String, dynamic>) {
       postData = {...post}; postData['visualBadge'] ??= getVisualBadge(post); // Use helper from utils
       // ... (Other data extraction)
     } else { return; }
     // ... (Video list preparation and navigation)
 }

 void _navigateToProfileFromData(dynamic postData) {
    // ... (Keep previous extraction logic)
     String profileId = ''; String profileType = 'user';
    if (postData is Map) { profileId = postData['author_id'] ?? postData['author']?['id'] ?? ''; if (postData['isLeisureProducer'] == true) profileType = 'leisureProducer'; else if (postData['isWellnessProducer'] == true || postData['isBeautyProducer'] == true) profileType = 'wellnessProducer'; else if (postData['isProducerPost'] == true || postData['producer_id'] != null) profileType = 'restaurant'; }
    else if (postData is Post) { profileId = postData.authorId ?? ''; if (postData.isLeisureProducer ?? false) profileType = 'leisureProducer'; else if (postData.isBeautyProducer ?? false) profileType = 'wellnessProducer'; else if (postData.isProducerPost ?? false) profileType = 'restaurant'; }
    if (profileId.isNotEmpty) _navigateToProfile(profileId, profileType); else print("❌ No profile ID.");
 }

 void _navigateToProfile(String profileId, String type) {
    print("Nav to profile: $profileId ($type)");
    Widget? screen; // Make screen nullable
    final bool isOwnProfile = (profileId == _producerAccountId);
    final String idToUse = (isOwnProfile && type == _producerTypeString) ? _producerAccountId : profileId;

    switch (type) {
      case 'restaurant':
        screen = ProducerScreen(producerId: idToUse);
        break;
      case 'leisureProducer':
        screen = ProducerLeisureScreen(producerId: idToUse);
        break;
      case 'wellnessProducer':
        screen = WellnessProducerScreen(producerId: idToUse);
        break;
      case 'user':
        screen = ProfileScreen(userId: idToUse);
        break;
      default:
        print("⚠️ Unknown profile type for navigation: $type");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d\'afficher ce profil ($type).'))
        );
        // Don't assign screen, effectively preventing navigation
    }

    // Only navigate if screen was assigned
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
    }
  }

 void _showSimplePostOptions(dynamic post) {
     final postId = (post is Map ? post['_id'] : post?.id) ?? 'inconnu';
     if (postId == 'inconnu') return;
     showModalBottomSheet(context: context, builder: (context) => Wrap(
        children: [ ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Supprimer le post', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); _confirmDeletePost(postId); }) ]
     ));
 }

 void _confirmDeletePost(String postId) {
    showDialog(context: context, builder: (context) => AlertDialog(
       title: const Text('Supprimer le Post'), content: const Text('Êtes-vous sûr ? Cette action est définitive.'),
       actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), TextButton(onPressed: () { Navigator.pop(context); _deletePost(postId); }, child: const Text('Supprimer', style: TextStyle(color: Colors.red))) ],
    ));
 }

 Future<void> _deletePost(String postId) async {
    print("🗑️ Deleting post $postId");
    try {
       // Pass the correct producer ID (assuming it's needed for authorization)
       await Provider.of<api_service.ApiService>(context, listen: false).deletePost(_producerAccountId, postId);
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post supprimé'), backgroundColor: Colors.green,));
       _controller.refreshFeed();
    } catch (e) {
       print("❌ Error deleting post $postId: $e");
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur suppression: ${e.toString()}'), backgroundColor: Colors.red,));
    }
 }

  // --- UI Building Methods ---
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: _controller,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                 SliverAppBar(
                    backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
                    elevation: 0, floating: true, pinned: true,
                    title: Row(children: [
                        Icon(
                          _producerTypeString == 'leisure' ? Icons.museum_outlined :
                          _producerTypeString == 'wellness' ? Icons.spa_outlined :
                          Icons.restaurant_menu_outlined,
                          color: _primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _producerTypeString == 'leisure' ? 'Feed Loisirs' :
                          _producerTypeString == 'wellness' ? 'Feed Bien-être' :
                          'Feed Restaurant',
                          style: GoogleFonts.poppins(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                    ]),
                    actions: [
                       IconButton(icon: const Icon(Icons.forum_outlined), tooltip: 'Messagerie', color: Colors.grey[600], onPressed: _navigateToMessaging),
                       const SizedBox(width: 8),
                    ],
                    bottom: TabBar(
                      controller: _tabController, indicatorColor: _primaryColor, labelColor: _primaryColor, unselectedLabelColor: Colors.grey[600],
                      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13), unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
                      tabs: const [ Tab(text: 'Tendances'), Tab(text: 'Mon lieu'), Tab(text: 'Interactions'), Tab(text: 'Followers') ],
                    ),
                 ),
                 _buildCategoryFilterRow(), // Keep this method in the main screen state
              ],
              body: Consumer<ProducerFeedController>(
                 builder: (context, controller, child) => RefreshIndicator(
                    onRefresh: () => controller.refreshFeed(),
                    color: _primaryColor,
                    child: _buildFeedContent(controller),
                 )
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => CreatePostModal.show(context, _producerTypeString),
            backgroundColor: _primaryColor, foregroundColor: Colors.white, tooltip: 'Créer une publication',
            child: const Icon(Icons.add),
          ),
        ),
    );
  }

  // Builds the main content area using imported widgets
  Widget _buildFeedContent(ProducerFeedController controller) {
     if (controller.loadState == api_service.ProducerFeedLoadState.initial || controller.loadState == api_service.ProducerFeedLoadState.loading) {
       return _buildLoadingView();
     }
     if (controller.loadState == api_service.ProducerFeedLoadState.error) {
       return _buildErrorView(controller.errorMessage);
     }
     if (controller.feedItems.isEmpty) {
       return ProducerEmptyView(
          tabIndex: _tabController.index, isLeisureProducer: _isLeisureProducer,
          onCreatePost: () => CreatePostModal.show(context, _producerTypeString),
       );
     }
     // Main feed list
     return ListView.builder(
       padding: const EdgeInsets.only(top: 8, bottom: 80),
       itemCount: controller.feedItems.length + (controller.loadState == api_service.ProducerFeedLoadState.loadingMore ? 1 : 0),
       itemBuilder: (context, index) {
         if (index >= controller.feedItems.length) {
           return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));
         }
         final item = controller.feedItems[index];
         if (item is DialogicAIMessage) { return AIMessageCard(message: item); }
         else if (item is Post || item is Map<String, dynamic>) {
           return ProducerPostCard(
              post: item,
              currentUserId: _producerAccountId, // Pass the correct ID for like status etc.
              onLike: (post) => controller.likePost(post),
              onComment: (post) => _openComments(post),
              onShare: (post) => print("Share..."), // Placeholder
              onShowStats: (post) => PostStatsModal.show(context, post),
              onShowOptions: (post) => _showSimplePostOptions(post),
              onVisibilityChanged: _handlePostVisibilityChanged,
              videoControllers: _videoControllers,
              initializeVideoController: _initializeVideoController,
              openReelsView: _openReelsView,
              openDetails: _openComments,
              onNavigateToProfile: (id, type) => _navigateToProfile(id, type),
           );
         } else {
           print('⚠️ Unhandled item type: ${item.runtimeType}');
           return const SizedBox.shrink();
         }
       },
     );
  }

  // --- Simple View Builders (Loading, Error) - Kept in State ---
  Widget _buildLoadingView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
        const SizedBox(height: 16),
        Text('Chargement du feed...', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16)),
    ]));
  }

  Widget _buildErrorView(String errorMessage) {
    return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, color: Colors.red[400], size: 48),
        const SizedBox(height: 16),
        Text('Oups! Une erreur', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800])),
        const SizedBox(height: 8),
        Text(errorMessage, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[700])),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () => _controller.refreshFeed(), icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
    ])));
  }

  // Category filter row - Kept in State
   Widget _buildCategoryFilterRow() {
    return SliverToBoxAdapter(child: Container(height: 50, padding: const EdgeInsets.symmetric(vertical: 8.0), child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12.0), itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index]; final isSelected = _selectedCategory == category;
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ChoiceChip(
              label: Text(category), selected: isSelected, onSelected: (_) => _changeCategory(category),
              selectedColor: _primaryColor.withOpacity(0.1), backgroundColor: Theme.of(context).chipTheme.backgroundColor ?? Colors.grey[100],
              labelStyle: GoogleFonts.poppins(color: isSelected ? _primaryColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSelected ? _primaryColor : (Theme.of(context).chipTheme.side?.color ?? Colors.grey[300]!), width: 1.5)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ));
        },
    )));
   }

  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
      print("Selected category: $category - Filtering not implemented.");
      // Call the controller's changeCategory method
      _controller.changeCategory(category == 'Tous' ? null : category);
    });
  }
}

// --- REMOVED Helper Functions LocALLY (Defined in producer_post_card.dart) ---
// // String _getVisualBadge(dynamic post) { ... }
// // Color _getPostTypeColor(dynamic post) { ... }
// // String _getPostTypeLabel(dynamic post) { ... }
// // String _formatTimestamp(DateTime timestamp) { ... }

