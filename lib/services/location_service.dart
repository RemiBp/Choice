// Location service abstraction with conditional export pattern
// similar to utils.dart

export 'location_stub.dart'
  if (dart.library.io) 'location_service_io.dart'
  if (dart.library.html) 'location_service_web.dart';

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:location/location.dart';

/// LocationPosition est une classe simple pour stocker des coordonnées
class LocationPosition {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  LocationPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    required this.timestamp,
  });
}

/// Service de localisation pour obtenir la position actuelle de l'utilisateur
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  LocationService._internal();

  final Location _location = Location();

  /// Vérifie si les services de localisation sont activés
  Future<bool> isLocationServiceEnabled() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
    }
    return serviceEnabled;
  }

  /// Vérifie et demande les permissions de localisation
  Future<bool> checkAndRequestPermission() async {
    PermissionStatus permission = await _location.hasPermission();
    
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    
    return permission == PermissionStatus.granted || 
           permission == PermissionStatus.grantedLimited;
  }

  /// Obtient la position actuelle de l'utilisateur
  Future<LocationPosition?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      bool permissionGranted = await checkAndRequestPermission();
      if (!permissionGranted) {
        return null;
      }

      // Configurer la précision
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 10000,  // 10 secondes
        distanceFilter: 10,  // 10 mètres
      );

      LocationData locationData = await _location.getLocation();
      
      if (locationData.latitude != null && locationData.longitude != null) {
        return LocationPosition(
          latitude: locationData.latitude!,
          longitude: locationData.longitude!,
          accuracy: locationData.accuracy,
          altitude: locationData.altitude,
          heading: locationData.heading,
          speed: locationData.speed,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (locationData.time ?? DateTime.now().millisecondsSinceEpoch).toInt(),
          ),
        );
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur de localisation: $e');
      return null;
    }
  }

  /// Active la mise à jour continue de la position
  Stream<LocationPosition> getPositionStream() {
    return _location.onLocationChanged.map((locationData) {
      return LocationPosition(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        accuracy: locationData.accuracy,
        altitude: locationData.altitude,
        heading: locationData.heading,
        speed: locationData.speed,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (locationData.time ?? DateTime.now().millisecondsSinceEpoch).toInt(),
        ),
      );
    });
  }

  /// Calcule la distance entre deux points (en mètres)
  double calculateDistance(
    double startLatitude, 
    double startLongitude, 
    double endLatitude, 
    double endLongitude
  ) {
    const int earthRadius = 6371000; // en mètres
    
    double lat1Rad = startLatitude * (pi / 180);
    double lat2Rad = endLatitude * (pi / 180);
    double lon1Rad = startLongitude * (pi / 180);
    double lon2Rad = endLongitude * (pi / 180);
    
    double latDiff = lat2Rad - lat1Rad;
    double lonDiff = lon2Rad - lon1Rad;
    
    double a = sin(latDiff / 2) * sin(latDiff / 2) +
               cos(lat1Rad) * cos(lat2Rad) *
               sin(lonDiff / 2) * sin(lonDiff / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    return earthRadius * c;
  }
}

// Constantes et fonctions mathématiques
const double pi = 3.1415926535897932;

double sin(double x) => math.sin(x);
double cos(double x) => math.cos(x);
double sqrt(double x) => math.sqrt(x);
double atan2(double y, double x) => math.atan2(y, x);

/// Énumération des états de permission pour la localisation
enum LocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
}