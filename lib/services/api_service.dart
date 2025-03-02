import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart'; // Changer utils.dart en constants.dart
import '../models/post.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Supprimez cette ligne car nous utiliserons getBaseUrl() directement
  // final String baseUrl = getBaseUrl();

  Future<List<Post>> getFeed(String userId, int page, int limit) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts?userId=$userId&page=$page&limit=$limit');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((post) => Post.fromJson(post)).toList();
      }
      throw Exception('Failed to load feed');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> markInterested(String userId, String targetId, {bool isLeisureProducer = false}) async {
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/interested');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'targetId': targetId,
          'isLeisureProducer': isLeisureProducer,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors du marquage interested: $e');
      return false;
    }
  }

  Future<bool> markChoice(String userId, String targetId) async {
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/choice');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'targetId': targetId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors du marquage choice: $e');
      return false;
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
  static Future<Map<String, dynamic>> getProducerDetails(String producerId) async {
    try {
      print('🔍 Chargement des détails pour le producteur $producerId');

      final uri = Uri.parse('${getBaseUrl()}/api/producers/$producerId');
      print('🔍 Requête vers : $uri');

      final response = await http.get(uri);

      print('📩 Réponse reçue : ${response.statusCode}');
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
}
