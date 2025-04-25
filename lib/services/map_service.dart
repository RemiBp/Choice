import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart' as constants;
import '../models/map_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/producer.dart';
import '../configs/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../services/auth_service.dart';

/// Service standardisé pour toutes les maps de l'application
/// Centralise les appels API et facilite la maintenance du code
class MapService {
  // Singleton pattern
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal() {
    // Initialisation de Dio avec des timeouts plus élevés
    dio = Dio(BaseOptions(
      baseUrl: constants.getBaseUrlSync(),
      connectTimeout: Duration(milliseconds: 60000),
      receiveTimeout: Duration(milliseconds: 60000),
      sendTimeout: Duration(milliseconds: 60000),
    ));
    
    // Ajouter un intercepteur pour retenter les requêtes en cas d'échec
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            print('⏱️ Timeout détecté, tentative de reconnexion...');
            
            // Tentative de reconnexion
            try {
              final options = e.requestOptions;
              final response = await dio.request(
                options.path,
                data: options.data,
                queryParameters: options.queryParameters,
                options: Options(
                  method: options.method,
                  headers: options.headers,
                ),
              );
              
              return handler.resolve(response);
            } catch (e) {
              // Si la tentative échoue, renvoyer l'erreur originale
              return handler.reject(e as DioException);
            }
          }
          
