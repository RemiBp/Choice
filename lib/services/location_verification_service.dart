import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../services/location_service.dart';
import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../utils/constants.dart' as constants;

class LocationVerificationService {
  static const String baseUrl = 'https://api.choiceapp.fr/api';
  
  // Distance maximale en mètres considérée comme "à cet endroit"
  static const double MAX_DISTANCE_METERS = 30.0;
  
  // Durée minimale en minutes à passer à un endroit pour le considérer comme visité
  static const int MIN_DURATION_MINUTES = 30;
  
  // Nombre de jours max pour considérer une visite comme récente
  static const int MAX_DAYS_AGO = 7;

  // Seuil de distance minimale en mètres
  static const double defaultDistanceThreshold = 100.0;
  // Seuil de temps minimal en minutes
  static const int defaultTimeThreshold = 30;
  // Temps par défaut pour considérer une visite valide (en jours)
  static const int defaultValidityPeriod = 7;

  /// Vérifie si l'utilisateur a passé assez de temps à un lieu spécifique
  /// dans les derniers jours pour pouvoir faire un choice
  static Future<bool> hasVisitedLocation({
    required String userId, 
    required String locationId, 
    required String locationType,
    double minDurationMinutes = MIN_DURATION_MINUTES,
    int maxDaysAgo = MAX_DAYS_AGO,
  }) async {
    try {
      // Construction de l'URL avec des paramètres de requête
      final url = Uri.parse('$baseUrl/location-history/verify?'
          'userId=$userId&'
          'locationId=$locationId&'
          'locationType=$locationType&'
          'minDurationMinutes=$minDurationMinutes&'
          'maxDaysAgo=$maxDaysAgo');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['verified'] == true;
      } else {
        print('❌ Erreur lors de la vérification de localisation: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception lors de la vérification de localisation: $e');
      return false;
    }
  }

