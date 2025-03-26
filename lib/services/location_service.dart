// Location service abstraction with conditional export pattern
// similar to utils.dart

export 'location_stub.dart'
  if (dart.library.io) 'location_service_io.dart'
  if (dart.library.html) 'location_service_web.dart';

/// Classe pour représenter une position géographique
class LocationPosition {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime? timestamp;

  LocationPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    this.timestamp,
  });
}

/// Service abstrait pour la géolocalisation
abstract class LocationService {
  /// Vérifie si les services de localisation sont activés
  Future<bool> isLocationServiceEnabled();

  /// Demande l'autorisation de localisation
  Future<LocationPermission> requestPermission();

  /// Vérifie l'état actuel de l'autorisation
  Future<LocationPermission> checkPermission();

  /// Obtient la position actuelle
  Future<LocationPosition> getCurrentPosition();
}

/// Énumération des états de permission pour la localisation
enum LocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
}