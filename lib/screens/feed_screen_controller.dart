import 'package:flutter/material.dart';
import 'dart:math';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/dialogic_ai_feed_service.dart';
import 'dart:async';
import '../services/user_service.dart';
import '../services/analytics_service.dart';
import '../models/media.dart' as app_media;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart' as constants;
import 'dart:convert' as json;
import 'dart:convert' as convert;

enum FeedContentType {
  all,
  restaurants,
  leisure,
  wellness,
  userPosts,
  aiDialogic,
}

enum FeedLoadState {
  idle,
  loading,
  loaded,
  loadingMore,
  error,
}

class FeedResult {
  final List<Post> posts;
  final bool hasMore;
  
  FeedResult({
    required this.posts,
    required this.hasMore,
  });
}

class FeedScreenController extends ChangeNotifier {
  final String userId;
  final ApiService _apiService = ApiService();
  final DialogicAIFeedService _dialogicService = DialogicAIFeedService();
  final UserService _userService = UserService();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  final ScrollController scrollController = ScrollController();
  bool _isRefreshing = false;
  bool _hasMore = true;
  bool _isInitialized = false;
  
  List<dynamic> _feedItems = [];
  List<dynamic> get feedItems => _feedItems;
  
  // Variables pour gérer l'état du chargement
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  FeedLoadState _loadState = FeedLoadState.idle;
  FeedLoadState get loadState => _loadState;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  int _currentPage = 1;
  final int _postsPerPage = 10;
  bool _hasMorePosts = true;
  bool get hasMorePosts => _hasMorePosts;

  FeedContentType _currentFilter = FeedContentType.all;
  FeedContentType get currentFilter => _currentFilter;

  // Track recently viewed posts for AI contextual messages
  final List<dynamic> _recentlyViewedPosts = [];
  final List<String> _recentInteractions = [];

  // Controls how often AI messages appear in the feed
  final int _aiMessageFrequency = 5; // Show AI message every X posts
  int _postsSinceLastAiMessage = 0;

  // Maps pour la gestion des différents types de contenu
  final Map<FeedContentType, List<Post>> _feedItemsByType = {
    FeedContentType.all: [],
    FeedContentType.restaurants: [],
    FeedContentType.leisure: [],
    FeedContentType.wellness: [],
    FeedContentType.userPosts: [],
  };
  
  final Map<FeedContentType, int> _currentPageByType = {
    FeedContentType.all: 1,
    FeedContentType.restaurants: 1,
    FeedContentType.leisure: 1,
    FeedContentType.wellness: 1,
    FeedContentType.userPosts: 1,
  };
  
  final Map<FeedContentType, bool> _hasMorePostsByType = {
    FeedContentType.all: true,
    FeedContentType.restaurants: true,
    FeedContentType.leisure: true,
    FeedContentType.wellness: true,
    FeedContentType.userPosts: true,
  };

  List<Post> _posts = [];
  List<Post> get posts => _posts;

  FeedScreenController({required this.userId});

