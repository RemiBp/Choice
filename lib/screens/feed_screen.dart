import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    final url = Uri.parse('${getBaseUrl()}/api/posts?userId=$userId&page=$page&limit=$limit');
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
    final url = Uri.parse('${getBaseUrl()}/api/users/$userId');
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

  Future<Map<String, dynamic>?> _fetchAuthorDetails(String authorId, bool isProducer, {bool isLeisureProducer = false}) async {
    // Vérifier si l'auteur est déjà dans le cache
    final cacheKey = '${isProducer ? (isLeisureProducer ? "leisure" : "producer") : "user"}_$authorId';
    if (_authorCache.containsKey(cacheKey)) {
      print('📋 Utilisation du cache pour l\'auteur $authorId');
      return _authorCache[cacheKey];
    }

    String endpoint = isLeisureProducer ? 'leisureProducers' : (isProducer ? 'producers' : 'users');
    Uri url = Uri.parse('${getBaseUrl()}/api/$endpoint/$authorId');

    try {
      print('🔍 Requête auteur vers : $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print('📩 Auteur récupéré avec succès depuis $endpoint');
        final Map<String, dynamic> authorData = json.decode(response.body);
        
        // Ajouter un indicateur du type de producteur dans les données retournées
        authorData['_producerType'] = endpoint;
        
        // Stocker dans le cache pour éviter des appels répétés
        _authorCache[cacheKey] = authorData;
        return authorData;
      } else {
        print('❌ Erreur lors de la récupération des détails de l\'auteur depuis $endpoint : ${response.body}');

        // Fallback : si la requête sur "producers" échoue, essaye "leisureProducers"
        if (!isLeisureProducer && isProducer) {
          print('🔄 Tentative de fallback vers leisureProducers...');
          endpoint = 'leisureProducers';
          url = Uri.parse('${getBaseUrl()}/api/$endpoint/$authorId');
          final fallbackResponse = await http.get(url);

          if (fallbackResponse.statusCode == 200) {
            print('📩 Auteur récupéré avec succès depuis $endpoint');
            final Map<String, dynamic> authorData = json.decode(fallbackResponse.body);
            
            // Marquer ce producteur comme un leisure producer
            authorData['_producerType'] = 'leisureProducers';
            
            // Mise à jour des posts pour refléter ce changement
            final postIndex = _posts.indexWhere((post) => post['producer_id'] == authorId);
            if (postIndex != -1) {
              setState(() {
                _posts[postIndex]['is_leisure_producer'] = true;
              });
              print('🔄 Post mis à jour pour refléter que c\'est un leisure producer');
            }
            
            // Stocker dans le cache avec le bon type
            _authorCache['leisure_$authorId'] = authorData;
            return authorData;
          } else {
            print('❌ Erreur également sur $endpoint : ${fallbackResponse.body}');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'auteur : $e');
    }

    // Retourne null si toutes les tentatives échouent
    return null;
  }

  /// Like un post
  Future<void> _likePost(String postId, Map<String, dynamic> post) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/like');
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

    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/interested');
    
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
    
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/choice');
    
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
      final url = Uri.parse('${getBaseUrl()}/api/users/${widget.userId}');
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
    final url = Uri.parse('${getBaseUrl()}/api/events/$eventId');
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
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/comments');
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
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/comments/$commentId/like');
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
      final url = Uri.parse('${getBaseUrl()}/api/producers/$id');
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
      final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
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
      final url = Uri.parse('${getBaseUrl()}/api/posts/$postId');
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

  /// Construit la carte d'un post avec un design amélioré
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

    // Variables d'état local
    bool isExpanded = false;
    bool showLikeAnimation = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informations sur l'auteur (nom + avatar) avec redirection
              if (producerId != null || userId != null)
                FutureBuilder<Map<String, dynamic>?>(
                  future: isProducer
                      ? _fetchAuthorDetails(producerId!, true, isLeisureProducer: isLeisureProducer)
                      : _fetchUserProfile(userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey,
                            ),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  height: 14,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.grey,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                  ),
                                ),
                                SizedBox(height: 4),
                                SizedBox(
                                  width: 80,
                                  height: 10,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.grey,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    } else if (snapshot.hasError || snapshot.data == null) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Auteur non disponible',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final authorData = snapshot.data!;
                    // Extraction intelligente du nom avec vérification de plusieurs champs possibles
                    final String name = _extractAuthorName(authorData, isProducer, isLeisureProducer);
                    final String avatarUrl = isProducer
                        ? (authorData['photo'] ?? authorData['image'] ?? authorData['photo_url'] ?? 'https://via.placeholder.com/150')
                        : (authorData['photo_url'] ?? authorData['photo'] ?? 'https://via.placeholder.com/150');

                    return GestureDetector(
                      onTap: () => isProducer
                          ? _navigateToDetails(producerId!, true, isLeisureProducer: isLeisureProducer)
                          : Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: userId!),
                              ),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'avatar-${isProducer ? producerId : userId}',
                              child: CircleAvatar(
                                backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                radius: 25,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _formatPostedTime(postedAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () {
                                // Show options menu
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.share),
                                        title: const Text('Partager'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          // Share functionality
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.report),
                                        title: const Text('Signaler'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          // Report functionality
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Texte du post avec ExpandableText
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ExpandableText(
                  content,
                  expandText: 'voir plus',
                  collapseText: 'voir moins',
                  maxLines: 3,
                  linkColor: Colors.blue,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),

              // Affichage vidéo ou image
              if (videoUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
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
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<VideoPlayerController>(
                            future: _initializeVideoController(videoUrl),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done &&
                                  snapshot.hasData) {
                                final controller = snapshot.data!;
                                return AspectRatio(
                                  aspectRatio: controller.value.aspectRatio,
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      VideoPlayer(controller),
                                      VideoProgressIndicator(controller, allowScrubbing: true),
                                    ],
                                  ),
                                );
                              } else if (snapshot.hasError) {
                                return Container(
                                  height: 300,
                                  width: double.infinity,
                                  color: Colors.black12,
                                  child: const Center(
                                    child: Text(
                                      'Erreur de chargement de la vidéo',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                );
                              } else {
                                return Container(
                                  height: 300,
                                  width: double.infinity,
                                  color: Colors.black12,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        // Like animation overlay
                        if (showLikeAnimation)
                          LikeAnimation(
                            isAnimating: showLikeAnimation,
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 100,
                            ),
                            duration: const Duration(milliseconds: 800),
                          ),
                      ],
                    ),
                  ),
                )
              else if (mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
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
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: mediaUrl,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              height: 300,
                              width: double.infinity,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              height: 300,
                              width: double.infinity,
                              child: const Center(
                                child: Text('Image invalide', style: TextStyle(color: Colors.red)),
                              ),
                            ),
                          ),
                        ),
                        // Like animation overlay
                        if (showLikeAnimation)
                          LikeAnimation(
                            isAnimating: showLikeAnimation,
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 100,
                            ),
                            duration: const Duration(milliseconds: 800),
                          ),
                      ],
                    ),
                  ),
                ),

              // Likes count
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                child: Text(
                  likesCount > 0 ? '$likesCount j\'aime' : '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const Divider(height: 0),

              // Boutons interactifs
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Like button
                        TextButton.icon(
                          onPressed: () => _likePost(postId, post),
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                          ),
                          label: Text(
                            'J\'aime',
                            style: TextStyle(
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                        
                        // Only show Interest and Choice buttons for producer posts
                        if (isProducer)
                          TextButton.icon(
                            onPressed: () {
                              _markInterested(targetId, post, isLeisureProducer: isLeisureProducer);
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(scale: animation, child: child);
                              },
                              child: Icon(
                                Icons.star,
                                key: ValueKey<bool>(post['interested'] == true),
                                color: post['interested'] == true ? Colors.amber : Colors.grey,
                              ),
                            ),
                            label: Text(
                              'Intéressé 👀',
                              style: TextStyle(
                                color: post['interested'] == true ? Colors.amber : Colors.grey,
                              ),
                            ),
                          ),
                        
                        // Only show Choice button for producer posts
                        if (isProducer)
                          TextButton.icon(
                            onPressed: () {
                              _markChoice(targetId, post, isLeisureProducer: isLeisureProducer);
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(scale: animation, child: child);
                              },
                              child: Icon(
                                Icons.check_circle,
                                key: ValueKey<bool>(post['choice'] == true),
                                color: post['choice'] == true ? Colors.green : Colors.grey,
                              ),
                            ),
                            label: Text(
                              'Choix ✅',
                              style: TextStyle(
                                color: post['choice'] == true ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    // Comment button positioned at right
                    TextButton.icon(
                      onPressed: () {
                        _showCommentsSheet(context, post);
                      },
                      icon: const Icon(Icons.comment_outlined),
                      label: const Text('Commenter'),
                    ),
                  ],
                ),
              ),

              // Preview of first 2 comments if available
              if (comments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...comments.take(2).map((comment) => _buildCommentPreview(comment)),
                      if (comments.length > 2)
                        TextButton(
                          onPressed: () {
                            _showCommentsSheet(context, post);
                          },
                          child: Text('Voir les ${comments.length} commentaires'),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
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
  
  // Preview of a comment (simplified)
  Widget _buildCommentPreview(Map<String, dynamic> comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: comment['author'] ?? 'Anonyme',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            TextSpan(
              text: ' ${comment['content'] ?? ''}',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Feed', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
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