  /// Récupère l'historique des visites d'un utilisateur pour un lieu donné
  static Future<List<Map<String, dynamic>>> getLocationVisitHistory({
    required String userId, 
    required String locationId, 
    required String locationType,
    int maxDaysAgo = MAX_DAYS_AGO,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/location-history?'
          'userId=$userId&'
          'locationId=$locationId&'
          'locationType=$locationType&'
          'maxDaysAgo=$maxDaysAgo');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['visits'] ?? []);
      } else {
        print('❌ Erreur lors de la récupération de l\'historique: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  /// Calcule la distance entre deux coordonnées GPS en mètres
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    final meter = distance(
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
    return meter;
  }

  /// Version alternative du calcul de distance utilisant le package Geolocator
  static double calculateDistanceGeolocator(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Vérifie si deux coordonnées sont à proximité selon un seuil défini
  static bool isNearLocation(
    double userLat, 
    double userLon,
    double locationLat, 
    double locationLon, 
    {double maxDistanceMeters = MAX_DISTANCE_METERS}
  ) {
    try {
      double distance = calculateDistance(userLat, userLon, locationLat, locationLon);
      return distance <= maxDistanceMeters;
    } catch (e) {
      print('❌ Erreur lors du calcul de distance: $e');
      // En cas d'erreur, on utilise une méthode alternative
      try {
        double distanceBackup = calculateDistanceGeolocator(userLat, userLon, locationLat, locationLon);
        return distanceBackup <= maxDistanceMeters;
      } catch (e2) {
        print('❌ Erreur avec méthode alternative: $e2');
        return false;
      }
    }
  }

  /// Formate la durée passée à un lieu en texte lisible
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours heure${hours > 1 ? 's' : ''}';
      } else {
        return '$hours heure${hours > 1 ? 's' : ''} et $remainingMinutes minute${remainingMinutes > 1 ? 's' : ''}';
      }
    }
  }

  /// Formate la date d'une visite en texte lisible
  static String formatVisitDate(DateTime visitDate) {
    final now = DateTime.now();
    final difference = now.difference(visitDate);
    
    if (difference.inDays == 0) {
      return "Aujourd'hui";
    } else if (difference.inDays == 1) {
      return "Hier";
    } else if (difference.inDays < 7) {
      return "Il y a ${difference.inDays} jours";
    } else {
      final day = visitDate.day.toString().padLeft(2, '0');
      final month = visitDate.month.toString().padLeft(2, '0');
      final year = visitDate.year;
      return "$day/$month/$year";
    }
  }

  /// Vérifie si l'utilisateur est physiquement présent à un emplacement
  /// 
  /// Returns un Map avec:
  /// - 'verified': bool - Si l'utilisateur est présent à l'emplacement
  /// - 'distance': double - La distance en mètres entre l'utilisateur et l'emplacement
  /// - 'message': String - Un message explicatif du résultat
  static Future<Map<String, dynamic>> verifyPresence({
    required double locationLat,
    required double locationLon,
    double distanceThreshold = defaultDistanceThreshold,
  }) async {
    try {
      // Obtenir la position actuelle de l'utilisateur
      final locationService = LocationService();
      final currentPosition = await locationService.getCurrentPosition();
      
      if (currentPosition == null) {
        return {
          'verified': false,
          'distance': double.infinity,
          'message': 'Impossible d\'obtenir votre position actuelle',
        };
      }
      
      // Calculer la distance entre l'utilisateur et l'emplacement cible
      final double distance = locationService.calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        locationLat,
        locationLon
      );
      
      final bool isPresent = distance <= distanceThreshold;
      
      return {
        'verified': isPresent,
        'distance': distance,
        'message': isPresent
            ? 'Présence vérifiée ! Vous êtes à ${distance.toStringAsFixed(0)} mètres de l\'emplacement.'
            : 'Vous êtes trop loin. Distance: ${distance.toStringAsFixed(0)} mètres (max: ${distanceThreshold.toStringAsFixed(0)} m)',
      };
    } catch (e) {
      print('❌ Erreur lors de la vérification de présence: $e');
      return {
        'verified': false,
        'distance': double.infinity,
        'message': 'Erreur lors de la vérification: $e',
      };
    }
  }
  
  /// Vérifie si l'historique de l'utilisateur montre qu'il a visité un lieu
  static Future<Map<String, dynamic>> verifyVisitHistory({
    required String userId,
    required String locationId,
    required double locationLat,
    required double locationLon,
    int timeThresholdMinutes = defaultTimeThreshold,
    int validityPeriodDays = defaultValidityPeriod,
  }) async {
    try {
      // Cette fonction devrait appeler une API backend pour vérifier l'historique
      // Pour l'instant, nous renvoyons un résultat simulé
      final locationService = LocationService();
      final currentPosition = await locationService.getCurrentPosition();
      
      if (currentPosition == null) {
        return {
          'verified': false,
          'lastVisit': null,
          'duration': 0,
          'message': 'Impossible d\'obtenir votre position actuelle',
        };
      }
      
      final double distanceCurrent = locationService.calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        locationLat,
        locationLon
      );
      
      // Pour test: si l'utilisateur est actuellement sur place, on simule une visite récente
      if (distanceCurrent <= 100) {
        return {
          'verified': true,
          'lastVisit': DateTime.now().toString(),
          'duration': timeThresholdMinutes + 10,
          'message': 'Vous êtes actuellement sur place !',
        };
      } else {
        // Simulation d'un résultat négatif ou positif aléatoire
        final bool hasVisited = math.Random().nextBool();
        
        if (hasVisited) {
          final visitDate = DateTime.now().subtract(Duration(days: math.Random().nextInt(validityPeriodDays)));
          final duration = timeThresholdMinutes + math.Random().nextInt(60);
          
          return {
            'verified': true,
            'lastVisit': visitDate.toString(),
            'duration': duration,
            'message': 'Vous avez visité ce lieu le ${_formatDate(visitDate)} pendant $duration minutes',
          };
        } else {
          return {
            'verified': false,
            'lastVisit': null,
            'duration': 0,
            'message': 'Aucune visite récente détectée au cours des $validityPeriodDays derniers jours',
          };
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'historique de visite: $e');
      return {
        'verified': false,
        'lastVisit': null,
        'duration': 0,
        'message': 'Erreur lors de la vérification: $e',
      };
    }
  }
  
  // Format une date pour affichage
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Vérifie si l'utilisateur est à proximité d'un restaurant
  static Future<bool> verifyUserNearRestaurant(
    String userId,
    String restaurantId,
    Location userLocation,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/location/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'restaurantId': restaurantId,
          'latitude': userLocation.latitude,
          'longitude': userLocation.longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isNearby'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error in location verification: $e');
      return false;
    }
  }
}