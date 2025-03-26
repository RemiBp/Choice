import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationVerificationService {
  static const String baseUrl = 'http://localhost:5000/api';
  
  // Distance maximale en mètres considérée comme "à cet endroit"
  static const double MAX_DISTANCE_METERS = 30.0;
  
  // Durée minimale en minutes à passer à un endroit pour le considérer comme visité
  static const int MIN_DURATION_MINUTES = 30;
  
  // Nombre de jours max pour considérer une visite comme récente
  static const int MAX_DAYS_AGO = 7;

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
}