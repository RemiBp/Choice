import 'dart:async';
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart' as constants;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show json;
import '../services/api_service.dart' as api_service;

class FeedController extends ChangeNotifier {
  final String userId;
  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();
  
  List<Post> _posts = [];
  List<Post> _restaurantPosts = [];
  List<Post> _leisurePosts = [];
  List<Post> _userPosts = [];
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  int _currentPage = 1;
  final int _postsPerPage = 10;
  
  // Ajout des propriétés pour la gestion des erreurs
  bool _hasError = false;
  String _errorMessage = '';
  
  // Métriques de préférences
  Map<String, double> _sectorPreferences = {
    'restaurant': 0.5,
    'leisure': 0.3,
    'user': 0.2,
  };
  
  Map<String, double> _contentTypePreferences = {
    'image': 0.6,
    'video': 0.4,
  };
  
  // Ajout de nouvelles métriques d'interaction pour l'apprentissage adaptatif
  Map<String, int> _userInteractions = {
    'likes': 0,
    'interests': 0,
    'comments': 0,
    'choices': 0,
    'shares': 0,
    'views': 0,
  };
  
  // Historique des interactions pour analyse des tendances
  List<Map<String, dynamic>> _interactionHistory = [];
  Map<String, int> _tagInteractions = {};
  Map<String, int> _producerTypeInteractions = {};
  Map<String, double> _categoryScores = {};
  
  // Getters
  List<Post> get posts => _posts;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _hasMorePosts;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  Map<String, double> get sectorPreferences => _sectorPreferences;
  Map<String, double> get contentTypePreferences => _contentTypePreferences;
  Map<String, int> get userInteractions => _userInteractions;
  
  FeedController({required this.userId});
  
