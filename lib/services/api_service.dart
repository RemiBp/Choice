import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../utils/feed_constants.dart';
import '../models/post.dart';
import '../models/comment.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:dio/dio.dart';
import '../screens/utils.dart';
import 'dart:math' as math;

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
      final baseUrl = getBaseUrl();
      print('🌐 URL de base: $baseUrl');
      print('📡 Appel API: GET $baseUrl/api/feed?userId=$userId&page=$page&limit=$limit');
      
      final response = await _dio.get(
        '$baseUrl/api/feed',
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
        options: Options(
          validateStatus: (status) => true,  // Accept all status codes for debugging
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('📥 Réponse reçue - Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.data == null) {
          print('❌ Données nulles reçues');
          return [];
        }
        
        print('✅ Données reçues: ${response.data.toString().substring(0, math.min(100, response.data.toString().length))}...');
        
        if (response.data['feed'] == null) {
          print('❌ Feed non trouvé dans les données');
          return [];
        }
        
        final List<dynamic> data = response.data['feed'];
        return data.map((json) {
          // Adapter les données du backend au format attendu par Post.fromMap
          return Post.fromJson({
            '_id': json['_id']?.toString(),
            'authorId': json['author_id']?.toString(),
            'authorName': json['author_name'] ?? 'Utilisateur',
            'authorAvatar': json['author_photo'] ?? '',
            'content': json['content'] ?? '',
            'mediaUrls': json['media_urls'] ?? [],
            'createdAt': json['created_at'] ?? json['time_posted'] ?? DateTime.now().toIso8601String(),
            'postedAt': json['time_posted'] ?? DateTime.now().toIso8601String(),
            'likes': json['likes'] ?? [],
            'interests': json['interests'] ?? [],
            'choices': json['choices'] ?? [],
            'comments': json['comments'] ?? [],
            'isProducerPost': json['isProducerPost'] ?? false,
            'isLeisureProducer': json['isLeisureProducer'] ?? false,
            'isAutomated': json['isAutomated'] ?? false,
            'metadata': json['metadata'],
          });
        }).toList();
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        print('📄 Corps de la réponse: ${response.data}');
        throw Exception('Erreur lors du chargement du feed: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      print('❌ Exception lors du chargement du feed: $e');
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
    final url = Uri.parse('${_baseUrl}/api/users/$userId/saved-posts');
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
    final url = Uri.parse('${_baseUrl}/api/media/upload');
    
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
      final url = Uri.parse('${_baseUrl}/api/media/upload/profile');
      
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
      
      final baseUrl = getBaseUrl();
      final uri = Uri.parse('${baseUrl}/api/user/$userId');
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
      
      final baseUrl = getBaseUrl();
      final uri = Uri.parse('${baseUrl}/api/user/$userId/favorites');
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
      final uri = Uri.parse('${_baseUrl}/api/producers/$producerId');
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
      final url = Uri.parse('${_baseUrl}/api/leisureproducers/$producerId');
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
      
      final baseUrl = getBaseUrl();
      final uri = Uri.parse('${baseUrl}/api/search');
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
      final url = Uri.parse('${_baseUrl}/api/posts').replace(
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
      final url = Uri.parse('${_baseUrl}/$endpoint')
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
      final url = Uri.parse('${_baseUrl}/api/posts/$postId/view');
      
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

  // Méthode pour obtenir les données utilisateur
  // Suppression de cette méthode dupliquée - nous conservons getUserProfile ci-dessus
  
  // Méthode pour obtenir les favoris de l'utilisateur
  // Suppression de cette méthode dupliquée - nous conservons getUserFavorites ci-dessus
  
  // Méthode pour obtenir les détails d'un producteur
  // Suppression de cette méthode dupliquée - nous conservons getProducerDetails ci-dessus

  // Méthode pour rechercher des producteurs
  Future<List<dynamic>> searchProducers(String query, {int? page}) async {
    try {
      final uri = Uri.parse('${_baseUrl}/api/search');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'page': page ?? 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results'] ?? [];
      } else {
        throw Exception('Failed to search producers');
      }
    } catch (e) {
      throw Exception('Error searching producers: $e');
    }
  }

  // Méthode pour obtenir les publications d'un producteur
  Future<List<dynamic>> getProducerPosts(String producerId, {int page = 1, int limit = 10}) async {
    try {
      final url = Uri.parse('${_baseUrl}/api/posts').replace(
        queryParameters: {
          'producerId': producerId,
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['posts'] ?? [];
      } else {
        throw Exception('Failed to load producer posts');
      }
    } catch (e) {
      throw Exception('Error getting producer posts: $e');
    }
  }

  // Méthode générique pour les appels d'API
  Future<dynamic> apiCall(String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? params,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    try {
      final url = Uri.parse('${_baseUrl}/$endpoint')
          .replace(queryParameters: params);
      
      headers ??= {'Content-Type': 'application/json'};
      
      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: data != null ? json.encode(data) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: headers,
            body: data != null ? json.encode(data) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body);
      } else {
        throw Exception('API call failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API call error: $e');
    }
  }

  // Enregistrer une vue sur un post
  Future<void> recordPostView(String postId) async {
    try {
      final url = Uri.parse('${_baseUrl}/api/posts/$postId/view');
      final response = await http.post(url);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to record post view');
      }
    } catch (e) {
      // Silently fail as this is non-critical
      print('Error recording post view: $e');
    }
  }

  // Obtenir les amis d'un utilisateur
  Future<List<dynamic>> getUserFriends(String userId, {int page = 1, int limit = 20}) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/users/$userId/friends');
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Erreur lors de la récupération des amis: ${response.statusCode}');
        // Données simulées pour les tests
        return [
          {
            'id': 'friend1',
            'name': 'Alice Dupont',
            'avatar': 'https://randomuser.me/api/portraits/women/12.jpg',
            'status': 'online',
            'lastSeen': DateTime.now().toIso8601String(),
          },
          {
            'id': 'friend2',
            'name': 'Thomas Martin',
            'avatar': 'https://randomuser.me/api/portraits/men/33.jpg',
            'status': 'offline',
            'lastSeen': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
          },
          {
            'id': 'friend3',
            'name': 'Sophie Petit',
            'avatar': 'https://randomuser.me/api/portraits/women/56.jpg',
            'status': 'online',
            'lastSeen': DateTime.now().toIso8601String(),
          }
        ];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des amis: $e');
      // Données simulées pour les tests
      return [
        {
          'id': 'friend1',
          'name': 'Alice Dupont',
          'avatar': 'https://randomuser.me/api/portraits/women/12.jpg',
          'status': 'online',
          'lastSeen': DateTime.now().toIso8601String(),
        },
        {
          'id': 'friend2',
          'name': 'Thomas Martin',
          'avatar': 'https://randomuser.me/api/portraits/men/33.jpg',
          'status': 'offline',
          'lastSeen': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
        }
      ];
    }
  }

  // Récupérer les centres d'intérêt d'un ami
  Future<List<dynamic>> getFriendInterests(String friendId) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/users/$friendId/interests');
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Erreur lors de la récupération des intérêts: ${response.statusCode}');
        // Données simulées pour les tests
        return [
          {
            '_id': 'interest1',
            'venue': {
              'name': 'Café des Arts',
              'category': 'Café',
              'location': {
                'type': 'Point',
                'coordinates': [2.3522, 48.8566]
              },
              'address': '15 rue des Arts, Paris',
              'photo': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?ixlib=rb-1.2.1&w=1080&q=80',
              'description': 'Un café charmant au cœur de Paris'
            },
            'created_at': DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
            'comment': 'J\'aimerais bien essayer ce café bientôt'
          },
          {
            '_id': 'interest2',
            'venue': {
              'name': 'Restaurant La Bonne Table',
              'category': 'Restaurant',
              'location': {
                'type': 'Point',
                'coordinates': [2.3612, 48.8676]
              },
              'address': '27 avenue Montaigne, Paris',
              'photo': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-1.2.1&w=1080&q=80',
              'description': 'Cuisine traditionnelle française dans un cadre élégant'
            },
            'created_at': DateTime.now().subtract(Duration(days: 5)).toIso8601String()
          }
        ];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des intérêts: $e');
      // Données simulées pour les tests
      return [
        {
          '_id': 'interest1',
          'venue': {
            'name': 'Café des Arts',
            'category': 'Café',
            'location': {
              'type': 'Point',
              'coordinates': [2.3522, 48.8566]
            },
            'address': '15 rue des Arts, Paris',
            'photo': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?ixlib=rb-1.2.1&w=1080&q=80'
          },
          'created_at': DateTime.now().subtract(Duration(days: 2)).toIso8601String()
        }
      ];
    }
  }

  // Récupérer les choix d'un ami
  Future<List<dynamic>> getFriendChoices(String friendId) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/users/$friendId/choices');
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Erreur lors de la récupération des choix: ${response.statusCode}');
        // Données simulées pour les tests
        return [
          {
            '_id': 'choice1',
            'venue': {
              'name': 'Bistrot du Coin',
              'category': 'Restaurant',
              'location': {
                'type': 'Point',
                'coordinates': [2.3522, 48.8566]
              },
              'address': '42 rue de la Paix, Paris',
              'photo': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?ixlib=rb-1.2.1&w=1080&q=80',
              'description': 'Bistrot traditionnel parisien'
            },
            'visit_date': DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
            'rating': 4.5,
            'review': 'Excellent bistrot, service attentionné et cuisine délicieuse'
          },
          {
            '_id': 'choice2',
            'venue': {
              'name': 'Le Café Moderne',
              'category': 'Café',
              'location': {
                'type': 'Point',
                'coordinates': [2.3452, 48.8596]
              },
              'address': '12 boulevard Haussman, Paris',
              'photo': 'https://images.unsplash.com/photo-1534040385115-33dcb3acba5b?ixlib=rb-1.2.1&w=1080&q=80',
              'description': 'Café moderne avec une belle terrasse'
            },
            'visit_date': DateTime.now().subtract(Duration(days: 14)).toIso8601String(),
            'rating': 4.0,
            'review': 'Beau café, bons produits et belle décoration'
          }
        ];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des choix: $e');
      // Données simulées pour les tests
      return [
        {
          '_id': 'choice1',
          'venue': {
            'name': 'Bistrot du Coin',
            'category': 'Restaurant',
            'location': {
              'type': 'Point',
              'coordinates': [2.3522, 48.8566]
            },
            'address': '42 rue de la Paix, Paris',
            'photo': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?ixlib=rb-1.2.1&w=1080&q=80'
          },
          'visit_date': DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
          'rating': 4.5
        }
      ];
    }
  }

  // Récupérer l'historique des emplacements
  Future<List<dynamic>> getLocationHistory() async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/location-history');
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Erreur lors de la récupération de l\'historique: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  // Récupérer les points chauds dans une zone
  Future<List<dynamic>> getHotspots(double latitude, double longitude, {double radius = 2000}) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/location-history/hotspots')
        .replace(queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'radius': radius.toString()
        });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Erreur lors de la récupération des points chauds: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des points chauds: $e');
      return [];
    }
  }

  // Récupérer la localisation d'un producteur
  Future<Map<String, dynamic>> getProducerLocation(String producerId) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/api/producers/$producerId/location');
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Erreur lors de la récupération de la localisation: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la localisation: $e');
      return {};
    }
  }

  /// Obtient les producteurs proches d'une position donnée
  Future<List<dynamic>> getNearbyProducers(double latitude, double longitude, {double radius = 5000}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/producers/nearby')
        .replace(queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'radius': radius.toString(),
        });
        
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['producers'] ?? [];
      } else {
        print('❌ Erreur lors de la récupération des producteurs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception: $e');
      // Retourner des données fictives en cas d'erreur
      return _getFakeProducers(latitude, longitude);
    }
  }
  
  /// Génère des données factices de producteurs
  List<Map<String, dynamic>> _getFakeProducers(double latitude, double longitude) {
    final List<Map<String, dynamic>> fakeProducers = [];
    final random = math.Random();
    
    final List<String> categories = ['Restaurant', 'Café', 'Bar', 'Boulangerie', 'Épicerie'];
    final List<String> tags = ['Bio', 'Local', 'Végétarien', 'Vegan', 'Sans gluten', 'Zéro déchet'];
    
    // Générer 10 producteurs aléatoires
    for (int i = 0; i < 10; i++) {
      // Position aléatoire dans un rayon de 5km
      final double distance = random.nextDouble() * 0.05;
      final double angle = random.nextDouble() * math.pi * 2;
      final double lat = latitude + distance * math.sin(angle);
      final double lon = longitude + distance * math.cos(angle);
      
      fakeProducers.add({
        '_id': 'fake_${i}_${random.nextInt(10000)}',
        'name': 'Producteur ${i + 1}',
        'description': 'Un super endroit à découvrir !',
        'address': '${random.nextInt(100)} rue Example, Paris',
        'category': categories[random.nextInt(categories.length)],
        'tags': List.generate(
          random.nextInt(3) + 1, 
          (_) => tags[random.nextInt(tags.length)]
        ),
        'rating': (3 + random.nextInt(20) / 10).toStringAsFixed(1),
        'is_from_friend': random.nextBool(),
        'gps_coordinates': {
          'type': 'Point',
          'coordinates': [lon, lat]
        },
        'friend_interests': random.nextBool() 
          ? List.generate(random.nextInt(3) + 1, (_) => tags[random.nextInt(tags.length)])
          : [],
      });
    }
    
    return fakeProducers;
  }
}
