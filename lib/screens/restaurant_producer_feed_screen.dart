import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:animations/animations.dart';
import '../models/post.dart';
import '../models/media.dart' as media_model;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../controllers/feed_controller.dart';
import '../widgets/feed/post_card.dart';
import 'post_detail_screen.dart';
import 'producer_screen.dart';
import 'profile_screen.dart';
import 'producer_messaging_screen.dart';

class RestaurantProducerFeedScreen extends StatefulWidget {
  final String userId;

  const RestaurantProducerFeedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _RestaurantProducerFeedScreenState createState() => _RestaurantProducerFeedScreenState();
}

class _RestaurantProducerFeedScreenState extends State<RestaurantProducerFeedScreen> with SingleTickerProviderStateMixin {
  late final RestaurantFeedController _controller;
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  // Pour les vidéos
  final Map<String, VideoPlayerController> _videoControllers = {};
  String? _currentlyPlayingVideoId;
  
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
    // Initialiser le contrôleur
    _controller = RestaurantFeedController(userId: widget.userId);
    
    // Configurer le contrôleur de tabs
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Ajouter un écouteur de défilement pour la pagination
    _scrollController.addListener(_handleScroll);
    
    // Charger le contenu initial du feed
    _controller.loadFeed(filter: FeedType.myRestaurant);
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    
    FeedType newFilter;
    switch (_tabController.index) {
      case 0:
        newFilter = FeedType.myRestaurant;
        break;
      case 1:
        newFilter = FeedType.customerInteractions;
        break;
      case 2:
        newFilter = FeedType.localTrends;
        break;
      default:
        newFilter = FeedType.myRestaurant;
    }
    
