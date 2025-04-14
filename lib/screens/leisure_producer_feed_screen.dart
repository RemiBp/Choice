import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
import 'producerLeisure_screen.dart';
import 'profile_screen.dart';
import 'producer_messaging_screen.dart';

// Type de contenu pour le filtre des posts
enum LeisureFeedType {
  myEstablishment,  // Mes établissements
  clients,          // Mes clients
  leisureInspiration, // Inspiration loisirs
}

// Controller pour gérer le feed des producteurs de loisir
class LeisureFeedController extends ChangeNotifier {
  final String userId;
  final String producerId;
  
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Post> _posts = [];
  LeisureFeedType? _currentFilter;
  
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  List<Post> get posts => _posts;
  LeisureFeedType? get currentFilter => _currentFilter;
  
  LeisureFeedController({
    required this.userId,
    required this.producerId,
  });
  
  Future<void> loadFeed({LeisureFeedType? filter}) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    _currentFilter = filter;
    notifyListeners();
    
    try {
      // Appeler l'API en fonction du filtre
      _posts = await _fetchPosts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Erreur lors du chargement des posts: $e';
      notifyListeners();
    }
  }
  
  Future<void> refreshFeed() async {
    return loadFeed(filter: _currentFilter);
  }
  
  Future<List<Post>> _fetchPosts() async {
    String? userId = _apiService.userId;
    if (userId == null) return [];

    try {
      _isLoading = true;
      notifyListeners();
      
      List<dynamic> posts = [];
      
      if (_currentFilter == LeisureFeedType.clients) {
        // Retourner les posts des clients
        final result = await _apiService.getClientPosts(producerId);
        if (result is List<Post>) {
          posts = result;
        } else if (result is List<dynamic>) {
          posts = result.map((dynamic json) {
            if (json is Post) return json;
            if (json is Map<String, dynamic>) return Post.fromJson(json);
            throw Exception('Format inattendu pour un post: ${json.runtimeType}');
          }).toList();
        }
      } else if (_currentFilter == LeisureFeedType.leisureInspiration) {
        // Retourner les posts d'inspiration loisir
        final result = await _apiService.getLeisureInspirationPosts();
        if (result is List<Post>) {
          posts = result;
        } else if (result is List<dynamic>) {
          posts = result.map((dynamic json) {
            if (json is Post) return json;
            if (json is Map<String, dynamic>) return Post.fromJson(json);
            throw Exception('Format inattendu pour un post: ${json.runtimeType}');
          }).toList();
        }
      } else {
        // Par défaut, retourner les posts de l'établissement
        final result = await _apiService.getProducerPosts(producerId);
        if (result is List<Post>) {
          posts = result;
        } else if (result is List<dynamic>) {
          posts = result.map((dynamic json) {
            if (json is Post) return json;
            if (json is Map<String, dynamic>) return Post.fromJson(json);
            throw Exception('Format inattendu pour un post: ${json.runtimeType}');
          }).toList();
        }
      }
      
      _isLoading = false;
      notifyListeners();
      
      return posts.cast<Post>();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Erreur lors du chargement des posts: $e';
      notifyListeners();
      
      print('❌ Error fetching leisure posts: $e');
      return [];
    }
  }
  
  Future<void> likePost(Post post) async {
    try {
      await _apiService.likePost(post.id, userId);
      
      // Mettre à jour l'état local
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          isLiked: true,
          likesCount: (_posts[index].likesCount ?? 0) + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error liking post: $e');
    }
  }
  
  Future<void> markAsInterested(Post post) async {
    try {
      await _apiService.markAsInterested(post.id);
      
      // Mettre à jour l'état local
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          isInterested: true,
          interestedCount: (_posts[index].interestedCount ?? 0) + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking as interested: $e');
    }
  }
  
  Future<void> loadMore() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Simuler un délai d'API pour le chargement
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Charger plus de posts en fonction du filtre actuel
      final morePosts = await _fetchPosts();
      
      // Ajouter les nouveaux posts à la liste existante
      _posts.addAll(morePosts);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Erreur lors du chargement des posts: $e';
      notifyListeners();
    }
  }
  
  // Récupérer les interactions pour un post (likes, intérêts)
  Future<List<Map<String, dynamic>>> getPostInteractions(String postId, String interactionType) async {
    try {
      return await _apiService.getPostInteractions(postId, interactionType);
    } catch (e) {
      print('❌ Error fetching post interactions: $e');
      return [];
    }
  }
  
  // Récupérer les insights pour un post
  Future<Map<String, dynamic>> getProducerPostInsights(String producerId, String postId) async {
    try {
      return await _apiService.getProducerPostInsights(producerId, postId);
    } catch (e) {
      print('❌ Error fetching post insights: $e');
      return {};
    }
  }
}

enum FeedType {
  myVenue,
  visitorInteractions,
  events,
}

class LeisureProducerFeedScreen extends StatefulWidget {
  final String userId;

  const LeisureProducerFeedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _LeisureProducerFeedScreenState createState() => _LeisureProducerFeedScreenState();
}