  // Initialiser et charger les préférences utilisateur
  Future<void> initializePreferences() async {
    try {
      if (userId.isEmpty) {
        print('⚠️ Aucun userId trouvé, utilisation des préférences par défaut');
        return;
      }
      
      // Tentative d'obtention du profil utilisateur
      final token = await _apiService.getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ Aucun token trouvé, utilisation des préférences par défaut');
        return;
      }
      
      // Appeler l'API pour obtenir le profil utilisateur
      final url = Uri.parse('${_apiService.getApiBaseUrl()}/api/users/$userId');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final userData = convert.jsonDecode(response.body);
        
        // Extraire les préférences sectorielles depuis le profil
        if (userData['preferences'] != null) {
          final prefs = userData['preferences'];
          if (prefs['sectors'] != null) {
            _sectorPreferences['restaurant'] = prefs['sectors']['restaurant']?.toDouble() ?? 0.5;
            _sectorPreferences['leisure'] = prefs['sectors']['leisure']?.toDouble() ?? 0.3;
            _sectorPreferences['user'] = prefs['sectors']['user']?.toDouble() ?? 0.2;
          }
          
          if (prefs['contentTypes'] != null) {
            _contentTypePreferences['image'] = prefs['contentTypes']['image']?.toDouble() ?? 0.6;
            _contentTypePreferences['video'] = prefs['contentTypes']['video']?.toDouble() ?? 0.4;
          }
        }
        
        // Extraire les tags préférés et les convertir en scores
        if (userData['liked_tags'] != null && userData['liked_tags'] is List) {
          final tags = userData['liked_tags'] as List;
          for (var tag in tags) {
            _tagInteractions[tag.toString()] = (_tagInteractions[tag.toString()] ?? 0) + 5;
          }
        }
        
        // Extraire les intérêts et les convertir en scores
        if (userData['interests'] != null && userData['interests'] is List) {
          for (var interest in userData['interests']) {
            String? type;
            if (interest is Map && interest['producer_type'] != null) {
              type = interest['producer_type'].toString();
            } else if (interest is String) {
              // Essayer de déterminer le type à partir de l'ID
              try {
                // Appeler l'API pour obtenir le type de producteur
                final producerUrl = Uri.parse('${_apiService.getApiBaseUrl()}/api/producers/$interest');
                final producerResponse = await http.get(
                  producerUrl,
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                );
                
                if (producerResponse.statusCode == 200) {
                  final producerData = convert.jsonDecode(producerResponse.body);
                  type = producerData['producer_type']?.toString();
                }
              } catch (e) {
                print('Erreur lors de la récupération du type du producteur: $e');
              }
            }
            
            if (type != null) {
              _producerTypeInteractions[type] = (_producerTypeInteractions[type] ?? 0) + 5;
            }
          }
        }
      } else {
        print('⚠️ Erreur lors de la récupération du profil: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Erreur lors du chargement des préférences: $e');
    }
  }
  
  // Mettre à jour les préférences utilisateur avec retour d'expérience
  Future<void> updateUserPreferences() async {
    try {
      final preferences = {
        'sectors': _sectorPreferences,
        'contentTypes': _contentTypePreferences,
      };
      await _apiService.updateUserPreferences(preferences);
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des préférences: $e');
    }
  }
  
  // Recalculer les préférences basées sur les interactions
  void _recalculatePreferences() {
    // Facteur d'apprentage - détermine la vitesse d'adaptation
    final double learningRate = 0.1;
    
    // Normaliser les interactions par type de contenu
    final total = _userInteractions.values.fold(0, (a, b) => a + b);
    if (total > 0) {
      // Calculer les scores de catégorie basés sur les interactions
      Map<String, int> categoryCounts = {
        'restaurant': 0,
        'leisure': 0,
        'user': 0,
      };
      
      // Comptabiliser les interactions par type de producteur
      _producerTypeInteractions.forEach((type, count) {
        if (type == 'restaurant') {
          categoryCounts['restaurant'] = (categoryCounts['restaurant'] ?? 0) + count;
        } else if (type == 'leisure') {
          categoryCounts['leisure'] = (categoryCounts['leisure'] ?? 0) + count;
        } else if (type == 'user') {
          categoryCounts['user'] = (categoryCounts['user'] ?? 0) + count;
        }
      });
      
      // Normaliser les scores
      final totalCategoryInteractions = categoryCounts.values.fold(0, (a, b) => a + b);
      if (totalCategoryInteractions > 0) {
        categoryCounts.forEach((category, count) {
          final newScore = count / totalCategoryInteractions;
          // Mettre à jour progressivement les préférences
          _sectorPreferences[category] = (_sectorPreferences[category] ?? 0.33) * (1 - learningRate) + 
                                         newScore * learningRate;
        });
      }
      
      // Normaliser pour assurer que la somme est 1
      final prefTotal = _sectorPreferences.values.fold(0.0, (a, b) => a + b);
      if (prefTotal > 0) {
        _sectorPreferences.forEach((key, value) {
          _sectorPreferences[key] = value / prefTotal;
        });
      }
    }
  }
  
  // Enregistrer une interaction utilisateur et mettre à jour les préférences
  void logUserInteraction(String type, Post post, {String? tag}) {
    // Incrémenter le compteur du type d'interaction
    _userInteractions[type] = (_userInteractions[type] ?? 0) + 1;
    
    // Enregistrer l'interaction dans l'historique
    _interactionHistory.add({
      'type': type,
      'post_id': post.id,
      'producer_type': post.producerType,
      'tag': tag,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Mettre à jour les compteurs par type de producteur
    if (post.producerType != null) {
      _producerTypeInteractions[post.producerType!] = 
        (_producerTypeInteractions[post.producerType!] ?? 0) + 1;
    }
    
    // Mettre à jour les compteurs par tag si spécifié
    if (tag != null) {
      _tagInteractions[tag] = (_tagInteractions[tag] ?? 0) + 1;
    }
    
    // Si le post a des tags, les enregistrer
    if (post.tags != null && post.tags!.isNotEmpty) {
      for (var tag in post.tags!) {
        _tagInteractions[tag] = (_tagInteractions[tag] ?? 0) + 1;
      }
    }
    
    // Recalculer les préférences tous les 5 interactions
    if (_interactionHistory.length % 5 == 0) {
      _recalculatePreferences();
      updateUserPreferences();
    }
    
    notifyListeners();
  }
  
  // Pour enregistrer un like
  void logLike(Post post) {
    logUserInteraction('likes', post);
  }
  
  // Pour enregistrer un intérêt
  void logInterest(Post post) {
    logUserInteraction('interests', post);
  }
  
  // Pour enregistrer un commentaire
  void logComment(Post post) {
    logUserInteraction('comments', post);
  }
  
  // Pour enregistrer un choice
  void logChoice(Post post) {
    logUserInteraction('choices', post);
  }
  
  // Pour enregistrer un partage
  void logShare(Post post) {
    logUserInteraction('shares', post);
  }
  
  // Pour enregistrer une vue (quand un post est affiché suffisamment longtemps)
  void logView(Post post) {
    logUserInteraction('views', post);
  }
  
  // Mettre à jour les préférences de secteur
  void updateSectorPreference(String sector, double value) {
    _sectorPreferences[sector] = value;
    notifyListeners();
    updateUserPreferences();
  }
  
  // Mettre à jour les préférences de type de contenu
  void updateContentTypePreference(String contentType, double value) {
    _contentTypePreferences[contentType] = value;
    notifyListeners();
    updateUserPreferences();
  }
  
  // Méthode principale pour charger le feed initial
  Future<void> loadInitialFeed() async {
    _isLoadingMore = true;
    _currentPage = 1;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Vider les listes existantes
      _posts = [];
      _restaurantPosts = [];
      _leisurePosts = [];
      _userPosts = [];
      
      // Charger les préférences avant de charger le feed
      await initializePreferences();
      
      // Charger les trois types de post en parallèle
      await Future.wait([
        _loadRestaurantPosts(),
        _loadLeisurePosts(),
        _loadUserPosts(),
      ]);
      
      // Organiser les posts pour la diversité
      _organizePostsForDiversity();
      
      _isLoadingMore = false;
      _hasError = false;
      notifyListeners();
    } catch (e) {
      print('❌ Erreur lors du chargement du feed: $e');
      _isLoadingMore = false;
      _hasError = true;
      _errorMessage = 'Erreur lors du chargement du feed: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Charger plus de posts pour le feed
  Future<void> loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    
    _isLoadingMore = true;
    _currentPage++;
    notifyListeners();
    
    try {
      // Charger plus de posts à partir des trois sources en parallèle
      await _loadMoreBalancedPosts();
      
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      print('Erreur lors du chargement de plus de posts: $e');
      _isLoadingMore = false;
      _currentPage--;
      notifyListeners();
    }
  }
  
  // Charger les posts de restaurants
  Future<void> _loadRestaurantPosts() async {
    try {
      if (_isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
      
      final posts = await _apiService.getRestaurantPosts(
        userId,
        page: _currentPage,
        limit: _postsPerPage,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⚠️ Timeout lors du chargement des posts de restaurants');
          throw TimeoutException('La connexion au serveur a pris trop de temps. Veuillez vérifier votre connexion internet et réessayer.');
        },
      );
      
      _restaurantPosts.addAll(posts);
      _hasMorePosts = posts.length >= _postsPerPage;
      _currentPage++;
      
      notifyListeners();
    } on TimeoutException catch (e) {
      print('❌ Timeout lors du chargement des posts de restaurants: $e');
      // Gérer spécifiquement les erreurs de timeout
    } catch (e) {
      print('❌ Error loading restaurant posts: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
  
  // Charger les posts de loisirs
  Future<void> _loadLeisurePosts() async {
    try {
      if (_isLoadingMore) return;
      _isLoadingMore = true;
      
      final posts = await _apiService.getLeisurePosts(
        userId,
        page: _currentPage,
        limit: _postsPerPage,
      );
      
      _leisurePosts.addAll(posts);
      _hasMorePosts = posts.length >= _postsPerPage;
      _currentPage++;
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading leisure posts: $e');
    } finally {
      _isLoadingMore = false;
    }
  }
  
  // Charger les posts d'utilisateurs
  Future<void> _loadUserPosts() async {
    try {
      if (_isLoadingMore) return;
      _isLoadingMore = true;
      
      final posts = await _apiService.getUserPosts(
        userId,
        page: _currentPage,
        limit: _postsPerPage,
      );
      
      _userPosts.addAll(posts);
      _hasMorePosts = posts.length >= _postsPerPage;
      _currentPage++;
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading user posts: $e');
    } finally {
      _isLoadingMore = false;
    }
  }
  
  // Organiser les posts pour la diversité
  void _organizePostsForDiversity() {
    // Mélanger les listes pour davantage de diversité
    _restaurantPosts.shuffle();
    _leisurePosts.shuffle();
    _userPosts.shuffle();
    
    // Calculer combien de posts prendre de chaque catégorie en fonction des préférences
    final totalPosts = _restaurantPosts.length + _leisurePosts.length + _userPosts.length;
    final maxPostsToShow = math.min(totalPosts, 30); // Limiter à 30 posts maximum
    
    // Calculer la répartition en fonction des préférences utilisateur
    final restaurantCount = (maxPostsToShow * _sectorPreferences['restaurant']!).round();
    final leisureCount = (maxPostsToShow * _sectorPreferences['leisure']!).round();
    final userCount = maxPostsToShow - restaurantCount - leisureCount;
    
    // Limiter aux nombres disponibles
    final actualRestaurantCount = math.min(restaurantCount, _restaurantPosts.length);
    final actualLeisureCount = math.min(leisureCount, _leisurePosts.length);
    final actualUserCount = math.min(userCount, _userPosts.length);
    
    // Créer une liste temporaire avec la répartition calculée
    List<Post> tempPosts = [];
    
    // Ajouter les posts en fonction du poids calculé
    tempPosts.addAll(_restaurantPosts.sublist(0, actualRestaurantCount));
    tempPosts.addAll(_leisurePosts.sublist(0, actualLeisureCount));
    tempPosts.addAll(_userPosts.sublist(0, actualUserCount));
    
    // Trier par pertinence et nouveauté
    _sortPostsByRelevance(tempPosts);
    
    // Mettre à jour la liste principale
    _posts = tempPosts;
  }
  
  // Trier les posts par pertinence en fonction des préférences utilisateur
  void _sortPostsByRelevance(List<Post> posts) {
    // Calculer un score pour chaque post basé sur:
    // - Fraîcheur (plus récent = score plus élevé)
    // - Correspondance aux intérêts (tags correspondants aux intérêts = score plus élevé)
    // - Pertinence de la catégorie (type de producteur préféré = score plus élevé)
    // - Popularité (nombre de likes, commentaires, etc.)
    posts.forEach((post) {
      double score = 0.0;
      
      // Score de fraîcheur (posts des dernières 24h = +5, des dernières 72h = +3, dernière semaine = +1)
      final now = DateTime.now();
      DateTime postDate;
      try {
        postDate = post.postedAt != null ? post.posted_at : now;
      } catch (e) {
        postDate = now;
      }
      
      final difference = now.difference(postDate).inHours;
      
      if (difference <= 24) {
        score += 5.0;
      } else if (difference <= 72) {
        score += 3.0;
      } else if (difference <= 168) { // 1 semaine
        score += 1.0;
      }
      
      // Score de correspondance aux intérêts
      if (post.tags != null) {
        double tagScore = 0.0;
        for (var tag in post.tags!) {
          tagScore += (_tagInteractions[tag] ?? 0) * 0.5;
        }
        score += math.min(tagScore, 5.0); // Plafonner à 5 points max
      }
      
      // Score de pertinence de catégorie
      if (post.producerType != null) {
        final categoryPreference = _sectorPreferences[post.producerType] ?? 0.0;
        score += categoryPreference * 10.0; // Max 10 points pour la catégorie
      }
      
      // Score de popularité
      final likesCount = post.likesCount ?? 0;
      final commentsCount = post.commentsCount ?? 0;
      score += math.min((likesCount / 10.0) + (commentsCount / 5.0), 3.0); // Max 3 points pour la popularité
      
      // Enregistrer le score dans une propriété temporaire
      post.relevanceScore = score;
    });
    
    // Trier par score de pertinence décroissant
    posts.sort((a, b) => (b.relevanceScore ?? 0).compareTo(a.relevanceScore ?? 0));
    
    // Appliquer une légère randomisation pour éviter que l'ordre soit trop prévisible
    // Diviser en tranches de pertinence similaire et mélanger à l'intérieur
    if (posts.length > 10) {
      final highRelevance = posts.sublist(0, posts.length ~/ 3);
      final mediumRelevance = posts.sublist(posts.length ~/ 3, 2 * posts.length ~/ 3);
      final lowRelevance = posts.sublist(2 * posts.length ~/ 3);
      
      highRelevance.shuffle();
      mediumRelevance.shuffle();
      
      posts = [...highRelevance, ...mediumRelevance, ...lowRelevance];
    }
  }
  
  // Charger plus de posts en maintenant l'équilibre
  Future<void> _loadMoreBalancedPosts() async {
    try {
      // Déterminer combien de posts de chaque type charger en fonction des préférences
      final restaurantRatio = _sectorPreferences['restaurant'] ?? 0.5;
      final leisureRatio = _sectorPreferences['leisure'] ?? 0.3;
      final userRatio = _sectorPreferences['user'] ?? 0.2;
      
      // Charger plus de posts en parallèle selon les ratios
      final futures = <Future>[];
      
      // Seulement charger les catégories qui ont besoin de plus de posts
      if (restaurantRatio > 0.05) {
        futures.add(_loadMoreCategoryPosts('restaurant'));
      }
      
      if (leisureRatio > 0.05) {
        futures.add(_loadMoreCategoryPosts('leisure'));
      }
      
      if (userRatio > 0.05) {
        futures.add(_loadMoreCategoryPosts('user'));
      }
      
      await Future.wait(futures);
      
      // Réorganiser les posts avec les nouvelles données
      _organizePostsForDiversity();
      
    } catch (e) {
      print('Erreur lors du chargement équilibré des posts: $e');
      throw e;
    }
  }
  
  // Charger plus de posts d'une catégorie spécifique
  Future<void> _loadMoreCategoryPosts(String category) async {
    try {
      List<Post> newPosts = [];
      
      switch (category) {
        case 'restaurant':
          newPosts = await _apiService.getRestaurantPosts(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          _restaurantPosts.addAll(newPosts);
          break;
        
        case 'leisure':
          newPosts = await _apiService.getLeisurePosts(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          _leisurePosts.addAll(newPosts);
          break;
        
        case 'user':
          newPosts = await _apiService.getUserPosts(
            userId,
            page: _currentPage,
            limit: _postsPerPage
          );
          _userPosts.addAll(newPosts);
          break;
      }
      
      _hasMorePosts = newPosts.length >= _postsPerPage ~/ 3;
      
    } catch (e) {
      print('❌ Erreur lors du chargement des posts de catégorie $category: $e');
    }
  }
  
  // Charger des posts additionnels d'un type spécifique - Cette méthode est maintenant divisée en méthodes spécifiques
  Future<void> _loadAdditionalPosts(
    dynamic Function(String userId, {int? page, int? limit, String? filter}) fetchFunction,
  ) async {
    try {
      // Cette méthode est désormais remplacée par des méthodes spécifiques
      print('⚠️ Méthode obsolète: utiliser _loadRestaurantPosts, _loadLeisurePosts ou _loadUserPosts');
    } catch (e) {
      print('❌ Erreur lors du chargement de posts additionnels: $e');
    }
  }
  
  // S'assurer que les photos de profil sont valides
  void _ensureValidProfilePhotos(List<Post> posts) {
    for (var post in posts) {
      // Vérifier la photo de profil de l'auteur
      if (post.author != null) {
        if (post.author!.avatar == null || 
            post.author!.avatar!.isEmpty || 
            !_isValidUrl(post.author!.avatar!)) {
          // Générer un avatar par défaut basé sur l'ID de l'auteur
          post.author!.avatar = _generateDefaultAvatarUrl(post.author!.id);
        }
      }
      
      // Vérifier les URLs des médias
      if (post.media.isNotEmpty) {
        for (var i = 0; i < post.media.length; i++) {
          if (!_isValidUrl(post.media[i].url)) {
            // Remplacer par une image par défaut
            post.media[i] = post.media[i].copyWithUrl('https://via.placeholder.com/300');
          }
        }
      }
    }
  }
  
  // Vérifier si une URL est valide
  bool _isValidUrl(String url) {
    return url.isNotEmpty && 
           (url.startsWith('http://') || url.startsWith('https://'));
  }
  
  // Générer une URL d'avatar par défaut
  String _generateDefaultAvatarUrl(String userId) {
    // Utiliser un service d'avatar comme Gravatar, Robohash, etc.
    return 'https://robohash.org/$userId?set=set4';
  }
  
  // Méthode pour gérer les interactions utilisateur avec les posts
  Future<void> handlePostInteraction(String postId, String interactionType) async {
    // Mettre à jour les préférences utilisateur en fonction des interactions
    if (interactionType == 'like') {
      // Trouver le post concerné
      final post = _getPostById(postId);
      if (post.id.isNotEmpty) {
        // Ajuster les préférences en fonction du type de post
        final category = _getCategoryForPost(post);
        _sectorPreferences[category] = (_sectorPreferences[category] ?? 0.5) * 1.1;
        
        // Normaliser les préférences pour qu'elles totalisent 1.0
        _normalizeSectorPreferences();
        
        // Synchroniser avec le backend
        updateUserPreferences();
      }
    }
  }
  
  // Normaliser les préférences de secteur pour qu'elles totalisent 1.0
  void _normalizeSectorPreferences() {
    final total = _sectorPreferences.values.fold(0.0, (sum, value) => sum + value);
    if (total > 0) {
      _sectorPreferences.forEach((key, value) {
        _sectorPreferences[key] = value / total;
      });
    }
  }
  
  Post _getPostById(String postId) {
    final post = _posts.firstWhere(
      (p) => p.id == postId, 
      orElse: () => Post(
        id: '',
        userId: '',
        userName: '',
        description: '',
        createdAt: DateTime.now(),
        content: '',
        title: '',
      )
    );
    
    return post;
  }
  
  String _getCategoryForPost(Post post) {
    if ((post.isProducerPost ?? false) && !(post.isLeisureProducer ?? false)) {
      return 'restaurant';
    } else if ((post.isProducerPost ?? false) && (post.isLeisureProducer ?? false)) {
      return 'leisure';
    } else {
      return 'user';
    }
  }

  void _processPostMedia(Post post) {
    // Traiter les médias du post pour s'assurer qu'ils sont valides
    for (int i = 0; i < post.media.length; i++) {
      if (post.media[i].url.isEmpty || !_isValidUrl(post.media[i].url)) {
        // Remplacer l'URL invalide par une image placeholder
        post.media[i] = post.media[i].copyWithUrl('https://via.placeholder.com/300');
      }
    }
  }

  Future<List<Post>> getUserPosts(String userId, {int page = 1, int limit = 20}) async {
    try {
      final token = await AuthService.getTokenStatic();
      final response = await http.get(
        Uri.parse('${_apiService.getApiBaseUrl()}/api/users/$userId/posts?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = convert.jsonDecode(response.body);
        return data.map((post) => Post.fromJson(post)).toList();
      } else {
        print('❌ Erreur lors de la récupération des posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des posts: $e');
      return [];
    }
  }

  Future<void> loadUserData() async {
    try {
      final token = await _apiService.getAuthToken();
      if (token == null || token.isEmpty) {
        print('❌ Token non trouvé, impossible de charger les données utilisateur.');
        return;
      }
      // ... (Rest of the method)
    } catch (e) {
      // ...
    }
  }

  Future<void> toggleLike(String postId) async {
    try {
      await _apiService.toggleLike(userId, postId);
      // Optimistic update or refresh feed after API call
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        _posts[index] = post.copyWith(
          isLiked: !(post.isLiked ?? false),
          likesCount: (post.likesCount ?? 0) + (post.isLiked ?? false ? -1 : 1),
        );
        notifyListeners();
      }
    } catch (e) {
      print("❌ Error toggling like in FeedController: $e");
      // Optionally revert optimistic update
    }
  }

  Future<void> markInterested(Post post, String source) async {
    try {
      await _apiService.markInterested(
        userId,
        post.producerId ?? post.authorId ?? '', // Use producerId first
        targetType: post.producerType ?? 'producer', // Pass type
        isLeisureProducer: post.isLeisureProducer ?? false, // Pass flag
        source: source,
        interested: true,
      );
      // Optional: Update UI or state
    } catch (e) {
      print("❌ Error marking interested in FeedController: $e");
    }
  }

  Future<Map<String, dynamic>> getUserDetails() async {
    try {
      final result = await _apiService.getUserDetails(userId);
      return result ?? <String, dynamic>{};
    } catch (e) {
      print('Error fetching user details: $e');
      return <String, dynamic>{};
    }
  }

  Future<List<Map<String, dynamic>>> getRestaurantFollowers() async {
    try {
      final followers = await _apiService.getProducerFollowers(userId);
      // Convert List<dynamic> to List<Map<String, dynamic>>
      return followers
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des followers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPostInteractions(String postId, String interactionType) async {
    try {
       return await _apiService.getPostInteractions(postId, interactionType);
    } catch (e) {
       print('Error fetching post interactions: $e');
       return [];
    }
  }

  Future<List<dynamic>> _fetchDataFromEndpoint(String endpoint, Map<String, dynamic>? queryParams) async {
    try {
      // Pass Map<String, dynamic>? directly
      final response = await _apiService.get(endpoint, queryParams: queryParams);

      // Process the Map response (assuming items are in a list)
      if (response is Map<String, dynamic>) {
        if (response['items'] is List) {
            return response['items'] as List<dynamic>;
        } else if (response['posts'] is List) {
            return response['posts'] as List<dynamic>;
        } else {
            // Return an empty list if we can't find a list in the response
            print('⚠️ Unexpected response format from $endpoint: no items or posts list found');
            return [];
        }
      } else if (response is List) { // Fallback if the response IS the list
          return response as List<dynamic>;
      } else {
        // If response is neither a Map nor a List, return an empty list
        print('⚠️ Unexpected response format from $endpoint: not a Map or List');
        return [];
      }
    } catch (e) {
      print("Error fetching data from $endpoint: $e");
      return [];
    }
  }
}

class RestaurantFeedController extends ChangeNotifier {
  final String userId;
  final ApiService _apiService = ApiService();
  
  List<Post> _posts = [];
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  FeedType _currentFilter = FeedType.myRestaurant;
  String _cuisineFilter = 'Tous';
  Map<String, Map<String, dynamic>> _interactionStats = {};
  
  RestaurantFeedController({required this.userId});
  
  // Getters
  List<Post> get posts => _posts;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _hasMorePosts;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  Map<String, Map<String, dynamic>> get interactionStats => _interactionStats;
  
  // Méthodes publiques
  Future<void> loadFeed({FeedType filter = FeedType.myRestaurant}) async {
    _isLoadingMore = true;
    _hasError = false;
    _currentFilter = filter;
    _currentPage = 1;
    notifyListeners();
    
    try {
      final result = await _fetchFeed(filter, _currentPage);
      _posts = result.posts;
      _hasMorePosts = result.hasMore;
      
      // Si nous chargeons les interactions des clients, récupérer également les stats
      if (filter == FeedType.customerInteractions) {
        await _loadInteractionStats();
      }
      
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      _isLoadingMore = false;
      notifyListeners();
      print('❌ Erreur lors du chargement du feed: $e');
    }
  }
  
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final result = await _fetchFeed(_currentFilter, _currentPage + 1);
      _posts.addAll(result.posts);
      _hasMorePosts = result.hasMore;
      _currentPage++;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      _isLoadingMore = false;
      notifyListeners();
      print('❌ Erreur lors du chargement de plus de posts: $e');
    }
  }
  
  Future<void> refreshFeed() async {
    return loadFeed(filter: _currentFilter);
  }
  
  void filterFeed(FeedType filter) {
    if (_currentFilter == filter) return;
    loadFeed(filter: filter);
  }
  
  void setCuisineFilter(String category) {
    _cuisineFilter = category;
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
      print('❌ Erreur lors du like: $e');
    }
  }
  
  Future<void> markInterested(Post post) async {
    final int index = _posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;
    
    final oldPost = _posts[index];
    final bool isCurrentlyInterested = oldPost.isInterested ?? false;
    final int currentInterests = oldPost.interestedCount ?? 0;
    
    // Mise à jour optimiste
    _posts[index] = oldPost.copyWith(
      isInterested: !isCurrentlyInterested,
      interestedCount: isCurrentlyInterested ? 
          (currentInterests > 0 ? currentInterests - 1 : 0) : 
          currentInterests + 1,
    );
    notifyListeners();
    
    try {
      await _apiService.markInterested(
        userId, 
        post.id,
        isLeisureProducer: post.isLeisureProducer ?? false
      );
    } catch (e) {
      // Revenir en arrière en cas d'erreur
      _posts[index] = oldPost;
      notifyListeners();
      print('❌ Erreur lors du marquage d\'intérêt: $e');
    }
  }
  
  // Nouvelle méthode pour récupérer les détails des interactions des clients
  Future<void> _loadInteractionStats() async {
    try {
      final stats = await _apiService.getProducerInteractionStats(userId);
      if (stats is Map<String, dynamic>) {
        _interactionStats = {};
        // Convertir la structure pour s'assurer qu'elle correspond à Map<String, Map<String, dynamic>>
        stats.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _interactionStats[key] = value;
          } else {
            _interactionStats[key] = {'value': value};
          }
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des statistiques d\'interaction: $e');
    }
  }
  
  // Récupérer les détails d'un utilisateur qui a interagi
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final details = await _apiService.getUserDetails(userId);
      // Ensure non-null result
      return details ?? {};
    } catch (e) {
      print("Error getting user details: $e");
      return {};
    }
  }
  
  // Obtenir les followers du restaurant
  Future<List<Map<String, dynamic>>> getRestaurantFollowers() async {
    try {
      final followers = await _apiService.getProducerFollowers(userId);
      // Convert List<dynamic> to List<Map<String, dynamic>>
      return followers
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des followers: $e');
      return [];
    }
  }
  
  // Voir les détails des utilisateurs intéressés par un post
  Future<List<Map<String, dynamic>>> getPostInteractions(String postId, String interactionType) async {
    try {
      return await _apiService.getPostInteractions(postId, interactionType);
    } catch (e) {
      print('❌ Erreur lors de la récupération des interactions: $e');
      return [];
    }
  }
  
  // Méthodes privées
  Future<FeedResult> _fetchFeed(FeedType filter, int page) async {
    // Construire les paramètres de requête
    Map<String, dynamic> queryParams = {
      'page': page,
      'limit': 10,
    };
    
    // Ajouter le filtre de cuisine si nécessaire
    if (_cuisineFilter != 'Tous') {
      queryParams['category'] = _cuisineFilter;
    }
    
    try {
      // Ajouter un paramètre de filtre basé sur le type de feed
      String? filterParam;
      switch (filter) {
        case FeedType.customerInteractions:
          filterParam = 'interactions';
          break;
        case FeedType.localTrends:
          filterParam = 'trends';
          break;
        default:
          filterParam = null;
      }
      
      final dynamic result = await _apiService.getRestaurantPosts(
        userId,
        page: page,
        limit: 10,
        filter: filterParam,
      );
      
      List<Post> posts = [];
      
      // Traiter directement si c'est déjà une liste de Post
      if (result is List<Post>) {
        posts = result;
      }
      // Si c'est une liste de dynamic, il faut convertir chaque élément en Post
      else if (result is List) {
        for (var item in result) {
          if (item is Post) {
            posts.add(item);
          } else if (item is Map<String, dynamic>) {
            try {
              posts.add(Post.fromJson(item));
            } catch (e) {
              print('❌ Erreur de conversion Map to Post: $e');
            }
          }
        }
      }
      // Si c'est une Map, il faut extraire les posts
      else if (result is Map<String, dynamic>) {
        // Vérifier si la map contient une clé 'posts'
        if (result.containsKey('posts')) {
          final dynamic postsData = result['posts'];
          if (postsData is List) {
            for (var item in postsData) {
              if (item is Post) {
                posts.add(item);
              } else if (item is Map<String, dynamic>) {
                try {
                  posts.add(Post.fromJson(item));
                } catch (e) {
                  print('❌ Erreur de conversion Map to Post (posts): $e');
                }
              }
            }
          }
        }
        // Alternative: vérifier si la map contient une clé 'data'
        else if (result.containsKey('data')) {
          final dynamic dataList = result['data'];
          if (dataList is List) {
            for (var item in dataList) {
              if (item is Post) {
                posts.add(item);
              } else if (item is Map<String, dynamic>) {
                try {
                  posts.add(Post.fromJson(item));
                } catch (e) {
                  print('❌ Erreur de conversion Map to Post (data): $e');
                }
              }
            }
          }
        }
        else {
          print('❌ Format de réponse non reconnu: $result');
        }
      }
      else {
        throw Exception('Format de réponse inattendu: ${result.runtimeType}');
      }
      
      return FeedResult(
        posts: posts,
        hasMore: posts.length >= 10,
      );
    } catch (e) {
      print('❌ Erreur lors de la récupération du feed: $e');
      throw e;
    }
  }
}

class FeedResult {
  final List<Post> posts;
  final bool hasMore;
  
  FeedResult({
    required this.posts,
    required this.hasMore,
  });
}

enum FeedType {
  myRestaurant,
  customerInteractions,
  localTrends,
}

Future<FeedResult> getFeeds(
  String endpoint, {
  Map<String, dynamic>? queryParams,
  String? filter,
}) async {
  try {
    // Créer une instance locale d'ApiService
    final apiService = ApiService();
    
    final response = await apiService.get(endpoint, queryParams: queryParams);
    final dynamic responseData = parseResponseData(response);
    final List<Post> posts = [];
    
    // Si le résultat est déjà une liste de Post, on la retourne directement
    if (responseData is List<Post>) {
      return FeedResult(
        posts: responseData,
        hasMore: responseData.length >= 10,
      );
    }
    // Si c'est une liste de dynamic, il faut convertir chaque élément en Post
    else if (responseData is List) {
      for (var item in responseData) {
        if (item is Post) {
          posts.add(item);
        } else if (item is Map<String, dynamic>) {
          try {
            posts.add(Post.fromJson(item));
          } catch (e) {
            print('❌ Erreur de conversion Map to Post: $e');
          }
        }
      }
      
      return FeedResult(
        posts: posts,
        hasMore: posts.length >= 10,
      );
    }
    // Si c'est une Map, il faut extraire les posts
    else if (responseData is Map<String, dynamic>) {
      // Vérifier si la map contient une clé 'posts'
      if (responseData.containsKey('posts')) {
        final dynamic postsData = responseData['posts'];
        if (postsData is List) {
          for (var item in postsData) {
            if (item is Post) {
              posts.add(item);
            } else if (item is Map<String, dynamic>) {
              try {
                posts.add(Post.fromJson(item));
              } catch (e) {
                print('❌ Erreur de conversion Map to Post (posts): $e');
              }
            }
          }
        }
        
        // Vérification du hasMore
        bool hasMore = false;
        if (responseData.containsKey('hasMore')) {
          final morePosts = responseData['hasMore'];
          if (morePosts is bool) {
            hasMore = morePosts;
          } else if (morePosts is String) {
            hasMore = morePosts.toLowerCase() == 'true';
          } else if (morePosts is int) {
            hasMore = morePosts > 0;
          }
        } else {
          hasMore = posts.length >= 10;
        }
        
        return FeedResult(
          posts: posts,
          hasMore: hasMore,
        );
      }
      // Alternative: vérifier si la map contient une clé 'data'
      else if (responseData.containsKey('data')) {
        final dynamic dataList = responseData['data'];
        if (dataList is List) {
          for (var item in dataList) {
            if (item is Post) {
              posts.add(item);
            } else if (item is Map<String, dynamic>) {
              try {
                posts.add(Post.fromJson(item));
              } catch (e) {
                print('❌ Erreur de conversion Map to Post (data): $e');
              }
            }
          }
        }
        
        return FeedResult(
          posts: posts,
          hasMore: posts.length >= 10,
        );
      }
      else {
        print('❌ Format de réponse non reconnu: $responseData');
        return FeedResult(posts: [], hasMore: false);
      }
    }
    else {
      throw Exception('Format de réponse inattendu: ${responseData.runtimeType}');
    }
  } catch (e) {
    print('❌ Erreur lors de la récupération du feed: $e');
    throw e;
  }
}

Future<FeedResult> _fetchFeed(String url) async {
  try {
    final client = http.Client();
    final response = await client.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger le flux, code: ${response.statusCode}');
    }
    
    final dynamic responseData = parseResponseData(response);
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

Future<List<Post>> _convertToPosts(dynamic data) async {
  final List<Post> posts = [];
  if (data is List) {
    for (var item in data) {
      if (item is Post) {
        posts.add(item);
      } else if (item is Map<String, dynamic>) {
        try {
          posts.add(Post.fromJson(item));
        } catch (e) {
          print('❌ Erreur de conversion Map to Post: $e');
        }
      }
    }
  }
  return posts;
}

// Méthode utilitaire pour convertir en toute sécurité une valeur en int
int? _parseIntSafely(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

dynamic parseResponseData(dynamic response) {
  if (response is String) {
    return convert.jsonDecode(response);
  } else {
    return response;
  }
} 