// Location service abstraction with conditional export pattern
// similar to utils.dart

export 'location_stub.dart'
  if (dart.library.io) 'location_service_io.dart'
  if (dart.library.html) 'location_service_web.dart';

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/constants.dart' as constants;
import 'notification_service.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Classe de modèle pour une position de localisation
class LocationPosition {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const LocationPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    required this.timestamp,
  });

  factory LocationPosition.fromPosition(Position position) {
        return LocationPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      heading: position.heading,
      speed: position.speed,
      timestamp: position.timestamp,
    );
  }

  @override
  String toString() => 'Lat: $latitude, Long: $longitude';
}

/// Classe de modèle pour un contact suivi pour les alertes de proximité
class ContactLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final DateTime lastUpdated;
  final DateTime? lastNotified;

  const ContactLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    required this.lastUpdated,
    this.lastNotified,
  });

  factory ContactLocation.fromJson(Map<String, dynamic> json) {
    return ContactLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      photoUrl: json['photoUrl'] as String?,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      lastNotified: json['lastNotified'] != null 
          ? DateTime.parse(json['lastNotified'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl,
      'lastUpdated': lastUpdated.toIso8601String(),
      'lastNotified': lastNotified?.toIso8601String(),
    };
  }
}

/// Classe de modèle pour un point d'intérêt
class PointOfInterest {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final String? description;
  final String? imageUrl;
  final DateTime? lastNotified;

  const PointOfInterest({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description,
    this.imageUrl,
    this.lastNotified,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      type: json['type'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      lastNotified: json['lastNotified'] != null 
          ? DateTime.parse(json['lastNotified'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'description': description,
      'imageUrl': imageUrl,
      'lastNotified': lastNotified?.toIso8601String(),
    };
  }
}

/// Service pour la gestion de la localisation et des fonctionnalités basées sur la localisation
abstract class LocationService extends ChangeNotifier {
  Position? get currentPosition;
  String? get currentAddress;
  bool get isTrackingLocation;
  bool get permissionGranted;
  bool get proximityAlertsEnabled;
  double get proximityThreshold;
  Map<String, ContactLocation> get trackedContacts;
  Map<String, PointOfInterest> get pointsOfInterest;
  int get proximityRadius;
  set proximityRadius(int value);

  /// Initialisation du service
  Future<void> initialize();

  /// Vérifie et demande les permissions de localisation
  Future<bool> checkLocationPermission();

  /// Obtient la position actuelle de l'utilisateur
  Future<Position?> getCurrentPosition();

  /// Démarre le suivi de la localisation en arrière-plan
  Future<void> startLocationTracking();

  /// Arrête le suivi de la localisation en arrière-plan
  void stopLocationTracking();

  /// Alternative à startLocationTracking avec une API plus simple
  Future<void> startTracking();

  /// Alternative à stopLocationTracking avec une API plus simple
  void stopTracking();

  /// Obtient l'adresse à partir de coordonnées
  Future<String?> getAddressFromCoordinates(double latitude, double longitude);

  /// Ajoute un contact à suivre pour les alertes de proximité
  Future<void> addTrackedContact({
    required String contactId,
    required String contactName,
    required double latitude,
    required double longitude,
    String? photoUrl,
  });

  /// Supprime un contact suivi
  Future<void> removeTrackedContact(String contactId);

  /// Met à jour la position d'un contact
  Future<void> updateContactLocation({
    required String contactId,
    required double latitude,
    required double longitude,
  });

  /// Ajoute un point d'intérêt
  Future<void> addPointOfInterest({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required String type,
    String? description,
    String? imageUrl,
  });

  /// Supprime un point d'intérêt
  Future<void> removePointOfInterest(String id);

  /// Obtient les contacts à proximité
  List<ContactLocation> getNearbyContacts();

  /// Obtient les points d'intérêt à proximité
  List<PointOfInterest> getNearbyPointsOfInterest();

  /// Crée une zone d'alerte
  Future<void> createAlertZone({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
    String? description,
  });

  /// Active/désactive les alertes de proximité
  Future<void> toggleProximityAlerts(bool enabled);

  /// Définit le seuil de proximité en mètres
  Future<void> setProximityThreshold(double threshold);
}

// La classe d'implémentation est maintenant définie dans location_service_io.dart

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