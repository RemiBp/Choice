import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../utils/constants.dart';
import '../models/post.dart';
import '../models/comment.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = getBaseUrl();

  Future<List<Post>> getFeedPosts({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/posts')
          .replace(queryParameters: {
        'userId': userId,
        'page': page.toString(),
        'limit': limit.toString(),
      });

      print('🔍 Requête feed vers : $url');
      final response = await http.get(url);
      print('📩 Réponse reçue : ${response.statusCode}');
      print('📩 Corps : ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('🔍 Données reçues : $jsonData');

        return jsonData.map((postJson) {
          try {
            return Post.fromJson(postJson);
          } catch (e) {
            print('❌ Erreur lors de la conversion du post :\n❌ Exception : $e\n❌ JSON problématique : $postJson');
            return null;
          }
        }).whereType<Post>().toList();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur réseau getFeed : $e');
      rethrow;
    }
  }

  Future<bool> markInterested(String userId, String targetId, {bool isLeisureProducer = false}) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$targetId/like');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur like: $e');
      return false;
    }
  }

  Future<bool> markChoice(String userId, String postId) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/choice');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur choice: $e');
      return false;
    }
  }

  Future<Comment> addComment(String postId, String userId, String content) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/comments');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'content': content,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Comment.fromJson(data['post']['comments'].last);
      }
      throw Exception('Erreur lors de l\'ajout du commentaire');
    } catch (e) {
      print('❌ Erreur addComment: $e');
      rethrow;
    }
  }

  Future<bool> savePost(String userId, String postId) async {
    final url = Uri.parse('${getBaseUrl()}/api/interactions/save-post');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'postId': postId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde : $e');
      return false;
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
}