  /// Initial load of feed content
  Future<void> loadFeed() async {
    if (_loadState == FeedLoadState.loading) return;
    
    _loadState = FeedLoadState.loading;
    _currentPage = 1;
    _feedItems = [];
    _errorMessage = null;
    notifyListeners();
    
    try {
      print('🔄 Chargement du feed pour l\'utilisateur $userId (page $_currentPage)');
      
      // Appel réel à l'API selon le filtre sélectionné
      List<dynamic> posts = [];
      
      switch (_currentFilter) {
        case FeedContentType.restaurants:
          final restaurantPosts = await _apiService.getRestaurantPosts(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          posts = restaurantPosts;
          print('🍔 ${posts.length} posts de restaurants chargés');
          break;
          
        case FeedContentType.leisure:
          final leisurePosts = await _apiService.getLeisurePosts(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          posts = leisurePosts;
          print('🎮 ${posts.length} posts de loisirs chargés');
          break;
          
        case FeedContentType.wellness:
          final wellnessPosts = await _apiService.getWellnessPosts(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          posts = wellnessPosts;
          print('💆 ${posts.length} posts de bien-être chargés');
          break;
          
        case FeedContentType.userPosts:
          final userPosts = await _apiService.getUserPosts(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          posts = userPosts;
          print('👤 ${posts.length} posts d\'utilisateurs chargés');
          break;
          
        case FeedContentType.all:
        default:
          // Feed général
          final feedPosts = await _apiService.getPostsForFeed(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          posts = feedPosts;
          print('📱 ${posts.length} posts généraux chargés');
          
          // Ajouter un message AI si nécessaire
          if (posts.isNotEmpty) {
            _insertAiMessageIfNeeded(posts);
          }
          break;
      }
      
      _feedItems = posts;
      _hasMorePosts = posts.length >= _postsPerPage;
      _loadState = FeedLoadState.loaded;
      
    } catch (e) {
      print('❌ Erreur lors du chargement du feed: $e');
      _loadState = FeedLoadState.error;
      _errorMessage = e.toString();
    }
    
    notifyListeners();
  }

  /// Load more content when scrolling
  Future<void> loadMore() async {
    if (_loadState == FeedLoadState.loadingMore || 
        _loadState == FeedLoadState.loading ||
        !_hasMorePosts) {
      return;
    }
    
    _loadState = FeedLoadState.loadingMore;
    notifyListeners();
    
    try {
      print('🔄 Chargement de plus de contenu pour l\'utilisateur $userId (page ${_currentPage + 1})');
      
      // Appel réel à l'API pour charger plus de contenu
      List<dynamic> morePosts = [];
      final nextPage = _currentPage + 1;
      
      switch (_currentFilter) {
        case FeedContentType.restaurants:
          final restaurantPosts = await _apiService.getRestaurantPosts(
            userId,
            page: nextPage,
            limit: _postsPerPage
          );
          morePosts = restaurantPosts;
          break;
          
        case FeedContentType.leisure:
          final leisurePosts = await _apiService.getLeisurePosts(
            userId,
            page: nextPage,
            limit: _postsPerPage
          );
          morePosts = leisurePosts;
          break;
          
        case FeedContentType.wellness:
          final wellnessPosts = await _apiService.getWellnessPosts(
            userId,
            page: nextPage,
            limit: _postsPerPage
          );
          morePosts = wellnessPosts;
          break;
          
        case FeedContentType.userPosts:
          final userPosts = await _apiService.getUserPosts(
            userId,
            page: nextPage,
            limit: _postsPerPage
          );
          morePosts = userPosts;
          break;
          
        case FeedContentType.all:
        default:
          final feedPosts = await _apiService.getPostsForFeed(
            userId,
            page: nextPage,
            limit: _postsPerPage
          );
          morePosts = feedPosts;
          break;
      }
      
      if (morePosts.isNotEmpty) {
        _feedItems.addAll(morePosts);
        _currentPage = nextPage;
        _hasMorePosts = morePosts.length >= _postsPerPage;
      } else {
        _hasMorePosts = false;
      }
      
      _loadState = FeedLoadState.loaded;
    } catch (e) {
      print('❌ Erreur lors du chargement de plus de contenu: $e');
      _loadState = FeedLoadState.error;
      _errorMessage = e.toString();
    }
    
    notifyListeners();
  }

  /// Add a view to recently viewed posts for context
  void trackPostView(dynamic post) {
    // Implement tracking logic
  }

  /// Track user interactions for AI context
  void trackInteraction(String interactionType, String targetId) {
    _recentInteractions.add('$interactionType:$targetId');
    if (_recentInteractions.length > 20) {
      _recentInteractions.removeAt(0);
    }
  }

  /// Handle like interaction for both Post objects and Map posts
  Future<void> likePost(dynamic postData) async {
    if (postData is Post) {
      // Handle Post object
      final int index = _findPostIndex(postData);
      
      if (index != -1) {
        // Get current state
        final bool isCurrentlyLiked = postData.isLiked ?? false;
        final int currentLikes = postData.likesCount ?? 0;
        
        // Optimistic update - toggle like state
        final updatedPost = postData.copyWith(
          isLiked: !isCurrentlyLiked,
          likesCount: isCurrentlyLiked 
              ? (currentLikes > 0 ? currentLikes - 1 : 0) 
              : currentLikes + 1,
        );
        
        _feedItems[index] = updatedPost;
        notifyListeners();
        
        // Track this interaction
        trackInteraction('like', postData.id);
        
        try {
          // Call API to update backend
          await _apiService.toggleLike(userId, postData.id);
        } catch (e) {
          print('❌ Error liking post: $e');
          // Revert on error
          _feedItems[index] = postData;
          notifyListeners();
        }
      }
    } else if (postData is Map<String, dynamic>) {
      // Handle Map-based post
      final String postId = postData['_id'] ?? '';
      final int index = _findPostIndex(postData);
      
      if (index != -1 && postId.isNotEmpty) {
        // Get current state
        final bool isCurrentlyLiked = postData['isLiked'] == true;
        final int currentLikes = 
            postData['likes_count'] ?? 
            postData['likesCount'] ?? 
            (postData['likes'] is List ? (postData['likes'] as List).length : 0);
        
        // Optimistic update
        final Map<String, dynamic> updatedPost = Map.from(postData);
        updatedPost['isLiked'] = !isCurrentlyLiked;
        updatedPost['likes_count'] = isCurrentlyLiked 
            ? (currentLikes > 0 ? currentLikes - 1 : 0) 
            : currentLikes + 1;
        updatedPost['likesCount'] = updatedPost['likes_count']; // Sync both fields
        
        _feedItems[index] = updatedPost;
        notifyListeners();
        
        // Track this interaction
        trackInteraction('like', postId);
        
        try {
          // Call API to update backend
          await _apiService.toggleLike(userId, postId);
        } catch (e) {
          print('❌ Error liking post: $e');
          // Revert on error
          _feedItems[index] = postData;
          notifyListeners();
        }
      }
    }
  }

  /// Handle interest interaction
  Future<void> markInterested(String targetId, dynamic postData, {bool isLeisureProducer = false}) async {
    try {
      // Find the post in the feed
      final int index = _findPostIndex(postData);
      if (index == -1) return;
      
      // Call API
      final success = await _apiService.markInterested(
        userId, 
        targetId,
        isLeisureProducer: isLeisureProducer
      );
      
      if (success) {
        // Update local state based on post type
        if (_feedItems[index] is Post) {
          final post = _feedItems[index] as Post;
          final bool isCurrentlyInterested = post.isInterested ?? false;
          final int interestCountVal = post.interestedCount ?? 0;
          
          _feedItems[index] = post.copyWith(
            isInterested: !isCurrentlyInterested,
            interestedCount: isCurrentlyInterested
                ? (interestCountVal > 0 ? interestCountVal - 1 : 0)
                : interestCountVal + 1,
          );
        } else if (_feedItems[index] is Map<String, dynamic>) {
          final map = _feedItems[index] as Map<String, dynamic>;
          final bool isCurrentlyInterested = map['interested'] == true || map['isInterested'] == true;
          final int currentCount = map['interested_count'] ?? map['interestedCount'] ?? 0;
          
          map['interested'] = !isCurrentlyInterested;
          map['isInterested'] = !isCurrentlyInterested; // Sync both fields
          map['interested_count'] = isCurrentlyInterested 
              ? (currentCount > 0 ? currentCount - 1 : 0)
              : currentCount + 1;
          map['interestedCount'] = map['interested_count']; // Sync both fields
        }
        
        // Track interaction
        trackInteraction('interest', targetId);
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking interested: $e');
    }
  }

  /// Handle choice interaction
  Future<void> markChoice(String targetId, dynamic postData, {bool isLeisureProducer = false}) async {
    try {
      // Find the post in the feed
      final int index = _findPostIndex(postData);
      if (index == -1) return;
      
      // Call API
      final success = await _apiService.markChoice(userId, targetId);
      
      if (success) {
        // Update local state based on post type
        if (_feedItems[index] is Post) {
          final post = _feedItems[index] as Post;
          final bool isCurrentlyChoice = post.isChoice ?? false;
          
          _feedItems[index] = post.copyWith(
            isChoice: !isCurrentlyChoice,
          );
        } else if (_feedItems[index] is Map<String, dynamic>) {
          final map = _feedItems[index] as Map<String, dynamic>;
          final bool isCurrentlyChoice = map['choice'] == true || map['isChoice'] == true;
          final int currentCount = map['choice_count'] ?? map['choiceCount'] ?? 0;
          
          map['choice'] = !isCurrentlyChoice;
          map['isChoice'] = !isCurrentlyChoice; // Sync both fields
          map['choice_count'] = isCurrentlyChoice 
              ? (currentCount > 0 ? currentCount - 1 : 0)
              : currentCount + 1;
          map['choiceCount'] = map['choice_count']; // Sync both fields
        }
        
        // Track interaction
        trackInteraction('choice', targetId);
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking choice: $e');
    }
  }

  /// Handle AI message interaction
  Future<DialogicAIMessage> interactWithAiMessage(String userResponse) async {
    try {
      final aiResponse = await _dialogicService.getResponseToUserInteraction(
        userId, 
        userResponse
      );
      
      // Track interaction
      trackInteraction('ai_interaction', userResponse);
      
      return aiResponse;
    } catch (e) {
      print('❌ Error interacting with AI: $e');
      return DialogicAIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Je suis désolé, je n'ai pas pu traiter votre demande.",
        isInteractive: true,
        suggestions: ["Essayer à nouveau", "Voir des recommandations"],
      );
    }
  }

  /// Set user mood for emotional recommendations
  Future<List<String>> setUserMood(String mood) async {
    try {
      return await _dialogicService.getEmotionalRecommendations(mood);
    } catch (e) {
      print('❌ Error setting mood: $e');
      return [];
    }
  }

  /// Filter feed content
  void filterFeed(FeedContentType filter) {
    if (_currentFilter == filter) return;
    
    _currentFilter = filter;
    loadFeed();
  }

  /// Refresh feed content
  Future<void> refreshFeed() async {
    return loadFeed();
  }

  // Private methods

  /// Fetch content based on current filter
  Future<void> _fetchFeedContent({bool isLoadingMore = false}) async {
    try {
      // Si nous sommes en train de récupérer des posts et que ce n'est pas un chargement supplémentaire ("load more")
      if (!isLoadingMore) {
        // Réinitialiser l'état pour un nouveau chargement
        _postsSinceLastAiMessage = 0;
      }
      
      // Paramètres de l'API
      final Map<String, dynamic> apiParams = {
        'page': _currentPage,
        'limit': _postsPerPage,
        'variety': 'high',    // Demander plus de variété
        'includeUsers': true, // Inclure les posts des utilisateurs
        'includeAll': true,   // Demander tous les types de posts
      };
      
      // Récupérer les posts depuis l'API
      List<Post> newPosts = [];
      
      // En fonction du filtre, utiliser différentes sources de données
      if (_currentFilter == FeedContentType.restaurants) {
        // Récupère les restaurants que l'utilisateur suit et leurs posts en priorité
        newPosts = await _apiService.getRestaurantPosts(
          userId,
          page: _currentPage,
          limit: _postsPerPage,
          filter: 'followed', // Nouveau paramètre pour prioriser les restaurants suivis
        );
      } else if (_currentFilter == FeedContentType.leisure) {
        newPosts = await _apiService.getLeisurePosts(
          userId,
          page: _currentPage,
          limit: _postsPerPage,
          filter: 'followed', // Prioriser les activités de loisir suivies
        );
      } else if (_currentFilter == FeedContentType.wellness) {
        // Nouveau cas pour les posts bien-être
        newPosts = await _apiService.getWellnessPosts(
          userId,
          page: _currentPage,
          limit: _postsPerPage,
          filter: 'followed', // Prioriser les établissements de bien-être suivis
        );
      } else if (_currentFilter == FeedContentType.userPosts) {
        newPosts = await _apiService.getUserPosts(
          userId,
          page: _currentPage,
          limit: _postsPerPage,
        );
      } else {
        // Pour le feed "Pour toi" (par défaut), utiliser un mélange de sources
        try {
          // D'abord essayer avec l'API feed qui devrait déjà mélanger les contenus
          newPosts = await _apiService.getPostsForFeed(
            userId,
            page: _currentPage,
            limit: _postsPerPage,
          );
          
          // Si nous n'avons pas assez de posts ou si les posts sont trop homogènes,
          // compléter avec des sources variées explicitement
          if (newPosts.length < _postsPerPage || _isContentTooHomogeneous(newPosts)) {
            print('⚠️ Feed pas assez varié, ajout de contenu diversifié');
            
            // Calculer combien de posts nous avons besoin de récupérer
            final int neededPosts = _postsPerPage - newPosts.length;
            
            // Si nous avons besoin de plus de posts, récupérer un mélange explicite
            if (neededPosts > 0) {
              List<Post> additionalPosts = await _loadMixedContentExplicitly(neededPosts);
              // Filtrer les doublons avant d'ajouter
              additionalPosts = additionalPosts.where((newPost) => 
                !newPosts.any((existingPost) => existingPost.id == newPost.id)
              ).toList();
              
              newPosts.addAll(additionalPosts);
            }
          }
        } catch (feedError) {
          print('❌ Erreur avec l\'API feed: $feedError');
          print('↪️ Repli sur le chargement mixte explicite');
          
          // En cas d'erreur, utiliser directement le chargement mixte
          newPosts = await _loadMixedContentExplicitly(_postsPerPage);
        }
      }
      
      // Vérifier si nous avons plus de posts à charger
      _hasMorePosts = newPosts.length >= _postsPerPage;
      
      // Organiser les posts pour assurer la diversité si nécessaire
      if (_currentFilter == FeedContentType.all && newPosts.length >= 5) {
        newPosts = _organizePostsForDiversity(newPosts);
      }
      
      // Ajouter tous les nouveaux posts au feed
      if (isLoadingMore) {
        _feedItems.addAll(newPosts);
      } else {
        _feedItems = newPosts;
      }
      
      // Ajouter un message AI après avoir montré quelques posts
      if (_currentFilter != FeedContentType.aiDialogic) {
        _addAIMessageIfNeeded();
      }
      
      print('✅ Feed chargé avec ${_feedItems.length} éléments');
      notifyListeners();
      
      // Mise à jour du cache si nécessaire
      _saveFeedCache();
      
    } catch (e) {
      print('❌ Erreur lors du chargement du feed: $e');
      // Revenir aux posts en cache en cas d'erreur
      await _loadFeedFromCache();
      _hasMorePosts = false; // Empêcher de charger plus de contenu en cas d'erreur
      
      // Propager l'erreur pour que l'interface puisse réagir
      rethrow;
    }
  }
  
  /// Méthode pour charger explicitement un contenu mixte depuis plusieurs sources
  Future<List<Post>> _loadMixedContentExplicitly(int totalNeeded) async {
    // Répartir le nombre total de posts nécessaires entre les différentes sources
    final int restaurantCount = (totalNeeded * 0.30).round(); // 30% restaurants
    final int leisureCount = (totalNeeded * 0.25).round();    // 25% loisirs
    final int wellnessCount = (totalNeeded * 0.25).round();   // 25% bien-être
    final int userCount = totalNeeded - restaurantCount - leisureCount - wellnessCount; // 20% utilisateurs
    
    try {
      print('🔄 Chargement mixte: $restaurantCount restaurants + $leisureCount loisirs + $wellnessCount bien-être + $userCount utilisateurs');
      
      // Charger en parallèle pour plus d'efficacité
      final futures = [
        _apiService.getRestaurantPosts(userId, page: _currentPage, limit: restaurantCount + 3, filter: 'followed'),
        _apiService.getLeisurePosts(userId, page: _currentPage, limit: leisureCount + 3, filter: 'followed'),
        _apiService.getWellnessPosts(userId, page: _currentPage, limit: wellnessCount + 3, filter: 'followed'),
        _apiService.getUserPosts(userId, page: _currentPage, limit: userCount + 3),
      ];
      
      // Attendre que toutes les requêtes soient terminées
      final results = await Future.wait(futures);
      
      // Combinaison des résultats
      List<Post> restaurantPosts = results[0];
      List<Post> leisurePosts = results[1];
      List<Post> wellnessPosts = results[2];
      List<Post> userPosts = results[3];
      
      print('📊 Résultats: ${restaurantPosts.length} restaurants, ${leisurePosts.length} loisirs, ${wellnessPosts.length} bien-être, ${userPosts.length} utilisateurs');
      
      // S'assurer que chaque catégorie a au moins un élément si possible
      List<Post> combinedPosts = [];
      
      // Fonction pour prendre un élément aléatoire d'une liste
      Post? getRandomPost(List<Post> posts) {
        if (posts.isEmpty) return null;
        posts.shuffle();
        return posts.isNotEmpty ? posts.removeAt(0) : null;
      }
      
      // Construire le feed de manière alternée pour assurer la diversité
      while (combinedPosts.length < totalNeeded && 
             (restaurantPosts.isNotEmpty || leisurePosts.isNotEmpty || wellnessPosts.isNotEmpty || userPosts.isNotEmpty)) {
        
        // Ajouter un post restaurant si disponible
        if (restaurantPosts.isNotEmpty) {
          final post = getRandomPost(restaurantPosts);
          if (post != null) combinedPosts.add(post);
        }
        
        // Si on a assez de posts, sortir
        if (combinedPosts.length >= totalNeeded) break;
        
        // Ajouter un post loisir si disponible
        if (leisurePosts.isNotEmpty) {
          final post = getRandomPost(leisurePosts);
          if (post != null) combinedPosts.add(post);
        }
        
        // Si on a assez de posts, sortir
        if (combinedPosts.length >= totalNeeded) break;
        
        // Ajouter un post bien-être si disponible
        if (wellnessPosts.isNotEmpty) {
          final post = getRandomPost(wellnessPosts);
          if (post != null) combinedPosts.add(post);
        }
        
        // Si on a assez de posts, sortir
        if (combinedPosts.length >= totalNeeded) break;
        
        // Ajouter un post utilisateur si disponible
        if (userPosts.isNotEmpty) {
          final post = getRandomPost(userPosts);
          if (post != null) combinedPosts.add(post);
        }
      }
      
      return combinedPosts;
    } catch (e) {
      print('❌ Erreur lors du chargement mixte: $e');
      return [];
    }
  }
  
  /// Vérifier si le contenu est trop homogène (pas assez diversifié)
  bool _isContentTooHomogeneous(List<Post> posts) {
    if (posts.length < 5) return true; // Trop peu de posts pour évaluer
    
    // Compter les différents types de posts
    int restaurantCount = 0;
    int leisureCount = 0;
    int userCount = 0;
    
    for (var post in posts) {
      if (post.isProducerPost ?? false) {
        if (post.isLeisureProducer ?? false) {
          leisureCount++;
        } else {
          restaurantCount++;
        }
      } else {
        userCount++;
      }
    }
    
    // Calculer si un type est surreprésenté (plus de 70% du contenu)
    final total = posts.length;
    final maxPercentage = 0.7;
    
    return (restaurantCount / total > maxPercentage) ||
           (leisureCount / total > maxPercentage) ||
           (userCount / total > maxPercentage);
  }
  
  /// Méthode pour éventuellement insérer un message IA dans le feed
  void _maybeInjectAiMessage(FeedContentType currentFilter) {
    // Ne pas insérer de message si nous sommes déjà dans le feed AI
    if (currentFilter == FeedContentType.aiDialogic) {
      return;
    }
    
    // Incrémenter le compteur de posts depuis le dernier message IA
    _postsSinceLastAiMessage++;
    
    // Vérifier si nous devrions insérer un nouveau message IA
    // La fréquence des messages IA peut être ajustée selon les besoins
    if (_postsSinceLastAiMessage >= 7) { // Après chaque 7 posts environ
      _insertAiMessage();
    }
  }
  
  /// Méthode pour insérer un message IA dans le feed
  void _insertAiMessage() {
    // Cette méthode sera implémentée pour insérer effectivement un message IA
    // Pour l'instant, on réinitialise simplement le compteur
    _postsSinceLastAiMessage = 0;
  }

  /// Organiser les posts pour avoir une bonne diversité entre utilisateurs et producteurs
  List<Post> _organizePostsForDiversity(List<Post> posts) {
    if (posts.isEmpty) return [];
    
    // Séparer les posts par type
    final restaurantPosts = posts.where((post) => 
      post is Post && (post.isProducerPost ?? false) && !(post.isLeisureProducer ?? false)
    ).toList();
    
    final leisurePosts = posts.where((post) => 
      post is Post && (post.isProducerPost ?? false) && (post.isLeisureProducer ?? false)
    ).toList();
    
    final userPosts = posts.where((post) => 
      post is Post && !(post.isProducerPost ?? false)
    ).toList();
    
    // Si nous avons moins de 3 posts de chaque type, essayer d'en obtenir plus
    if (userPosts.length < 3 || restaurantPosts.length < 3 || leisurePosts.length < 3) {
      _loadMoreBalancedPosts();
    }
    
    // Mélanger chaque liste pour éviter les répétitions par type
    restaurantPosts.shuffle();
    leisurePosts.shuffle();
    userPosts.shuffle();
    
    // Déterminer la répartition des types en fonction des préférences de l'utilisateur
    // et de ce qui est disponible
    final userRatio = 0.35;  // 35% posts utilisateurs
    final restaurantRatio = 0.35;  // 35% posts restaurants
    final leisureRatio = 0.30;  // 30% posts loisirs
    
    final totalDesired = _postsPerPage;
    final userDesired = (totalDesired * userRatio).round();
    final restaurantDesired = (totalDesired * restaurantRatio).round();
    final leisureDesired = totalDesired - userDesired - restaurantDesired;
    
    // Créer un nouveau feed équilibré
    List<Post> organizedFeed = [];
    
    // Fonction pour prendre le nombre désiré d'éléments, ou tout si moins disponible
    List<Post> takeUpTo(List<Post> source, int count) {
      return source.take(count < source.length ? count : source.length).toList();
    }
    
    // Prendre des éléments de chaque type selon la répartition souhaitée
    final userSelection = takeUpTo(userPosts, userDesired);
    final restaurantSelection = takeUpTo(restaurantPosts, restaurantDesired);
    final leisureSelection = takeUpTo(leisurePosts, leisureDesired);
    
    // Calculer combien d'éléments nous avons pu obtenir
    final shortfallUser = userDesired - userSelection.length;
    final shortfallRestaurant = restaurantDesired - restaurantSelection.length;
    final shortfallLeisure = leisureDesired - leisureSelection.length;
    
    // Fonction pour combler les manques avec d'autres types
    List<Post> fillShortfall(List<Post> source, int count) {
      return takeUpTo(source, count < source.length ? count : source.length);
    }
    
    // Si nous n'avons pas assez d'un type, combler avec d'autres types
    List<Post> additionalRestaurants = [];
    List<Post> additionalLeisure = [];
    List<Post> additionalUsers = [];
    
    if (shortfallUser > 0) {
      // Combler le manque d'utilisateurs avec des restaurants et loisirs
      final extraFromRestaurants = fillShortfall(
        restaurantPosts.skip(restaurantSelection.length).toList(), 
        (shortfallUser / 2).ceil()
      );
      final extraFromLeisure = fillShortfall(
        leisurePosts.skip(leisureSelection.length).toList(), 
        shortfallUser - extraFromRestaurants.length
      );
      
      additionalRestaurants.addAll(extraFromRestaurants);
      additionalLeisure.addAll(extraFromLeisure);
    }
    
    if (shortfallRestaurant > 0) {
      // Combler le manque de restaurants avec des loisirs et utilisateurs
      final extraFromLeisure = fillShortfall(
        leisurePosts.skip(leisureSelection.length + additionalLeisure.length).toList(), 
        (shortfallRestaurant / 2).ceil()
      );
      final extraFromUsers = fillShortfall(
        userPosts.skip(userSelection.length).toList(), 
        shortfallRestaurant - extraFromLeisure.length
      );
      
      additionalLeisure.addAll(extraFromLeisure);
      additionalUsers.addAll(extraFromUsers);
    }
    
    if (shortfallLeisure > 0) {
      // Combler le manque de loisirs avec des restaurants et utilisateurs
      final extraFromRestaurants = fillShortfall(
        restaurantPosts.skip(restaurantSelection.length + additionalRestaurants.length).toList(), 
        (shortfallLeisure / 2).ceil()
      );
      final extraFromUsers = fillShortfall(
        userPosts.skip(userSelection.length + additionalUsers.length).toList(), 
        shortfallLeisure - extraFromRestaurants.length
      );
      
      additionalRestaurants.addAll(extraFromRestaurants);
      additionalUsers.addAll(extraFromUsers);
    }
    
    // Ajouter tous les éléments sélectionnés à notre feed
    organizedFeed.addAll(userSelection);
    organizedFeed.addAll(restaurantSelection);
    organizedFeed.addAll(leisureSelection);
    organizedFeed.addAll(additionalUsers);
    organizedFeed.addAll(additionalRestaurants);
    organizedFeed.addAll(additionalLeisure);
    
    // Mélanger l'ensemble pour éviter que des blocs du même type se retrouvent ensemble
    organizedFeed.shuffle();
    
    // S'assurer qu'on ne dépasse pas le nombre de posts par page
    return organizedFeed.take(totalDesired).toList();
  }
  
  /// Charger plus de posts de manière équilibrée depuis les différentes sources
  Future<void> _loadMoreBalancedPosts() async {
    try {
      // Charger des posts de différentes sources en parallèle
      final String userId = _userService.currentUserId ?? '';
      if (userId.isEmpty) return;
      
      // Créer les futures pour le chargement asynchrone de données
      final Future<List<Post>> userPostsFuture = _apiService.getUserPosts(userId, page: 1, limit: 5);
      final Future<List<Post>> restaurantPostsFuture = _apiService.getRestaurantPosts(userId, page: 1, limit: 5);
      final Future<List<Post>> leisurePostsFuture = _apiService.getLeisurePosts(userId, page: 1, limit: 5);
      
      // Attendre que les futures se terminent
      final List<Post> userPosts = await userPostsFuture;
      final List<Post> restaurantPosts = await restaurantPostsFuture;
      final List<Post> leisurePosts = await leisurePostsFuture;
      
      // Ajouter ces posts à la liste existante s'ils ne sont pas déjà présents
      for (final post in userPosts) {
        if (!_feedItems.any((item) => 
          item is Post && item.id == post.id
        )) {
          _feedItems.add(post);
        }
      }
      
      for (final post in restaurantPosts) {
        if (!_feedItems.any((item) => 
          item is Post && item.id == post.id
        )) {
          _feedItems.add(post);
        }
      }
      
      for (final post in leisurePosts) {
        if (!_feedItems.any((item) => 
          item is Post && item.id == post.id
        )) {
          _feedItems.add(post);
        }
      }
      
    } catch (e) {
      print('Erreur lors du chargement équilibré des posts: $e');
    }
  }
  
  /// S'assurer que les photos de profil sont valides pour tous les posts
  Future<List<dynamic>> _ensureValidProfilePhotos(List<dynamic> posts) async {
    List<dynamic> updatedPosts = List.from(posts);
    for (int i = 0; i < updatedPosts.length; i++) {
      dynamic post = updatedPosts[i];
      
      // Vérifier et corriger la photo de profil
      if (post is Post && (post.authorAvatar == null || post.authorAvatar!.isEmpty)) {
        // Générer un avatar par défaut basé sur l'ID
        String defaultAvatarUrl = 'https://ui-avatars.com/api/?name=';
        
        if (post.authorName != null && post.authorName!.isNotEmpty) {
          defaultAvatarUrl += post.authorName!.split(' ')
                              .take(2)
                              .map((e) => e.isNotEmpty ? e[0] : '')
                              .join('');
        } else {
          defaultAvatarUrl += 'User';
        }
        defaultAvatarUrl += '&background=random';
        
        updatedPosts[i] = post.copyWith(authorAvatar: defaultAvatarUrl);
      }
      
      // Vérifier et corriger les URLs des médias
      if (post is Post && post.media != null && post.media!.isNotEmpty) {
        List<app_media.Media> updatedMedia = [];
        for (app_media.Media media in post.media!) {
          if (media.url.isEmpty) {
            // Ajouter une image par défaut pour les médias invalides
            updatedMedia.add(app_media.Media(
              url: post.isProducerPost ?? false
                  ? 'assets/images/default_restaurant.jpg' 
                  : 'assets/images/default_post.jpg',
              type: 'image',
            ));
          } else {
            updatedMedia.add(media);
          }
        }
        updatedPosts[i] = post.copyWith(media: updatedMedia);
      }
    }
    return updatedPosts;
  }
  
  /// Vérifie si deux listes de médias sont égales
  bool _areMediaEqual(List<app_media.Media>? list1, List<app_media.Media>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].url != list2[i].url || list1[i].type != list2[i].type) {
        return false;
      }
    }
    return true;
  }
  
  /// Load AI greeting in the background without blocking the UI
  void _loadAiGreetingInBackground() {
    // Don't use await here to avoid blocking the UI thread
    _dialogicService.getContextualMessage(
      userId, 
      _convertToPostList(_recentlyViewedPosts), 
      _recentInteractions
    ).then((contextualMessage) {
      // Insert AI message at the beginning of the feed
      if (_feedItems.isNotEmpty) {
        _feedItems.insert(0, contextualMessage);
        notifyListeners();
      }
    }).catchError((e) {
      print('❌ Error loading AI greeting in background: $e');
      // Don't set error state, simply log the error
      // This ensures the user still sees content even if AI fails
    });
  }
  
  /// Load periodic AI message in the background without blocking the UI
  void _loadPeriodicAiMessageInBackground() {
    // Don't use await here to avoid blocking the UI thread
    _dialogicService.getContextualMessage(
      userId, 
      _convertToPostList(_recentlyViewedPosts), 
      _recentInteractions
    ).then((contextualMessage) {
      // Insert AI message randomly within the existing feed
      if (_feedItems.isNotEmpty) {
        final int insertPosition = min(
          Random().nextInt(_feedItems.length), 
          _feedItems.length
        );
        
        _feedItems.insert(insertPosition, contextualMessage);
        _postsSinceLastAiMessage = 0;
        notifyListeners();
      }
    }).catchError((e) {
      print('❌ Error loading periodic AI message: $e');
      // Don't set error state, simply log the error
      // User experience continues even if AI fails
    });
  }

  /// Helper to extract user interests from recently viewed posts
  List<String> _extractInterests() {
    Set<String> interests = {};
    
    for (final dynamic postItem in _recentlyViewedPosts) {
      if (postItem is Post) {
        // Handle Post object
        if (postItem.isProducerPost ?? false) {
          interests.add((postItem.isLeisureProducer ?? false) ? 'leisure' : 'restaurant');
        }
        // Post objects don't have tags field currently
      } else if (postItem is Map<String, dynamic>) {
        // Handle Map-based post
        final bool isProducer = postItem['isProducerPost'] == true || 
                             postItem['producer_id'] != null;
        final bool isLeisure = postItem['isLeisureProducer'] == true;
        
        if (isProducer) {
          interests.add((isLeisure ? 'leisure' : 'restaurant'));
        }
        
        // Extract from tags if available
        if (postItem['tags'] is List) {
          interests.addAll((postItem['tags'] as List).map((tag) => tag.toString()));
        }
      }
    }
    
    return interests.toList();
  }

  // Find a post in the feed items by ID (works with both Post objects and Map posts)
  int _findPostIndex(dynamic postData) {
    String postId = '';
    
    if (postData is Post) {
      postId = postData.id;
    } else if (postData is Map<String, dynamic>) {
      postId = postData['_id'] ?? '';
    }
    
    final index = _feedItems.indexWhere((item) {
      if (item is DialogicAIMessage) {
        // Just use the ID property from DialogicAIMessage
        return item.id == postId;
      }
      return false;
    });
    
    return index;
  }

  // Convert dynamic items to Post objects
  List<Post> _convertToPostList(List<dynamic> items) {
    List<Post> result = [];
    
    for (var item in items) {
      if (item is Post) {
        // Already a Post, just add it
        result.add(item);
      } else if (item is Map<String, dynamic>) {
        // Try to convert Map to Post
        try {
          final String postId = item['_id'] ?? '';
          final String content = item['content'] ?? '';
          
          // Get author info
          String authorName = '';
          String authorAvatar = '';
          String authorId = '';
          
          if (item['author'] is Map) {
            final author = item['author'] as Map;
            authorName = author['name'] ?? '';
            authorAvatar = author['avatar'] ?? '';
            authorId = author['id'] ?? '';
          } else {
            authorName = item['author_name'] ?? '';
            authorAvatar = item['author_avatar'] ?? item['author_photo'] ?? '';
            authorId = item['author_id'] ?? item['user_id'] ?? '';
          }
          
          // Get post timestamp
          DateTime postedAt = DateTime.now();
          if (item['posted_at'] != null) {
            try {
              postedAt = DateTime.parse(item['posted_at'].toString());
            } catch (e) {
              print('❌ Error parsing timestamp: $e');
            }
          } else if (item['time_posted'] != null) {
            try {
              postedAt = DateTime.parse(item['time_posted'].toString());
            } catch (e) {
              print('❌ Error parsing timestamp: $e');
            }
          }
          
          // Determine if this is a producer post
          final bool isProducerPost = item['isProducerPost'] == true || 
                                  item['producer_id'] != null;
          final bool isLeisureProducer = item['isLeisureProducer'] == true;
          
          // Convert to Post object and add to result
          result.add(Post(
            id: postId,
            authorId: authorId,
            authorName: authorName,
            authorAvatar: authorAvatar,
            content: content,
            postedAt: postedAt,
            createdAt: postedAt, // Utiliser postedAt comme createdAt
            description: content, // Utiliser content comme description
            mediaUrls: [], // Champ requis
            likes: 0,  // Utiliser un int à la place d'une liste vide
            tags: [],
            comments: [],
            isProducerPost: isProducerPost,
            isLeisureProducer: isLeisureProducer,
            isInterested: item['interested'] == true || item['isInterested'] == true,
            isChoice: item['choice'] == true || item['isChoice'] == true,
            interestedCount: item['interested_count'] ?? item['interestedCount'] ?? 0,
            choiceCount: item['choice_count'] ?? item['choiceCount'] ?? 0,
            isLiked: item['isLiked'] == true,
            likesCount: item['likes_count'] ?? item['likesCount'] ?? 
                    (item['likes'] is List ? (item['likes'] as List).length : 0),
            userId: authorId, // Ajout de userId
          ));
        } catch (e) {
          print('❌ Error converting map to Post: $e');
          // Skip this item if conversion fails
        }
      }
    }
    
    return result;
  }

  void _setLoadState(FeedLoadState state) {
    _loadState = state;
    notifyListeners();
  }

void _setErrorState(String message) {
    _loadState = FeedLoadState.error;
    _errorMessage = message;
    notifyListeners();
  }
  
  /// Load initial AI message in the background without blocking the UI
  Future<void> _loadAiMessageInBackground(List<dynamic> items) async {
    try {
      // Get contextual AI message asynchronously
      final contextualMessage = await _dialogicService.getContextualMessage(
        userId, 
        _convertToPostList(_recentlyViewedPosts), 
        _recentInteractions
      );
      
      // Insert AI message at the beginning of the feed
      _feedItems.insert(0, contextualMessage);
      
      // Update UI
      notifyListeners();
    } catch (e) {
      print('❌ Error loading AI message in background: $e');
      // Don't set error state, simply log the error
      // This ensures the user still sees content even if AI fails
    }
  }
  
  /// Load periodic AI message in the background without blocking the UI
  Future<void> _loadPeriodicAiMessage(List<dynamic> items) async {
    try {
      // Get contextual AI message asynchronously
      final contextualMessage = await _dialogicService.getContextualMessage(
        userId, 
        _convertToPostList(_recentlyViewedPosts), 
        _recentInteractions
      );
      
      // Insert AI message randomly within the existing feed
      final int insertPosition = min(
        Random().nextInt(_feedItems.length), 
        _feedItems.length
      );
      
      _feedItems.insert(insertPosition, contextualMessage);
      _postsSinceLastAiMessage = 0;
      
      // Update UI
      notifyListeners();
    } catch (e) {
      print('❌ Error loading periodic AI message: $e');
      // Don't set error state, simply log the error
      // User experience continues even if AI fails
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMorePosts) return;
    
    _isLoading = true;
    notifyListeners();
    
    final userId = _userService.currentUserId;
    
    if (userId == null || userId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    
    try {
      final newItems = <Post>[];
      
      // Créer des futures séparés pour chaque type de contenu
      final userPostsFuture = _apiService.getUserPosts(
        userId, 
        page: _currentPage, 
        limit: _postsPerPage
      );
      
      final restaurantPostsFuture = _apiService.getRestaurantPosts(
        userId, 
        page: _currentPage, 
        limit: _postsPerPage
      );
      
      final leisurePostsFuture = _apiService.getLeisurePosts(
        userId, 
        page: _currentPage, 
        limit: _postsPerPage
      );
      
      // Attendre les résultats de manière indépendante
      var userPosts = await userPostsFuture;
      var restaurantPosts = await restaurantPostsFuture;
      var leisurePosts = await leisurePostsFuture;
      
      // Traiter les résultats des posts utilisateurs
      if (userPosts is List<Post>) {
        for (final post in userPosts) {
          if (!_feedItems.any((p) => p is Post && p.id == post.id)) {
            newItems.add(post);
          }
        }
      } else if (userPosts is List<dynamic>) {
        for (final item in userPosts) {
          if (item is Post) {
            if (!_feedItems.any((p) => p is Post && p.id == item.id)) {
              newItems.add(item);
            }
          } else if (item is Map<String, dynamic>) {
            // Vérifier si c'est une structure contenant des posts
            if (item.containsKey('posts')) {
              final postsData = item['posts'];
              if (postsData is List) {
                for (final postItem in postsData) {
                  if (postItem is Post) {
                    if (!_feedItems.any((p) => p is Post && p.id == postItem.id)) {
                      newItems.add(postItem);
                    }
                  } else if (postItem is Map<String, dynamic>) {
                    try {
                      // Création manuelle d'un Post au lieu d'utiliser fromJson
                      final post = Post(
                        id: postItem['id'] ?? postItem['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        userId: postItem['userId'] ?? postItem['user_id'] ?? '',
                        userName: postItem['userName'] ?? postItem['user_name'] ?? '',
                        description: postItem['description'] ?? postItem['content'] ?? '',
                        content: postItem['content'] ?? '',
                        title: postItem['title'] ?? '',
                        authorId: postItem['authorId'] ?? postItem['author_id'] ?? '',
                        authorName: postItem['authorName'] ?? postItem['author_name'] ?? '',
                        authorAvatar: postItem['authorAvatar'] ?? postItem['author_avatar'] ?? '',
                        createdAt: DateTime.now(),
                        postedAt: DateTime.now(),
                        mediaUrls: [],
                        likes: 0,
                        comments: [],
                        tags: [],
                      );
                      if (!_feedItems.any((p) => p is Post && p.id == post.id)) {
                        newItems.add(post);
                      }
                    } catch (e) {
                      print('❌ Erreur de conversion Map to Post: $e');
                    }
                  }
                }
              }
            } else {
              // C'est un post direct
              try {
                // Création manuelle du Post au lieu d'utiliser fromJson
                final post = Post(
                  id: item['id'] ?? item['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: item['userId'] ?? item['user_id'] ?? '',
                  userName: item['userName'] ?? item['user_name'] ?? '',
                  description: item['description'] ?? item['content'] ?? '',
                  content: item['content'] ?? '',
                  title: item['title'] ?? '',
                  authorId: item['authorId'] ?? item['author_id'] ?? '',
                  authorName: item['authorName'] ?? item['author_name'] ?? '',
                  authorAvatar: item['authorAvatar'] ?? item['author_avatar'] ?? '',
                  createdAt: DateTime.now(),
                  postedAt: DateTime.now(),
                  mediaUrls: [],
                  likes: 0,
                  comments: [],
                  tags: [],
                );
                if (!_feedItems.any((p) => p is Post && p.id == post.id)) {
                  newItems.add(post);
                }
              } catch (e) {
                print('❌ Erreur de conversion Map to Post: $e');
              }
            }
          }
        }
      }
      
      // Traiter les résultats des posts restaurants
      if (restaurantPosts is List<Post>) {
        for (final post in restaurantPosts) {
          if (!_feedItems.any((p) => p is Post && p.id == post.id)) {
            newItems.add(post);
          }
        }
      } else if (restaurantPosts is List) {
        for (final item in restaurantPosts) {
          _processItemWithPosts(item, newItems);
        }
      } else if (restaurantPosts is Map<String, dynamic>) {
        _processItemWithPosts(restaurantPosts, newItems);
      }
      
      // Traiter les résultats des posts loisirs
      if (leisurePosts is List<Post>) {
        for (final post in leisurePosts) {
          if (!_feedItems.any((p) => p is Post && p.id == post.id)) {
            newItems.add(post);
          }
        }
      } else if (leisurePosts is List) {
        for (final item in leisurePosts) {
          _processItemWithPosts(item, newItems);
        }
      } else if (leisurePosts is Map<String, dynamic>) {
        _processItemWithPosts(leisurePosts, newItems);
      }
      
      // Ajouter les nouveaux posts au feed
      if (newItems.isNotEmpty) {
        _feedItems.addAll(newItems);
        _currentPage++;
        _hasMorePosts = true;
      } else {
        _hasMorePosts = false;
      }
    } catch (e) {
      print('❌ Error loading more feed posts: $e');
      _hasMorePosts = false;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreForContentType(FeedContentType contentType) async {
    if (_isLoading || !_hasMorePostsByType[contentType]!) return;
    
    _isLoading = true;
    notifyListeners();
    
    final userId = _userService.currentUserId;
    
    if (userId == null || userId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    
    try {
      final newItems = <Post>[];
      dynamic response;
      
      // Récupérer les données en fonction du type de contenu
      switch (contentType) {
        case FeedContentType.restaurants:
          response = await _apiService.getRestaurantPosts(
            userId, 
            page: _currentPageByType[contentType]!, 
            limit: _postsPerPage
          );
          break;
          
        case FeedContentType.leisure:
          response = await _apiService.getLeisurePosts(
            userId, 
            page: _currentPageByType[contentType]!, 
            limit: _postsPerPage
          );
          break;
          
        case FeedContentType.userPosts:
          response = await _apiService.getUserPosts(
            userId, 
            page: _currentPageByType[contentType]!, 
            limit: _postsPerPage
          );
          break;
          
        case FeedContentType.all:
        default:
          // Charger un mélange de tous les types de posts
          await _loadMorePosts();
          _isLoading = false;
          notifyListeners();
          return;
      }
      
      // Traitement de la réponse uniformisé
      if (response is List) {
        for (var item in response) {
          if (item is Post) {
            newItems.add(item);
          } else if (item is Map<String, dynamic>) {
            // Traiter la réponse selon son type
            if (item.containsKey('posts')) {
              final postsData = item['posts'];
              if (postsData is List) {
                for (var postItem in postsData) {
                  if (postItem is Post) {
                    newItems.add(postItem);
                  } else if (postItem is Map<String, dynamic>) {
                    try {
                      // Créer un Post à partir de la Map
                      newItems.add(Post(
                        id: item['id'] ?? item['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        userId: item['userId'] ?? item['user_id'] ?? '',
                        userName: item['userName'] ?? item['user_name'] ?? '',
                        authorId: item['authorId'] ?? item['author_id'] ?? '',
                        authorName: item['authorName'] ?? item['author_name'] ?? '',
                        authorAvatar: item['authorAvatar'] ?? item['author_avatar'] ?? '',
                        title: item['title'] ?? '',
                        description: item['description'] ?? item['content'] ?? '',
                        content: item['content'] ?? '',
                        createdAt: DateTime.now(),
                        postedAt: DateTime.now(),
                        mediaUrls: [],
                        likes: 0,
                        comments: [],
                        tags: [],
                      ));
                    } catch (e) {
                      print('❌ Erreur conversion de Map to Post: $e');
                    }
                  }
                }
              }
            } else if (item is Map<String, dynamic>) {
              // Si c'est une Map contenant une liste de posts
              if (item.containsKey('posts')) {
                final postsData = item['posts'];
                if (postsData is List) {
                  for (var postItem in postsData) {
                    if (postItem is Post) {
                      newItems.add(postItem);
                    } else if (postItem is Map<String, dynamic>) {
                      try {
                        // Créer un Post à partir de la Map
                        newItems.add(Post(
                          id: item['id'] ?? item['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          userId: item['userId'] ?? item['user_id'] ?? '',
                          userName: item['userName'] ?? item['user_name'] ?? '',
                          authorId: item['authorId'] ?? item['author_id'] ?? '',
                          authorName: item['authorName'] ?? item['author_name'] ?? '',
                          authorAvatar: item['authorAvatar'] ?? item['author_avatar'] ?? '',
                          title: item['title'] ?? '',
                          description: item['description'] ?? item['content'] ?? '',
                          content: item['content'] ?? '',
                          createdAt: DateTime.now(),
                          postedAt: DateTime.now(),
                          mediaUrls: [],
                          likes: 0,
                          comments: [],
                          tags: [],
                        ));
                      } catch (e) {
                        print('❌ Erreur conversion de Map to Post: $e');
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      // Mise à jour du feed
      if (newItems.isNotEmpty) {
        // Mise à jour de la liste par type
        if (_feedItemsByType.containsKey(contentType)) {
          _feedItemsByType[contentType]!.addAll(newItems);
        }
        
        // Mise à jour de la page courante
        if (_currentPageByType.containsKey(contentType)) {
          _currentPageByType[contentType] = _currentPageByType[contentType]! + 1;
        }
        
        // Mise à jour du flag hasMore
        if (_hasMorePostsByType.containsKey(contentType)) {
          _hasMorePostsByType[contentType] = true;
        }
        
        // Ajouter également au feed général
        _feedItems.addAll(newItems);
      } else {
        if (_hasMorePostsByType.containsKey(contentType)) {
          _hasMorePostsByType[contentType] = false;
        }
      }
    } catch (e) {
      print('❌ Error loading more $contentType posts: $e');
      if (_hasMorePostsByType.containsKey(contentType)) {
        _hasMorePostsByType[contentType] = false;
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Méthode pour mettre à jour un post dans le feed
  void updatePost(String postId, dynamic updatedItem) {
    final index = _feedItems.indexWhere((item) {
      if (item is Post) {
        return item.id == postId;
      } else if (item is Map<String, dynamic>) {
        return item['id'] == postId;
      } else if (item is DialogicAIMessage) {
        // Just use the ID property from DialogicAIMessage
        return item.id == postId;
      }
      return false;
    });

    if (index != -1) {
      _feedItems[index] = updatedItem;
      notifyListeners();
    }
  }

  // Méthode générique pour ajouter des éléments au feed
  void addItems(List<dynamic> items) {
    _feedItems.addAll(items);
    _isLoading = false;
    _hasMorePosts = items.isNotEmpty;
    notifyListeners();
  }

  // Méthode pour effacer complètement le feed
  void clearFeed() {
    _feedItems.clear();
    notifyListeners();
  }

  Future<void> initializeFeed() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    final userId = _userService.currentUserId;
    
    if (userId == null || userId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    
    try {
      // Paralléliser les requêtes de chargement initial
      final Future<List<Post>> userPostsFuture = _apiService.getUserPosts(userId, page: 1, limit: 5);
      final Future<List<Post>> restaurantPostsFuture = _apiService.getRestaurantPosts(userId, page: 1, limit: 5);
      final Future<List<Post>> leisurePostsFuture = _apiService.getLeisurePosts(userId, page: 1, limit: 5);
      
      // Si le service DialogicAIFeedService est disponible, utiliser sa méthode
      final List<Post> aiMessages = [];
      try {
        if (_dialogicService != null) {
          final messages = await _dialogicService!.getPersonalizedMessages(userId, limit: 2);
          aiMessages.addAll(messages);
        }
      } catch (e) {
        print('❌ Error loading AI messages: $e');
        // Continuer même en cas d'erreur
      }
      
      // ... existing code ...
    } catch (e) {
      // ... existing code ...
    }
  }

  // Méthode utilitaire pour traiter un élément et l'ajouter à la liste si ce n'est pas un doublon
  void _processPostItem(dynamic item, List<dynamic> targetList) {
    if (item is Post) {
      // Si l'item est déjà un Post, vérifier simplement qu'il n'est pas déjà présent
      if (!_feedItems.any((p) => p is Post && p.id == item.id)) {
        targetList.add(item);
      }
    } else if (item is Map<String, dynamic>) {
      // Si l'item est une Map, convertir en Post
      try {
        // Création manuelle du Post au lieu d'utiliser fromJson
        final post = Post(
          id: item['id'] ?? item['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          userId: item['userId'] ?? item['user_id'] ?? '',
          userName: item['userName'] ?? item['user_name'] ?? '',
          description: item['description'] ?? item['content'] ?? '',
          content: item['content'] ?? '',
          title: item['title'] ?? '',
          tags: [],
          comments: [],
          mediaUrls: [],
          createdAt: DateTime.now(),
          postedAt: DateTime.now(),
          authorId: item['authorId'] ?? item['author_id'] ?? '',
          authorName: item['authorName'] ?? item['author_name'] ?? '',
          authorAvatar: item['authorAvatar'] ?? item['author_avatar'] ?? '',
        );
        if (!_feedItems.any((p) => p is Post && p.id == post.id)) {
          targetList.add(post);
        }
      } catch (e) {
        print('❌ Erreur de conversion Map to Post: $e');
      }
    }
  }

  // Méthode pour vérifier si un item contient des posts dans une clé 'posts'
  void _processItemWithPosts(dynamic item, List<dynamic> targetList) {
    if (item is Post) {
      // Si l'item est déjà un Post, l'ajouter directement
      _processPostItem(item, targetList);
    } else if (item is Map<String, dynamic>) {
      // Si l'item est une Map, vérifier s'il contient une clé 'posts'
      if (item.containsKey('posts')) {
        final postsData = item['posts'];
        if (postsData is List) {
          // Traiter chaque élément dans la liste 'posts'
          for (final postItem in postsData) {
            _processPostItem(postItem, targetList);
          }
        }
      } else {
        // Si l'item est une Map sans clé 'posts', considérer comme un post direct
        _processPostItem(item, targetList);
      }
    }
  }

  Post _createDummyPost() {
    return Post(
      id: 'dummy-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'system',
      userName: 'Choice App',
      authorId: 'system',
      authorName: 'Choice App',
      authorAvatar: '',
      title: 'Chargement...',
      description: 'Contenu en cours de chargement.',
      createdAt: DateTime.now(),
      postedAt: DateTime.now(),
      likesCount: 0,
      commentsCount: 0,
    );
  }

  Future<List<Post>> _fetchAndProcessPosts(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      // Essayer de récupérer les données
      final response = await _apiService.fetchData(endpoint, queryParams: queryParams);
      
      if (response == null) {
        print('❌ Erreur: aucune donnée reçue de $_apiService.fetchData');
        return [];
      }
      
      List<Post> posts = [];
      
      // Traiter la réponse en fonction de son format
      if (response is List) {
        // Convertir chaque élément en Post
        for (var item in response) {
          if (item is Map<String, dynamic>) {
            // Création du post avec les données requises
            final post = Post(
              id: item['_id'] ?? '',
              userId: item['userId'] ?? item['user_id'] ?? 'system',
              userName: item['userName'] ?? item['user_name'] ?? item['authorName'] ?? 'Utilisateur',
              authorId: item['authorId'] ?? '',
              authorName: item['authorName'] ?? '',
              authorAvatar: item['authorAvatar'] ?? '',
              // S'assurer que le titre est toujours fourni
              title: item['title'] ?? '',
              description: item['description'] ?? '',
              createdAt: DateTime.now(),
              postedAt: item['createdAt'] != null 
                  ? DateTime.parse(item['createdAt'])
                  : DateTime.now(),
              likesCount: item['likes'] is List ? (item['likes'] as List).length : (item['likesCount'] as int? ?? 0),
              commentsCount: item['comments'] is List ? (item['comments'] as List).length : (item['commentsCount'] as int? ?? 0),
              isLiked: item['isLiked'] ?? false,
              location: item['location'] ?? '',
              // Autres propriétés
              isProducerPost: item['isProducerPost'] ?? false,
              isLeisureProducer: item['isLeisureProducer'] ?? false,
              tags: item['tags'] is List<String> 
                  ? item['tags'] 
                  : (item['tags'] is List ? (item['tags'] as List).map((t) => t.toString()).toList() : []),
            );
            
            posts.add(post);
          }
        }
      }
      
      return posts;
    } catch (e) {
      print('❌ Erreur lors de la récupération des posts: $e');
      return [];
    }
  }

  Post _createDefaultPost() {
    return Post(
      id: '',
      userId: '',
      userName: '',
      description: '',
      createdAt: DateTime.now(),
      content: '',
      title: '',
      tags: [],
      comments: [],
      mediaUrls: [],
    );
  }

  Future<List<Post>> _convertToPosts(dynamic data) async {
    final List<Post> posts = [];
    if (data is List) {
      for (var item in data) {
        if (item is Post) {
          posts.add(item);
        } else if (item is Map<String, dynamic>) {
          try {
            // Créer manuellement au lieu d'utiliser fromJson pour éviter les erreurs
            final post = Post(
              id: item['id'] ?? item['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              userId: item['userId'] ?? item['user_id'] ?? '',
              userName: item['userName'] ?? item['user_name'] ?? '',
              description: item['description'] ?? item['content'] ?? '',
              createdAt: item['createdAt'] != null ? DateTime.parse(item['createdAt']) : DateTime.now(),
              content: item['content'] ?? item['description'] ?? '',
              title: item['title'] ?? '',
              tags: [],
              comments: [],
              mediaUrls: [],
              authorId: item['authorId'] ?? item['author_id'] ?? '',
              authorName: item['authorName'] ?? item['author_name'] ?? '',
              authorAvatar: item['authorAvatar'] ?? item['author_avatar'] ?? '',
              postedAt: item['postedAt'] != null ? DateTime.parse(item['postedAt']) : DateTime.now(),
            );
            posts.add(post);
          } catch (e) {
            print('❌ Erreur de conversion Map to Post: $e');
          }
        }
      }
    } else if (data is Map<String, dynamic>) {
      // Vérifier si la map contient une clé 'posts'
      if (data.containsKey('posts')) {
        final postsData = data['posts'];
        if (postsData is List) {
          for (var item in postsData) {
            if (item is Post) {
              posts.add(item);
            } else if (item is Map<String, dynamic>) {
              try {
                // Créer manuellement au lieu d'utiliser fromJson pour éviter les erreurs
                final post = Post(
                  id: item['id'] ?? item['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: item['userId'] ?? item['user_id'] ?? '',
                  userName: item['userName'] ?? item['user_name'] ?? '',
                  authorId: item['authorId'] ?? item['author_id'] ?? '',
                  authorName: item['authorName'] ?? item['author_name'] ?? '',
                  authorAvatar: item['authorAvatar'] ?? item['author_avatar'] ?? '',
                  title: item['title'] ?? '',
                  description: item['description'] ?? item['content'] ?? '',
                  content: item['content'] ?? '',
                  createdAt: DateTime.now(),
                  postedAt: DateTime.now(),
                  mediaUrls: [],
                  likes: 0,
                  comments: [],
                  tags: [],
                );
                posts.add(post);
              } catch (e) {
                print('❌ Erreur de conversion Map to Post: $e');
              }
            }
          }
        }
      }
    }
    return posts;
  }

  Future<FeedResult> _fetchFeed(String url) async {
    try {
      final client = http.Client();
      final response = await client.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Impossible de charger le flux, code: ${response.statusCode}');
      }
      
      final dynamic responseData = jsonDecode(response.body);
      final List<Post> posts = [];
      bool hasMore = false;
      
      if (responseData is List) {
        posts.addAll(await _convertToPosts(responseData));
        hasMore = posts.isNotEmpty;
      } else if (responseData is Map<String, dynamic>) {
        if (responseData['posts'] != null) {
          final postsData = responseData['posts'];
          if (postsData is List) {
            posts.addAll(await _convertToPosts(postsData));
          }
        }
        
        if (responseData['hasMore'] != null) {
          final morePosts = responseData['hasMore'];
          if (morePosts is bool) {
            hasMore = morePosts;
          } else if (morePosts is String) {
            hasMore = morePosts.toLowerCase() == 'true';
          } else if (morePosts is int) {
            hasMore = morePosts > 0;
          }
        }
      }
      
      return FeedResult(posts: posts, hasMore: hasMore);
    } catch (e) {
      print('❌ Erreur lors du chargement du flux: $e');
      return FeedResult(posts: [], hasMore: false);
    }
  }

  // Fonction helper pour convertir un post en objet Post pour les commentaires
  Post _convertToPost(dynamic post) {
    if (post is Post) {
      return post;
    } else if (post is Map<String, dynamic>) {
      try {
        return Post(
          id: post['id'] ?? post['_id'] ?? '',
          userId: post['userId'] ?? post['user_id'] ?? '',
          userName: post['userName'] ?? post['user_name'] ?? 'Utilisateur',
          description: post['description'] ?? post['content'] ?? '',
          content: post['content'] ?? post['description'] ?? '',
          title: post['title'] ?? '',
          createdAt: DateTime.now(),
          authorId: post['authorId'] ?? post['author_id'] ?? '',
          authorName: post['authorName'] ?? post['author_name'] ?? '',
          authorAvatar: post['authorAvatar'] ?? post['author_avatar'] ?? '',
          tags: [],
        );
      } catch (e) {
        print('❌ Erreur lors de la conversion Map vers Post: $e');
        // Retourner un Post vide en cas d'erreur
        return Post(
          id: '',
          userId: '',
          userName: '',
          description: '',
          createdAt: DateTime.now(),
          content: '',
          title: '',
          tags: [],
        );
      }
    }
    
    // Fallback, créer un post vide si le type n'est pas reconnu
    return Post(
      id: '',
      userId: '',
      userName: '',
      description: '',
      createdAt: DateTime.now(),
      content: '',
      title: '',
      tags: [],
    );
  }

  /// Méthode pour ajouter un message AI si nécessaire
  void _addAIMessageIfNeeded() {
    // Incrémenter le compteur
    _postsSinceLastAiMessage++;
    
    // Vérifier si nous devons ajouter un message AI
    if (_postsSinceLastAiMessage >= _aiMessageFrequency) {
      _loadPeriodicAiMessage(_feedItems);
    }
  }

  /// Méthode pour sauvegarder le feed en cache
  Future<void> _saveFeedCache() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Convertir les objets Post en JSON
      List<String> serializedPosts = [];
      for (var post in _feedItems) {
        if (post is Post) {
          serializedPosts.add(convert.jsonEncode(post.toJson()));
        } else if (post is Map<String, dynamic>) {
          serializedPosts.add(convert.jsonEncode(post));
        }
      }
      
      // Enregistrer dans les préférences
      await prefs.setStringList('feed_cache_$_currentFilter', serializedPosts);
      await prefs.setInt('feed_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('✅ Feed sauvegardé en cache');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du feed en cache: $e');
    }
  }

  /// Méthode pour charger le feed depuis le cache
  Future<void> _loadFeedFromCache() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Vérifier si le cache existe et n'est pas trop ancien (max 1 heure)
      final timestamp = prefs.getInt('feed_cache_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now - timestamp > 3600000) {
        print('⚠️ Cache trop ancien, pas de restauration');
        return;
      }
      
      final cachedPosts = prefs.getStringList('feed_cache_$_currentFilter');
      if (cachedPosts == null || cachedPosts.isEmpty) {
        print('⚠️ Cache vide, pas de restauration');
        return;
      }
      
      // Désérialiser les objets
      List<dynamic> restoredPosts = [];
      for (var jsonPost in cachedPosts) {
        try {
          final Map<String, dynamic> postMap = convert.jsonDecode(jsonPost);
          if (postMap.containsKey('id') && 
              (postMap.containsKey('description') || postMap.containsKey('content'))) {
            final post = Post.fromJson(postMap);
            restoredPosts.add(post);
          } else {
            restoredPosts.add(postMap);
          }
        } catch (e) {
          print('❌ Erreur lors de la désérialisation d\'un post: $e');
        }
      }
      
      if (restoredPosts.isNotEmpty) {
        _feedItems = restoredPosts;
        print('✅ Feed restauré depuis le cache: ${restoredPosts.length} items');
        notifyListeners();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement du feed depuis le cache: $e');
    }
  }

  // Insérer un message AI dans le feed si les conditions sont remplies
  void _insertAiMessageIfNeeded(List<dynamic> posts) {
    // Incrémenter le compteur de posts vus depuis le dernier message AI
    _postsSinceLastAiMessage += posts.length;
    
    // Vérifier si on doit ajouter un message AI (tous les X posts)
    if (_postsSinceLastAiMessage >= _aiMessageFrequency) {
      try {
        // Récupérer un message AI contextuel basé sur le contenu récent
        _dialogicService.getContextualMessage(
          userId, 
          _convertToPostList(_recentlyViewedPosts), // Convertir la liste dynamic en liste de Post
          _recentInteractions
        ).then((aiMessage) {
            if (aiMessage != null) {
              // Convertir le message AI en format compatible avec le feed
              final aiMessageAsMap = aiMessage.toJson();
              
              // Ajouter le message AI après quelques posts (pas tout en haut)
              int insertPosition = min(3, posts.length);
              if (_feedItems.length > insertPosition) {
                _feedItems.insert(insertPosition, aiMessageAsMap);
                notifyListeners();
              }
              
              // Réinitialiser le compteur
              _postsSinceLastAiMessage = 0;
            }
          });
      } catch (e) {
        print('❌ Erreur lors de l\'insertion d\'un message AI: $e');
      }
    }
  }

  Future<void> initializePreferences() async {
    // Implémentation de la méthode
  }

  Future<void> loadInitialFeed() async {
    // Implémentation de la méthode
  }

  void logShare(Post post) {
    // Implémentation de la méthode
  }

  void logLike(Post post) {
    // Implémentation de la méthode
  }

  void logInterest(Post post) {
    // Implémentation de la méthode
  }

  void logComment(Post post) {
    // Implémentation de la méthode
  }

  void logView(Post post) {
    // Implémentation de la méthode
  }

  // Sauvegarder les posts en cache
  Future<void> _savePostsToCache(List<Post> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> postsJson = posts.map((post) => post.toJson()).toList();
      await prefs.setString('cached_posts', convert.jsonEncode(postsJson));
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des posts en cache: $e');
    }
  }

  // Charger les posts depuis le cache
  Future<List<Post>> _loadPostsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedPosts = prefs.getString('cached_posts');
      if (cachedPosts == null) return [];

      final List<dynamic> postsJson = convert.jsonDecode(cachedPosts);
      return postsJson.map((postJson) => Post.fromJson(postJson)).toList();
    } catch (e) {
      print('❌ Erreur lors du chargement des posts depuis le cache: $e');
      return [];
    }
  }
}