class _LeisureProducerFeedScreenState extends State<LeisureProducerFeedScreen> with SingleTickerProviderStateMixin {
  late final LeisureFeedController _controller;
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  // Pour les vidéos
  final Map<String, VideoPlayerController> _videoControllers = {};
  String? _currentlyPlayingVideoId;
  
  // Catégories de loisirs et culture pour les filtres
  final List<String> _leisureCategories = [
    'Tous',
    'Art & Culture',
    'Musique',
    'Théâtre',
    'Cinéma',
    'Musée',
    'Exposition',
    'Sport',
    'Bien-être',
  ];
  
  String _selectedCategory = 'Tous';
  
  @override
  void initState() {
    super.initState();
    // Initialiser le contrôleur
    _controller = LeisureFeedController(userId: widget.userId, producerId: widget.userId);
    
    // Configurer le contrôleur de tabs
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Ajouter un écouteur de défilement pour la pagination
    _scrollController.addListener(_handleScroll);
    
    // Charger le contenu initial du feed
    _controller.loadFeed(filter: LeisureFeedType.myEstablishment);
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    
    LeisureFeedType newFilter;
    switch (_tabController.index) {
      case 0:
        newFilter = LeisureFeedType.myEstablishment;
        break;
      case 1:
        newFilter = LeisureFeedType.clients;
        break;
      case 2:
        newFilter = LeisureFeedType.leisureInspiration;
        break;
      default:
        newFilter = LeisureFeedType.myEstablishment;
    }
    
    _controller.loadFeed(filter: newFilter);
  }
  
  void _handleScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 && 
        !_controller.isLoading && 
        _controller.posts.isNotEmpty) {
      _controller.loadMore();
    }
  }
  
  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _controller.loadFeed(filter: _controller.currentFilter);
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
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
                      Icons.theater_comedy,
                      color: Colors.deepPurple,
                      size: 26,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Feed Loisirs & Culture',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.deepPurple),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProducerMessagingScreen(
                            producerId: widget.userId,
                            producerType: 'leisureProducer',
                          ),
                        ),
                      );
                    },
                    tooltip: 'Messages',
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple,
                  tabs: const [
                    Tab(text: 'Mon Lieu'),
                    Tab(text: 'Visiteurs'),
                    Tab(text: 'Événements'),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _leisureCategories.length,
                    itemBuilder: (context, index) {
                      final category = _leisureCategories[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          selectedColor: Colors.deepPurple.shade100,
                          onSelected: (_) => _changeCategory(category),
                          labelStyle: TextStyle(
                            color: _selectedCategory == category ? Colors.deepPurple : Colors.black87,
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
              if (_controller.isLoading && _controller.posts.isEmpty) {
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
                color: Colors.deepPurple,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  itemCount: _controller.posts.length + 
                    (_controller.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _controller.posts.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
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
        backgroundColor: Colors.deepPurple,
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
            color: Colors.deepPurple,
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
                backgroundColor: Colors.deepPurple,
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
        emptyMessage = 'Vous n\'avez pas encore publié de contenu sur votre établissement culturel.';
        emptyIcon = Icons.theater_comedy;
        break;
      case 1: // Visitor interactions
        emptyMessage = 'Aucune interaction récente avec vos visiteurs.';
        emptyIcon = Icons.people;
        break;
      case 2: // Events
        emptyMessage = 'Aucun événement à afficher pour le moment.';
        emptyIcon = Icons.event;
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
                backgroundColor: Colors.deepPurple,
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
    // Détecter si le post contient une vidéo
    final videoUrl = post.media.any((m) => m.type == 'video') 
        ? post.media.firstWhere((m) => m.type == 'video', orElse: () => media_model.Media(url: '', type: '')).url 
        : null;
    
    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (info) {
        if (videoUrl != null && videoUrl.isNotEmpty) {
          _handlePostVisibilityChanged(post.id, info.visibleFraction, videoUrl);
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
              onInterested: (post) => _showInterestedUsers(post), // Nouvelle fonction pour voir les utilisateurs intéressés
              onChoice: (_) {}, // Fonction vide car nous avons supprimé cette fonctionnalité
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
                          ? ProducerLeisureScreen(producerId: post.authorId ?? '')
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
            if (_tabController.index == 1) // Tab visiteurs
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
                        foregroundColor: Colors.purple,
                        side: BorderSide(color: Colors.purple.shade200),
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
                      color: Colors.deepPurple,
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
                      leading: Icon(Icons.photo, color: Colors.deepPurple),
                      title: Text('Photo'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création de post photo
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.videocam, color: Colors.deepPurple),
                      title: Text('Vidéo'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création de post vidéo
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.event, color: Colors.deepPurple),
                      title: Text('Nouvel événement'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création d'événement
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.art_track, color: Colors.deepPurple),
                      title: Text('Nouvelle exposition'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création d'exposition
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.local_activity, color: Colors.deepPurple),
                      title: Text('Promotion'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création de promotion
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.music_note, color: Colors.deepPurple),
                      title: Text('Concert/Spectacle'),
                      onTap: () {
                        Navigator.pop(context);
                        // Naviguer vers l'écran de création de concert
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
