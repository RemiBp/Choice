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
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show HttpLoggingInterceptor;
import '../utils/utils.dart';
import '../models/media.dart' as app_media;
import '../models/kpi_data.dart';
import '../models/recommendation_data.dart';
import '../models/profile_data.dart';
import '../models/sales_data.dart';
import '../models/ai_query_response.dart';

// Enum manquant pour les types de contenu du feed du producteur
enum ProducerFeedContentType {
  venue,
  interactions, 
  localTrends
}

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

  Future<Map<String, dynamic>> addComment(String postId, String userId, String content) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/comments');
      
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
        return Post.fromJson(response.data['post']);
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
    String producerId, {
    required ProducerFeedContentType contentType,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      String filter;
      
      // Déterminer le type de filtre à appliquer
      switch (contentType) {
        case ProducerFeedContentType.venue:
          filter = 'venue';
          break;
        case ProducerFeedContentType.interactions:
          filter = 'interactions';
          break;
        case ProducerFeedContentType.localTrends:
          filter = 'localTrends';
          break;
        default:
          filter = 'venue';
      }
      
      String endpoint = 'api/producer-feed/$producerId';
      
      print('🏪 Récupération du feed producteur: $endpoint (filtre: $filter)');
      
      return await fetchFeed(
        endpoint: endpoint,
        queryParams: {
          'page': page.toString(),
          'limit': limit.toString(),
          'filter': filter,
        },
      );
    } catch (e) {
      print('❌ Erreur lors de la récupération du feed producteur: $e');
      return {
        'items': [],
        'hasMore': false,
      };
    }
  }
  
  // Suivre la vue d'un post pour les statistiques
  Future<bool> trackPostView({
    required String postId,
    required String userId,
  }) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/view');
      
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
        '${constants.getBaseUrl()}/api/interactions/interest',
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
        '${constants.getBaseUrl()}/api/interactions/choice',
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
  Future<bool> likePost(String postId, [String? userId]) async {
    try {
      final Map<String, dynamic> data = {};
      if (userId != null) {
        data['userId'] = userId;
      }
      
      final response = await _dio.post(
        '/api/posts/$postId/like',
        data: data,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur lors du like du post: $e');
      return false;
    }
  }

  // Ajouter la méthode getPostDetails
  Future<Map<String, dynamic>> getPostDetails(String postId) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId');
      
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
      final uri = Uri.parse('${constants.getBaseUrl()}/api/search');
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
      final response = await _dio.get(
        '/api/producers/$producerId/posts',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return response.data;
        } else if (response.data is Map && response.data['posts'] != null) {
          return response.data['posts'];
        }
        return [];
      } else {
        print('❌ Error fetching producer posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching producer posts: $e');
      return [];
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
      final url = Uri.parse('${constants.getBaseUrl()}/$endpoint')
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
      final baseUrl = await constants.getBaseUrl(); // Await here
      final response = await _dio.post(
        '$baseUrl/api/posts/$postId/view',
        options: Options(headers: await _getHeaders()),
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('❌ Error recording post view: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception recording post view: $e');
      throw e;
    }
  }

  // Obtenir les amis d'un utilisateur
  Future<List<dynamic>> getUserFriends(String userId, {int page = 1, int limit = 20}) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/users/$userId/friends');
      
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
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/users/$friendId/interests');
      
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
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/users/$friendId/choices');
      
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
      // Simulation data...
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
        }
      ];
    }
  }

  // Récupérer l'historique des emplacements
  Future<List<dynamic>> getLocationHistory() async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/location-history');
      
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
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/location-history/hotspots')
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
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId/location');
      
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
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/nearby')
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

  // Implémenter le code manquant dans getProducerPostsDetailed
  Future<Map<String, dynamic>> getProducerPostsDetailed(String producerId, {int page = 1, int limit = 10, String? filter}) async {
    try {
      final response = await _dio.get(
        '/api/producers/$producerId/posts/detailed',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (filter != null) 'filter': filter,
        },
      );
      
      if (response.statusCode == 200) {
        if (response.data is Map) {
          return response.data;
        }
        return {'posts': [], 'total': 0, 'hasMore': false};
      } else {
        print('❌ Error fetching detailed producer posts: ${response.statusCode}');
        return {'posts': [], 'total': 0, 'hasMore': false};
      }
    } catch (e) {
      print('❌ Error fetching detailed producer posts: $e');
      return {'posts': [], 'total': 0, 'hasMore': false};
    }
  }

  // Récupérer les posts des clients d'un producteur
  Future<List<Post>> getClientPosts(String producerId, {int page = 1, int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/api/producers/$producerId/client_posts',
        queryParameters: {
          'page': page,
          'limit': limit,
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
        print('❌ Error fetching client posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching client posts: $e');
      return [];
    }
  }

  // Méthodes pour les feeds des producteurs - Nous gardons cette version qui renvoie Map<String, dynamic>
  Future<Map<String, dynamic>> getProducerPostsForRestaurant(String producerId, {int page = 1, int limit = 10, String? filter}) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/producers/$producerId/posts',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (filter != null && filter != 'Tous') 'category': filter,
        },
      );

      if (response.statusCode == 200) {
        final posts = (response.data['posts'] as List).map((json) => Post.fromJson(json)).toList();
        return {
          'posts': posts,
          'hasMore': response.data['hasMore'] ?? false,
        };
      } else {
        // Fallback to generic feed if endpoint not found
        final fallbackResponse = await getFeedPosts(producerId, page: page, limit: limit);
        return {
          'posts': fallbackResponse,
          'hasMore': fallbackResponse.length >= limit,
        };
      }
    } catch (e) {
      print('❌ Error fetching restaurant posts: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLeisurePostsForProducer(String producerId, {int page = 1, int limit = 10, String? filter}) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/leisure/$producerId/posts',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (filter != null && filter != 'Tous') 'category': filter,
        },
      );

      if (response.statusCode == 200) {
        final posts = (response.data['posts'] as List).map((json) => Post.fromJson(json)).toList();
        return {
          'posts': posts,
          'hasMore': response.data['hasMore'] ?? false,
        };
      } else {
        // Fallback to generic feed
        final fallbackResponse = await getFeedPosts(producerId, page: page, limit: limit);
        return {
          'posts': fallbackResponse,
          'hasMore': fallbackResponse.length >= limit,
        };
      }
    } catch (e) {
      print('❌ Error fetching leisure posts: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getWellnessPostsForProducer(String producerId, {int page = 1, int limit = 10, String? filter}) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/wellness/$producerId/posts',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (filter != null && filter != 'Tous') 'category': filter,
        },
      );

      if (response.statusCode == 200) {
        final posts = (response.data['posts'] as List).map((json) => Post.fromJson(json)).toList();
        return {
          'posts': posts,
          'hasMore': response.data['hasMore'] ?? false,
        };
      } else {
        // Fallback to generic feed
        final fallbackResponse = await getFeedPosts(producerId, page: page, limit: limit);
        return {
          'posts': fallbackResponse,
          'hasMore': fallbackResponse.length >= limit,
        };
      }
    } catch (e) {
      print('❌ Error fetching wellness posts: $e');
      rethrow;
    }
  }

  // Nouvelle méthode pour récupérer les statistiques d'interaction pour un producteur
  Future<Map<String, dynamic>> getProducerInteractionStats(String producerId) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/posts/producer/$producerId/interaction-stats',
      );
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        // Fallback to dummy data if endpoint not implemented yet
        return {
          'totalPosts': 0,
          'totalLikes': 0,
          'totalInterests': 0,
          'totalComments': 0,
          'engagementRate': 0.0,
        };
      }
    } catch (e) {
      print('❌ Error fetching producer interaction stats: $e');
      // Return dummy data as fallback
      return {
        'totalPosts': 0,
        'totalLikes': 0,
        'totalInterests': 0,
        'totalComments': 0,
        'engagementRate': 0.0,
      };
    }
  }

  // Récupérer la liste des followers d'un producteur
  Future<List<Map<String, dynamic>>> getProducerFollowers(String producerId) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/producers/$producerId/followers',
      );
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['followers']);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error fetching producer followers: $e');
      return [];
    }
  }

  // Récupérer les interactions spécifiques à un post (likes, interests, commentaires)
  Future<List<Map<String, dynamic>>> getPostInteractions(String postId, String interactionType) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/posts/$postId/interactions',
        queryParameters: {'type': interactionType},
      );
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['users']);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error fetching post interactions: $e');
      return [];
    }
  }

  // Récupérer les insights sur les posts d'un producteur (vues, engagement, etc.)
  Future<Map<String, dynamic>> getProducerPostInsights(String producerId, String postId) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/posts/producer/$producerId/posts/$postId/insights',
      );
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        // Fallback to dummy insights data
        return {
          'impressions': math.Random().nextInt(100) + 50,
          'reach': math.Random().nextInt(80) + 30,
          'engagementRate': (math.Random().nextDouble() * 10).toStringAsFixed(2),
          'profileClicks': math.Random().nextInt(20) + 5,
          'visitors': math.Random().nextInt(30) + 10,
          'performanceScore': math.Random().nextInt(100),
        };
      }
    } catch (e) {
      print('❌ Error fetching post insights: $e');
      // Return dummy insights data
      return {
        'impressions': math.Random().nextInt(100) + 50,
        'reach': math.Random().nextInt(80) + 30,
        'engagementRate': (math.Random().nextDouble() * 10).toStringAsFixed(2),
        'profileClicks': math.Random().nextInt(20) + 5,
        'visitors': math.Random().nextInt(30) + 10,
        'performanceScore': math.Random().nextInt(100),
      };
    }
  }

  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/users/$userId',
      );
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch user details: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching user details: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserPreferences(Map<String, dynamic> preferences) async {
    final url = Uri.parse('${getBaseUrl()}/api/user/preferences');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await getToken()}',
      },
      body: jsonEncode(preferences),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update user preferences');
    }
  }

  // Obtenir les en-têtes HTTP pour les requêtes authentifiées
  Future<Map<String, String>> _getHeaders() async {
    final String? token = await _secureStorage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Récupérer les posts d'inspiration pour le bien-être
  Future<List<Post>> getWellnessInspirationPosts({int page = 1, int limit = 10}) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/posts/inspiration/wellness',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: Options(headers: await _getHeaders()),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> postsData = response.data['posts'] ?? [];
        return postsData.map((json) => Post.fromJson(json)).toList();
      } else {
        print('❌ Error fetching wellness inspiration posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching wellness inspiration posts: $e');
      return [];
    }
  }
  
  // Récupérer les posts d'inspiration pour les loisirs
  Future<List<Post>> getLeisureInspirationPosts({int page = 1, int limit = 10}) async {
    try {
      final response = await _dio.get(
        '${constants.getBaseUrl()}/api/posts/inspiration/leisure',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: Options(headers: await _getHeaders()),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> postsData = response.data['posts'] ?? [];
        return postsData.map((json) => Post.fromJson(json)).toList();
      } else {
        print('❌ Error fetching leisure inspiration posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching leisure inspiration posts: $e');
      return [];
    }
  }

  // Marquer comme intéressé à un post
  Future<bool> markAsInterested(String postId) async {
    try {
      final response = await _dio.post(
        '${constants.getBaseUrl()}/api/posts/$postId/interest',
        options: Options(headers: await _getHeaders()),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Exception marking post as interested: $e');
      return false;
    }
  }

  /// Fetch users activities
  Future<List<Map<String, dynamic>>> fetchUsersActivities() async {
    try {
      final baseUrl = constants.getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/api/activities'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Méthode GET générique
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    return fetchData(endpoint, queryParams: queryParams);
  }

  // Récupérer les événements d'un producteur
  Future<dynamic> fetchProducerEvents(String producerId) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId/events'),
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération des événements du producteur: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des événements du producteur: $e');
      return null;
    }
  }
  
  // Récupérer les événements populaires
  Future<dynamic> fetchPopularEvents({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/events/popular?limit=$limit'),
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération des événements populaires: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des événements populaires: $e');
      return null;
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      print('Erreur API (${response.statusCode}): ${response.body}');
      throw Exception('Erreur API: ${response.statusCode}');
    }
  }

  // Ajouter la méthode fetchData manquante
  Future<dynamic> fetchData(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      final String baseUrl = getBaseUrl();
      final Uri uri = Uri.parse('$baseUrl/api/$endpoint').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await getAuthToken()}',
        },
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('Erreur lors de la récupération des données: $e');
      throw e;
    }
  }

  /// Récupérer le token d'authentification
  Future<String> getAuthToken() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      return token ?? '';
    } catch (e) {
      print('❌ Erreur lors de la récupération du token: $e');
      return '';
    }
  }

  // Méthode utilitaire pour vérifier et corriger les URLs des médias
  void _processAndFixMediaUrls(Map<String, dynamic> postData) {
    try {
      // Traitement pour 'media' au format liste d'objets
      if (postData['media'] is List) {
        final mediaList = postData['media'] as List;
        for (int i = 0; i < mediaList.length; i++) {
          if (mediaList[i] is Map<String, dynamic>) {
            final mediaItem = mediaList[i] as Map<String, dynamic>;
            
            // Vérifier si l'URL est une référence Google Maps
            final String url = mediaItem['url'] ?? '';
            if (url.contains('maps.googleapis.com') && url.contains('photoreference=')) {
              // S'assurer que l'URL complète est maintenue
              // Si l'URL a été tronquée, nous pouvons reconstituer l'URL Google Maps Photos
              final Uri parsedUrl = Uri.parse(url);
              final photoRef = parsedUrl.queryParameters['photoreference'];
              final apiKey = parsedUrl.queryParameters['key'];
              
              if (photoRef != null && apiKey != null) {
                // Reconstituer une URL propre pour Google Maps Photos
                mediaItem['url'] = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoRef&key=$apiKey';
                
                // Ajouter un URL de vignette si nécessaire
                if (mediaItem['thumbnailUrl'] == null) {
                  mediaItem['thumbnailUrl'] = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoRef&key=$apiKey';
                }
              }
            }
            
            // Définir le type par défaut s'il manque
            if (mediaItem['type'] == null) {
              mediaItem['type'] = url.contains('.mp4') || url.contains('.mov') ? 'video' : 'image';
            }
          } else if (mediaList[i] is String) {
            // Si media est juste une chaîne URL, la convertir en objet
            final String url = mediaList[i] as String;
            mediaList[i] = {
              'url': url,
              'type': url.contains('.mp4') || url.contains('.mov') ? 'video' : 'image'
            };
          }
        }
      } 
      // Traiter le cas où media est une chaîne unique
      else if (postData['media'] is String) {
        final String url = postData['media'] as String;
        postData['media'] = [
          {
            'url': url,
            'type': url.contains('.mp4') || url.contains('.mov') ? 'video' : 'image'
          }
        ];
      }
    } catch (e) {
      print('❌ Erreur lors du traitement des médias: $e');
    }
  }
  
  // Méthode utilitaire pour s'assurer que les informations d'auteur sont présentes
  void _ensureAuthorInfo(Map<String, dynamic> postData) {
    if (postData['author_id'] == null && postData['user_id'] != null) {
      postData['author_id'] = postData['user_id'];
    }
    
    if (postData['author_name'] == null) {
      postData['author_name'] = postData['user_name'] ?? 'Utilisateur';
    }
    
    if (postData['author_avatar'] == null && postData['user_photo_url'] != null) {
      postData['author_avatar'] = postData['user_photo_url'];
    }
    
    // Générer un avatar par défaut si nécessaire
    if ((postData['author_avatar'] == null || postData['author_avatar'] == '') && postData['author_id'] != null) {
      postData['author_avatar'] = 'https://api.dicebear.com/6.x/adventurer/png?seed=${postData['author_id']}';
    }
  }

  // ==================== NOUVELLES MÉTHODES POUR LIEUX DE LOISIRS ====================

  /// Récupérer les détails d'un producteur de loisir
  Future<Map<String, dynamic>> getLeisureProducer(String producerId) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/leisure/producer/$producerId');
      final response = await http.get(uri, headers: await _getHeadersMap());

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Erreur lors de la récupération du producteur de loisir: ${response.statusCode}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception lors de la récupération du producteur de loisir: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Mettre à jour les informations d'un producteur de loisir
  Future<Map<String, dynamic>> updateLeisureProducer(String producerId, Map<String, dynamic> data) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/leisure/producer/$producerId/update');
      final response = await http.post(
        uri, 
        headers: await _getHeadersMap(),
        body: jsonEncode(data)
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Erreur lors de la mise à jour du producteur de loisir: ${response.statusCode}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception lors de la mise à jour du producteur de loisir: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Créer un nouvel événement pour un producteur de loisir
  Future<Map<String, dynamic>> createLeisureEvent(Map<String, dynamic> eventData) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/leisure/event/create');
      final response = await http.post(
        uri, 
        headers: await _getHeadersMap(),
        body: jsonEncode(eventData)
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print('❌ Erreur lors de la création de l\'événement: ${response.statusCode}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception lors de la création de l\'événement: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Mettre à jour un événement existant
  Future<Map<String, dynamic>> updateLeisureEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/leisure/event/$eventId');
      final response = await http.put(
        uri, 
        headers: await _getHeadersMap(),
        body: jsonEncode(eventData)
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Erreur lors de la mise à jour de l\'événement: ${response.statusCode}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception lors de la mise à jour de l\'événement: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Supprimer un événement
  Future<bool> deleteLeisureEvent(String eventId) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/leisure/event/$eventId');
      final response = await http.delete(
        uri, 
        headers: await _getHeadersMap()
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Erreur lors de la suppression de l\'événement: ${response.statusCode}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception lors de la suppression de l\'événement: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupérer les détails d'un événement
  Future<Map<String, dynamic>> getLeisureEvent(String eventId) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/leisure/event/$eventId');
      final response = await http.get(uri, headers: await _getHeadersMap());

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Erreur lors de la récupération de l\'événement: ${response.statusCode}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception lors de la récupération de l\'événement: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Marquer l'intérêt pour un événement
  Future<bool> markEventInterest(String eventId, String userId) async {
    try {
      final Uri uri = Uri.parse('${constants.getBaseUrl()}/api/leisure/event/$eventId/interest');
      final response = await http.post(
        uri, 
        headers: await _getHeadersMap(),
        body: jsonEncode({
          'userId': userId
        })
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Erreur lors du marquage de l\'intérêt: ${response.statusCode}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception lors du marquage de l\'intérêt: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  // Méthode pour obtenir les headers d'authentification sous forme de Map
  Future<Map<String, String>> _getHeadersMap() async {
    // Utiliser la méthode existante _getHeaders() pour obtenir les options Dio
    final dioOptions = await _getHeaders();
    // Convertir les headers Dio en Map<String, String>
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    // Ajouter le token d'autorisation s'il existe
    // Vérifier si dioOptions contient directement le token d'autorisation
    if (dioOptions.containsKey('Authorization')) {
      headers['Authorization'] = dioOptions['Authorization'] ?? '';
    }
    
    return headers;
  }

  // Récupérer les posts populaires
  Future<List<Post>> getPopularPosts({int limit = 10}) async {
    try {
      print('📥 Récupération des posts populaires (limite: $limit)');
      
      final response = await _dio.get(
        '/api/posts/popular',
        queryParameters: {
          'limit': limit,
        },
      );
      
      if (response.statusCode == 200) {
        // Traiter la réponse
        List<Post> posts = [];
        
        if (response.data is List) {
          posts = (response.data as List).map((item) {
            try {
              if (item is Map<String, dynamic>) {
                // Vérifier et corriger les médias si nécessaire
                _processAndFixMediaUrls(item);
                
                // S'assurer que les informations d'auteur sont présentes
                _ensureAuthorInfo(item);
                
                return Post.fromJson(item);
              }
            } catch (e) {
              print('❌ Erreur lors de la conversion d\'un élément en Post: $e');
            }
            return null;
          }).where((post) => post != null).cast<Post>().toList();
        } else if (response.data is Map && response.data['posts'] != null) {
          final postsData = response.data['posts'] as List;
          posts = postsData.map((item) {
            try {
              if (item is Map<String, dynamic>) {
                // Vérifier et corriger les médias si nécessaire
                _processAndFixMediaUrls(item);
                
                // S'assurer que les informations d'auteur sont présentes
                _ensureAuthorInfo(item);
                
                return Post.fromJson(item);
              }
            } catch (e) {
              print('❌ Erreur lors de la conversion d\'un élément en Post: $e');
            }
            return null;
          }).where((post) => post != null).cast<Post>().toList();
        }
        
        // Si nous n'avons pas assez de posts ou en cas d'erreur, générer des posts fictifs
        if (posts.isEmpty) {
          print('⚠️ Aucun post populaire trouvé, utilisation de données fictives');
          return _generateMockPosts(limit);
        }
        
        return posts;
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        
        // En cas d'erreur, retourner des posts fictifs
        return _generateMockPosts(limit);
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des posts populaires: $e');
      
      // En cas d'erreur, retourner des posts fictifs
      return _generateMockPosts(limit);
    }
  }
  
  // Génère des posts fictifs pour les fallbacks
  List<Post> _generateMockPosts(int count) {
    List<Post> mockPosts = [];
    
    final categories = ['Restaurant', 'Café', 'Loisir', 'Culture', 'Sport'];
    final userNames = ['Sophie', 'Thomas', 'Emma', 'Lucas', 'Léa', 'Hugo'];
    
    for (var i = 0; i < count; i++) {
      final isProducer = i % 3 == 0;  // Un tiers des posts sont des producteurs
      final isLeisure = isProducer && i % 6 == 0; // La moitié des producteurs sont des loisirs
      
      final randomIndex = i % categories.length;
      final category = categories[randomIndex];
      final userName = userNames[i % userNames.length];
      
      mockPosts.add(
        Post(
          id: 'mock-${DateTime.now().millisecondsSinceEpoch}-$i',
          content: 'Contenu de démonstration pour $category #$i',
          description: 'Description pour $category #$i avec quelques détails intéressants à découvrir.',
          authorName: isProducer ? '$category Paris $i' : userName,
          authorId: 'user-$i',
          authorAvatar: isProducer 
              ? 'https://picsum.photos/seed/producer$i/200' 
              : 'https://picsum.photos/seed/user$i/200',
          isProducerPost: isProducer,
          isLeisureProducer: isLeisure,
          likesCount: 10 + (i * 5),
          interestedCount: isProducer ? 5 + (i * 2) : 0,
          createdAt: DateTime.now().subtract(Duration(hours: i * 5)),
          postedAt: DateTime.now().subtract(Duration(hours: i * 5)),
          tags: ['choice', category.toLowerCase(), 'paris'],
          media: [
            app_media.Media(
              url: 'https://picsum.photos/seed/post$i/800/600',
              type: 'image',
            ),
          ],
        ),
      );
    }
    
    return mockPosts;
  }

  // Method to get the API base URL as a direct String (not Future)
  String getApiBaseUrl() {
    // Return the base URL using constants
    return constants.getBaseUrl();
  }

  // Method to mark a post as interested or not
  Future<bool> markPostAsInterested(String postId, bool interested) async {
    try {
      final token = await getAuthToken();
      final userId = await getUserId();
      
      if (userId == null || userId.isEmpty) {
        print('❌ Erreur: userId non trouvé');
        return false;
      }
      
      final url = Uri.parse('${getApiBaseUrl()}/api/posts/$postId/interest');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'interested': interested,
        }),
      );
      
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('❌ Exception lors du marquage d\'intérêt: $e');
      return false;
    }
  }

  Future<String> getToken() async {
    final storage = FlutterSecureStorage();
    return await storage.read(key: 'auth_token') ?? '';
  }

  Future<String> getUserId() async {
    final storage = FlutterSecureStorage();
    return await storage.read(key: 'user_id') ?? '';
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
}
