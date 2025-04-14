import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/feed/post_card.dart';
import '../controllers/feed_controller.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';
import 'producer_screen.dart';

class RestaurantFeedScreen extends StatefulWidget {
  final String userId;
  
  const RestaurantFeedScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<RestaurantFeedScreen> createState() => _RestaurantFeedScreenState();
}

class _RestaurantFeedScreenState extends State<RestaurantFeedScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  late FeedController _feedController;
  late TabController _tabController;
  
  // Catégories culinaires pour les filtres
  final List<String> _cuisineCategories = [
    'Tous',
    'Français',
    'Italien',
    'Asiatique',
    'Végétarien',
    'Fast Food',
    'Desserts',
    'Cafés',
  ];
  
  String _selectedCategory = 'Tous';
  
  @override
  void initState() {
    super.initState();
    _feedController = FeedController(userId: widget.userId);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    _scrollController.addListener(_handleScroll);
    
    // Charger le feed initial des restaurants
    _feedController.filterFeed(FeedContentType.restaurants);
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    
    switch (_tabController.index) {
      case 0: // Populaires
        // Filtrer par popularité (déjà géré par le backend)
        _refreshFeed();
        break;
      case 1: // Récents
        // Filtrer par date
        _refreshFeed();
        break;
      case 2: // Suivis
        // Filtrer uniquement les restaurants suivis
        _refreshFeed();
        break;
    }
  }
  
  void _handleScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 && 
        !_feedController.isLoadingMore && 
        _feedController.hasMorePosts) {
      _feedController.loadMorePosts();
    }
  }
  
  Future<void> _refreshFeed() async {
    if (!mounted) return;
    
    try {
      await _feedController.loadInitialFeed();
    } catch (e) {
      print('❌ Erreur lors du rafraîchissement du feed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement. Veuillez réessayer.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  void _handlePostLike(Post post) {
    if (!mounted) return;
    _feedController.handlePostInteraction(post.id, 'like');
  }
  
  void _handlePostInterested(Post post) {
    if (!mounted) return;
    _feedController.handlePostInteraction(post.id, 'interested');
  }
  
  void _onPostTap(Post post) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: post.id),
      ),
    );
  }
  
  void _onUserTap(Post post) {
    if (!mounted) return;
    if (post.isProducerPost) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerScreen(producerId: post.authorId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: post.authorId),
        ),
      );
    }
  }
  
  // Changer la catégorie sélectionnée
  void _changeCategory(String category) {
    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
    });
    _refreshFeed();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                title: Row(
                  children: [
                    Icon(
                      Icons.restaurant,
                      color: Colors.orange,
                      size: 26,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Restaurants',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                floating: true,
                pinned: true,
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.orange,
                  tabs: [
                    Tab(text: 'Populaires'),
                    Tab(text: 'Récents'),
                    Tab(text: 'Suivis'),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cuisineCategories.length,
                    itemBuilder: (context, index) {
                      final category = _cuisineCategories[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          selectedColor: Colors.orange.shade100,
                          onSelected: (_) => _changeCategory(category),
                          labelStyle: TextStyle(
                            color: _selectedCategory == category ? Colors.orange : Colors.black87,
                            fontWeight: _selectedCategory == category ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ];
          },
          body: AnimatedBuilder(
            animation: _feedController,
            builder: (context, child) {
              if (_feedController.isLoadingMore && _feedController.posts.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                );
              }
              
              if (_feedController.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.orange.shade300,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Problème de connexion',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          _feedController.errorMessage.isEmpty 
                              ? 'Impossible de se connecter au serveur. Vérifiez votre connexion internet et réessayez.'
                              : _feedController.errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _refreshFeed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }
              
              if (_feedController.posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aucun post de restaurant disponible',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshFeed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text('Actualiser'),
                      ),
                    ],
                  ),
                );
              }
              
              return RefreshIndicator(
                key: _refreshIndicatorKey,
                onRefresh: _refreshFeed,
                color: Colors.orange,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _feedController.posts.length + (_feedController.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _feedController.posts.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                      );
                    }
                    
                    final post = _feedController.posts[index];
                    return PostCard(
                      post: post,
                      onLike: _handlePostLike,
                      onInterested: _handlePostInterested,
                      onChoice: (post) {}, // Fonction vide car nous avons supprimé cette fonctionnalité
                      onCommentTap: _onPostTap,
                      onUserTap: () => _onUserTap(post),
                      onShare: (post) {},
                      onSave: (post) {},
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
} 