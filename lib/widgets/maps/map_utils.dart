// Utilitaires pour la gestion cross-platform des cartes
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latLng;

/// Utilitaires pour faciliter l'interaction avec les cartes sur toutes les plateformes
class MapUtils {
  /// Convertit un LatLng de Google Maps en LatLng de flutter_map
  static latLng.LatLng googleToFlutterLatLng(gmaps.LatLng position) {
    return latLng.LatLng(position.latitude, position.longitude);
  }

  /// Convertit un LatLng de flutter_map en LatLng de Google Maps
  static gmaps.LatLng flutterToGoogleLatLng(latLng.LatLng position) {
    return gmaps.LatLng(position.latitude, position.longitude);
  }

  /// Convertit une couleur en "hue" pour Google Maps BitmapDescriptor
  static double colorToHue(Color color) {
    // Convertit une couleur RGB en teinte (hue)
    final int r = color.red;
    final int g = color.green;
    final int b = color.blue;

    double max = [r, g, b].reduce((a, b) => a > b ? a : b).toDouble();
    double min = [r, g, b].reduce((a, b) => a < b ? a : b).toDouble();

    double hue = 0.0;
    if (max == min) {
      hue = 0.0;
    } else if (max == r) {
      hue = (60 * ((g - b) / (max - min)) + 360) % 360;
    } else if (max == g) {
      hue = (60 * ((b - r) / (max - min)) + 120) % 360;
    } else if (max == b) {
      hue = (60 * ((r - g) / (max - min)) + 240) % 360;
    }

    return hue; // Retourne la teinte entre 0 et 360
  }

  /// Calcule la distance entre deux coordonnées en mètres
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Rayon de la Terre en mètres
    double dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
    double dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (3.141592653589793 / 180.0)) *
            cos(lat2 * (3.141592653589793 / 180.0)) *
            (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Vérifie si l'application est en mode web
  static bool isWeb() {
    return kIsWeb;
  }

  /// Obtient le BitmapDescriptor correspondant à une teinte
  static gmaps.BitmapDescriptor getMarkerIcon(double hue) {
    return gmaps.BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  /// Crée une couleur Flutter Map basée sur la teinte Google Maps
  static Color getFlutterMapColor(double hue) {
    if (hue == gmaps.BitmapDescriptor.hueRed) {
      return Colors.red;
    } else if (hue == gmaps.BitmapDescriptor.hueOrange) {
      return Colors.orange;
    } else if (hue == gmaps.BitmapDescriptor.hueYellow) {
      return Colors.yellow;
    } else if (hue == gmaps.BitmapDescriptor.hueGreen) {
      return Colors.green;
    } else if (hue == gmaps.BitmapDescriptor.hueCyan) {
      return Colors.cyan;
    } else if (hue == gmaps.BitmapDescriptor.hueAzure) {
      return Colors.blue;
    } else if (hue == gmaps.BitmapDescriptor.hueBlue) {
      return Colors.blue.shade800;
    } else if (hue == gmaps.BitmapDescriptor.hueViolet) {
      return Colors.purple;
    } else if (hue == gmaps.BitmapDescriptor.hueMagenta) {
      return Colors.pink;
    } else if (hue == gmaps.BitmapDescriptor.hueRose) {
      return Colors.pink.shade300;
    } else {
      // Calculer une couleur approximative basée sur la teinte
      return HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    }
  }
}