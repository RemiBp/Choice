import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animations/animations.dart';

// Models
import '../models/post.dart';
import '../models/media.dart';
import '../models/comment.dart';

// Services
import '../services/api_service.dart';
import '../utils/constants.dart';

// Screens
import 'producer_screen.dart';
import 'profile_screen.dart';
import 'eventLeisure_screen.dart';
import 'producerLeisure_screen.dart';
import 'reels_view_screen.dart';

// Widgets
import '../widgets/animations/like_animation.dart';

class FeedScreen extends StatefulWidget {
  final String userId;

  const FeedScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiService _apiService = ApiService();
  final List<dynamic> _posts = [];
  bool _isLoading = false;
  bool _hasMorePosts = true;
  int _currentPage = 1;
  final int _postsPerPage = 10;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _fetchFeed();
    
    // Add scroll listener for infinite scrolling
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent * 0.8 && 
          !_isLoading && 
          _hasMorePosts) {
        _loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Récupère les données du feed depuis le backend pour la première fois
  void _fetchFeed() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final newPosts = await _getFeedData(widget.userId, _currentPage, _postsPerPage);
      setState(() {
        _posts.addAll(newPosts);
        _isLoading = false;
        _hasMorePosts = newPosts.length == _postsPerPage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ Error fetching feed: $e');
    }
  }
  
  /// Charge plus de posts quand l'utilisateur scrolle
  void _loadMorePosts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _currentPage++;
    });
    
    try {
      final newPosts = await _getFeedData(widget.userId, _currentPage, _postsPerPage);
      setState(() {
        _posts.addAll(newPosts);
        _isLoading = false;
        _hasMorePosts = newPosts.length == _postsPerPage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentPage--; // Revert page increase on error
      });
      print('❌ Error loading more posts: $e');
    }
  }

  /// Effectue la requête HTTP pour récupérer les posts
  Future<List<dynamic>> _getFeedData(String userId, int page, int limit) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/posts', {
        'userId': userId,
        'page': page.toString(),
        'limit': limit.toString()
      });
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/posts', {
        'userId': userId,
        'page': page.toString(),
        'limit': limit.toString()
      });
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/posts?userId=$userId&page=$page&limit=$limit');
    }
    
    try {
      print('🔍 Requête vers : $url');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📩 Réponse reçue : ${data.length} posts');
        return data;
      } else {
        print('❌ Erreur lors de la récupération du feed : ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
      return [];
    }
  }

  /// Récupère les informations d'un auteur (producteur ou utilisateur)
  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/users/$userId');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/users/$userId');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/users/$userId');
    }
    
    try {
      print('🔍 Requête utilisateur vers : $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print('📩 Profil utilisateur récupéré avec succès');
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération du profil utilisateur : ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur réseau pour le profil utilisateur : $e');
      return null;
    }
  }

  // Cache pour éviter des appels répétés à l'API pour les mêmes auteurs
  final Map<String, Map<String, dynamic>> _authorCache = {};

  // Liste pour suivre les IDs des producers qui ont échoué
  final Set<String> _failedProducerIds = <String>{};
  
  Future<Map<String, dynamic>?> _fetchAuthorDetails(String authorId, bool isProducer, {bool isLeisureProducer = false}) async {
    // Vérifier si l'auteur est déjà dans le cache
    final cacheKey = '${isProducer ? (isLeisureProducer ? "leisure" : "producer") : "user"}_$authorId';
    if (_authorCache.containsKey(cacheKey)) {
      // Silencieux pour réduire les logs
      return _authorCache[cacheKey];
    }
    
    // URL par défaut fiable pour les placeholders
    final placeholderUrl = 'https://storage.googleapis.com/choice-app/images/placeholder.jpg';
    
    // Si c'est un producer et qu'on a eu des erreurs précédentes, essayer directement en tant que leisure
    String endpoint;
    if (isProducer && _failedProducerIds.contains(authorId)) {
      endpoint = 'leisureProducers';
      isLeisureProducer = true;
    } else {
      endpoint = isLeisureProducer ? 'leisureProducers' : (isProducer ? 'producers' : 'users');
    }
    
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/$endpoint/$authorId');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/$endpoint/$authorId');
    } else {
      url = Uri.parse('$baseUrl/api/$endpoint/$authorId');
    }

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> authorData = json.decode(response.body);
        
        // S'assurer que les URLs sont valides pour éviter les erreurs de résolution
        if (authorData.containsKey('photo') && authorData['photo'] == null) {
          authorData['photo'] = placeholderUrl;
        }
        if (authorData.containsKey('photo_url') && authorData['photo_url'] == null) {
          authorData['photo_url'] = placeholderUrl;
        }
        if (authorData.containsKey('image') && authorData['image'] == null) {
          authorData['image'] = placeholderUrl;
        }
        
        // Ajouter un indicateur du type de producteur dans les données retournées
        authorData['_producerType'] = endpoint;
        
        // Stocker dans le cache pour éviter des appels répétés
        _authorCache[cacheKey] = authorData;
        
        return authorData;
      } else {
        // Fallback : si la requête sur "producers" échoue, essaye "leisureProducers"
        if (!isLeisureProducer && isProducer && endpoint != 'leisureProducers') {
          // Ajouter l'ID à la liste des producers qui ont échoué
          _failedProducerIds.add(authorId);
          
          endpoint = 'leisureProducers';
          
          // Construire une nouvelle URL pour le fallback
          if (baseUrl.startsWith('http://')) {
            final domain = baseUrl.replaceFirst('http://', '');
            url = Uri.http(domain, '/api/$endpoint/$authorId');
          } else if (baseUrl.startsWith('https://')) {
            final domain = baseUrl.replaceFirst('https://', '');
            url = Uri.https(domain, '/api/$endpoint/$authorId');
          } else {
            url = Uri.parse('$baseUrl/api/$endpoint/$authorId');
          }
          
          final fallbackResponse = await http.get(url);

          if (fallbackResponse.statusCode == 200) {
            final Map<String, dynamic> authorData = json.decode(fallbackResponse.body);
            
            // S'assurer que les URLs sont valides
            if (authorData.containsKey('photo') && authorData['photo'] == null) {
              authorData['photo'] = placeholderUrl;
            }
            if (authorData.containsKey('photo_url') && authorData['photo_url'] == null) {
              authorData['photo_url'] = placeholderUrl;
            }
            if (authorData.containsKey('image') && authorData['image'] == null) {
              authorData['image'] = placeholderUrl;
            }
            
            // Marquer ce producteur comme un leisure producer
            authorData['_producerType'] = 'leisureProducers';
            
            // Mise à jour des posts pour refléter ce changement
            final postIndex = _posts.indexWhere((post) => post['producer_id'] == authorId);
            if (postIndex != -1) {
              setState(() {
                _posts[postIndex]['is_leisure_producer'] = true;
              });
            }
            
            // Stocker dans le cache avec le bon type
            _authorCache[cacheKey] = authorData;
            return authorData;
          }
        }
      }
    } catch (e) {
      // En cas d'erreur, retourner un objet minimal pour éviter les crashs
      Map<String, dynamic> fallbackData = {
        'name': isProducer ? 'Producteur' : 'Utilisateur',
        'photo': placeholderUrl,
        'photo_url': placeholderUrl,
        'image': placeholderUrl,
        '_producerType': endpoint
      };
      
      _authorCache[cacheKey] = fallbackData;
      return fallbackData;
    }

    // Retourne un objet minimal si toutes les tentatives échouent
    Map<String, dynamic> fallbackData = {
      'name': isProducer ? 'Producteur' : 'Utilisateur',
      'photo': placeholderUrl,
      'photo_url': placeholderUrl,
      'image': placeholderUrl,
      '_producerType': endpoint
    };
    
    _authorCache[cacheKey] = fallbackData;
    return fallbackData;
  }

  /// Like un post
  Future<void> _likePost(String postId, Map<String, dynamic> post) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/posts/$postId/like');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/posts/$postId/like');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/posts/$postId/like');
    }
    
    final body = {
      'userId': widget.userId,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          post['isLiked'] = data['isLiked'] ?? true;
          post['likesCount'] = data['likesCount'] ?? (post['likesCount'] ?? 0) + 1;
        });
        print('✅ Post liké avec succès');
      } else {
        print('❌ Erreur lors du like du post : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors du like du post : $e');
    }
  }

  Future<void> _markInterested(String targetId, Map<String, dynamic> post, {bool isLeisureProducer = false}) async {
    // Vérification que le post provient d'un producer
    final bool isProducer = post['producer_id'] != null;
    if (!isProducer) {
      print('⚠️ Interest/Choice uniquement pour les posts de producers');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Option uniquement disponible pour les publications de producteurs')),
      );
      return;
    }

    // Afficher l'indicateur de chargement
    setState(() {
      post['isLoading'] = true;
    });

    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/choicexinterest/interested');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/choicexinterest/interested');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/choicexinterest/interested');
    }
    
    // Format de données attendu par le backend - simplifié pour correspondre à l'API
    final body = {
      'userId': widget.userId,
      'targetId': targetId, // ID du producer ou de l'événement
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Convertir explicitement en booléen pour éviter les erreurs de type 'Null is not a subtype of bool'
        final bool updatedInterested = responseData['interested'] == true;
        setState(() {
          post['interested'] = updatedInterested;
          post['isLoading'] = false;
        });
        
        // Feedback à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedInterested ? 'Ajouté à vos intérêts' : 'Retiré de vos intérêts'),
            backgroundColor: updatedInterested ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Mettre à jour le profil utilisateur pour refléter le changement
        _updateUserProfile();
        
        print('✅ Interested mis à jour avec succès');
      } else {
        setState(() {
          post['isLoading'] = false;
        });
        print('❌ Erreur lors de la mise à jour d\'Interested : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        post['isLoading'] = false;
      });
      print('❌ Erreur réseau lors de la mise à jour d\'Interested : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markChoice(String targetId, Map<String, dynamic> post, {bool isLeisureProducer = false}) async {
    // Vérification que le post provient d'un producer
    final bool isProducer = post['producer_id'] != null;
    if (!isProducer) {
      print('⚠️ Interest/Choice uniquement pour les posts de producers');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Option uniquement disponible pour les publications de producteurs')),
      );
      return;
    }
    
    // Afficher l'indicateur de chargement
    setState(() {
      post['isLoading'] = true;
    });
    
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/choicexinterest/choice');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/choicexinterest/choice');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/choicexinterest/choice');
    }
    
    // Format de données attendu par le backend - simplifié pour correspondre à l'API
    final body = {
      'userId': widget.userId,
      'targetId': targetId,
      // Optionnel: ajout d'un commentaire si nécessaire
      // 'comment': 'Ajouté depuis le feed'
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Convertir explicitement en booléen pour éviter les erreurs de type 'Null is not a subtype of bool'
        final bool updatedChoice = responseData['choice'] == true;
        setState(() {
          post['choice'] = updatedChoice;
          post['isLoading'] = false;
        });
        
        // Feedback à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedChoice ? 'Ajouté à vos choix' : 'Retiré de vos choix'),
            backgroundColor: updatedChoice ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Mettre à jour le profil utilisateur pour refléter le changement
        _updateUserProfile();
        
        print('✅ Choice mis à jour avec succès');
      } else {
        setState(() {
          post['isLoading'] = false;
        });
        print('❌ Erreur lors de la mise à jour de Choice : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        post['isLoading'] = false;
      });
      print('❌ Erreur réseau lors de la mise à jour de Choice : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Mettre à jour le profil utilisateur après un changement d'interest/choice
  Future<void> _updateUserProfile() async {
    try {
      // Récupérer les intérêts et choix mis à jour de l'utilisateur
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/users/${widget.userId}');
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/users/${widget.userId}');
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl/api/users/${widget.userId}');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        print('✅ Profil utilisateur mis à jour avec succès');
        print('📋 Intérêts: ${userData['interests']?.length ?? 0}');
        print('📋 Choices: ${userData['choices']?.length ?? 0}');
        
        // On pourrait mettre à jour un state global ici ou déclencher une mise à jour de l'interface
        // par exemple, rafraîchir la liste des posts pour refléter les nouveaux états
        
        // Montrer un toast de confirmation à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vos préférences ont été mises à jour dans votre profil'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print('❌ Erreur lors de la mise à jour du profil : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de la mise à jour du profil : $e');
    }
  }

  /// Récupère les informations d'un événement
  Future<Map<String, dynamic>?> _fetchEventDetails(String eventId) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/events/$eventId');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/events/$eventId');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/events/$eventId');
    }
    
    try {
      print('🔍 Requête événement vers : $url');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération des détails de l\'événement : ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'événement : $e');
      return null;
    }
  }

  /// Ajoute un commentaire
  Future<void> _addComment(String postId, String comment) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/posts/$postId/comments');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/posts/$postId/comments');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/posts/$postId/comments');
    }
    
    try {
      final response = await http.post(
        url,
        body: json.encode({'comment': comment}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        print('✅ Commentaire ajouté avec succès');
        
        // Update the comments of the specific post
        final postIndex = _posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          final updatedPost = json.decode(response.body)['post'];
          setState(() {
            _posts[postIndex] = updatedPost;
          });
        }
      } else {
        print('❌ Erreur lors de l\'ajout du commentaire : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'ajout du commentaire : $e');
    }
  }

  /// Like un commentaire
  Future<void> _likeComment(String postId, String commentId) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/posts/$postId/comments/$commentId/like');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/posts/$postId/comments/$commentId/like');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/posts/$postId/comments/$commentId/like');
    }
    
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        print('✅ Commentaire liké avec succès');
        
        // Update the comments of the specific post
        final postIndex = _posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          final updatedPost = json.decode(response.body)['post'];
          setState(() {
            _posts[postIndex] = updatedPost;
          });
        }
      } else {
        print('❌ Erreur lors du like du commentaire : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour le like du commentaire : $e');
    }
  }

  Future<VideoPlayerController> _initializeVideoController(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    try {
      await controller.initialize();
      controller.setLooping(true); // Permet à la vidéo de boucler automatiquement.
      controller.setVolume(0); // Désactive le son si vous le souhaitez.
      controller.play(); // Lance automatiquement la lecture de la vidéo.
      return controller;
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de la vidéo : $e');
      throw Exception('Impossible de charger la vidéo');
    }
  }

  // Navigation intelligente vers les profils producteurs avec vérification du type
  void _navigateToDetails(String id, bool isProducer, {bool isLeisureProducer = false}) {
    try {
      // Vérifier d'abord si c'est un loisir ou un restaurant
      if (isProducer) {
        // Si on pense que c'est un leisure producer, essayer cette route en premier
        if (isLeisureProducer) {
          _tryNavigateToLeisureProducer(id);
        } else {
          _tryNavigateToRestaurantProducer(id);
        }
      } else {
        // Navigation vers EventLeisureScreen si ce n'est pas un producteur
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(eventId: id),
          ),
        ).then((_) {
          _refreshVisiblePosts();
        });
        
        // Feedback à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation vers l\'événement'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la navigation : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de navigation : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Tente de naviguer vers un restaurant producer
  void _tryNavigateToRestaurantProducer(String id) async {
    try {
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/producers/$id');
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/producers/$id');
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl/api/producers/$id');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        // C'est bien un restaurant, on navigue vers ProducerScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(producerId: id, userId: widget.userId),
          ),
        ).then((_) {
          _refreshVisiblePosts();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation vers le restaurant'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Si ce n'est pas un restaurant, essayer comme leisure producer
        print('❌ Erreur restaurant producer : ${response.statusCode}. Tentative en tant que leisure producer.');
        _tryNavigateToLeisureProducer(id);
      }
    } catch (e) {
      print('❌ Erreur lors de la navigation vers restaurant producer : $e');
      // En cas d'erreur, essayer comme leisure producer
      _tryNavigateToLeisureProducer(id);
    }
  }
  
  // Tente de naviguer vers un leisure producer
  void _tryNavigateToLeisureProducer(String id) async {
    try {
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/leisureProducers/$id');
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/leisureProducers/$id');
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl/api/leisureProducers/$id');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        // C'est bien un leisure producer, on navigue vers ProducerLeisureScreen
        final producerData = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerData: producerData),
          ),
        ).then((_) {
          _refreshVisiblePosts();
        });
        
        // Mettre à jour le flag dans les posts concernés
        final postIndex = _posts.indexWhere((post) => post['producer_id'] == id);
        if (postIndex != -1) {
          setState(() {
            _posts[postIndex]['is_leisure_producer'] = true;
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation vers le lieu de loisir'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Si les deux tentatives échouent, afficher un message d'erreur
        print('❌ Erreur également pour leisure producer : ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producteur non trouvé (ID: $id)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la navigation vers leisure producer : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Rafraîchit les posts visibles actuellement à l'écran
  void _refreshVisiblePosts() {
    if (_posts.isNotEmpty) {
      // Calculer quels posts sont actuellement visibles
      final firstVisibleIndex = 0; // Simplification - normalement calculé à partir du ScrollController
      final lastVisibleIndex = (_posts.length > 5) ? 5 : _posts.length - 1; // Prendre les 5 premiers posts ou moins
      
      for (int i = firstVisibleIndex; i <= lastVisibleIndex; i++) {
        final String postId = _posts[i]['_id']?.toString() ?? '';
        if (postId.isNotEmpty) {
          _refreshPostData(postId);
        }
      }
    }
  }
  
  // Rafraîchit les données d'un post spécifique
  Future<void> _refreshPostData(String postId) async {
    try {
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/posts/$postId');
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/posts/$postId');
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl/api/posts/$postId');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final updatedPost = json.decode(response.body);
        setState(() {
          final postIndex = _posts.indexWhere((post) => post['_id'] == postId);
          if (postIndex != -1) {
            _posts[postIndex] = updatedPost;
          }
        });
      }
    } catch (e) {
      print('❌ Erreur lors du rafraîchissement du post $postId: $e');
    }
  }

  /// Formate la date et l'heure du post
  String _formatPostedTime(String postedAt) {
    final DateTime postedDate = DateTime.parse(postedAt);
    final Duration difference = DateTime.now().difference(postedDate);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} h";
    } else {
      return DateFormat('dd MMM, yyyy').format(postedDate);
    }
  }

  /// Construit un bouton d'interaction style Instagram avec compteur proéminent
  Widget _buildInteractionButton({
    required IconData icon,
    Color? iconColor,
    required int count,
    int? showFollowerCount,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final bool isActive = iconColor != null;
    final baseColor = iconColor ?? Colors.grey.shade700;
    
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? baseColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: baseColor.withOpacity(0.2), width: 0.5) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône avec animation avancée
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.9,
                end: isActive ? 1.2 : 1.0,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (_, value, __) {
                return Transform.scale(
                  scale: value,
                  child: Icon(
                    icon,
                    color: isActive 
                      ? baseColor 
                      : count > 0 
                        ? Colors.grey.shade700 
                        : Colors.grey.shade400,
                    size: 26,
                  ),
                );
              },
            ),
            
            // Compteur principal plus grand et plus visible
            if (count > 0)
              GestureDetector(
                onTap: onLongPress ?? onTap,
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? baseColor.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isActive ? [
                      BoxShadow(
                        color: baseColor.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 0,
                      )
                    ] : null,
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? baseColor : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              
            // Compteur secondaire (followers) amélioré
            if (showFollowerCount != null && showFollowerCount > 0)
              GestureDetector(
                onTap: onLongPress ?? onTap,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.userGroup,
                        size: 9,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$showFollowerCount amis',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Construit la carte d'un post avec un design ultra-moderne, style Instagram
  Widget _buildPostCard(Map<String, dynamic> post) {
    final String postId = post['_id']?.toString() ?? '';
    final String content = post['content']?.toString() ?? 'Contenu non disponible';
    final String postedAt = post['posted_at']?.toString() ?? DateTime.now().toIso8601String();
    final String? mediaUrl = (post['media'] as List?)?.isNotEmpty == true
        ? ((post['media'][0]?.toString()?.endsWith('.jpg') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.png') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.jpeg') ?? false))
            ? post['media'][0].toString()
            : null
        : null;
    final String? videoUrl = (post['media'] as List?)?.isNotEmpty == true
        ? ((post['media'][0]?.toString()?.endsWith('.mp4') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.mov') ?? false) ||
                (post['media'][0]?.toString()?.endsWith('.avi') ?? false))
            ? post['media'][0].toString()
            : null
        : null;
    final String? producerId = post['producer_id']?.toString();
    final String? userId = post['user_id']?.toString();
    final String? eventId = post['event_id']?.toString();
    final bool isProducer = producerId != null;
    final bool isLeisureProducer = post['is_leisure_producer'] == true;
    final String targetId = isLeisureProducer ? (eventId ?? '') : (producerId ?? '');
    final List<dynamic> comments = post['comments'] ?? [];
    final bool isLiked = post['isLiked'] == true;
    final int likesCount = post['likesCount'] ?? 0;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        // Variables d'état local
        bool showLikeAnimation = false;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec avatar et nom
              if (producerId != null || userId != null)
                FutureBuilder<Map<String, dynamic>?>(
                  future: isProducer
                      ? _fetchAuthorDetails(producerId!, true, isLeisureProducer: isLeisureProducer)
                      : _fetchUserProfile(userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: const CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(
                                      height: 14,
                                      width: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(
                                      height: 10,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    } else if (snapshot.hasError || snapshot.data == null) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          'Auteur non disponible',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final authorData = snapshot.data!;
                    final String name = _extractAuthorName(authorData, isProducer, isLeisureProducer);
                    final String avatarUrl = isProducer
                        ? (authorData['photo'] ?? authorData['image'] ?? authorData['photo_url'] ?? 'https://storage.googleapis.com/choice-app/images/placeholder.jpg')
                        : (authorData['photo_url'] ?? authorData['photo'] ?? 'https://storage.googleapis.com/choice-app/images/placeholder.jpg');

                    return InkWell(
                      onTap: () => isProducer
                          ? _navigateToDetails(producerId!, true, isLeisureProducer: isLeisureProducer)
                          : Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: userId!),
                              ),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            // Avatar avec Animation Hero
                            Hero(
                              tag: 'avatar-${isProducer ? producerId : userId}',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isProducer
                                        ? Colors.amber.withOpacity(0.5)
                                        : Colors.blue.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isProducer
                                          ? Colors.amber.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                  radius: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatPostedTime(postedAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Options menu
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(50),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (context) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.symmetric(vertical: 10),
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        ListTile(
                                          leading: const Icon(FontAwesomeIcons.shareNodes, size: 20),
                                          title: Text('Partager', style: GoogleFonts.poppins()),
                                          onTap: () {
                                            Navigator.pop(context);
                                            // Logique de partage
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(FontAwesomeIcons.flag, size: 20),
                                          title: Text('Signaler', style: GoogleFonts.poppins()),
                                          onTap: () {
                                            Navigator.pop(context);
                                            // Logique de signalement
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    FontAwesomeIcons.ellipsisVertical,
                                    size: 20,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Texte du post avec ExpandableText
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: ExpandableText(
                  content,
                  expandText: 'voir plus',
                  collapseText: 'voir moins',
                  maxLines: 3,
                  linkColor: Colors.blue,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  linkStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[600],
                  ),
                  animation: true,
                  animationDuration: const Duration(milliseconds: 200),
                ),
              ),

              // Media (vidéo ou image)
              if (videoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: GestureDetector(
                    onDoubleTap: () {
                      setState(() {
                        showLikeAnimation = true;
                      });
                      _likePost(postId, post);
                      
                      Future.delayed(const Duration(milliseconds: 800), () {
                        if (mounted) {
                          setState(() {
                            showLikeAnimation = false;
                          });
                        }
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.zero, // Instagram-style full width
                          child: FutureBuilder<VideoPlayerController>(
                            future: _initializeVideoController(videoUrl),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done &&
                                  snapshot.hasData) {
                                final controller = snapshot.data!;
                                return GestureDetector(
                                  onTap: () => _openMediaInReelsMode(context, videoUrl, true, post),
                                  child: AspectRatio(
                                    aspectRatio: controller.value.aspectRatio,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Video player
                                        VideoPlayer(controller),
                                        
                                        // Video progress
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: VideoProgressIndicator(
                                            controller, 
                                            allowScrubbing: true,
                                            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 0),
                                            colors: VideoProgressColors(
                                              playedColor: Colors.blue[400]!,
                                              bufferedColor: Colors.grey[300]!,
                                              backgroundColor: Colors.black.withOpacity(0.2),
                                            ),
                                          ),
                                        ),
                                        
                                        // Bouton plein écran
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              colors: [
                                                Colors.black.withOpacity(0.4),
                                                Colors.black.withOpacity(0.0),
                                              ],
                                              radius: 0.8,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const FaIcon(
                                            FontAwesomeIcons.expand,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        
                                        // Bouton mute/unmute
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                controller.setVolume(controller.value.volume > 0 ? 0 : 1.0);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: FaIcon(
                                                controller.value.volume > 0 
                                                  ? FontAwesomeIcons.volumeHigh 
                                                  : FontAwesomeIcons.volumeXmark,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else if (snapshot.hasError) {
                                return Container(
                                  height: 300,
                                  width: double.infinity,
                                  color: Colors.black12,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const FaIcon(FontAwesomeIcons.circleExclamation, color: Colors.red),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Erreur de chargement',
                                          style: GoogleFonts.poppins(color: Colors.red),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                return Container(
                                  height: 300,
                                  width: double.infinity,
                                  color: Colors.black12,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 40, 
                                          height: 40,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Chargement de la vidéo...',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        // Animation cœur
                        if (showLikeAnimation)
                          LikeAnimation(
                            isAnimating: showLikeAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 80,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 25),
                                ],
                              ),
                            ),
                            duration: const Duration(milliseconds: 800),
                          ),
                      ],
                    ),
                  ),
                )
              else if (mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: GestureDetector(
                    onDoubleTap: () {
                      setState(() {
                        showLikeAnimation = true;
                      });
                      _likePost(postId, post);
                      
                      Future.delayed(const Duration(milliseconds: 800), () {
                        if (mounted) {
                          setState(() {
                            showLikeAnimation = false;
                          });
                        }
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _openMediaInReelsMode(context, mediaUrl, false, post),
                          child: CachedNetworkImage(
                            imageUrl: mediaUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              height: 300,
                              width: double.infinity,
                              child: Center(
                                child: Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(
                                    width: double.infinity,
                                    height: 300,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              height: 300,
                              width: double.infinity,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image indisponible',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Animation cœur
                        if (showLikeAnimation)
                          LikeAnimation(
                            isAnimating: showLikeAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 80,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 25),
                                ],
                              ),
                            ),
                            duration: const Duration(milliseconds: 800),
                          ),
                        // Bouton plein écran
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _openMediaInReelsMode(context, mediaUrl, false, post),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.expand,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Compteurs d'interactions Instagram-style avec preview des profils
              if (likesCount > 0 || (isProducer && ((post['follower_interests_count'] ?? 0) > 0 || (post['entity_interests_count'] ?? 0) > 0 || (post['entity_choices_count'] ?? 0) > 0)))
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Like count avec avatars
                      if (likesCount > 0)
                        GestureDetector(
                          onTap: () => _showInteractionsList(context, postId, 'like', 'post'),
                          child: Row(
                            children: [
                              // Icône animée
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.9, end: isLiked ? 1.1 : 1.0),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                builder: (_, value, __) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const FaIcon(
                                        FontAwesomeIcons.solidHeart,
                                        size: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              // Texte avec nombre de likes cliquable
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$likesCount ',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'J\'aime${likesCount > 1 ? 's' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Séparateur
                      if (likesCount > 0 && isProducer && 
                         ((post['follower_interests_count'] ?? 0) > 0 || (post['entity_interests_count'] ?? 0) > 0 || (post['entity_choices_count'] ?? 0) > 0))
                        const SizedBox(height: 8),
                      
                      // Intérêts count avec indication des amis (pour les posts de producteurs)
                      if (isProducer && ((post['entity_interests_count'] ?? 0) > 0 || (post['follower_interests_count'] ?? 0) > 0))
                        GestureDetector(
                          onTap: () => _showInteractionsList(
                            context, 
                            targetId, 
                            'interest', 
                            isLeisureProducer ? 'event' : 'producer'
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                // Icône animée
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.9, end: post['interested'] == true ? 1.1 : 1.0),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.elasticOut,
                                  builder: (_, value, __) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const FaIcon(
                                          FontAwesomeIcons.solidStar,
                                          size: 12,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                // Texte avec détail
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${post['entity_interests_count'] ?? 0} ',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'personne${(post['entity_interests_count'] ?? 0) > 1 ? 's' : ''} intéressée${(post['entity_interests_count'] ?? 0) > 1 ? 's' : ''}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if ((post['follower_interests_count'] ?? 0) > 0)
                                          TextSpan(
                                            text: ' dont ${post['follower_interests_count']} ami${(post['follower_interests_count'] ?? 0) > 1 ? 's' : ''}',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Colors.purple[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Choices count (pour les posts de producteurs)
                      if (isProducer && (post['entity_choices_count'] ?? 0) > 0)
                        GestureDetector(
                          onTap: () => _showInteractionsList(
                            context, 
                            targetId, 
                            'choice', 
                            isLeisureProducer ? 'event' : 'producer'
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                // Icône animée
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.9, end: post['choice'] == true ? 1.1 : 1.0),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.elasticOut,
                                  builder: (_, value, __) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const FaIcon(
                                          FontAwesomeIcons.solidCircleCheck,
                                          size: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                // Texte avec détail
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${post['entity_choices_count'] ?? 0} ',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'choix',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // Barre d'interactions Instagram-style
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Likes - style Instagram
                    _buildInteractionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      iconColor: isLiked ? Colors.red : null,
                      count: likesCount,
                      onTap: () => _likePost(postId, post),
                      onLongPress: likesCount > 0 
                        ? () => _showInteractionsList(context, postId, 'like', 'post')
                        : null,
                    ),
                    
                    // Interests - avec étoile brillante
                    if (isProducer)
                      _buildInteractionButton(
                        icon: post['interested'] == true ? Icons.star : Icons.star_border, 
                        iconColor: post['interested'] == true ? Colors.amber : null,
                        count: post['entity_interests_count'] ?? 0,
                        showFollowerCount: post['follower_interests_count'] ?? 0,
                        onTap: () => _markInterested(targetId, post, isLeisureProducer: isLeisureProducer),
                        onLongPress: () => _showInteractionsList(
                          context, 
                          targetId, 
                          'interest', 
                          isLeisureProducer ? 'event' : 'producer'
                        ),
                      ),
                    
                    // Choices - coche animée
                    if (isProducer)
                      _buildInteractionButton(
                        icon: post['choice'] == true ? Icons.check_circle : Icons.check_circle_outline,
                        iconColor: post['choice'] == true ? Colors.green : null,
                        count: post['entity_choices_count'] ?? 0,
                        onTap: () => _markChoice(targetId, post, isLeisureProducer: isLeisureProducer),
                        onLongPress: () => _showInteractionsList(
                          context, 
                          targetId, 
                          'choice', 
                          isLeisureProducer ? 'event' : 'producer'
                        ),
                      ),
                    
                    // Commentaires
                    _buildInteractionButton(
                      icon: Icons.chat_bubble_outline,
                      count: comments.length,
                      onTap: () => _showCommentsSheet(context, post),
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

  /// Affiche la liste des utilisateurs ayant interagi avec un post ou une entité
  void _showInteractionsList(BuildContext context, String id, String type, String entityType) {
    // Afficher un dialogue de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    _fetchInteractionsList(context, id, type, entityType);
  }

  /// Récupère la liste des utilisateurs ayant interagi avec un post ou une entité
  Future<void> _fetchInteractionsList(BuildContext context, String id, String type, String entityType) async {
    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (entityType == 'post') {
        // Pour les interactions sur des posts (likes)
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/posts/$id/interactions/$type');
        } else if (baseUrl.startsWith('https://')) {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/posts/$id/interactions/$type');
        } else {
          url = Uri.parse('$baseUrl/api/posts/$id/interactions/$type');
        }
      } else {
        // Pour les interactions sur des entités (producer/event)
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/posts/entity/$entityType/$id/interactions/$type');
        } else if (baseUrl.startsWith('https://')) {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/posts/entity/$entityType/$id/interactions/$type');
        } else {
          url = Uri.parse('$baseUrl/api/posts/entity/$entityType/$id/interactions/$type');
        }
      }
      
      final response = await http.get(
        url,
        headers: {'userId': widget.userId},
      );
      
      // Fermer le dialogue de chargement
      Navigator.pop(context);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> allUsers = data['allUsers'] ?? [];
        final List<dynamic> followedUsers = data['followedUsers'] ?? [];
        
        _showUsersListModal(context, allUsers, followedUsers, type);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // Fermer le dialogue de chargement en cas d'erreur
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion: $e')),
      );
    }
  }
  
  /// Modal pour afficher les utilisateurs ayant interagi
  void _showUsersListModal(
    BuildContext context, 
    List<dynamic> allUsers, 
    List<dynamic> followedUsers,
    String interactionType
  ) {
    String interactionTitle;
    Color headerColor;
    IconData interactionIcon;
    
    switch (interactionType) {
      case 'like':
        interactionTitle = 'J\'aime';
        headerColor = Colors.red;
        interactionIcon = Icons.favorite;
        break;
      case 'interest':
        interactionTitle = 'Intéressés';
        headerColor = Colors.amber;
        interactionIcon = Icons.star;
        break;
      case 'choice':
        interactionTitle = 'Choix';
        headerColor = Colors.green;
        interactionIcon = Icons.check_circle;
        break;
      default:
        interactionTitle = 'Interactions';
        headerColor = Colors.blue;
        interactionIcon = Icons.thumb_up;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return DefaultTabController(
              length: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle pour faire glisser
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    
                    // Titre avec icône
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(interactionIcon, color: headerColor),
                          const SizedBox(width: 8),
                          Text(
                            interactionTitle,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: headerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tabs
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: headerColor,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(text: 'Tous (${allUsers.length})'),
                          Tab(text: 'Vos contacts (${followedUsers.length})'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Contenu des tabs
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Tous les utilisateurs
                          allUsers.isEmpty
                              ? const Center(child: Text('Aucun utilisateur'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: allUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = allUsers[index];
                                    return _buildUserListItem(user, headerColor);
                                  },
                                ),
                                
                          // Tab 2: Utilisateurs suivis
                          followedUsers.isEmpty
                              ? const Center(child: Text('Aucun de vos contacts'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: followedUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = followedUsers[index];
                                    return _buildUserListItem(user, headerColor);
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
        );
      },
    );
  }
  
  /// Item de la liste des utilisateurs
  Widget _buildUserListItem(Map<String, dynamic> user, Color accentColor) {
    final String name = user['name'] ?? 'Utilisateur';
    final String? avatarUrl = user['photo_url'] ?? user['photo'] ?? 'https://via.placeholder.com/40';
    final String? userId = user['_id'];
    
    return ListTile(
      leading: Hero(
        tag: 'user-avatar-${userId ?? 'unknown'}',
        child: CircleAvatar(
          backgroundImage: CachedNetworkImageProvider(avatarUrl ?? 'https://via.placeholder.com/40'),
          radius: 20,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: userId != null && userId != widget.userId
          ? OutlinedButton(
              onPressed: () {
                // Logique pour suivre/ne plus suivre
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Suivre'),
            )
          : null,
      onTap: userId != null
          ? () {
              Navigator.pop(context); // Fermer le modal
              
              // Naviguer vers le profil de l'utilisateur
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: userId),
                ),
              );
            }
          : null,
    );
  }

  // Instagram-style comments sheet
  void _showCommentsSheet(BuildContext context, Map<String, dynamic> post) {
    final String postId = post['_id'];
    final List<dynamic> comments = post['comments'] ?? [];
    final TextEditingController commentController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6, // Start at half screen
              minChildSize: 0.4, // Min half screen
              maxChildSize: 0.9, // Almost full screen max
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
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
                        'Commentaires (${comments.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Expanded(
                      child: comments.isEmpty
                          ? const Center(child: Text('Aucun commentaire pour le moment'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                final comment = comments[index];
                                return _buildCommentSection(postId, comment);
                              },
                            ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                        left: 16,
                        right: 16,
                        top: 8,
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage('https://via.placeholder.com/36'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              decoration: const InputDecoration(
                                hintText: 'Ajouter un commentaire...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(20)),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Color(0xFFEEEEEE),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.blue),
                            onPressed: () async {
                              if (commentController.text.isNotEmpty) {
                                final newComment = commentController.text;
                                commentController.clear();
                                
                                // Close keyboard
                                FocusScope.of(context).unfocus();
                                
                                await _addComment(postId, newComment);
                                
                                // Update UI with new comment list
                                final updatedPost = _posts.firstWhere((p) => p['_id'] == postId);
                                setState(() {
                                  // This updates the StatefulBuilder state
                                  comments.clear();
                                  comments.addAll(updatedPost['comments'] ?? []);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommentSection(String postId, Map<String, dynamic> comment) {
    final bool isLiked = comment['isLiked'] == true;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(
              comment['authorAvatar'] ?? 'https://via.placeholder.com/36'
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: comment['author'] ?? 'Anonyme',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: ' ${comment['content'] ?? ''}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatPostedTime(comment['posted_at'] ?? DateTime.now().toIso8601String()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _likeComment(postId, comment['_id'] ?? ''),
                      child: Text(
                        'J\'aime',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // Reply functionality
                      },
                      child: const Text(
                        'Répondre',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: isLiked ? Colors.red : Colors.grey,
            ),
            onPressed: () => _likeComment(postId, comment['_id'] ?? ''),
          ),
        ],
      ),
    );
  }

  // Fonction pour extraire intelligemment le nom d'un auteur en fonction de son type
  String _extractAuthorName(Map<String, dynamic> authorData, bool isProducer, bool isLeisureProducer) {
    if (!isProducer) {
      // Pour les utilisateurs réguliers
      return authorData['name'] ?? 'Utilisateur';
    }
    
    // Pour les producteurs, vérifier différents champs possibles selon le type
    if (isLeisureProducer) {
      // Vérification de plusieurs champs possibles pour les leisure producers
      return authorData['nom'] ?? 
             authorData['intitulé'] ?? 
             authorData['title'] ?? 
             authorData['name'] ?? 
             authorData['nom_lieu'] ?? 
             'Lieu culturel';
    } else {
      // Pour les restaurants/producteurs standards
      return authorData['name'] ?? 
             authorData['nom'] ?? 
             authorData['établissement'] ?? 
             authorData['restaurant_name'] ?? 
             'Restaurant';
    }
  }

  // Widget réutilisable pour les colonnes d'interactions avec icônes vectorielles
  Widget _buildInteractionColumn({
    required String emoji, // Gardé pour compatibilité
    required int count,
    int? secondaryCount,
    required bool isActive,
    required Color color,
    required Function() onTap,
    Function()? onLongPress,
    IconData? iconData, // Nouvelle option pour utiliser FontAwesome
  }) {
    // Détermine l'icône à utiliser pour chaque type d'interaction
    IconData icon;
    if (iconData != null) {
      icon = iconData;
    } else {
      // Mapping des emojis vers des icônes FontAwesome
      switch (emoji) {
        case '❤️':
        case '🤍':
          icon = isActive ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart;
          break;
        case '⭐':
        case '☆':
          icon = isActive ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star;
          break;
        case '✅':
        case '⬜':
          icon = isActive ? FontAwesomeIcons.solidCircleCheck : FontAwesomeIcons.circleCheck;
          break;
        case '💬':
          icon = FontAwesomeIcons.solidComment;
          break;
        default:
          icon = FontAwesomeIcons.thumbsUp;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône FontAwesome avec animation d'échelle
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0.8,
                  end: isActive ? 1.1 : 0.9,
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: FaIcon(
                      icon,
                      size: 26,
                      color: isActive 
                        ? color
                        : count > 0 
                          ? Colors.grey.shade700
                          : Colors.grey.shade400,
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 4),
              
              // Compteur avec effet de pulsation si actif
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 1.0,
                  end: isActive && count > 0 ? 1.05 : 1.0,
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive 
                          ? color.withOpacity(0.15) 
                          : count > 0 
                            ? Colors.grey.shade200 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isActive && count > 0
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.2),
                                blurRadius: 4,
                                spreadRadius: 0,
                              )
                            ]
                          : null,
                      ),
                      child: Text(
                        count.toString(),
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive 
                            ? color
                            : count > 0 
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Compteur secondaire (followers) avec icône utilisateur
              if (secondaryCount != null && secondaryCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.userGroup,
                        size: 8,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        secondaryCount.toString(),
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Ouvre une image/vidéo en mode "reels" pour navigation verticale
  void _openMediaInReelsMode(BuildContext context, String mediaUrl, bool isVideo, Map<String, dynamic> post) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          final curveTween = CurveTween(curve: Curves.easeOut);
          final fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          final fadeAnimation = animation.drive(fadeTween.chain(curveTween));
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: ReelsViewScreen(
              initialMediaUrl: mediaUrl, 
              isVideo: isVideo,
              postData: post,
              userId: widget.userId,
              onLike: _likePost,
              onInterested: _markInterested,
              onChoice: _markChoice,
              onComment: () => _showCommentsSheet(context, post),
            ),
          );
        },
        opaque: false,
        barrierColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // En-tête simplifiée sans les boutons inutiles
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Choice',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: _posts.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.feed, size: 70, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun post trouvé',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchFeed,
                        child: const Text('Actualiser'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Reset and reload from page 1
                    setState(() {
                      _posts.clear();
                      _currentPage = 1;
                      _hasMorePosts = true;
                    });
                    _fetchFeed();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _posts.length + (_isLoading && _hasMorePosts ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _posts.length) {
                        return _buildPostCard(_posts[index]);
                      } else {
                        // Loading indicator at the bottom
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                    },
                  ),
                ),
    );
  }
}