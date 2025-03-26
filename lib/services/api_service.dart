import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../utils/constants.dart';
import '../utils/feed_constants.dart';
import '../models/post.dart';
import '../models/comment.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import '../screens/utils.dart';

// Enum manquant pour les types de contenu du feed du producteur
enum ProducerFeedContentType {
  venue,
  interactions, 
  localTrends
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  ApiService._internal() {
    _initDio();
  }

  final String _baseUrl = getBaseUrl();
  late Dio _dio;
  
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: Duration(milliseconds: 15000),
      receiveTimeout: Duration(milliseconds: 15000),
    ));
    
    // Ajouter des intercepteurs pour le logging si nécessaire
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      requestHeader: false,
      responseHeader: false,
      request: false,
    ));
  }

  Future<List<Post>> getFeedPosts(String userId, {int page = 1, int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/api/feed',
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['posts'];
        return data.map((json) => Post.fromMap(json)).toList();
      } else {
        throw Exception('Erreur lors du chargement du feed');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement du feed: $e');
      rethrow;
    }
  }

  Future<bool> toggleLike(String userId, String postId) async {
    try {
      final response = await _dio.post(
        '/api/posts/$postId/like',
        data: {'userId': userId},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur lors du like du post: $e');
      rethrow;
    }
  }

  Future<bool> toggleInterest(String userId, String targetId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/interactions/interest',
        data: {
          'userId': userId,
          'targetId': targetId,
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error toggling interest: $e');
      rethrow;
    }
  }

  Future<bool> toggleChoice(String userId, String postId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/interactions/choice',
        data: {
          'userId': userId,
          'postId': postId,
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error toggling choice: $e');
      rethrow;
    }
  }

  Future<bool> savePost(String userId, String postId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/posts/save',
        data: {
          'userId': userId,
          'postId': postId,
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error saving post: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addComment(String postId, String userId, String content) async {
    try {
      final url = Uri.parse('$_baseUrl/api/comments');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'post_id': postId,
          'user_id': userId,
          'content': content,
        }),
      );
      
      if (response.statusCode == 201) {
        // Commentaire créé avec succès
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Retourner directement la map au lieu de convertir en Comment
        return {
          'id': data['_id'] ?? '',
          'authorId': data['author_id'] ?? userId,
          'authorName': data['author_name'] ?? 'Utilisateur',
          'username': data['username'] ?? data['author_name'] ?? 'Utilisateur',
          'authorAvatar': data['author_avatar'] ?? '',
          'content': data['content'] ?? content,
          'postedAt': data['posted_at'] ?? DateTime.now().toIso8601String(),
        };
      } else {
        print('❌ Erreur lors de l\'ajout du commentaire: ${response.statusCode}');
        throw Exception('Erreur lors de l\'ajout du commentaire: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception lors de l\'ajout du commentaire: $e');
      
      // En cas d'erreur, créer un commentaire local avec l'heure actuelle
      return {
        'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
        'authorId': userId,
        'authorName': 'Vous',
        'username': 'Vous',
        'authorAvatar': '',
        'content': content,
        'postedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<bool> likeComment(String userId, String postId, String commentId) async {
    try {
      final response = await _dio.post(
        '/api/posts/$postId/comments/$commentId/like',
        data: {'userId': userId},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur lors du like du commentaire: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> replyToComment(
    String userId,
    String postId,
    String commentId,
    String content,
  ) async {
    try {
      final response = await _dio.post(
        '/api/posts/$postId/comments/$commentId/reply',
        data: {
          'userId': userId,
          'content': content,
        },
      );

      if (response.statusCode == 200) {
        return response.data['reply'];
      } else {
        throw Exception('Erreur lors de la réponse au commentaire');
      }
    } catch (e) {
      print('❌ Erreur lors de la réponse au commentaire: $e');
      rethrow;
    }
  }

  Future<Post> createPost({
    required String userId,
    required String content,
    List<String>? mediaUrls,
    String? locationId,
    String? locationName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/posts',
        data: {
          'userId': userId,
          'content': content,
          'mediaUrls': mediaUrls,
          'locationId': locationId,
          'locationName': locationName,
        },
      );

      if (response.statusCode == 200) {
        return Post.fromMap(response.data['post']);
      } else {
        throw Exception('Erreur lors de la création du post');
      }
    } catch (e) {
      print('❌ Erreur lors de la création du post: $e');
      rethrow;
    }
  }

  Future<bool> deletePost(String userId, String postId) async {
    try {
      final response = await _dio.delete(
        '/api/posts/$postId',
        data: {'userId': userId},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur lors de la suppression du post: $e');
      rethrow;
    }
  }

  Future<List<Post>> getSavedPosts(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/users/$userId/saved-posts');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Post.fromJson(json)).toList();
      }
      throw Exception('Failed to load saved posts');
    } catch (e) {
      print('❌ Erreur lors de la récupération des posts sauvegardés : $e');
      rethrow;
    }
  }

  Future<String> uploadMedia(String userId, dynamic media) async {
    final url = Uri.parse('${getBaseUrl()}/api/media/upload');
    
    try {
      late http.MultipartRequest request;
      
      if (kIsWeb) {
        // Gestion spécifique pour le web
        request = http.MultipartRequest('POST', url)
          ..fields['userId'] = userId;
        // Ajouter la logique spécifique pour le web ici
      } else {
        // Pour mobile
        request = http.MultipartRequest('POST', url)
          ..fields['userId'] = userId
          ..files.add(await http.MultipartFile.fromPath('media', media.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return json.decode(responseData)['mediaUrl'];
      }
      throw Exception('Failed to upload media');
    } catch (e) {
      print('❌ Erreur lors de l\'upload du média : $e');
      rethrow;
    }
  }
  
  /// Télécharger une image de profil et retourner son URL
  Future<String?> uploadImage(String imagePath) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/media/upload/profile');
      
      // Vérifier si le fichier existe
      final file = File(imagePath);
      if (!await file.exists()) {
        print('❌ Le fichier d\'image n\'existe pas: $imagePath');
        return null;
      }
      
      // Créer une requête multipart pour l'upload
      final request = http.MultipartRequest('POST', url);
      
      // Ajouter le fichier à la requête
      if (kIsWeb) {
        // TODO: Implémenter la gestion des fichiers pour le web si nécessaire
        print('⚠️ L\'upload d\'images depuis le web n\'est pas encore supporté');
        return null;
      } else {
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
      
      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Analyser la réponse
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Image téléchargée avec succès: ${data['imageUrl']}');
        return data['imageUrl'] ?? data['url'] ?? data['mediaUrl'];
      } else {
        print('❌ Erreur lors du téléchargement de l\'image: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception lors du téléchargement de l\'image: $e');
      return null;
    }
  }

  /// Récupérer les informations de profil utilisateur
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      print('🔍 Récupération du profil utilisateur $userId');

      final uri = Uri.parse('${getBaseUrl()}/api/user/$userId');
      print('🔍 Requête vers : $uri');

      final response = await http.get(uri);

      print('📩 Réponse reçue : ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Erreur ${response.statusCode} lors de la récupération du profil utilisateur : ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Erreur dans getUserProfile : $e');
      throw Exception('Erreur de connexion au serveur : $e');
    }
  }

  /// Récupérer les favoris d'un utilisateur
  static Future<List<dynamic>> getUserFavorites(String userId) async {
    try {
      print('🔍 Récupération des favoris pour $userId');

      final uri = Uri.parse('${getBaseUrl()}/api/user/$userId/favorites');
      print('🔍 Requête vers : $uri');

      final response = await http.get(uri);

      print('📩 Réponse reçue : ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Erreur ${response.statusCode} lors de la récupération des favoris : ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Erreur dans getUserFavorites : $e');
      throw Exception('Erreur de connexion au serveur : $e');
    }
  }

  /// Récupérer les détails d'un producteur
  Future<Map<String, dynamic>> getProducerDetails(String producerId) async {
    try {
      print('🔍 Chargement des détails pour le producteur $producerId');
      final uri = Uri.parse('${getBaseUrl()}/api/producers/$producerId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Erreur ${response.statusCode} lors du chargement des détails : ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Erreur dans getProducerDetails : $e');
      throw Exception('Erreur de connexion au serveur : $e');
    }
  }

  Future<Map<String, dynamic>> getProducerLeisureDetails(String producerId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/leisureproducers/$producerId');
      print('🔍 Requête détails producteur loisir vers : $url');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📩 Données producteur loisir reçues');
        return data;
      } else {
        print('❌ Erreur ${response.statusCode} : ${response.body}');
        throw Exception('Erreur lors de la récupération des détails du producteur de loisirs');
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
      throw Exception('Erreur de connexion au serveur');
    }
  }

  /// Recherche de lieux, producteurs ou posts
  static Future<List<dynamic>> search({
    String? motCle,
    double? latitude,
    double? longitude,
    double? rayon,
  }) async {
    try {
      final Map<String, dynamic> query = {
        'motCle': motCle,
        'latitude': latitude,
        'longitude': longitude,
        'rayon': rayon,
      }..removeWhere((key, value) => value == null);

      print('🔍 Recherche : $query');

      final uri = Uri.parse('${getBaseUrl()}/api/search');
      print('🔍 Requête vers : $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(query),
      );

      print('📩 Réponse reçue : ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Erreur ${response.statusCode} lors de la recherche : ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Erreur dans search : $e');
      throw Exception('Erreur de connexion au serveur : $e');
    }
  }

  Future<List<Post>> getFeed(String userId, int page, int limit) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/posts').replace(
        queryParameters: {
          'userId': userId,
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      print('🔍 Requête feed vers : $url');
      final response = await http.get(url);
      print('📩 Réponse reçue : ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        print('📦 Corps de la réponse brut : $responseBody');
        
        // Decoder proprement le JSON
        final decodedData = json.decode(responseBody);
        if (decodedData is! List) {
          throw FormatException('Format de réponse invalide: attendu une liste');
        }

        final posts = decodedData.map((item) {
          if (item is! Map<String, dynamic>) {
            print('⚠️ Item invalide: $item');
            return null;
          }
          try {
            return Post.fromJson(item);
          } catch (e) {
            print('❌ Erreur parsing post individuel: $e');
            return null;
          }
        }).whereType<Post>().toList();

        print('✅ Posts parsés avec succès: ${posts.length}');
        return posts;
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur getFeed: $e');
      rethrow;
    }
  }
  
  // Méthode fetchFeed avec support pour les endpoints et paramètres personnalisés
  Future<Map<String, dynamic>> fetchFeed({
    required String endpoint,
    Map<String, String>? queryParams,
  }) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/$endpoint')
          .replace(queryParameters: queryParams);

      print('🔍 Requête feed vers : $url');
      final response = await http.get(url);
      print('📩 Réponse reçue : ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        
        // Decoder proprement le JSON
        final decodedData = json.decode(responseBody);
        
        // Standardiser la réponse
        final result = <String, dynamic>{};
        
        if (decodedData is List) {
          // Si la réponse est une liste, la convertir en format standard
          result['items'] = decodedData;
          result['hasMore'] = decodedData.isNotEmpty;
        } else if (decodedData is Map) {
          // Si la réponse est déjà un Map, utiliser les champs standards s'ils existent
          result['items'] = decodedData['items'] ?? 
                       decodedData['posts'] ?? 
                       decodedData['data'] ?? 
                       decodedData;
          result['hasMore'] = decodedData['hasMore'] ?? 
                         decodedData['has_more'] ?? 
                         false;
        }
        
        return result;
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur fetchFeed: $e');
      throw Exception('Erreur lors de la récupération du feed: $e');
    }
  }
  
  // Suivre la vue d'un post pour les statistiques
  Future<bool> trackPostView({
    required String postId,
    required String userId,
  }) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/view');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur trackPostView: $e');
      return false;
    }
  }

  /// Récupérer la liste des amis
  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/friends').replace(
        queryParameters: {'userId': userId}
      );
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      throw Exception('Erreur lors de la récupération des amis');
    } catch (e) {
      print('❌ Erreur getFriends: $e');
      rethrow;
    }
  }

  /// Récupérer les activités des amis
  Future<List<Map<String, dynamic>>> getFriendsActivity({
    required String userId,
    double? latitude,
    double? longitude,
    double radius = 10000,
    bool showInterests = true,
    bool showChoices = true,
    List<String>? selectedFriends,
    List<String>? selectedCategories,
  }) async {
    try {
      final queryParams = {
        'userId': userId,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        'radius': radius.toString(),
        'showInterests': showInterests.toString(),
        'showChoices': showChoices.toString(),
        if (selectedFriends?.isNotEmpty ?? false) 'friends': selectedFriends!.join(','),
        if (selectedCategories?.isNotEmpty ?? false) 'categories': selectedCategories!.join(','),
      };

      final url = Uri.parse('${getBaseUrl()}/api/friendsActivity').replace(
        queryParameters: queryParams
      );
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      throw Exception('Erreur lors de la récupération des activités des amis');
    } catch (e) {
      print('❌ Erreur getFriendsActivity: $e');
      rethrow;
    }
  }

  // Méthode spécifique pour le feed des producteurs
  Future<Map<String, dynamic>> _fetchProducerFeed(int page, ProducerFeedContentType filter, String producerId) async {
    // API endpoint to get producer-specific feed
    String endpoint = '';
    switch (filter) {
      case ProducerFeedContentType.venue:
        endpoint = 'api/producers/$producerId/venue-posts';
        break;
      case ProducerFeedContentType.interactions:
        endpoint = 'api/producers/$producerId/interactions';
        break;
      case ProducerFeedContentType.localTrends:
        endpoint = 'api/producers/$producerId/local-trends';
        break;
    }
    
    final response = await fetchFeed(
      endpoint: endpoint,
      queryParams: {
        'page': page.toString(),
        'limit': '10',
      },
    );
    
    return response;
  }

  // Renommer la deuxième méthode fetchFeed pour éviter le conflit
  Future<Map<String, dynamic>> fetchProducerFeed({
    required String endpoint,
    required Map<String, String> queryParams,
  }) async {
    try {
      final Uri uri = _buildUri(endpoint, queryParams);
      print('🔍 Récupération du feed: $uri');
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('⚠️ Erreur API: ${response.statusCode}. Utilisation des données mockées.');
        // Générer des données mockées temporaires si l'API n'est pas disponible
        return _generateMockFeedData(endpoint, queryParams);
      }
    } catch (e) {
      print('❌ Exception: $e. Utilisation des données mockées.');
      // Générer des données mockées temporaires si l'API n'est pas disponible
      return _generateMockFeedData(endpoint, queryParams);
    }
  }
  
  Uri _buildUri(String endpoint, Map<String, String> queryParams) {
    String baseUrl = _baseUrl;
    
    // Nettoyer le baseUrl s'il termine par un slash
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    
    // Nettoyer l'endpoint s'il commence par un slash
    if (endpoint.startsWith('/')) {
      endpoint = endpoint.substring(1);
    }
    
    final Uri uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);
    return uri;
  }
  
  Map<String, dynamic> _generateMockFeedData(String endpoint, Map<String, String> queryParams) {
    final int page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
    final int limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
    
    bool isRestaurantProducer = !endpoint.contains('leisure');
    bool isLocalTrends = endpoint.contains('local-trends');
    bool isInteractions = endpoint.contains('interactions');
    bool isVenue = endpoint.contains('venue-posts');
    
    List<Map<String, dynamic>> items = [];
    
    // Déterminer quel type de contenu générer
    for (int i = 0; i < limit * 2; i++) { // Générer plus d'items pour pouvoir les trier
      if (isLocalTrends) {
        items.add(_generateLocalTrendPost(isRestaurantProducer, i));
      } else if (isInteractions) {
        items.add(_generateInteractionPost(isRestaurantProducer, i));
      } else {
        items.add(_generateVenuePost(isRestaurantProducer, i));
      }
    }
    
    // Trier les posts selon l'algorithme intelligent
    items = FeedConstants.sortPostsByScore(items);
    
    // Prendre seulement le nombre d'items demandés après tri
    if (items.length > limit) {
      items = items.sublist(0, limit);
    }
    
    return {
      'items': items,
      'hasMore': page < 3, // Limiter à 3 pages pour les données mockées
      'page': page,
      'total_pages': 3,
      'total_items': 30,
    };
  }
  
  Map<String, dynamic> _generateVenuePost(bool isRestaurantProducer, int index) {
    final timestamp = DateTime.now().subtract(Duration(hours: index * 3));
    final Map<String, dynamic> post = {
      '_id': 'venue_post_${timestamp.millisecondsSinceEpoch}_$index',
      'posted_at': timestamp.toIso8601String(),
      'time_posted': timestamp.toIso8601String(),
      'isProducerPost': true,
      'isLeisureProducer': !isRestaurantProducer,
      'producer_id': 'producer_${timestamp.millisecondsSinceEpoch}',
      'likes': List.generate(5 + index, (i) => 'user_$i'),
      'likes_count': 5 + index,
      'interested_count': 3 + index,
      'interestedCount': 3 + index,
      'choice_count': 2 + index,
      'choiceCount': 2 + index,
      'comments': List.generate(1 + (index % 3), (i) => {
        'id': 'comment_${i}_${timestamp.millisecondsSinceEpoch}',
        'userId': 'user_commenter_$i',
        'username': 'Utilisateur ${i + 1}',
        'userAvatar': 'https://picsum.photos/id/${50 + i}/100/100',
        'content': 'Commentaire ${i + 1} sur ce lieu. ${isRestaurantProducer ? "J\'adore ce restaurant !" : "Super endroit pour se détendre !"}',
        'timestamp': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
        'likes': List.generate(i, (j) => 'user_$j'),
      }),
    };
    
    // Ajouter des champs spécifiques selon le type de producteur
    if (isRestaurantProducer) {
      post.addAll({
        'content': 'Nouvelle spécialité de la semaine ! Notre chef vous propose ${index % 2 == 0 ? "une création unique" : "un plat traditionnel"} à découvrir dès maintenant. #gastronomie',
        'author_name': 'Restaurant Le Gourmet',
        'author_avatar': 'https://picsum.photos/id/${100 + index}/100/100',
        'author_id': 'restaurant_producer_1',
        'media': [
          {
            'type': 'image',
            'url': 'https://picsum.photos/id/${200 + index}/600/400',
            'thumbnail': 'https://picsum.photos/id/${200 + index}/100/100',
            'aspectRatio': 1.5,
          }
        ],
        'tags': ['restaurant', 'gastronomie', 'cuisine', 'paris'],
        'location': {
          'name': 'Restaurant Le Gourmet',
          'address': '123 Rue de Paris, 75001 Paris',
          'latitude': 48.856614,
          'longitude': 2.3522219,
        }
      });
    } else {
      post.addAll({
        'content': 'Nouvel événement à ne pas manquer ! ${index % 2 == 0 ? "Une exposition exceptionnelle" : "Un spectacle unique"} vous attend ce weekend. #culture #loisirs',
        'author_name': 'Espace Culturel Lumière',
        'author_avatar': 'https://picsum.photos/id/${150 + index}/100/100',
        'author_id': 'leisure_producer_1',
        'media': [
          {
            'type': 'image',
            'url': 'https://picsum.photos/id/${250 + index}/600/400',
            'thumbnail': 'https://picsum.photos/id/${250 + index}/100/100',
            'aspectRatio': 1.5,
          }
        ],
        'tags': ['culture', 'exposition', 'loisirs', 'paris'],
        'location': {
          'name': 'Espace Culturel Lumière',
          'address': '45 Avenue des Arts, 75014 Paris',
          'latitude': 48.845614,
          'longitude': 2.3422219,
        }
      });
    }
    
    return post;
  }
  
  Map<String, dynamic> _generateInteractionPost(bool isRestaurantProducer, int index) {
    final timestamp = DateTime.now().subtract(Duration(days: index % 7, hours: index * 2));
    final Map<String, dynamic> post = {
      '_id': 'interaction_${timestamp.millisecondsSinceEpoch}_$index',
      'posted_at': timestamp.toIso8601String(),
      'time_posted': timestamp.toIso8601String(),
      'isProducerPost': false,
      'isUserPost': true,
      'user_id': 'user_${100 + index}',
      'producer_id': 'producer_${timestamp.millisecondsSinceEpoch}',
      'likes': List.generate(3 + (index % 5), (i) => 'user_$i'),
      'likes_count': 3 + (index % 5),
      'comments': List.generate(index % 3, (i) => {
        'id': 'comment_${i}_${timestamp.millisecondsSinceEpoch}',
        'userId': 'user_commenter_$i',
        'username': 'Utilisateur ${i + 1}',
        'userAvatar': 'https://picsum.photos/id/${50 + i}/100/100',
        'content': 'Super expérience, merci !',
        'timestamp': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
        'likes': List.generate(i, (j) => 'user_$j'),
      }),
    };
    
    // Ajouter des champs spécifiques selon le type de producteur
    if (isRestaurantProducer) {
      final int rating = 4 + (index % 2);
      post.addAll({
        'content': 'J\'ai passé un excellent moment au restaurant ! ${rating}/5 ⭐️ La nourriture était ${rating == 5 ? "excellente" : "très bonne"} et le service impeccable.',
        'author_name': 'Jean Dupont',
        'author_avatar': 'https://picsum.photos/id/${300 + index}/100/100',
        'author_id': 'user_${100 + index}',
        'media': [
          {
            'type': 'image',
            'url': 'https://picsum.photos/id/${400 + index}/600/400',
            'thumbnail': 'https://picsum.photos/id/${400 + index}/100/100',
            'aspectRatio': 1.5,
          }
        ],
        'rating': rating,
        'location': {
          'name': 'Restaurant Le Gourmet',
          'address': '123 Rue de Paris, 75001 Paris',
          'latitude': 48.856614,
          'longitude': 2.3522219,
        }
      });
    } else {
      final int rating = 4 + (index % 2);
      post.addAll({
        'content': 'Superbe exposition ! ${rating}/5 ⭐️ J\'ai adoré découvrir ces œuvres exceptionnelles dans un cadre aussi agréable.',
        'author_name': 'Marie Martin',
        'author_avatar': 'https://picsum.photos/id/${350 + index}/100/100',
        'author_id': 'user_${150 + index}',
        'media': [
          {
            'type': 'image',
            'url': 'https://picsum.photos/id/${450 + index}/600/400',
            'thumbnail': 'https://picsum.photos/id/${450 + index}/100/100',
            'aspectRatio': 1.5,
          }
        ],
        'rating': rating,
        'location': {
          'name': 'Espace Culturel Lumière',
          'address': '45 Avenue des Arts, 75014 Paris',
          'latitude': 48.845614,
          'longitude': 2.3422219,
        }
      });
    }
    
    return post;
  }
  
  Map<String, dynamic> _generateLocalTrendPost(bool isRestaurantProducer, int index) {
    final timestamp = DateTime.now().subtract(Duration(days: index % 3, hours: index));
    final isCompetitor = index % 3 == 0;
    
    final Map<String, dynamic> post = {
      '_id': 'trend_${timestamp.millisecondsSinceEpoch}_$index',
      'posted_at': timestamp.toIso8601String(),
      'time_posted': timestamp.toIso8601String(),
      'isProducerPost': true,
      'isLeisureProducer': !isRestaurantProducer,
      'is_trending': true,
      'trend_score': 80 + (index % 20),
      'producer_id': isCompetitor ? 'competitor_${index}' : 'producer_${timestamp.millisecondsSinceEpoch}',
      'is_competitor': isCompetitor,
      'likes': List.generate(10 + index, (i) => 'user_$i'),
      'likes_count': 10 + index,
      'interested_count': 7 + index,
      'interestedCount': 7 + index,
      'comments': [],
    };
    
    // Ajouter des champs spécifiques selon le type de producteur
    if (isRestaurantProducer) {
      post.addAll({
        'content': isCompetitor 
            ? 'Découvrez notre nouvelle carte de saison ! Des saveurs uniques qui raviront vos papilles. #gastronomie'
            : 'Tendances culinaires à Paris : les plats qui font fureur en ce moment ! #foodtrends',
        'author_name': isCompetitor ? 'Restaurant Concurrent' : 'Tendances Gastronomiques',
        'author_avatar': 'https://picsum.photos/id/${500 + index}/100/100',
        'author_id': isCompetitor ? 'competitor_${index}' : 'trends_1',
        'media': [
          {
            'type': 'image',
            'url': 'https://picsum.photos/id/${600 + index}/600/400',
            'thumbnail': 'https://picsum.photos/id/${600 + index}/100/100',
            'aspectRatio': 1.5,
          }
        ],
        'tags': ['restaurant', 'gastronomie', 'tendances', 'paris'],
        'location': isCompetitor ? {
          'name': 'Restaurant Concurrent',
          'address': '456 Boulevard Saint-Germain, 75006 Paris',
          'latitude': 48.853614,
          'longitude': 2.3392219,
          'distance': '2.3 km'
        } : null
      });
    } else {
      post.addAll({
        'content': isCompetitor 
            ? 'Exposition exceptionnelle ce weekend ! Venez nombreux découvrir nos nouvelles acquisitions. #culture'
            : 'Les événements culturels à ne pas manquer ce mois-ci à Paris ! #culturaltrends',
        'author_name': isCompetitor ? 'Galerie Concurrente' : 'Guide Culturel Paris',
        'author_avatar': 'https://picsum.photos/id/${550 + index}/100/100',
        'author_id': isCompetitor ? 'competitor_${index}' : 'trends_2',
        'media': [
          {
            'type': 'image',
            'url': 'https://picsum.photos/id/${650 + index}/600/400',
            'thumbnail': 'https://picsum.photos/id/${650 + index}/100/100',
            'aspectRatio': 1.5,
          }
        ],
        'tags': ['culture', 'exposition', 'tendances', 'paris'],
        'location': isCompetitor ? {
          'name': 'Galerie Concurrente',
          'address': '789 Rue de Rivoli, 75001 Paris',
          'latitude': 48.863614,
          'longitude': 2.3372219,
          'distance': '3.1 km'
        } : null
      });
    }
    
    return post;
  }

  /// Marque un contenu comme intéressant
  Future<bool> markInterested(String userId, String targetId, {bool isLeisureProducer = false}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/interactions/interest',
        data: {
          'userId': userId,
          'targetId': targetId,
          'isLeisureProducer': isLeisureProducer,
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error marking interest: $e');
      return false;
    }
  }

  /// Marque un contenu comme choix
  Future<bool> markChoice(String userId, String targetId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/interactions/choice',
        data: {
          'userId': userId,
          'targetId': targetId,
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error marking choice: $e');
      return false;
    }
  }

  /// Like un post (pour la compatibilité avec le code existant)
  Future<bool> likePost(String userId, String postId) async {
    return toggleLike(userId, postId);
  }

  // Ajouter la méthode getPostDetails
  Future<Map<String, dynamic>> getPostDetails(String postId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/posts/$postId');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else {
        print('❌ Erreur lors de la récupération du post: ${response.statusCode}');
        // En cas d'erreur, utiliser des données mockées
        return _generateMockPostDetail(postId);
      }
    } catch (e) {
      print('❌ Exception lors de la récupération du post: $e');
      // En cas d'erreur, utiliser des données mockées
      return _generateMockPostDetail(postId);
    }
  }

  // Méthode pour générer un post moqué pour les tests
  Map<String, dynamic> _generateMockPostDetail(String postId) {
    return {
      '_id': postId,
      'author_id': 'user_mock',
      'author_name': 'Utilisateur Test',
      'author_avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=150&h=150',
      'content': 'Ceci est un post de test généré localement car le serveur est indisponible.',
      'posted_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'interested_count': 5,
      'choice_count': 2,
      'likes_count': 10,
      'comments': [
        {
          '_id': 'comment_mock_1',
          'author_id': 'commenter_1',
          'author_name': 'Commentateur 1',
          'author_avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=150&h=150',
          'content': 'Très beau post !',
          'posted_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          '_id': 'comment_mock_2',
          'author_id': 'commenter_2',
          'author_name': 'Commentateur 2',
          'author_avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=150&h=150',
          'content': 'Je suis d\'accord !',
          'posted_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        },
      ],
      'media': [
        {
          'url': 'https://images.unsplash.com/photo-1519692933481-e162a57d6721?auto=format&fit=crop&w=1200&q=80',
          'type': 'image',
        },
      ],
      'isProducerPost': true,
      'isLeisureProducer': false,
    };
  }
}
