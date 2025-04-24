import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../utils/feed_constants.dart';
import '../utils/constants.dart' as constants;
import '../models/post.dart';
import '../models/comment.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:dio/dio.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/utils.dart';
import '../models/media.dart' as app_media;
import '../models/kpi_data.dart';
import '../models/recommendation_data.dart';
import '../models/profile_data.dart';
import '../models/sales_data.dart';
import '../models/ai_query_response.dart';
import '../services/auth_service.dart';

// Enum manquant pour les types de contenu du feed du producteur
enum ProducerFeedContentType {
  venue,
  interactions, 
  localTrends,
  followers // Add followers type to match the enum in producer_feed_screen.dart
}

// Add missing enum
enum ProducerFeedLoadState { initial, loading, loaded, loadingMore, error }

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  String? _userId;
  String? get userId => _userId;

  ApiService._internal() {
    _initDio();
    _initUserId();
  }

  /// Méthode pour obtenir l'URL de base de façon cohérente
  static String getBaseUrl() {
    return constants.getBaseUrl();
  }

  /// Initialisation du client HTTP commun avec intercepteurs pour logging
  static final http.Client _client = http.Client();
  
  // Logger (désactivé car HttpLoggingInterceptor n'est pas disponible)
  // static final _interceptor = HttpLoggingInterceptor(...);

  late Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  Future<void> _initUserId() async {
    try {
      _userId = await _secureStorage.read(key: 'userId');
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'ID utilisateur: $e');
    }
  }
  
  Future<void> setUserId(String id) async {
    _userId = id;
    try {
      await _secureStorage.write(key: 'userId', value: id);
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement de l\'ID utilisateur: $e');
    }
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: constants.getBaseUrlSync(),
      connectTimeout: Duration(milliseconds: 30000),    // Augmenté de 8000 à 30000 ms
      receiveTimeout: Duration(milliseconds: 30000),    // Augmenté de 12000 à 30000 ms
      sendTimeout: Duration(milliseconds: 30000),       // Augmenté de 8000 à 30000 ms
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Connection': 'keep-alive',
      },
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
    
    // Ajouter un intercepteur personnalisé pour gérer les erreurs réseau de manière cohérente
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, ErrorInterceptorHandler handler) {
        print('🔴 Erreur Dio interceptée: ${e.type} - ${e.message}');
        
        // Personnaliser le message d'erreur pour faciliter le débogage
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          print('⚠️ Timeout détecté: ${e.requestOptions.uri}');
          e = DioException(
            requestOptions: e.requestOptions,
            error: "Le délai de connexion a été dépassé. Veuillez vérifier votre connexion internet et réessayer.",
            type: e.type,
          );
        } else if (e.type == DioExceptionType.connectionError) {
          print('⚠️ Erreur de connexion: ${e.requestOptions.uri}');
          e = DioException(
            requestOptions: e.requestOptions,
            error: "Impossible de se connecter au serveur. Veuillez vérifier votre connexion internet.",
            type: e.type,
          );
        }
        
        return handler.next(e);
      },
    ));
  }

  // Méthode pour récupérer les posts principaux du feed
  Future<dynamic> getFeedPosts(String userId, {int page = 1, int limit = 10}) async {
    try {
      print('📥 Récupération des posts du feed pour utilisateur $userId (page $page, limit $limit)');
      final response = await _dio.get(
        '/api/posts',
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
      );

      print('*** Response ***');
      print('uri: ${response.requestOptions.uri}');
      print('Response Text:');
      print('${response.data is String ? response.data : 'Not string data'}');
      print('');
      
      if (response.statusCode == 200) {
        print('📥 Réponse reçue - Status: ${response.statusCode}');
        
        // Vérifier le type de réponse et adapter le traitement
        if (response.data is List) {
          // Si la réponse est une simple liste, la renvoyer telle quelle
          print('✅ Données reçues: ${(response.data as List).length} éléments');
          return response.data;
        } else if (response.data is Map && response.data['posts'] != null) {
          // Si la réponse est un objet avec une clé 'posts', extraire cette liste
          print('✅ Données reçues: ${(response.data['posts'] as List).length} posts');
          return response.data['posts'];
        } else {
          // Format inconnu, renvoyer la réponse brute
          print('⚠️ Format de réponse non reconnu');
          return response.data;
        }
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
  
  // Méthode pour récupérer les posts pour le feed principal
  Future<List<Post>> getPostsForFeed(String userId, {int page = 1, int limit = 10}) async {
    try {
      print('*** Request ***');
      print('uri: ${_dio.options.baseUrl}/api/feed?userId=$userId&page=$page&limit=$limit');
      print('');
      
      final response = await _dio.get(
        '/api/feed',
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
      );
      
      print('*** Response ***');
      print('uri: ${response.requestOptions.uri}');
      print('Response Text:');
      print('${response.data is String ? response.data : 'Not string data'}');
      print('');
      
      if (response.statusCode == 200) {
        List<Post> posts = [];
        try {
          if (response.data is List) {
            // Analyse chaque élément de la liste et tente de créer un Post
            posts = (response.data as List).map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  // Vérifier et corriger les médias si nécessaire
                  _processAndFixMediaUrls(item);
                  
                  // S'assurer que les informations d'auteur sont présentes
                  _ensureAuthorInfo(item);
                  
                  return Post.fromJson(item);
                } else {
                  print('❌ Format d\'élément inattendu dans la liste: ${item.runtimeType}');
                  return null;
                }
              } catch (e) {
                print('❌ Erreur lors de la conversion d\'un élément en Post: $e');
                return null;
              }
            }).where((post) => post != null).cast<Post>().toList();
          } else if (response.data is Map && response.data['posts'] != null) {
            // Si la réponse est un objet avec une clé 'posts'
            final postsData = response.data['posts'] as List;
            posts = postsData.map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  // Vérifier et corriger les médias si nécessaire
                  _processAndFixMediaUrls(item);
                  
                  // S'assurer que les informations d'auteur sont présentes
                  _ensureAuthorInfo(item);
                  
                  return Post.fromJson(item);
                } else {
                  print('❌ Format d\'élément inattendu dans posts: ${item.runtimeType}');
                  return null;
                }
              } catch (e) {
                print('❌ Erreur lors de la conversion d\'un élément en Post: $e');
                return null;
              }
            }).where((post) => post != null).cast<Post>().toList();
          } else {
            print('❌ Format de réponse non supporté: ${response.data.runtimeType}');
          }
        } catch (e) {
          print('❌ Erreur lors du traitement de la réponse: $e');
        }
        
        // Vérification finale - assurer que tous les posts ont des données cohérentes
        posts = posts.where((post) => 
          post.id.isNotEmpty && 
          (post.authorName?.isNotEmpty ?? false) && 
          (post.content?.isNotEmpty ?? post.description.isNotEmpty)
        ).toList();
        
        print('✅ Posts récupérés et traités: ${posts.length}');
        return posts;
      } else {
        print('❌ Error fetching feed posts: ${response.statusCode}');
        // Fallback to user posts
        return getUserPosts(userId, page: page, limit: limit);
      }
    } on DioException catch (e) {
      print('❌ Dio Error fetching feed posts: ${e.type} - ${e.message}');
      print('   Cause: ${e.error}');
      return [];
    } catch (e) {
      print('❌ Error fetching feed posts: $e');
      return [];
    }
  }
  
  // Méthodes spécifiques pour les différents types de contenu
  Future<List<Post>> getRestaurantPosts(String userId, {int page = 1, int limit = 10, String? filter}) async {
    try {
      print('🔍 REQUÊTE RESTAURANT: userId=$userId, page=$page, limit=$limit, filter=$filter');
      
      // Nouvelle route spécifique pour les posts de restaurants
      String endpoint = '/api/posts/restaurants';
      
      // Utiliser les autres routes selon le contexte
      if (filter == 'followed') {
        endpoint = '/api/posts/producers';
      } else if (filter == 'producer') {
        endpoint = '/api/producer-feed/$userId/venue-posts';
      } else if (filter == 'deprecated') {
        endpoint = '/api/producers/posts';
      }
      
      print('📌 GET ${endpoint}?page=$page&limit=$limit');
      
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'page': page,
          'limit': limit,
          'userId': userId,
          'type': 'restaurant',
          'prioritizeFollowed': filter == 'followed' ? 'true' : 'false',
        },
        options: Options(
          sendTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10),
        ),
      );
      
      print('📤 RÉPONSE [${response.statusCode}] depuis $endpoint');
      
      if (response.statusCode == 200) {
        List<Post> posts = [];
        
        if (response.data is List) {
          posts = (response.data as List).map((json) => Post.fromJson(json)).toList();
          print('✅ ${posts.length} posts de restaurants convertis depuis une liste');
        } else if (response.data is Map && response.data['posts'] != null) {
          final postsData = response.data['posts'] as List;
          posts = postsData.map((json) => Post.fromJson(json)).toList();
          print('✅ ${posts.length} posts de restaurants convertis depuis posts.data');
        } else {
          print('⚠️ Format de réponse non reconnu pour les posts de restaurants');
        }
        
        return posts;
      } else {
        print('❌ Erreur HTTP lors de la récupération des posts de restaurants: ${response.statusCode}');
        print('📄 Corps de la réponse: ${response.data}');
        return [];
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        print('❌ Timeout lors de la récupération des posts de restaurants: ${e.message}');
      } else {
        print('❌ Erreur Dio lors de la récupération des posts de restaurants: ${e.message}');
      }
      return [];
    } catch (e) {
      print('❌ Exception lors de la récupération des posts de restaurants: $e');
      return [];
    }
  }
  
  Future<List<Post>> getLeisurePosts(String userId, {int page = 1, int limit = 10, String? filter}) async {
    try {
      String endpoint = '/api/posts/leisure';
      
      // Utiliser la route pour les producteurs suivis si demandé
      if (filter == 'followed') {
        endpoint = '/api/posts/producers';
      }
      
      // Utiliser la route spécifique du producteur si nécessaire
      if (filter == 'producer') {
        endpoint = '/api/producers/$userId/leisure_posts';
      }
      
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
          'type': 'leisure',
          'prioritizeFollowed': filter == 'followed' ? 'true' : 'false',
          if (filter != null && filter != 'producer' && filter != 'followed') 'filter': filter,
        },
      );
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return (response.data as List).map((json) => Post.fromJson(json)).toList();
        } else if (response.data is Map && response.data['posts'] != null) {
          final posts = response.data['posts'] as List;
          return posts.map((json) => Post.fromJson(json)).toList();
        }
        return [];
      } else {
        print('❌ Error fetching leisure posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching leisure posts: $e');
      return [];
    }
  }
  
  Future<List<Post>> getWellnessPosts(String userId, {int page = 1, int limit = 10, String? filter}) async {
    try {
      print('🔍 REQUÊTE BIEN-ÊTRE: userId=$userId, page=$page, limit=$limit, filter=$filter');
      
      // Définir la route API pour les posts bien-être
      String endpoint = '/api/posts/wellness';
      
      // Utiliser différentes routes selon le contexte
      if (filter == 'followed') {
        endpoint = '/api/posts/producers';
      } else if (filter == 'producer') {
        endpoint = '/api/producers/$userId/wellness_posts';
      }
      
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
          'type': 'wellness',
          'prioritizeFollowed': filter == 'followed' ? 'true' : 'false',
          if (filter != null && filter != 'producer' && filter != 'followed') 'filter': filter,
        },
        options: Options(
          sendTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10),
        ),
      );
      
      print('📤 RÉPONSE [${response.statusCode}] depuis $endpoint');
      
      if (response.statusCode == 200) {
        List<Post> posts = [];
        
        if (response.data is List) {
          posts = (response.data as List).map((json) => Post.fromJson(json)).toList();
          print('✅ ${posts.length} posts bien-être convertis depuis une liste');
        } else if (response.data is Map && response.data['posts'] != null) {
          final postsData = response.data['posts'] as List;
          posts = postsData.map((json) => Post.fromJson(json)).toList();
          print('✅ ${posts.length} posts bien-être convertis depuis posts.data');
        } else {
          print('⚠️ Format de réponse non reconnu pour les posts bien-être');
        }
        
        return posts;
      } else {
        print('❌ Erreur HTTP lors de la récupération des posts bien-être: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        print('❌ Timeout lors de la récupération des posts bien-être: ${e.message}');
      } else {
        print('❌ Erreur Dio lors de la récupération des posts bien-être: ${e.message}');
      }
      return [];
    } catch (e) {
      print('❌ Exception lors de la récupération des posts bien-être: $e');
      return [];
    }
  }
  
  Future<List<Post>> getUserPosts(String userId, {int? page, int? limit}) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/user/$userId');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await getToken()}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((post) => Post.fromJson(post)).toList();
    } else {
      throw Exception('Failed to load user posts');
    }
  }
  
  // Méthode pour récupérer des posts filtrés par type de contenu
  Future<List<Post>> getFilteredFeedPosts(String userId, {required String contentType, int page = 1, int limit = 10}) async {
    try {
      String endpoint = '/api/posts';
      
      // Ajouter le type de contenu si spécifié
      if (contentType.isNotEmpty) {
        endpoint = '/api/posts/$contentType';
      }
      
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
        },
      );
      
      if (response.statusCode == 200) {
        // Vérifier le type de réponse et adapter le traitement
        if (response.data is List) {
          return (response.data as List).map((json) => Post.fromJson(json)).toList();
        } else if (response.data is Map && response.data['posts'] != null) {
          final posts = response.data['posts'] as List;
          return posts.map((json) => Post.fromJson(json)).toList();
        }
        return [];
      } else {
        // En cas d'erreur, essayer avec l'endpoint générique
        return await getFeedPosts(userId, page: page, limit: limit);
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des posts filtrés: $e');
      // Fallback sur l'endpoint principal
      return await getFeedPosts(userId, page: page, limit: limit);
    }
  }

  Future<bool> toggleInterest(String userId, String targetId) async {
    try {
      final response = await _dio.post(
        '${constants.getBaseUrl()}/api/interactions/interest',
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
        '${constants.getBaseUrl()}/api/interactions/choice',
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
        '${constants.getBaseUrl()}/api/posts/save',
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

  // Unified addComment method that handles both parameter styles
  Future<Map<String, dynamic>> addComment(
    String postId, 
    String userId, 
    String content,
    {String? authorId}
  ) async {
    // If authorId is provided via named parameter, use it instead
    final String effectiveAuthorId = authorId ?? userId;
    
    try {
      final token = await _getToken();
      final url = Uri.parse('${await constants.getBaseUrl()}/api/posts/$postId/comments');
      print('🌐 POST Comment: $url');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'post_id': postId,
          'user_id': effectiveAuthorId,
          'content': content,
          'authorId': effectiveAuthorId,
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Commentaire créé avec succès
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Retourner directement la map au lieu de convertir en Comment
        return {
          'id': data['_id'] ?? '',
          'authorId': data['author_id'] ?? effectiveAuthorId,
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
        'authorId': effectiveAuthorId,
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
        return Post.fromJson(response.data['post']);
      } else {
        throw Exception('Erreur lors de la création du post');
      }
    } catch (e) {
      print('❌ Erreur lors de la création du post: $e');
      rethrow;
    }
  }

  Future<List<Post>> getSavedPosts(String userId) async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/users/$userId/saved-posts');
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
    final url = Uri.parse('${constants.getBaseUrl()}/api/media/upload');
    
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
      final url = Uri.parse('${constants.getBaseUrl()}/api/media/upload/profile');
      
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
      
      final baseUrl = await constants.getBaseUrl();
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
      
      final baseUrl = await constants.getBaseUrl();
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
      final url = Uri.parse('${constants.getBaseUrl()}/api/leisureproducers/$producerId');
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
      
      final baseUrl = await constants.getBaseUrl();
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
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts').replace(
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
                         decodedData['totalPages'] > decodedData['currentPage'] ?? 
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
  
  // Nouvelle méthode pour obtenir le feed du producteur
  Future<Map<String, dynamic>> getProducerFeed(
    String producerId,
    {
      ProducerFeedContentType contentType = ProducerFeedContentType.venue,
      int page = 1,
      int limit = 10,
      String? producerType,
      String? category,
    }
  ) async {
    final token = await _getToken();
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'contentType': contentType.name,
      if (producerType != null) 'producerType': producerType,
      if (category != null) 'category': category,
    };
    final url = Uri.parse('${await constants.getBaseUrl()}/api/producers/$producerId/feed').replace(queryParameters: queryParams);
    print('🚀 GET Producer Feed: $url');

    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'items': data['items'] ?? [],
          'hasMore': data['pagination']?['hasNextPage'] ?? false,
        };
      } else {
        print('❌ Error getting producer feed: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load producer feed');
      }
    } catch (e) {
      print('❌ Exception getting producer feed: $e');
      throw Exception('Failed to load producer feed: $e');
    }
  }

  // --- Post Interaction Methods ---

  Future<String> getToken() async {
    final storage = FlutterSecureStorage();
    return await storage.read(key: 'auth_token') ?? '';
  }

  Future<String> getUserId() async {
    final storage = FlutterSecureStorage();
    return await storage.read(key: 'user_id') ?? '';
  }

  // Helper to get token (ensure it handles null)
  Future<String?> _getToken() async {
    return await AuthService().getTokenInstance();
  }

  // --- Producer Analytics Endpoints --- 

  Future<List<KpiData>> getKpis(String producerType, String producerId) async {
    final String token = await getToken() ?? '';
    final url = Uri.parse('${getBaseUrl()}/api/analytics/kpis/$producerType/$producerId');
    print('🚀 GET KPIs: $url');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ KPIs received: ${data.length}');
        return data.map((kpiJson) => KpiData.fromJson(kpiJson)).toList();
      } else {
        print('❌ Error fetching KPIs: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load KPIs: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception fetching KPIs: $e');
      rethrow; // Or return empty list: return [];
    }
  }

  Future<List<SalesData>> getTrends(String producerType, String producerId, String period) async {
    final String token = await getToken() ?? '';
    final url = Uri.parse('${getBaseUrl()}/api/analytics/trends/$producerType/$producerId?period=$period');
     print('🚀 GET Trends: $url');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
         print('✅ Trends received: ${data.length} points for period $period');
        return data.map((trendJson) => SalesData.fromJson(trendJson)).toList();
      } else {
        print('❌ Error fetching Trends: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load trends: ${response.statusCode}');
      }
    } catch (e) {
       print('❌ Exception fetching Trends: $e');
      rethrow; // Or return empty list: return [];
    }
  }

  Future<List<ProfileData>> getCompetitors(String producerType, String producerId) async {
    final String token = await getToken() ?? '';
    final url = Uri.parse('${getBaseUrl()}/api/analytics/competitors/$producerType/$producerId');
     print('🚀 GET Competitors: $url');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
         print('✅ Competitors received: ${data.length}');
        // Assuming ProfileData.fromJson exists and handles the competitor structure
        return data.map((compJson) => ProfileData.fromJson(compJson)).toList();
      } else {
         print('❌ Error fetching Competitors: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load competitors: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception fetching Competitors: $e');
      rethrow; // Or return empty list: return [];
    }
  }

  // --- Producer AI Endpoints --- 

  Future<List<RecommendationData>> getRecommendations(String producerType, String producerId) async {
    final String token = await getToken() ?? '';
    final url = Uri.parse('${getBaseUrl()}/api/ai/recommendations/$producerType/$producerId');
     print('🚀 GET Recommendations: $url');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
         print('✅ Recommendations received: ${data.length}');
        return data.map((recJson) => RecommendationData.fromJson(recJson)).toList();
      } else {
         print('❌ Error fetching Recommendations: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load recommendations: ${response.statusCode}');
      }
    } catch (e) {
       print('❌ Exception fetching Recommendations: $e');
      rethrow; // Or return empty list: return [];
    }
  }

  Future<AiQueryResponse> postProducerQuery(String producerType, String producerId, String message) async {
    final String token = await getToken() ?? '';
    final url = Uri.parse('${getBaseUrl()}/api/ai/producer-query');
    print('🚀 POST Producer Query: $url');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'producerType': producerType,
          'producerId': producerId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('✅ AI Query response received.');
        return AiQueryResponse.fromJson(data);
      } else {
        print('❌ Error posting producer query: ${response.statusCode} ${response.body}');
        throw Exception('Failed to process query: ${response.statusCode}');
      }
    } catch (e) {
       print('❌ Exception posting producer query: $e');
       // Return a default error response object
       return AiQueryResponse(response: "Une erreur est survenue lors de la connexion au service AI.", profiles: []); 
    }
  }
  
  // --- Placeholder for Interaction Logging from Frontend --- 
  // Call this from UI widgets when a user performs a specific action to log
  Future<void> logInteraction(String producerId, String producerType, String interactionType, {Map<String, dynamic>? metadata}) async {
    try {
      final token = await getToken() ?? '';
      // Use the stored userId from ApiService instance
      final currentUserId = userId; // Access the stored _userId
      
      if (currentUserId == null || currentUserId.isEmpty) {
        print('⚠️ Cannot log interaction: User ID not available in ApiService.');
        return;
      }
      if (token.isEmpty) {
         print('⚠️ Cannot log interaction: Auth token not available.');
         // Optionally handle this case, e.g., prompt login
         return;
      }
      
      final url = Uri.parse('${getBaseUrl()}/api/interactions'); 
      print('🚀 Logging Interaction: $interactionType for $producerType $producerId by $currentUserId');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'userId': currentUserId, // Send the logged-in user's ID
          'producerId': producerId,
          'producerType': producerType,
          'type': interactionType,
          'metadata': metadata ?? {},
        }),
      );

      if (response.statusCode == 200) {
        // print('✅ Interaction logged successfully via API.');
      } else {
        print('❌ Failed to log interaction via API: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Exception logging interaction from frontend: $e');
    }
  }

  Future<String> detectProducerType(String producerId) async {
    final String token = await getToken() ?? '';
    // Use a default type in case of error or if detection fails
    const String defaultType = 'restaurant'; 
    final url = Uri.parse('${getBaseUrl()}/api/ai/detect-producer-type/$producerId');
    print('🚀 GET Detect Producer Type: $url');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final detectedType = data['producerType'] as String?;
        if (detectedType != null && detectedType != 'unknown') {
          print('✅ Detected Producer Type: $detectedType');
          return detectedType;
        } else {
           print('⚠️ Could not detect producer type via API, using default: $defaultType');
           return defaultType;
        }
      } else {
        print('❌ Error detecting producer type: ${response.statusCode} ${response.body}');
        return defaultType; // Return default on error
      }
    } catch (e) {
       print('❌ Exception detecting producer type: $e');
      return defaultType; // Return default on exception
    }
  }

  /// Helper method to convert between ProducerFeedContentType enums from different files
  /// This is needed because the ProducerFeedContentType enum may be defined in multiple places
  ProducerFeedContentType convertToApiContentType(dynamic contentType) {
    // Check if it's already the correct type
    if (contentType is ProducerFeedContentType) {
      return contentType;
    }
    
    // Handle conversion from string
    if (contentType is String) {
      switch (contentType.toLowerCase()) {
        case 'venue': return ProducerFeedContentType.venue;
        case 'interactions': return ProducerFeedContentType.interactions;
        case 'localtrends': return ProducerFeedContentType.localTrends;
        case 'followers': return ProducerFeedContentType.followers;
        default: return ProducerFeedContentType.venue; // Default
      }
    }
    
    // Handle conversion from enum index
    if (contentType is int) {
      switch (contentType) {
        case 0: return ProducerFeedContentType.venue;
        case 1: return ProducerFeedContentType.interactions;
        case 2: return ProducerFeedContentType.localTrends;
        case 3: return ProducerFeedContentType.followers;
        default: return ProducerFeedContentType.venue; // Default
      }
    }
    
    // If it's another enum type with similar values, convert by name
    try {
      final name = contentType.toString().split('.').last;
      switch (name) {
        case 'venue': return ProducerFeedContentType.venue;
        case 'interactions': return ProducerFeedContentType.interactions;
        case 'localTrends': return ProducerFeedContentType.localTrends;
        case 'followers': return ProducerFeedContentType.followers;
        default: return ProducerFeedContentType.venue; // Default
      }
    } catch (e) {
      print('❌ Error converting content type: $e');
      return ProducerFeedContentType.venue; // Default to venue
    }
  }

  // --- Helper for processing media URLs (Placeholder) ---
  void _processAndFixMediaUrls(Map<String, dynamic> item) {
      // TODO: Implement logic to fix/process media URLs if needed
  }

  // --- Helper for ensuring author info (Placeholder) ---
  void _ensureAuthorInfo(Map<String, dynamic> item) {
     // TODO: Implement logic to add placeholder author info if missing
     if (item['author'] == null && item['author_id'] == null) {
         item['author_name'] = item['author_name'] ?? 'Utilisateur Choice';
         item['author_avatar'] = item['author_avatar'] ?? '';
     }
  }

  // --- Post Interaction Methods ---

  Future<void> toggleLike(String userId, String postId) async {
     final token = await _getToken();
     final url = Uri.parse('${await constants.getBaseUrl()}/api/posts/$postId/like');
     print('🌐 POST Toggle Like: $url (User: $userId)');

     try {
       final response = await http.post(
         url,
         headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
         body: json.encode({'userId': userId})
       );
       if (response.statusCode < 200 || response.statusCode >= 300) {
         print('❌ Error toggling like: ${response.statusCode} - ${response.body}');
         String errorMessage = 'Failed to toggle like';
         try {
             final errorData = json.decode(response.body);
             errorMessage = errorData['message'] ?? response.body;
         } catch (_){}
         throw Exception(errorMessage);
       }
        print('✅ Like toggled successfully for post $postId');
     } catch (e) {
       print('❌ Exception toggling like: $e');
       throw Exception('Failed to toggle like: ${e.toString()}');
     }
  }

  Future<List<dynamic>> getComments(String postId) async {
      final token = await _getToken();
      final url = Uri.parse('${await constants.getBaseUrl()}/api/posts/$postId/comments');
      print('🌐 GET Comments: $url');
      try {
         final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
         if (response.statusCode == 200) {
           return json.decode(response.body) ?? [];
         } else {
           print('❌ Error getting comments: ${response.statusCode} - ${response.body}');
           return [];
         }
      } catch (e) {
         print('❌ Exception getting comments: $e');
         return [];
      }
  }

  // --- Interest/Choice Methods ---

  Future<void> markInterested(
    String userId,
    String targetId,
    {
      bool interested = true,
      String? targetType, 
      bool? isLeisureProducer,
      String? source,
      Map<String, dynamic>? metadata,
    }
  ) async {
    final token = await _getToken();
    final url = Uri.parse('${await constants.getBaseUrl()}/api/users/$userId/interested');
    print('🌐 POST Mark Interested: $url (Target: $targetId, Interested: $interested)');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'targetId': targetId,
          'targetType': targetType ?? (isLeisureProducer == true ? 'leisureProducer' : 'producer'),
          'interested': interested,
          if (source != null) 'source': source,
          if (metadata != null) 'metadata': metadata,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
         print('❌ Error marking interest: ${response.statusCode} - ${response.body}');
      }
       print('✅ Interest marked successfully for target $targetId');
    } catch (e) {
      print('❌ Exception marking interest: $e');
    }
  }

  Future<bool> markChoice(String userId, String targetId) async {
    final token = await _getToken();
    final url = Uri.parse('${await constants.getBaseUrl()}/api/choices');
    print('🌐 POST Mark Choice: $url (Target: $targetId)');
    try {
       final response = await http.post(
          url,
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'producerId': targetId,
          }),
       );
        if (response.statusCode == 201) {
           print('✅ Choice marked successfully for target $targetId');
           return true;
        }
        print('❌ Error marking choice: ${response.statusCode} - ${response.body}');
        return false;
    } catch (e) {
       print('❌ Exception marking choice: $e');
       return false;
    }
  }

  // --- Post Detail/View Methods ---

  Future<Map<String, dynamic>?> getPostDetails(String postId) async {
    final token = await _getToken();
    final url = Uri.parse('${await constants.getBaseUrl()}/api/posts/$postId');
    print('🌐 GET Post Details: $url');
    try {
       final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
       if (response.statusCode == 200) {
         return json.decode(response.body);
       } else {
         print('❌ Error getting post details: ${response.statusCode} - ${response.body}');
         return null;
       }
    } catch (e) {
       print('❌ Exception getting post details: $e');
       return null;
    }
  }

  Future<void> trackPostView({required String postId, required String userId}) async {
     await recordPostView(postId);
  }

  Future<void> recordPostView(String postId) async {
     final token = await _getToken();
     final url = Uri.parse('${await constants.getBaseUrl()}/api/posts/$postId/view');
     print('🌐 POST Record View: $url');
     try {
       await http.post(url, headers: {'Authorization': 'Bearer $token'});
     } catch (e) {
       print('⚠️ Exception recording post view: $e');
     }
  }

  // --- User/Producer Detail Methods ---

  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    final token = await _getToken();
    final url = Uri.parse('${await constants.getBaseUrl()}/api/users/$userId');
    print('🌐 GET User Details: $url');
    try {
       final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
       if (response.statusCode == 200) {
         return json.decode(response.body);
       } else {
         print('❌ Error getting user details: ${response.statusCode} - ${response.body}');
         return null;
       }
    } catch (e) {
       print('❌ Exception getting user details: $e');
       return null;
    }
  }

  Future<List<dynamic>> getProducerFollowers(String producerId) async {
    final token = await _getToken();
    final url = Uri.parse('${await constants.getBaseUrl()}/api/producers/$producerId/followers');
    print('🌐 GET Producer Followers: $url');
    try {
       final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
       if (response.statusCode == 200) {
         return json.decode(response.body) ?? [];
       } else {
         print('❌ Error getting producer followers: ${response.statusCode} - ${response.body}');
         return [];
       }
    } catch (e) {
       print('❌ Exception getting producer followers: $e');
       return [];
    }
  }

  Future<Map<String, dynamic>?> getProducerInteractionStats(String producerId) async {
     final token = await _getToken();
     final url = Uri.parse('${await constants.getBaseUrl()}/api/producers/$producerId/stats');
     print('🌐 GET Producer Stats: $url');
     try {
        final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode == 200) {
           return json.decode(response.body);
        } else {
           print('❌ Error getting producer stats: ${response.statusCode} - ${response.body}');
           return null;
        }
     } catch (e) {
        print('❌ Exception getting producer stats: $e');
        return null;
     }
  }

  Future<List<Map<String, dynamic>>> getPostInteractions(String postId, String interactionType) async {
      final token = await _getToken();
      final url = Uri.parse('${await constants.getBaseUrl()}/api/posts/$postId/interactions?type=$interactionType');
      print('🌐 GET Post Interactions: $url');
      try {
          final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
          if (response.statusCode == 200) {
              final List<dynamic> data = json.decode(response.body) ?? [];
              return data.whereType<Map<String, dynamic>>().toList();
          } else {
              print('❌ Error getting post interactions: ${response.statusCode} - ${response.body}');
              return [];
          }
      } catch (e) {
          print('❌ Exception getting post interactions: $e');
          return [];
      }
  }

  Future<Map<String, dynamic>?> updateUserPreferences(Map<String, dynamic> preferences) async {
     final token = await _getToken();
     final userId = AuthService().userId;
     if (userId == null) throw Exception('User not logged in');
     final url = Uri.parse('${await constants.getBaseUrl()}/api/users/$userId/preferences');
     print('🌐 PUT Update Preferences: $url');
     try {
        final response = await http.put(
           url,
           headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
           body: json.encode(preferences),
        );
        if (response.statusCode == 200) {
           return json.decode(response.body);
        } else {
           print('❌ Error updating preferences: ${response.statusCode} - ${response.body}');
           return null;
        }
     } catch (e) {
        print('❌ Exception updating preferences: $e');
        return null;
     }
  }

  // --- Generic Fetch Methods ---

  Future<Map<String, dynamic>> fetchData(String endpoint, {Map<String, dynamic>? queryParams}) async {
    final token = await _getToken();
    final Map<String, String>? stringQueryParams = queryParams?.map(
        (key, value) => MapEntry(key, value.toString()),
    );
    final url = Uri.parse('${await constants.getBaseUrl()}$endpoint').replace(queryParameters: stringQueryParams);
    print('🌐 GET Generic Fetch: $url');
    try {
       final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
       if (response.statusCode == 200) {
         return json.decode(response.body);
       } else {
         throw Exception('Failed to fetch data ($endpoint): ${response.statusCode}');
       }
    } catch (e) {
       throw Exception('Exception fetching data ($endpoint): $e');
    }
  }

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
      return await fetchData(endpoint, queryParams: queryParams);
  }

  // --- Auth Related ---

  Future<String?> getAuthToken() async {
     return await _getToken();
  }

  Future<String> getApiBaseUrl() async {
     return constants.getBaseUrlSync();
  }

  // --- Comment Methods ---
  
  Future<void> deletePost(String postId, String userId) async {
    final token = await _getToken();
    final url = Uri.parse('${await constants.getBaseUrl()}/api/posts/$postId');
    print('🌐 DELETE Post: $url (User: $userId)');

    try {
      final response = await http.delete(
          url,
          headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        print('❌ Error deleting post: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to delete post');
      }
       print('✅ Post deleted successfully: $postId');
    } catch (e) {
      print('❌ Exception deleting post: $e');
      throw Exception('Failed to delete post: $e');
    }
  }
}
