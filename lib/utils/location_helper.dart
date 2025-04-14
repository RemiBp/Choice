import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

/// Classe utilitaire pour gérer les fonctionnalités de géolocalisation
class LocationHelper {
  /// Vérifie les permissions de localisation et les demande si nécessaire
  static Future<bool> checkLocationPermission() async {
    // Vérifier si les services de localisation sont activés
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Essayer d'activer les services de localisation
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        return false;
      }
    }

    // Vérifier les permissions de localisation
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Les permissions sont définitivement refusées, rediriger vers les paramètres
      await openAppSettings();
      return false;
    }
    
    return true;
  }
  
  /// Récupère la position actuelle de l'utilisateur
  static Future<Position> getCurrentLocation() async {
    // Vérifier les permissions
    bool permissionGranted = await checkLocationPermission();
    if (!permissionGranted) {
      throw Exception('Les permissions de localisation ne sont pas accordées');
    }
    
    // Obtenir la position actuelle
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      throw Exception('Erreur lors de la récupération de la position: $e');
    }
  }
  
  /// Convertit un objet Position en LatLng pour Google Maps
  static gmaps.LatLng positionToLatLng(Position position) {
    return gmaps.LatLng(position.latitude, position.longitude);
  }
  
  /// Calcule la distance entre deux points géographiques en kilomètres
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double radius = 6371; // Rayon de la Terre en km
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
               math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
               math.sin(dLon / 2) * math.sin(dLon / 2);
               
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radius * c;
  }
  
  /// Convertit des degrés en radians
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  /// Récupère une adresse à partir de coordonnées géographiques
  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // Note: Dans une vraie implémentation, nous utiliserions ici geocoding
      // Mais pour simplifier, nous retournons simplement les coordonnées formatées
      return 'Lat: ${latitude.toStringAsFixed(6)}, Long: ${longitude.toStringAsFixed(6)}';
    } catch (e) {
      return 'Adresse non disponible';
    }
  }
  
  /// Anime la caméra vers une position spécifique
  static void animateCameraToPosition(
    gmaps.GoogleMapController controller,
    gmaps.LatLng position, {
    double zoom = 15.0,
  }) {
    controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: position,
          zoom: zoom,
        ),
      ),
    );
  }
  
  /// Ajuste la vue de la carte pour inclure tous les marqueurs
  static void fitBoundsToMarkers(
    gmaps.GoogleMapController controller,
    Set<gmaps.Marker> markers, {
    double padding = 50.0,
  }) {
    if (markers.isEmpty) return;
    
    // Trouver les limites de tous les marqueurs
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (var marker in markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }
    
    // Créer des limites avec une marge
    gmaps.LatLngBounds bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
    
    // Animer la caméra pour inclure tous les marqueurs
    controller.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }
} 