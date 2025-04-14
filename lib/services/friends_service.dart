import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import '../utils/utils.dart';
import '../services/auth_service.dart';

class FriendsService {
  // URL de base pour les requêtes API
  final String baseUrl = getBaseUrl();

  // Récupérer la liste des amis d'un utilisateur
  Future<List<Map<String, dynamic>>> getFriendsList(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['friends'] ?? []);
      } else {
        print('❌ Erreur lors de la récupération des amis: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des amis: $e');
      return [];
    }
  }

  // Récupérer les activités des amis
  Future<List<Map<String, dynamic>>> getFriendsActivities(
    String userId, {
    double? lat,
    double? lng,
    double radius = 5000,
    List<String>? friendIds,
    List<String>? categories,
  }) async {
    try {
      // Construction des paramètres de la requête
      final queryParams = {
        'userId': userId,
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
        'radius': radius.toString(),
        if (friendIds != null && friendIds.isNotEmpty)
          'friendIds': friendIds.join(','),
        if (categories != null && categories.isNotEmpty)
          'categories': categories.join(','),
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/activities').replace(queryParameters: queryParams),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['activities'] ?? []);
      } else {
        print('❌ Erreur lors de la récupération des activités: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des activités: $e');
      return [];
    }
  }

  // Récupérer les intérêts des amis
  Future<List<Map<String, dynamic>>> getFriendsInterests(
    String userId, {
    List<String>? friendIds,
  }) async {
    try {
      // Construction des paramètres de la requête
      final queryParams = {
        'userId': userId,
        if (friendIds != null && friendIds.isNotEmpty)
          'friendIds': friendIds.join(','),
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/interests').replace(queryParameters: queryParams),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['interests'] ?? []);
      } else {
        print('❌ Erreur lors de la récupération des intérêts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des intérêts: $e');
      return [];
    }
  }

  /// Récupérer la liste des amis d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserFriends(String userId) async {
    try {
      print('🔍 FriendsService: getUserFriends($userId)');
      if (userId.isEmpty) {
        print('⚠️ userId est vide');
        return [];
      }

      // Récupérer le token d'authentification
      final String? token = await AuthService().getTokenInstance();
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/$userId'),
        headers: headers,
      );

      print('📊 Statut de la réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('📊 Amis récupérés: ${data.length}');
        return data.map((friend) => friend as Map<String, dynamic>).toList();
      } else {
        print('❌ Erreur ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception dans getUserFriends: $e');
      return [];
    }
  }

  /// Récupérer les choix et intérêts des followers pour la carte
  Future<Map<String, dynamic>> getFollowersChoicesAndInterests(String userId) async {
    try {
      print('🔍 FriendsService: getFollowersChoicesAndInterests($userId)');
      if (userId.isEmpty) {
        print('⚠️ userId est vide');
        return {
          'followers': [],
          'choices': [],
          'interests': []
        };
      }

      // Récupérer le token d'authentification
      final String? token = await AuthService().getTokenInstance();
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Utiliser la nouvelle route spécifique pour la carte
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/map-activities/$userId'),
        headers: headers,
      );

      print('📊 Statut de la réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Logs de débogage pour comprendre la structure des données
        print('📊 Followers récupérés: ${(data['followers'] as List?)?.length ?? 0}');
        print('📊 Choix récupérés: ${(data['choices'] as List?)?.length ?? 0}');
        print('📊 Intérêts récupérés: ${(data['interests'] as List?)?.length ?? 0}');
        
        return data;
      } else {
        print('❌ Erreur ${response.statusCode}: ${response.body}');
        // En cas d'erreur, renvoyer une structure vide mais valide
        return {
          'followers': [],
          'choices': [],
          'interests': []
        };
      }
    } catch (e) {
      print('❌ Exception dans getFollowersChoicesAndInterests: $e');
      // En cas d'exception, renvoyer une structure vide mais valide
      return {
        'followers': [],
        'choices': [],
        'interests': []
      };
    }
  }

  /// Récupère les activités des amis d'un utilisateur
  Future<List<Map<String, dynamic>>> getFriendsActivity(
    String userId, {
    List<String>? friendIds,
    List<String>? activityTypes,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      // Construire l'URL avec les paramètres
      String url = '$baseUrl/api/users/$userId/friends/activity';
      
      // Ajouter les paramètres de requête si fournis
      Map<String, dynamic> queryParams = {};
      
      if (friendIds != null && friendIds.isNotEmpty) {
        queryParams['friends'] = friendIds.join(',');
      }
      
      if (activityTypes != null && activityTypes.isNotEmpty) {
        queryParams['types'] = activityTypes.join(',');
      }
      
      if (latitude != null && longitude != null) {
        queryParams['lat'] = latitude.toString();
        queryParams['lng'] = longitude.toString();
      }
      
      if (radius != null) {
        queryParams['radius'] = radius.toString();
      }
      
      // Convertir les paramètres en string de requête
      if (queryParams.isNotEmpty) {
        url += '?';
        url += queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((x) => Map<String, dynamic>.from(x)));
        } else if (data is Map && data['activities'] is List) {
          return List<Map<String, dynamic>>.from(data['activities'].map((x) => Map<String, dynamic>.from(x)));
        }
      }
      // Retourne une liste vide si aucun résultat ou format inattendu
      return [];
    } catch (e) {
      print("❌ Erreur lors de la récupération des activités des amis: $e");
      // Retourne une liste vide en cas d'erreur
      return [];
    }
  }
  
  // Méthode pour récupérer le compte d'abonnés
  Future<int> getFollowersCount(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/api/users/$userId/followers/count');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      
      return 0;
    } catch (e) {
      print('❌ Erreur lors de la récupération du compte d\'abonnés: $e');
      return 0;
    }
  }
  
  // Méthode pour récupérer le compte d'abonnements
  Future<int> getFollowingCount(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/api/users/$userId/following/count');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      
      return 0;
    } catch (e) {
      print('❌ Erreur lors de la récupération du compte d\'abonnements: $e');
      return 0;
    }
  }
  
  /// Suivre un utilisateur
  Future<bool> followUser(String userId, String friendId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/friends/follow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'friendId': friendId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Exception dans followUser: $e');
      return false;
    }
  }
  
  /// Ne plus suivre un utilisateur
  Future<bool> unfollowUser(String userId, String friendId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/friends/unfollow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'friendId': friendId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Exception dans unfollowUser: $e');
      return false;
    }
  }
  
  // Méthode pour vérifier si un utilisateur suit un autre
  Future<bool> isFollowing(String userId, String targetUserId) async {
    try {
      final url = Uri.parse('$baseUrl/api/users/$userId/isFollowing/$targetUserId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isFollowing'] ?? false;
      }
      
      return false;
    } catch (e) {
      print('❌ Erreur lors de la vérification du statut de suivi: $e');
      return false;
    }
  }

  /// Récupération directe des choices et intérêts pour John Brown (mode de test)
  Future<Map<String, dynamic>> getJohnBrownFollowersData() async {
    try {
      // Données de test pour John Brown (ID: 677db5b562dbd1a04ed621c8)
      final List<Map<String, dynamic>> followers = [
        {
          '_id': '677db5b562dbd1a04ed621c9',
          'name': 'Jane Smith',
          'photo_url': 'https://api.dicebear.com/6.x/adventurer/png?seed=jane'
        },
        {
          '_id': '677db5b562dbd1a04ed621c8', // John Brown se suit lui-même
          'name': 'John Brown',
          'photo_url': 'https://api.dicebear.com/6.x/adventurer/png?seed=677db5b562dbd1a04ed621c8'
        }
      ];

      // Exemple de choix (lieux visités) simulés
      final List<Map<String, dynamic>> choices = [
        {
          'type': 'choice',
          'userId': '677db5b562dbd1a04ed621c9', // Jane Smith
          '_id': '675adf63da75cfe37235c7ac',
          'name': 'Le Petit Bistro',
          'category': 'Restaurant',
          'address': '12 Rue de la Paix, Paris',
          'rating': 4.5,
          'photo_url': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500',
          'location': {
            'type': 'Point',
            'coordinates': [2.341, 48.866] // [lng, lat]
          }
        },
        {
          'type': 'choice',
          'userId': '677db5b562dbd1a04ed621c8', // John Brown
          '_id': '675adf63da75cfe37235c7d1',
          'name': 'Musée d\'Orsay',
          'category': 'Musée',
          'address': '1 Rue de la Légion d\'Honneur, Paris',
          'rating': 4.8,
          'photo_url': 'https://images.unsplash.com/photo-1583125311318-902066a1d09e?w=500',
          'location': {
            'type': 'Point',
            'coordinates': [2.3266, 48.8599] // [lng, lat]
          }
        }
      ];

      // Exemple d'intérêts simulés
      final List<Map<String, dynamic>> interests = [
        {
          'type': 'interest',
          'userId': '677db5b562dbd1a04ed621c9', // Jane Smith
          '_id': '676d7734bc725bb6e91c51e6',
          'name': 'Tour Eiffel',
          'category': 'Monument',
          'address': 'Champ de Mars, Paris',
          'rating': 4.6,
          'photo_url': 'https://images.unsplash.com/photo-1543349689-9a4d426bee8e?w=500',
          'location': {
            'type': 'Point',
            'coordinates': [2.2945, 48.8584] // [lng, lat]
          }
        },
        {
          'type': 'interest',
          'userId': '677db5b562dbd1a04ed621c8', // John Brown
          '_id': '676d7734bc725bb6e91c51e5',
          'name': 'Shakespeare and Company',
          'category': 'Librairie',
          'address': '37 Rue de la Bûcherie, Paris',
          'rating': 4.7,
          'photo_url': 'https://images.unsplash.com/photo-1544383835-bda2bc66a55d?w=500',
          'location': {
            'type': 'Point',
            'coordinates': [2.3471, 48.8526] // [lng, lat]
          }
        },
        {
          'type': 'interest',
          'userId': '677db5b562dbd1a04ed621c9', // Jane Smith
          '_id': '675adf63da75cfe37235c7b4',
          'name': 'Le Louvre',
          'category': 'Musée',
          'address': 'Rue de Rivoli, Paris',
          'rating': 4.9,
          'photo_url': 'https://images.unsplash.com/photo-1515260268569-9271009adfdb?w=500',
          'location': {
            'type': 'Point',
            'coordinates': [2.3376, 48.8606] // [lng, lat]
          }
        }
      ];

      print('📊 Mode de test: Utilisation des données de test pour John Brown');
      return {
        'followers': followers,
        'choices': choices,
        'interests': interests,
      };
    } catch (e) {
      print('❌ Erreur lors de la récupération des données de test: $e');
      return _getEmptyFollowersData();
    }
  }

  // Formater les données des followers pour l'affichage
  List<Map<String, dynamic>> _formatFollowers(List<dynamic> followers) {
    return followers.map<Map<String, dynamic>>((follower) {
      return {
        '_id': follower['_id'] ?? follower['id'] ?? '',
        'name': follower['name'] ?? 'Utilisateur',
        'photo_url': follower['photo_url'] ?? follower['avatar'] ?? 'https://api.dicebear.com/6.x/adventurer/png?seed=default',
      };
    }).toList();
  }
  
  // Retourner une structure vide en cas d'erreur
  Map<String, dynamic> _getEmptyFollowersData() {
    return {
      'followers': <Map<String, dynamic>>[],
      'choices': <Map<String, dynamic>>[],
      'interests': <Map<String, dynamic>>[],
    };
  }

  /// Récupérer les amis à proximité
  Future<List<Map<String, dynamic>>> getNearbyFriends(
    String userId, 
    double latitude, 
    double longitude, 
    {double radius = 5000, 
    bool onlyFollowing = false, 
    bool onlyFollowers = false}
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/friends/nearby?userId=$userId&lat=$latitude&lng=$longitude&radius=$radius'
          '&onlyFollowing=${onlyFollowing.toString()}&onlyFollowers=${onlyFollowers.toString()}'
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((friend) => friend as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Exception dans getNearbyFriends: $e');
      return [];
    }
  }
} 