    _controller.filterFeed(newFilter);
  }
  
  void _handleScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 && 
        !_controller.isLoadingMore && 
        _controller.hasMorePosts) {
      _controller.loadMore();
    }
  }
  
  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _controller.setCuisineFilter(category);
    _controller.refreshFeed();
  }
  
  // Initialiser un contrôleur de vidéo pour un post spécifique
  Future<void> _initializeVideoController(String postId, String videoUrl) async {
    if (_videoControllers.containsKey(postId)) {
      return;
    }
    
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[postId] = controller;
      
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0.0); // Muet par défaut
      
      // Lecture automatique uniquement si ce post est actuellement visible
      if (_currentlyPlayingVideoId == postId) {
        controller.play();
      }
      
      // S'assurer que le widget se reconstruit après l'initialisation du contrôleur
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du contrôleur vidéo: $e');
    }
  }
  
  // Gérer les changements de visibilité des posts pour la lecture automatique des vidéos
  void _handlePostVisibilityChanged(String postId, double visibleFraction, String? videoUrl) {
    if (videoUrl == null) return;
    
    if (visibleFraction > 0.7) {
      // Le post est principalement visible, lire sa vidéo
      if (_currentlyPlayingVideoId != postId) {
        // Mettre en pause la vidéo actuelle
        if (_currentlyPlayingVideoId != null && 
            _videoControllers.containsKey(_currentlyPlayingVideoId)) {
          _videoControllers[_currentlyPlayingVideoId]!.pause();
        }
        
        // Définir la nouvelle vidéo en cours de lecture
        _currentlyPlayingVideoId = postId;
        
        // Initialiser et lire la vidéo si nécessaire
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
      // Le post est à peine visible, mettre en pause sa vidéo
      _videoControllers[postId]!.pause();
      _currentlyPlayingVideoId = null;
    }
  }
  
  // Nouvelle méthode pour afficher un dialogue avec les utilisateurs intéressés
  void _showInterestedUsers(Post post) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _controller.getPostInteractions(post.id, 'interest'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              title: Text('Utilisateurs intéressés'),
              content: Container(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return AlertDialog(
              title: Text('Erreur'),
              content: Text('Impossible de charger les utilisateurs intéressés.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
                ),
              ],
            );
          } else {
            final users = snapshot.data ?? [];
            return AlertDialog(
              title: Text('Utilisateurs intéressés (${users.length})'),
              content: Container(
                width: double.maxFinite,
                child: users.isEmpty
                    ? Center(child: Text('Aucun utilisateur intéressé pour le moment.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                user['photo_url'] ?? 'https://api.dicebear.com/6.x/adventurer/png?seed=${user['_id']}'
                              ),
                            ),
                            title: Text(user['name'] ?? 'Utilisateur'),
                            subtitle: Text(user['timestamp'] != null 
                                ? 'Intéressé le ${_formatDate(user['timestamp'])}'
                                : 'Intéressé récemment'),
                            onTap: () {
                              // Naviguer vers le profil utilisateur
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(userId: user['_id']),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
                ),
              ],
            );
          }
        },
      ),
    );
  }
  
  // Afficher les utilisateurs qui ont liké un post
  void _showLikedByUsers(Post post) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _controller.getPostInteractions(post.id, 'like'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              title: Text('J\'aime'),
              content: Container(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return AlertDialog(
              title: Text('Erreur'),
              content: Text('Impossible de charger les j\'aime.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
                ),
              ],
            );
          } else {
            final users = snapshot.data ?? [];
            return AlertDialog(
              title: Text('J\'aime (${users.length})'),
              content: Container(
                width: double.maxFinite,
                child: users.isEmpty
                    ? Center(child: Text('Aucun j\'aime pour le moment.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                user['photo_url'] ?? 'https://api.dicebear.com/6.x/adventurer/png?seed=${user['_id']}'
                              ),
                            ),
                            title: Text(user['name'] ?? 'Utilisateur'),
                            subtitle: Text(user['timestamp'] != null 
                                ? 'Aimé le ${_formatDate(user['timestamp'])}'
                                : 'Aimé récemment'),
                            onTap: () {
                              // Naviguer vers le profil utilisateur
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(userId: user['_id']),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
                ),
              ],
            );
          }
        },
      ),
    );
  }
  
  // Afficher les insights pour un post
  void _showPostInsights(Post post) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: _controller.getProducerPostInsights(widget.userId, post.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              title: Text('Statistiques du post'),
              content: Container(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return AlertDialog(
              title: Text('Erreur'),
              content: Text('Impossible de charger les statistiques.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
                ),
              ],
            );
          } else {
            final insights = snapshot.data ?? {};
            return AlertDialog(
              title: Text('Statistiques du post'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInsightTile('Impressions', insights['impressions'] ?? 0),
                    _buildInsightTile('Portée', insights['reach'] ?? 0),
                    _buildInsightTile('Engagement', '${insights['engagement_rate'] ?? 0}%'),
                    _buildInsightTile('Clics sur le profil', insights['profile_clicks'] ?? 0),
                    _buildInsightTile('Visiteurs', insights['visitors'] ?? 0),
                    SizedBox(height: 16),
                    Text(
                      'Performance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (insights['performance_score'] ?? 0) / 100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getPerformanceColor(insights['performance_score'] ?? 0),
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${insights['performance_score'] ?? 0}/100',
                      style: TextStyle(
                        color: _getPerformanceColor(insights['performance_score'] ?? 0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
                ),
              ],
            );
          }
        },
      ),
    );
  }
  
  Widget _buildInsightTile(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getPerformanceColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
  
  // Formater une date pour l'affichage
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays < 1) {
        if (difference.inHours < 1) {
          return 'il y a ${difference.inMinutes} min';
        }
        return 'il y a ${difference.inHours} h';
      } else if (difference.inDays < 7) {
        return 'il y a ${difference.inDays} j';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'date inconnue';
    }
  }
  
  @override
  void dispose() {
    // Nettoyer les contrôleurs de vidéo
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    
    _tabController.dispose();
    _scrollController.dispose();
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
                floating: true,
                pinned: true,
                title: Row(
                  children: [
                    Icon(
                      Icons.restaurant,
                      color: Colors.orange,
                      size: 26,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Feed Restaurant',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.orange),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProducerMessagingScreen(
                            producerId: widget.userId,
                            producerType: 'restaurant',
                          ),
                        ),
                      );
                    },
                    tooltip: 'Messages',
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.orange,
                  tabs: const [
                    Tab(text: 'Mon Restaurant'),
                    Tab(text: 'Clients'),
                    Tab(text: 'Tendances'),
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
            animation: _controller,
            builder: (context, child) {
              if (_controller.isLoadingMore && _controller.posts.isEmpty) {
                return _buildLoadingView();
              }
              
              if (_controller.hasError) {
                return _buildErrorView();
              }
              
              if (_controller.posts.isEmpty) {
                return _buildEmptyView();
              }
              
              return RefreshIndicator(
                onRefresh: () => _controller.refreshFeed(),
                color: Colors.orange,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  itemCount: _controller.posts.length + 
                    (_controller.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _controller.posts.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                      );
                    }
                    
                    final post = _controller.posts[index];
                    return _buildPostCard(post);
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Afficher une modale de création de post
          _showCreatePostModal();
        },
        backgroundColor: Colors.orange,
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
            color: Colors.orange,
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
                backgroundColor: Colors.orange,
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
      case 0: // Restaurant posts
        emptyMessage = 'Vous n\'avez pas encore publié de contenu sur votre restaurant.';
        emptyIcon = Icons.restaurant;
        break;
      case 1: // Customer interactions
        emptyMessage = 'Aucune interaction récente avec vos clients.';
        emptyIcon = Icons.people;
        break;
      case 2: // Local trends
        emptyMessage = 'Aucune tendance locale à afficher pour le moment.';
        emptyIcon = Icons.trending_up;
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
            ElevatedButton(
              onPressed: () {
                _showCreatePostModal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Créer votre première publication'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPostCard(Post post) {
    // Corriger la vérification du type de média
    final String thumbnailUrl = post.metadata?['mediaType'] == 'video' 
        ? post.imageUrl ?? ''
        : post.imageUrl ?? '';
    
    // Alternative en fonction des metadata
    final bool isVideo = post.metadata?['mediaType'] == 'video' || 
        post.metadata?['type'] == 'video' ||
        (post.imageUrl?.toLowerCase().endsWith('.mp4') ?? false);
    
    // Si nécessaire, utiliser
    final String mediaType = post.metadata?['mediaType'] ?? post.metadata?['type'] ?? 'image';
    
    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (info) {
        if (thumbnailUrl.isNotEmpty) {
          _handlePostVisibilityChanged(post.id, info.visibleFraction, thumbnailUrl);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostCard(
              post: post,
              onLike: (post) => _controller.likePost(post),
              onInterested: (post) => _showInterestedUsers(post),
              onChoice: (_) {},
              onCommentTap: (post) {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(
                      postId: post.id,
                      userId: widget.userId,
                    ),
                  )
                );
              },
              onUserTap: () {
                if (post.authorId?.isNotEmpty == true) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => (post.isProducerPost ?? false)
                          ? ProducerScreen(producerId: post.authorId ?? '')
                          : ProfileScreen(userId: post.authorId ?? ''),
                    ),
                  );
                }
              },
              onShare: (post) {
                // Implémenter partage
              },
              onSave: (post) {
                // Implémenter sauvegarde
              },
            ),
            // Ajouter des boutons d'action pour les producteurs
            if (_tabController.index == 1) // Tab clients
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(Icons.favorite, size: 16),
                      label: Text('J\'aime', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showLikedByUsers(post),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.remove_red_eye, size: 16),
                      label: Text('Insights', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showPostInsights(post),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue.shade200),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.interests, size: 16),
                      label: Text('Intérêts', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showInterestedUsers(post),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green.shade200),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Créer une publication',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: Icon(Icons.photo, color: Colors.orange),
                      title: Text('Photo'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création de post photo
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.videocam, color: Colors.orange),
                      title: Text('Vidéo'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création de post vidéo
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.menu_book, color: Colors.orange),
                      title: Text('Nouveau plat du menu'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran d'ajout de plat
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.event, color: Colors.orange),
                      title: Text('Événement'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création d'événement
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.local_offer, color: Colors.orange),
                      title: Text('Promotion'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création de promotion
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RestaurantFeedController extends ChangeNotifier {
  final String userId;
  final ApiService _apiService = ApiService();
  bool isLoadingMore = false;
  bool hasMorePosts = true;
  FeedType currentFilter = FeedType.myRestaurant;
  String currentCategory = 'Tous';
  
  // Ajouter les propriétés manquantes
  List<Post> _posts = [];
  List<Post> get posts => _posts;
  
  bool _hasError = false;
  bool get hasError => _hasError;
  
  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  
  RestaurantFeedController({required this.userId});
  
  Future<List<Post>> loadFeed({FeedType filter = FeedType.myRestaurant}) async {
    isLoadingMore = true;
    _hasError = false;
    currentFilter = filter;
    notifyListeners();
    
    try {
      final dynamic result = await _apiService.getRestaurantPosts(userId, page: 1, limit: 10);
      
      // Reset _posts et hasMorePosts
      _posts = [];
      hasMorePosts = false;
      
      if (result is Map<String, dynamic>) {
        // Format Map avec une propriété 'posts'
        if (result.containsKey('posts')) {
          final dynamic postsData = result['posts'];
          if (postsData is List) {
            _posts = _extractPosts(postsData);
          }
        }
        
        // Vérification de la propriété 'hasMore'
        if (result.containsKey('hasMore')) {
          final dynamic hasMoreData = result['hasMore'];
          hasMorePosts = hasMoreData is bool ? hasMoreData : false;
        } else {
          hasMorePosts = _posts.length >= 10;
        }
      } 
      else if (result is List) {
        // Format Liste directe
        _posts = _extractPosts(result);
        hasMorePosts = result.length >= 10;
      }
      
      isLoadingMore = false;
      notifyListeners();
      return _posts;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      isLoadingMore = false;
      notifyListeners();
      print('❌ Error loading restaurant feed: $e');
      return [];
    }
  }
  
  Future<void> refreshFeed() async {
    try {
      final dynamic result = await _apiService.getRestaurantPosts(userId, page: 1, limit: 10);
      
      // Reset _posts et hasMorePosts
      _posts = [];
      hasMorePosts = false;
      
      if (result is Map<String, dynamic>) {
        // Format Map avec une propriété 'posts'
        if (result.containsKey('posts')) {
          final dynamic postsData = result['posts'];
          if (postsData is List) {
            _posts = _extractPosts(postsData);
          }
        }
        
        // Vérification de la propriété 'hasMore'
        if (result.containsKey('hasMore')) {
          final dynamic hasMoreData = result['hasMore'];
          hasMorePosts = hasMoreData is bool ? hasMoreData : false;
        } else {
          hasMorePosts = _posts.length >= 10;
        }
      } 
      else if (result is List) {
        // Format Liste directe
        _posts = _extractPosts(result);
        hasMorePosts = result.length >= 10;
      }
      
      _hasError = false;
      notifyListeners();
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      notifyListeners();
      print('❌ Error refreshing restaurant feed: $e');
    }
  }
  
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMorePosts) return;
    
    isLoadingMore = true;
    notifyListeners();
    
    try {
      final dynamic result = await _apiService.getRestaurantPosts(userId, page: _posts.length ~/ 10 + 1, limit: 10);
      
      List<Post> newPosts = [];
      
      if (result is Map<String, dynamic>) {
        // Format Map avec une propriété 'posts'
        if (result.containsKey('posts')) {
          final dynamic postsData = result['posts'];
          if (postsData is List) {
            newPosts = _extractPosts(postsData);
            _posts.addAll(newPosts);
          }
        }
        
        // Vérification de la propriété 'hasMore'
        if (result.containsKey('hasMore')) {
          final dynamic hasMoreData = result['hasMore'];
          hasMorePosts = hasMoreData is bool ? hasMoreData : false;
        } else {
          hasMorePosts = newPosts.length >= 10;
        }
      } 
      else if (result is List) {
        // Format Liste directe
        newPosts = _extractPosts(result);
        _posts.addAll(newPosts);
        hasMorePosts = newPosts.length >= 10;
      }
      
      isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      isLoadingMore = false;
      notifyListeners();
      print('❌ Error loading more restaurant posts: $e');
    }
  }

  void filterFeed(FeedType filter) {
    if (currentFilter == filter) return;
    currentFilter = filter;
    loadFeed(filter: filter);
  }
  
  void setCuisineFilter(String category) {
    currentCategory = category;
    refreshFeed();
  }
  
  Future<void> likePost(Post post) async {
    final int index = _posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;
    
    final oldPost = _posts[index];
    final bool isCurrentlyLiked = oldPost.isLiked ?? false;
    final int currentLikes = oldPost.likesCount ?? 0;
    
    // Mise à jour optimiste
    _posts[index] = oldPost.copyWith(
      isLiked: !isCurrentlyLiked,
      likesCount: isCurrentlyLiked ? 
          (currentLikes > 0 ? currentLikes - 1 : 0) : 
          currentLikes + 1,
    );
    notifyListeners();
    
    try {
      await _apiService.toggleLike(userId, post.id);
    } catch (e) {
      // Revenir en arrière en cas d'erreur
      _posts[index] = oldPost;
      notifyListeners();
      print('❌ Error liking post: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getPostInteractions(String postId, String interactionType) async {
    try {
      return await _apiService.getPostInteractions(postId, interactionType);
    } catch (e) {
      print('❌ Error fetching post interactions: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> getProducerPostInsights(String producerId, String postId) async {
    try {
      return await _apiService.getProducerPostInsights(producerId, postId);
    } catch (e) {
      print('❌ Error fetching post insights: $e');
      return {};
    }
  }

  // Extraire les posts d'une liste de données
  List<Post> _extractPosts(List<dynamic> items) {
    List<Post> posts = [];
    
    for (final item in items) {
      if (item is Post) {
        posts.add(item);
      } else if (item is Map<String, dynamic>) {
        try {
          posts.add(Post.fromJson(item));
        } catch (e) {
          print('❌ Erreur lors de la conversion d\'un post: $e');
        }
      }
    }
    
    return posts;
  }
}

enum FeedType {
  myRestaurant,
  customerInteractions,
  localTrends
} 