          // Pour les autres types d'erreurs, laisser passer
          return handler.next(e);
        },
      ),
    );
  }

  late final Dio dio;
  
  // Propriété pour stocker l'URL de base
  String get baseUrl => constants.getBaseUrl();
  
  // Méthode pour récupérer l'URL de base SANS récursion
  String getBaseUrl() {
    // Appel à la méthode dans constants au lieu de s'appeler elle-même
    return constants.getBaseUrl();
  }
  
  // Méthode générique pour effectuer une recherche avec gestion des timeouts
  Future<List<Map<String, dynamic>>> _performSearch({
    required String endpoint,
    required double latitude,
    required double longitude,
    double radius = 1500,
    Map<String, dynamic>? filters,
  }) async {
    // Construction des paramètres de requête
    final queryParameters = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'radius': radius.toString(),
    };
    
    // Ajout des filtres aux paramètres
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null) {
          if (value is List) {
            if (value.isNotEmpty) {
              queryParameters[key] = value.join(",");
            }
          } else if (value is num) {
            queryParameters[key] = value.toString();
          } else if (value is String && value.isNotEmpty) {
            queryParameters[key] = value;
          } else if (value is bool) {
            queryParameters[key] = value.toString();
          }
        }
      });
    }

    final Uri uri = _buildUri(endpoint, queryParameters);
    print("🔍 Requête envoyée à $endpoint : $uri");

    try {
      // Utiliser Dio au lieu de http pour les requêtes avec retry et gestion de timeout
      final response = await dio.getUri(uri).timeout(
        Duration(milliseconds: 45000),
        onTimeout: () {
          print('⏱️ Timeout lors de la requête à $endpoint');
          throw TimeoutException('Délai d\'attente dépassé lors du chargement des données');
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        print('❌ Erreur HTTP : Code ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      String errorMsg = 'Erreur réseau: ${e.message}';
      
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMsg = 'Délai d\'attente dépassé lors du chargement des données';
      }
      
      print('❌ $errorMsg');
      throw TimeoutException(errorMsg);
    } catch (e) {
      print('❌ Erreur réseau: $e');
      return [];
    }
  }
  
  // RESTAURANT MAP METHODS
  
  /// Récupère les producteurs de type restaurant à proximité
  Future<List<Map<String, dynamic>>> searchRestaurants({
    required double latitude,
    required double longitude,
    double radius = 1500,
    String? searchKeyword,
    double? minRating,
    double? minServiceRating,
    double? minLocationRating,
    double? minPortionRating,
    double? minAmbianceRating,
    String? openingHours,
    List<String>? selectedCategories,
    List<String>? selectedDishTypes,
    double? minPrice,
    double? maxPrice,
    double? minCalories,
    double? maxCalories,
    double? maxCarbonFootprint,
    List<String>? selectedNutriScores,
    String? choice,
    int? minFavorites,
    double? minItemRating,
    double? maxItemRating,
  }) async {
    final filters = {
      if (searchKeyword != null && searchKeyword.isNotEmpty) 'itemName': searchKeyword,
      if (minCalories != null) 'minCalories': minCalories,
      if (maxCalories != null) 'maxCalories': maxCalories,
      if (maxCarbonFootprint != null) 'maxCarbonFootprint': maxCarbonFootprint,
      if (selectedNutriScores != null && selectedNutriScores.isNotEmpty) 'nutriScores': selectedNutriScores,
      if (minRating != null) 'minRating': minRating,
      if (minServiceRating != null) 'minServiceRating': minServiceRating,
      if (minLocationRating != null) 'minLocationRating': minLocationRating,
      if (minPortionRating != null) 'minPortionRating': minPortionRating,
      if (minAmbianceRating != null) 'minAmbianceRating': minAmbianceRating,
      if (openingHours != null) 'openingHours': openingHours,
      if (selectedCategories != null && selectedCategories.isNotEmpty) 'categories': selectedCategories,
      if (selectedDishTypes != null && selectedDishTypes.isNotEmpty) 'dishTypes': selectedDishTypes,
      if (choice != null) 'choice': choice,
      if (minFavorites != null) 'minFavorites': minFavorites,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (minItemRating != null) 'minItemRating': minItemRating,
      if (maxItemRating != null) 'maxItemRating': maxItemRating,
    };

    // Utiliser la méthode générique pour faire la recherche
    return _performSearch(
      endpoint: '/api/producers/nearby',
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      filters: filters,
    );
  }
  
  /// Récupère les items de menu des restaurants
  Future<List<Map<String, dynamic>>> searchRestaurantItems({
    required double latitude,
    required double longitude,
    double radius = 1500,
    String? searchKeyword,
    List<String>? selectedCategories,
    List<String>? selectedDishTypes,
    double? minPrice,
    double? maxPrice,
    double? minCalories,
    double? maxCalories,
    List<String>? selectedNutriScores,
  }) async {
    final filters = {
      if (searchKeyword != null && searchKeyword.isNotEmpty) 'keyword': searchKeyword,
      if (selectedCategories != null && selectedCategories.isNotEmpty) 'categories': selectedCategories,
      if (selectedDishTypes != null && selectedDishTypes.isNotEmpty) 'dishTypes': selectedDishTypes,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (minCalories != null) 'minCalories': minCalories,
      if (maxCalories != null) 'maxCalories': maxCalories,
      if (selectedNutriScores != null && selectedNutriScores.isNotEmpty) 'nutriScores': selectedNutriScores,
    };

    // En mode développement, renvoyer des données mock
    if (kDebugMode) {
      // Désactiver les données simulées
      // return _getMockRestaurantItems(latitude, longitude);
    }

    // Utiliser la méthode générique pour faire la recherche
    return _performSearch(
      endpoint: '/api/restaurant-items/nearby',
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      filters: filters,
    );
  }
  
  /// Retourne des données de restaurants simulées pour le développement
  List<Map<String, dynamic>> _getMockRestaurantItems(double latitude, double longitude) {
    // Création de données simulées pour le développement
    return [
      {
        'id': 'mock-rest-1',
        'name': 'Restaurant Paris',
        'address': '123 Rue de Paris',
        'location': {
          'type': 'Point',
          'coordinates': [longitude + 0.002, latitude + 0.001]
        },
        'rating': 4.5,
        'cuisine': 'Française',
        'price_level': 2,
        'images': ['https://example.com/image1.jpg'],
        'distance': 350
      },
      {
        'id': 'mock-rest-2',
        'name': 'Bistro Lyon',
        'address': '456 Avenue de Lyon',
        'location': {
          'type': 'Point',
          'coordinates': [longitude - 0.001, latitude - 0.002]
        },
        'rating': 4.2,
        'cuisine': 'Lyonnaise',
        'price_level': 3,
        'images': ['https://example.com/image2.jpg'],
        'distance': 520
      },
      {
        'id': 'mock-rest-3',
        'name': 'Café Marseille',
        'address': '789 Boulevard de Marseille',
        'location': {
          'type': 'Point',
          'coordinates': [longitude + 0.003, latitude - 0.001]
        },
        'rating': 3.8,
        'cuisine': 'Méditerranéenne',
        'price_level': 1,
        'images': ['https://example.com/image3.jpg'],
        'distance': 430
      }
    ];
  }
  
  // LEISURE MAP METHODS
  
  /// Récupère les événements de loisirs à proximité
  Future<List<Map<String, dynamic>>> searchLeisureEvents({
    required double latitude,
    required double longitude,
    double radius = 1500,
    String? keyword,
    double? minRating,
    List<String>? categories,
    List<String>? emotions,
    Map<String, String>? dateRange,
    String? priceRange,
    bool? familyFriendly,
    // Critères artistiques
    double? minMiseEnScene,
    double? minJeuActeurs, 
    double? minScenario,
    double? minAmbiance,
    double? minOrganisation,
    double? minProgrammation,
    // Autres filtres
    String? eventType,
    List<String>? lineup,
    String? sortBy,
  }) async {
    try {
      // Construction des paramètres de requête
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (minRating != null) 'minRating': minRating.toString(),
        if (categories != null && categories.isNotEmpty) 'categories': categories.join(','),
        if (emotions != null && emotions.isNotEmpty) 'emotions': emotions.join(','),
        if (dateRange != null && dateRange['start'] != null) 'dateStart': dateRange['start']!,
        if (dateRange != null && dateRange['end'] != null) 'dateEnd': dateRange['end']!,
        if (priceRange != null && priceRange.isNotEmpty) 'priceRange': priceRange,
        if (familyFriendly != null) 'familyFriendly': familyFriendly.toString(),
        // Ajouter les critères artistiques à la requête
        if (minMiseEnScene != null && minMiseEnScene > 0) 'minMiseEnScene': minMiseEnScene.toString(),
        if (minJeuActeurs != null && minJeuActeurs > 0) 'minJeuActeurs': minJeuActeurs.toString(),
        if (minScenario != null && minScenario > 0) 'minScenario': minScenario.toString(),
        if (minAmbiance != null && minAmbiance > 0) 'minAmbiance': minAmbiance.toString(),
        if (minOrganisation != null && minOrganisation > 0) 'minOrganisation': minOrganisation.toString(),
        if (minProgrammation != null && minProgrammation > 0) 'minProgrammation': minProgrammation.toString(),
        // Ajouter les autres filtres
        if (eventType != null && eventType.isNotEmpty) 'eventType': eventType,
        if (lineup != null && lineup.isNotEmpty) 'lineup': lineup.join(','),
        if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
      };
      
      try {
        // Utiliser Dio avec gestion de timeout
        final response = await dio.get(
          '/api/leisure/events',
          queryParameters: queryParams,
        ).timeout(
          Duration(milliseconds: 45000),
          onTimeout: () {
            print('⏱️ Timeout lors de la requête pour les événements de loisirs');
            throw TimeoutException('Délai d\'attente dépassé lors du chargement des données');
          },
        );
        
        if (response.statusCode == 200) {
          final data = response.data;
          List<Map<String, dynamic>> events;
          
          if (data is List) {
            events = data.map((item) => Map<String, dynamic>.from(item)).toList();
          } else if (data is Map && data.containsKey('events')) {
            events = (data['events'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
          } else {
            print('❌ Format de réponse inattendu');
            return [];
          }
          
          print('📊 Événements reçus: ${events.length}');
          return events;
        } else {
          print('❌ Erreur lors de la requête API events: ${response.statusCode}');
          print('Response: ${response.data}');
          return [];
        }
      } on DioException catch (e) {
        String errorMsg = 'Erreur réseau: ${e.message}';
        
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          errorMsg = 'Délai d\'attente dépassé lors du chargement des événements de loisirs';
        }
        
        print('❌ $errorMsg');
        throw TimeoutException(errorMsg);
      }
    } catch (e) {
      print('Erreur lors de la recherche d\'événements de loisirs: $e');
      throw e; // Propager l'erreur pour une meilleure gestion
    }
  }

  /// Récupère les interests et choices des followings pour un lieu donné
  Future<List<Map<String, dynamic>>> getFollowingsInterestsForVenue(String venueId) async {
    try {
      final Uri uri = Uri.parse('${getBaseUrl()}/api/leisure/venues/$venueId/following-interests');
      final response = await http.get(uri, headers: await _getAuthHeaders());
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => {'name': item.toString()}).toList();
      } else {
        print('❌ Erreur HTTP lors de la récupération des intérêts des followings: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des intérêts des followings: $e');
      return [];
    }
  }

  /// Obtenir les headers d'authentification
  Future<Map<String, String>> _getAuthHeaders() async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    // Récupérer le token d'authentification s'il est disponible
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      print('Erreur lors de la récupération du token: $e');
    }
    
    return headers;
  }

  /// Récupère les signets (bookmarks) de l'utilisateur
  Future<List<Map<String, dynamic>>> getUserLeisureBookmarks() async {
    try {
      final Uri uri = Uri.parse('${getBaseUrl()}/api/bookmarks/leisure');
      
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['bookmarks'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        print('❌ Erreur lors de la requête API bookmarks: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Erreur lors de la récupération des signets: $e');
      return [];
    }
  }

  /// Ajoute un signet (bookmark) pour un lieu
  Future<bool> addLeisureBookmark(String venueId) async {
    try {
      final Uri uri = Uri.parse('${getBaseUrl()}/api/bookmarks/leisure');
      
      final response = await http.post(
        uri,
        headers: await _getAuthHeaders(),
        body: json.encode({'venueId': venueId}),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erreur lors de l\'ajout du signet: $e');
      return false;
    }
  }

  /// Supprime un signet (bookmark) pour un lieu
  Future<bool> removeLeisureBookmark(String venueId) async {
    try {
      final Uri uri = Uri.parse('${getBaseUrl()}/api/bookmarks/leisure/$venueId');
      
      final response = await http.delete(
        uri,
        headers: await _getAuthHeaders(),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors de la suppression du signet: $e');
      return false;
    }
  }
  
  // WELLNESS MAP METHODS
  
  /// Récupère les établissements de bien-être à proximité
  Future<List<Map<String, dynamic>>> searchWellnessPlaces({
    required double latitude,
    required double longitude,
    double radius = 1500,
    String? keyword,
    double? minRating,
    List<String>? serviceTypes,
    List<String>? benefits,
    String? priceRange,
    Map<String, String>? availability,
  }) async {
    final filters = {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (minRating != null) 'minRating': minRating,
      if (serviceTypes != null && serviceTypes.isNotEmpty) 'serviceTypes': serviceTypes,
      if (benefits != null && benefits.isNotEmpty) 'benefits': benefits,
      if (priceRange != null) 'priceRange': priceRange,
      if (availability != null) ...{
        'days': availability['days'],
        'openingTime': availability['openingTime'],
        'closingTime': availability['closingTime'],
      },
    };

    // Utiliser la méthode générique pour faire la recherche
    return _performSearch(
      endpoint: '/api/wellness/nearby',
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      filters: filters,
    );
  }
  
  // FRIENDS MAP METHODS
  
  /// Récupère les amis à proximité
  Future<List<Map<String, dynamic>>> searchFriends({
    required double latitude,
    required double longitude,
    double radius = 1500,
    String? searchKeyword,
    List<String>? selectedInterests,
    bool? onlyFollowing,
    bool? onlyFollowers,
    int? minCommonInterests,
    String? lastActiveTime,
  }) async {
    final filters = {
      if (searchKeyword != null && searchKeyword.isNotEmpty) 'keyword': searchKeyword,
      if (selectedInterests != null && selectedInterests.isNotEmpty) 'interests': selectedInterests,
      if (onlyFollowing != null) 'onlyFollowing': onlyFollowing,
      if (onlyFollowers != null) 'onlyFollowers': onlyFollowers,
      if (minCommonInterests != null) 'minCommonInterests': minCommonInterests,
      if (lastActiveTime != null) 'lastActiveTime': lastActiveTime,
    };

    // Utiliser la méthode générique pour faire la recherche
    return _performSearch(
      endpoint: '/api/friends/nearby',
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      filters: filters,
    );
  }
  
  /// Récupère les activités récentes des amis
  Future<List<Map<String, dynamic>>> getFriendsActivities({
    required String userId,
    String? activityType,
    int? limit,
    String? fromDate,
  }) async {
    if (kDebugMode) {
      return _getMockFriendsActivities(userId);
    }
    
    // D'abord essayer la nouvelle API
    try {
      final result = await getFriendsMapData(userId: userId);
      
      // Combiner les choices et interests
      List<Map<String, dynamic>> activities = [];
      if (result != null) {
        if (result.containsKey('choices')) {
          final choices = List<Map<String, dynamic>>.from(result['choices']);
          activities.addAll(choices);
        }
        
        if (result.containsKey('interests')) {
          final interests = List<Map<String, dynamic>>.from(result['interests']);
          activities.addAll(interests);
        }
      }
      
      if (activities.isNotEmpty) {
        return activities;
      }
    } catch (e) {
      print('⚠️ Erreur avec la nouvelle API, utilisation du fallback: $e');
    }
    
    // Fallback: utiliser l'ancienne API
    return searchFriendActivities(
      userId: userId,
      activityType: activityType,
      limit: limit,
      fromDate: fromDate,
    );
  }

  /// Récupère les données complètes pour la carte des amis
  Future<Map<String, dynamic>?> getFriendsMapData({required String userId, double? lat, double? lng, double radius = 50000}) async {
    try {
      // Utiliser l'API sans authentification pour le développement
      final Uri url = Uri.parse(
        '$baseUrl/api/friends/public/following-map?userId=$userId${lat != null ? "&lat=$lat" : ""}${lng != null ? "&lng=$lng" : ""}&radius=$radius'
      );

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        print('❌ Erreur API: ${response.statusCode} - ${response.body}');
        
        // Si l'API ne fonctionne pas, essayer avec l'ancienne méthode (à supprimer en production)
        print('⚠️ Tentative avec l\'ancienne méthode pour récupérer les données');
        return await _getLegacyFriendsMapData(userId);
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des données de la carte des amis: $e');
      return null;
    }
  }

  /// Méthode obsolète pour la rétrocompatibilité uniquement
  Future<Map<String, dynamic>?> _getLegacyFriendsMapData(String userId) async {
    try {
      final followersUri = Uri.parse('$baseUrl/api/friends/$userId');
      final followersResponse = await http.get(
        followersUri,
        headers: {'Content-Type': 'application/json'},
      );

      if (followersResponse.statusCode != 200) {
        print('❌ Erreur API followers: ${followersResponse.statusCode}');
        return null;
      }

      final List<dynamic> followers = jsonDecode(followersResponse.body);
      
      // Pour chaque follower, récupérer les choices et interests
      // Format de retour attendu
      final Map<String, dynamic> result = {
        'choices': <Map<String, dynamic>>[],
        'interests': <Map<String, dynamic>>[]
      };
      
      for (final follower in followers) {
        if (follower is Map<String, dynamic> && follower['_id'] != null) {
          try {
            final activitiesUri = Uri.parse(
              '$baseUrl/api/friends/map-activities/${follower['_id']}'
            );
            
            final activitiesResponse = await http.get(
              activitiesUri,
              headers: {'Content-Type': 'application/json'},
            );
            
            if (activitiesResponse.statusCode == 200) {
              final data = jsonDecode(activitiesResponse.body);
              
              if (data['choices'] is List) {
                for (final choice in data['choices']) {
                  if (choice is Map<String, dynamic>) {
                    choice['userId'] = follower['_id'];
                    choice['friendName'] = follower['name'];
                    (result['choices'] as List).add(choice);
                  }
                }
              }
              
              if (data['interests'] is List) {
                for (final interest in data['interests']) {
                  if (interest is Map<String, dynamic>) {
                    interest['userId'] = follower['_id'];
                    interest['friendName'] = follower['name'];
                    (result['interests'] as List).add(interest);
                  }
                }
              }
            }
          } catch (e) {
            print('❌ Erreur récupération activities pour ${follower['_id']}: $e');
          }
        }
      }
      
      return result;
    } catch (e) {
      print('❌ Exception legacy method: $e');
      return null;
    }
  }

  // GEOCODING METHODS
  
  /// Recherche d'adresses à partir d'un texte
  Future<List<Map<String, dynamic>>> searchAddresses(String address) async {
    if (kDebugMode) {
      return _generateMockAddressResults(address);
    }

    final queryParameters = {'address': address};
    final Uri uri = _buildUri('/api/geocode', queryParameters);

    try {
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        print('❌ Erreur HTTP : Code ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      return [];
    }
  }
  
  // UTILITY METHODS
  
  /// Construit une URI avec les paramètres
  Uri _buildUri(String path, Map<String, String> queryParameters) {
    final baseUrl = _getBaseUrl();
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
  
  /// Récupère l'URL de base pour les appels API
  String _getBaseUrl() {
    // Utiliser les constantes existantes au lieu d'ApiConfig
    return constants.getBaseUrl();
  }
  
  // MOCK DATA METHODS
  
  /// Génère des données mock pour les amis
  List<Map<String, dynamic>> _getMockFriends() {
    final List<Map<String, dynamic>> mockFriends = [];
    
    for (int i = 0; i < 10; i++) {
      mockFriends.add({
        'id': 'friend_$i',
        'name': 'Ami ${i + 1}',
        'username': 'user${i + 1}',
        'profileImage': 'https://randomuser.me/api/portraits/${i % 2 == 0 ? 'men' : 'women'}/${i + 1}.jpg',
        'location': {
          'coordinates': [
            2.3522 + (math.Random().nextDouble() - 0.5) * 0.05,
            48.8566 + (math.Random().nextDouble() - 0.5) * 0.05
          ]
        },
        'lastActive': '${DateTime.now().subtract(Duration(minutes: i * 10)).toIso8601String()}',
        'interests': ['Cuisine', 'Cinéma', 'Voyage', 'Sport'].take(math.Random().nextInt(3) + 1).toList(),
        'commonInterests': math.Random().nextInt(3) + 1,
        'isFollowing': math.Random().nextBool(),
        'isFollower': math.Random().nextBool(),
      });
    }
    
    return mockFriends;
  }
  
  /// Génère des données mock pour les activités des amis
  List<Map<String, dynamic>> _getMockFriendsActivities(String userId) {
    return [
      {
        'id': 'act_1',
        'type': 'choice',
        'userId': 'user_1',
        'userName': 'Alice Martin',
        'userAvatar': 'https://example.com/avatar1.jpg',
        'placeId': 'place_1',
        'placeName': 'Le Bistrot Parisien',
        'placeType': 'restaurant',
        'location': {
          'type': 'Point',
          'coordinates': [2.3522, 48.8566]
        },
        'rating': 4.8,
        'comment': 'Excellente cuisine française',
        'timestamp': '2023-05-15T14:30:00Z'
      },
      {
        'id': 'act_2',
        'type': 'interest',
        'userId': 'user_2',
        'userName': 'Thomas Dubois',
        'userAvatar': 'https://example.com/avatar2.jpg',
        'placeId': 'place_2',
        'placeName': 'Musée d\'Orsay',
        'placeType': 'leisure',
        'location': {
          'type': 'Point',
          'coordinates': [2.3265, 48.8600]
        },
        'timestamp': '2023-05-14T10:15:00Z'
      },
      {
        'id': 'act_3',
        'type': 'choice',
        'userId': 'user_3',
        'userName': 'Sophie Leroy',
        'userAvatar': 'https://example.com/avatar3.jpg',
        'placeId': 'place_3',
        'placeName': 'Spa Zen',
        'placeType': 'wellness',
        'location': {
          'type': 'Point',
          'coordinates': [2.3412, 48.8534]
        },
        'rating': 4.5,
        'comment': 'Massage relaxant incroyable',
        'timestamp': '2023-05-13T16:45:00Z'
      }
    ];
  }
  
  /// Génère des résultats d'adresse mock
  List<Map<String, dynamic>> _generateMockAddressResults(String address) {
    return [
      {
        'address': '$address, Paris, France',
        'latitude': 48.8566,
        'longitude': 2.3522,
      },
      {
        'address': '$address, Lyon, France',
        'latitude': 45.7640,
        'longitude': 4.8357,
      },
      {
        'address': '$address, Marseille, France',
        'latitude': 43.2965,
        'longitude': 5.3698,
      }
    ];
  }
  
  /// Calcule des coordonnées à partir d'un point de départ, une distance et un cap
  Map<String, double> _calculateCoordinates(double lat, double lon, double distanceKm, double bearingDegrees) {
    final double R = 6371.0; // Rayon de la Terre en kilomètres
    final double d = distanceKm / R;
    final double bearing = bearingDegrees * math.pi / 180.0;
    
    final double lat1 = lat * math.pi / 180.0;
    final double lon1 = lon * math.pi / 180.0;
    
    final double lat2 = math.asin(math.sin(lat1) * math.cos(d) + 
                       math.cos(lat1) * math.sin(d) * math.cos(bearing));
    final double lon2 = lon1 + math.atan2(math.sin(bearing) * math.sin(d) * math.cos(lat1),
                        math.cos(d) - math.sin(lat1) * math.sin(lat2));
    
    return {
      'latitude': lat2 * 180.0 / math.pi,
      'longitude': lon2 * 180.0 / math.pi,
    };
  }
  
  /// Génère des lieux de loisirs mock
  List<Map<String, dynamic>> _getMockLeisureVenues() {
    return [
      {
        'id': 'mock_theatre_1',
        'name': 'Théâtre des Champs-Élysées',
        'category': 'Théâtre',
        'description': 'Un théâtre historique proposant une programmation variée de pièces classiques et contemporaines.',
        'address': '15 avenue Montaigne, 75008 Paris',
        'rating': 4.7,
        'latitude': 48.8662,
        'longitude': 2.3031,
        'imageUrl': 'https://www.sortiraparis.com/images/80/66131/337503-le-theatre-des-champs-elysees-11.jpg',
        'events': [
          {'id': 'event_t1', 'title': 'Le Misanthrope', 'category': 'Pièce classique', 'date_debut': '23/04/2025'},
          {'id': 'event_t2', 'title': 'Cyrano de Bergerac', 'category': 'Pièce classique', 'date_debut': '28/04/2025'},
        ],
      },
      {
        'id': 'mock_museum_1',
        'name': 'Musée du Louvre',
        'category': 'Musée',
        'description': 'Le plus grand musée d\'art et d\'antiquités au monde, abritant la Joconde et la Vénus de Milo.',
        'address': 'Rue de Rivoli, 75001 Paris',
        'rating': 4.9,
        'latitude': 48.8606,
        'longitude': 2.3376,
        'imageUrl': 'https://www.sortiraparis.com/images/80/91674/692927-visuel-paris-louvre-musee-museum-cour.jpg',
        'events': [
          {'id': 'event_m1', 'title': 'Exposition: L\'Art Égyptien', 'category': 'Exposition', 'date_debut': '20/04/2025'},
          {'id': 'event_m2', 'title': 'Nocturne du Louvre', 'category': 'Visite guidée', 'date_debut': '25/04/2025'},
        ],
      },
      {
        'id': 'mock_concert_1',
        'name': 'L\'Olympia',
        'category': 'Salle de concert',
        'description': 'Salle de spectacle mythique qui a accueilli les plus grands artistes français et internationaux.',
        'address': '28 Boulevard des Capucines, 75009 Paris',
        'rating': 4.6,
        'latitude': 48.8702,
        'longitude': 2.3281,
        'imageUrl': 'https://www.parisinfo.com/var/otcp/sites/images/media/1.-photos/01.-ambiance-630-x-405/vue-de-l_olympia-630x405-c-otcp-dr/20093-1-fre-FR/Vue-de-l_Olympia-630x405-C-OTCP-DR.jpg',
        'events': [
          {'id': 'event_c1', 'title': 'Concert de Clara Luciani', 'category': 'Pop française', 'date_debut': '05/05/2025'},
          {'id': 'event_c2', 'title': 'Angèle en tournée', 'category': 'Pop française', 'date_debut': '12/05/2025'},
        ],
      },
      {
        'id': 'mock_cinema_1',
        'name': 'Cinéma Le Grand Rex',
        'category': 'Cinéma',
        'description': 'Cinéma emblématique de Paris avec la plus grande salle d\'Europe.',
        'address': '1 Boulevard Poissonnière, 75002 Paris',
        'rating': 4.5,
        'latitude': 48.8711,
        'longitude': 2.3478,
        'imageUrl': 'https://uploads.lebonbon.fr/source/2020/march/le-grand-rex-reouvert.jpg',
        'events': [
          {'id': 'event_cin1', 'title': 'Avant-première: Dune 3', 'category': 'Science-fiction', 'date_debut': '15/05/2025'},
          {'id': 'event_cin2', 'title': 'Rétrospective Spielberg', 'category': 'Cinéma classique', 'date_debut': '20/05/2025'},
        ],
      },
      {
        'id': 'mock_general_1',
        'name': 'Parc des Expositions',
        'category': 'Espace d\'événements',
        'description': 'Grande espace polyvalent accueillant salons, expositions et événements culturels.',
        'address': '1 Place de la Porte de Versailles, 75015 Paris',
        'rating': 4.2,
        'latitude': 48.8328,
        'longitude': 2.2868,
        'imageUrl': 'https://www.sortiraparis.com/images/80/1467/79056-le-parc-des-expositions-de-la-porte-de-versailles-a-paris.jpg',
        'events': [
          {'id': 'event_pe1', 'title': 'Salon du livre', 'category': 'Salon', 'date_debut': '25/05/2025'},
          {'id': 'event_pe2', 'title': 'Foire d\'art contemporain', 'category': 'Exposition', 'date_debut': '01/06/2025'},
        ],
      },
    ];
  }

  /// Normalise les filtres pour qu'ils correspondent à la structure côté API et MongoDB
  Map<String, dynamic> _normalizeFilters(Map<String, dynamic> filters, String placeType) {
    Map<String, dynamic> normalizedFilters = {...filters};
    
    // Transformation des catégories selon le type d'établissement
    if (filters.containsKey('categories') && filters['categories'].isNotEmpty) {
      if (placeType == 'restaurant') {
        // Mapping des catégories conviviales vers les codes de la base de données
        final categoryMapping = {
          'Française': 'french',
          'Italienne': 'italian',
          'Japonaise': 'japanese',
          'Asiatique': 'asian',
          'Indienne': 'indian',
          'Végétarienne': 'vegetarian',
          'Américaine': 'american',
          'Méditerranéenne': 'mediterranean'
        };
        
        List<String> dbCategories = [];
        for (String cat in filters['categories']) {
          if (categoryMapping.containsKey(cat)) {
            dbCategories.add(categoryMapping[cat]!);
          } else {
            dbCategories.add(cat.toLowerCase());
          }
        }
        
        normalizedFilters['categories'] = dbCategories;
      } else if (placeType == 'leisure') {
        // Mapping pour les loisirs
        final categoryMapping = {
          'Théâtre': 'theatre',
          'Musée': 'museum',
          'Galerie': 'gallery',
          'Cinéma': 'cinema',
          'Salle de concert': 'concert_hall',
          'Exposition': 'exhibition',
          'Festival': 'festival',
          'Spectacle': 'show'
        };
        
        List<String> dbCategories = [];
        for (String cat in filters['categories']) {
          if (categoryMapping.containsKey(cat)) {
            dbCategories.add(categoryMapping[cat]!);
          } else {
            dbCategories.add(cat.toLowerCase());
          }
        }
        
        normalizedFilters['categories'] = dbCategories;
      } else if (placeType == 'wellness') {
        // Mapping pour le bien-être
        final categoryMapping = {
          'Spa': 'spa',
          'Massage': 'massage',
          'Yoga': 'yoga',
          'Méditation': 'meditation',
          'Fitness': 'fitness',
          'Sauna': 'sauna',
          'Hammam': 'hammam',
          'Jacuzzi': 'jacuzzi'
        };
        
        List<String> dbCategories = [];
        for (String cat in filters['categories']) {
          if (categoryMapping.containsKey(cat)) {
            dbCategories.add(categoryMapping[cat]!);
          } else {
            dbCategories.add(cat.toLowerCase());
          }
        }
        
        normalizedFilters['categories'] = dbCategories;
      }
    }
    
    // Transformation des filtres spécifiques à chaque type d'établissement
    switch (placeType) {
      case 'restaurant':
        // Adapter les notes détaillées si la structure MongoDB ne les contient pas directement
        if (filters.containsKey('min_service_rating')) {
          // Si MongoDB utilise 'ratings.service' au lieu de 'service_rating'
          normalizedFilters['ratings.service'] = filters['min_service_rating'];
          normalizedFilters.remove('min_service_rating');
        }
        
        if (filters.containsKey('min_ambiance_rating')) {
          normalizedFilters['ratings.ambiance'] = filters['min_ambiance_rating'];
          normalizedFilters.remove('min_ambiance_rating');
        }
        
        // Ajuster pour la structure des prix dans MongoDB
        if (filters.containsKey('min_price') || filters.containsKey('max_price')) {
          // Si MongoDB utilise un entier simple pour price_level (1-4)
          int minLevel = _getPriceLevelFromPrice(filters['min_price'] ?? 0);
          int maxLevel = _getPriceLevelFromPrice(filters['max_price'] ?? 1000);
          
          normalizedFilters['price_level'] = {'\$gte': minLevel, '\$lte': maxLevel};
          normalizedFilters.remove('min_price');
          normalizedFilters.remove('max_price');
        }
        break;
        
      case 'leisure':
        // Adapter les filtres des loisirs
        if (filters.containsKey('emotions')) {
          normalizedFilters['émotions'] = filters['emotions'];
          normalizedFilters.remove('emotions');
        }
        
        if (filters.containsKey('accessibility')) {
          normalizedFilters['accessibilité'] = filters['accessibility'];
          normalizedFilters.remove('accessibility');
        }
        break;
        
      case 'wellness':
        // Adapter les filtres du bien-être
        if (filters.containsKey('services')) {
          normalizedFilters['service_types'] = filters['services'];
          normalizedFilters.remove('services');
        }
        
        if (filters.containsKey('features')) {
          normalizedFilters['amenities'] = filters['features'];
          normalizedFilters.remove('features');
        }
        break;
    }
    
    return normalizedFilters;
  }

  /// Convertit un prix en euros en niveau de prix (1-4)
  int _getPriceLevelFromPrice(double price) {
    if (price <= 15) return 1;
    if (price <= 40) return 2;
    if (price <= 80) return 3;
    return 4;
  }

  /// Méthode principale pour récupérer les lieux sur la carte
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    String placeType = 'restaurant',
    double radius = 5000,
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      // Normaliser les filtres pour qu'ils correspondent à MongoDB
      final normalizedFilters = _normalizeFilters(filters, placeType);
      
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/producers/advanced-search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': latitude,
          'lng': longitude,
          'radius': radius,
          'type': placeType,
          'page': 1,
          'limit': 50,
          ...normalizedFilters,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['results'] is List) {
          return List<Map<String, dynamic>>.from(responseData['results']);
        } else {
          print('❌ Format de réponse inattendu: ${response.body.substring(0, 100)}...');
          return [];
        }
      } else {
        print('❌ Erreur API: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des lieux: $e');
      return [];
    }
  }

  /// Récupère les options de filtrage pour la carte bien-être
  Future<Map<String, List<String>>> getWellnessFilterOptions() async {
    // En mode développement, retourner des données mock
    if (kDebugMode) {
      return {
        'serviceTypes': [
          'Spa',
          'Massage',
          'Yoga',
          'Méditation',
          'Fitness',
          'Sauna',
          'Hammam',
          'Jacuzzi',
        ],
        'benefits': [
          'Relaxation',
          'Détente musculaire',
          'Équilibre mental',
          'Énergie',
          'Bien-être',
          'Stress',
          'Circulation',
          'Sommeil',
        ],
        'priceRanges': ['€', '€€', '€€€'],
      };
    }

    // Dans une implémentation réelle, on ferait un appel API
    try {
      final Uri uri = _buildUri('/api/wellness/filter-options', {});
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        return {
          'serviceTypes': List<String>.from(data['serviceTypes'] ?? []),
          'benefits': List<String>.from(data['benefits'] ?? []),
          'priceRanges': List<String>.from(data['priceRanges'] ?? []),
        };
      } else {
        print('❌ Erreur HTTP : Code ${response.statusCode}');
        return {
          'serviceTypes': [],
          'benefits': [],
          'priceRanges': [],
        };
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      return {
        'serviceTypes': [],
        'benefits': [],
        'priceRanges': [],
      };
    }
  }

  /// Récupère les amis d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserFriends(String userId) async {
    if (kDebugMode) {
      return _getMockFriends();
    }
    
    final queryParameters = {'userId': userId};
    final Uri uri = _buildUri('/api/users/friends', queryParameters);

    try {
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        print('❌ Erreur HTTP : Code ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      return [];
    }
  }

  /// Recherche les activités des amis (version obsolète)
  Future<List<Map<String, dynamic>>> searchFriendActivities({
    required String userId,
    String? activityType,
    int? limit,
    String? fromDate,
  }) async {
    try {
      final Uri uri = Uri.parse(
        '$baseUrl/api/friends/$userId/activities?${activityType != null ? 'type=$activityType&' : ''}${limit != null ? 'limit=$limit&' : ''}${fromDate != null ? 'from=$fromDate' : ''}'
      );
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        print('❌ Erreur lors de la recherche des activités des amis: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la recherche des activités des amis: $e');
      return [];
    }
  }

  /// Récupère les critères d'évaluation par catégorie
  Future<Map<String, dynamic>> getRatingCriteria(String? category) async {
    try {
      final Uri uri = Uri.parse('${getBaseUrl()}/api/leisure/rating-criteria')
          .replace(queryParameters: category != null ? {'category': category} : null);
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error ${response.statusCode}: ${response.body}');
        // Retourner des critères par défaut en cas d'erreur
        return {
          'ambiance': 'Ambiance',
          'qualite_service': 'Qualité du service',
          'rapport_qualite_prix': 'Rapport qualité/prix'
        };
      }
    } catch (e) {
      print('Exception: $e');
      // Retourner des critères par défaut en cas d'erreur
      return {
        'ambiance': 'Ambiance',
        'qualite_service': 'Qualité du service',
        'rapport_qualite_prix': 'Rapport qualité/prix'
      };
    }
  }

  /// Récupère les lieux de loisirs avec tous les paramètres spécifiés
  Future<List<Map<String, dynamic>>> getLeisureVenues(Map<String, dynamic> params) async {
    try {
      // Rediriger vers la nouvelle méthode searchLeisureEvents avec les paramètres appropriés
      final double latitude = double.tryParse(params['latitude'].toString()) ?? 0.0;
      final double longitude = double.tryParse(params['longitude'].toString()) ?? 0.0;
      final double radius = double.tryParse(params['radius'].toString()) ?? 5000.0;
      
      return await searchLeisureEvents(
        latitude: latitude,
        longitude: longitude, 
        radius: radius,
        keyword: params['keyword'],
        minRating: params['minRating'] != null ? double.tryParse(params['minRating'].toString()) : null,
        categories: params['categories'] != null ? params['categories'].toString().split(',') : null,
        emotions: params['emotions'] != null ? params['emotions'].toString().split(',') : null,
        dateRange: params['dateStart'] != null || params['dateEnd'] != null ? {
          if (params['dateStart'] != null) 'start': params['dateStart'].toString(),
          if (params['dateEnd'] != null) 'end': params['dateEnd'].toString(),
        } : null,
        priceRange: params['minPrice'] != null && params['maxPrice'] != null ? 
          "${params['minPrice']}-${params['maxPrice']}" : null,
        familyFriendly: params['familyFriendly'] == 'true',
        // Critères artistiques 
        minMiseEnScene: params['minMiseEnScene'] != null ? 
          double.tryParse(params['minMiseEnScene'].toString()) : null,
        minJeuActeurs: params['minJeuActeurs'] != null ? 
          double.tryParse(params['minJeuActeurs'].toString()) : null,
        minScenario: params['minScenario'] != null ? 
          double.tryParse(params['minScenario'].toString()) : null,
        minAmbiance: params['minAmbiance'] != null ? 
          double.tryParse(params['minAmbiance'].toString()) : null,
        minOrganisation: params['minOrganisation'] != null ? 
          double.tryParse(params['minOrganisation'].toString()) : null,
        minProgrammation: params['minProgrammation'] != null ? 
          double.tryParse(params['minProgrammation'].toString()) : null,
        // Autres filtres
        eventType: params['eventType'],
        lineup: params['lineup'] != null ? params['lineup'].toString().split(',') : null,
        sortBy: params['sortBy'],
      );
    } catch (e) {
      print('Exception lors de la récupération des lieux: $e');
      return [];
    }
  }

  /// Récupère les données cartographiques des amis de l'utilisateur
  Future<Map<String, dynamic>> getFriendsMapDataLegacy() async {
    try {
      final Uri uri = Uri.parse('${getBaseUrl()}/api/users/friends/map-data');
      
      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        print('❌ Erreur lors de la récupération des données cartographiques des amis: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des données cartographiques des amis: $e');
      return {};
    }
  }

  /// Appelle l'API avancée pour la recherche de restaurants (GET /api/producers/advanced-search)
  Future<Map<String, dynamic>> fetchAdvancedRestaurants(Map<String, String> queryParams) async {
    final baseUrl = constants.getBaseUrl();
    final uri = Uri.parse(baseUrl + '/api/producers/advanced-search').replace(queryParameters: queryParams);
    print('🔍 [fetchAdvancedRestaurants] GET $uri');
    
    try {
      // Ajouter un timeout pour éviter les attentes trop longues
      final client = http.Client();
      final request = http.Request('GET', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';
      
      // Ajouter un timeout de 15 secondes
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          client.close();
          throw TimeoutException('La requete a mis trop de temps a s\'executer');
        },
      );
      
      // Lire la réponse en streaming pour les gros résultats
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('❌ Erreur API: ${response.statusCode} - ${response.body.substring(0, math.min(200, response.body.length))}...');
        return {'success': false, 'message': 'Erreur API', 'results': []};
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      return {'success': false, 'message': 'Erreur réseau: ${e.toString()}', 'results': []};
    }
  }

  // *** NOUVELLE MÉTHODE POUR RÉCUPÉRER LES UTILISATEURS INTERACTIFS ***
  Future<List<Map<String, dynamic>>> getInteractingUsers(String targetId, String targetType) async {
    final uri = Uri.parse('${constants.getBaseUrl()}/api/interactions/$targetType/$targetId/users');
    print('📞 Calling Interaction Users API: ${uri.toString()}');
    
    try {
      final response = await http.get(
        uri,
        headers: { 'Content-Type': 'application/json' }, // Ajouter des headers d'auth si nécessaire
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Received ${data.length} interacting users for $targetType $targetId');
        return List<Map<String, dynamic>>.from(data);
      } else {
        print('❌ Failed to load interacting users: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load interacting users');
      }
    } catch (e) {
      print('❌ Error calling interacting users API: $e');
      throw Exception('Error fetching interacting users: $e');
    }
  }
} 