import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Classe utilitaire pour fonctions communes aux cartes
class MapUtils {
  /// Calcule la distance en kilomètres entre deux coordonnées (formule de Haversine)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Rayon terrestre en kilomètres
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Convertit des degrés en radians
  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
  
  /// Ajuste la caméra pour voir tous les marqueurs
  static Future<void> fitMapToMarkers(GoogleMapController controller, Set<Marker> markers, {double padding = 50.0}) async {
    if (markers.isEmpty) return;
    
    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;
    
    for (Marker marker in markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }
    
    // Ajouter une marge pour améliorer la visibilité
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;
    
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
    
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
  }
  
  /// Fonction pour obtenir une couleur en fonction d'un score (0 à 1)
  static Color getColorFromScore(double score) {
    // Garantir que le score est dans la plage 0-1
    score = score.clamp(0.0, 1.0);
    
    // Rouge (0) -> Jaune (0.5) -> Vert (1.0)
    if (score < 0.5) {
      // Rouge à Jaune (0 à 0.5)
      return Color.lerp(
        Colors.red,
        Colors.yellow,
        score * 2,
      )!;
    } else {
      // Jaune à Vert (0.5 à 1.0)
      return Color.lerp(
        Colors.yellow,
        Colors.green,
        (score - 0.5) * 2,
      )!;
    }
  }
  
  /// Convertit une couleur en valeur de teinte pour BitmapDescriptor
  static double colorToHue(Color color) {
    HSVColor hsvColor = HSVColor.fromColor(color);
    return hsvColor.hue;
  }
  
  /// Formater une durée en format lisible
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min';
    } else {
      return '${duration.inSeconds}s';
    }
  }
  
  /// Formater une distance en format lisible
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      double distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceInMeters.round()} m';
    }
  }
} 