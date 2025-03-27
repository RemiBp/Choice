import 'dart:async';
import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'location_service.dart' as location_service;

/// Implémentation web du service de localisation
class LocationService implements location_service.LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  final StreamController<location_service.LocationPosition> _locationUpdates = 
      StreamController<location_service.LocationPosition>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async {
    // Sur le web, on ne peut pas vraiment vérifier si le service est activé
    // avant de demander la permission
    return true;
  }

  @override
  Future<bool> checkAndRequestPermission() async {
    // Sur le web, on ne peut pas vérifier la permission sans la demander
    // On retourne true car la vérification sera faite lors de l'appel à getCurrentPosition
    return true;
  }

  @override
  Future<location_service.LocationPosition?> getCurrentPosition() async {
    try {
      final completer = Completer<location_service.LocationPosition>();
      
      html.window.navigator.geolocation.getCurrentPosition(
        (position) {
          completer.complete(
            location_service.LocationPosition(
              latitude: position.coords!.latitude!,
              longitude: position.coords!.longitude!,
              accuracy: position.coords!.accuracy,
              altitude: position.coords!.altitude,
              heading: position.coords!.heading,
              speed: position.coords!.speed,
              timestamp: DateTime.now(),
            ),
          );
        },
        (error) {
          completer.completeError('Erreur de géolocalisation: ${error.message}');
        },
        {'enableHighAccuracy': true, 'timeout': 10000, 'maximumAge': 0},
      );
      
      return await completer.future;
    } catch (e) {
      print('❌ Erreur de géolocalisation web: $e');
      return null;
    }
  }

  @override
  Stream<location_service.LocationPosition> getPositionStream() {
    try {
      final int watchId = html.window.navigator.geolocation.watchPosition(
        (position) {
          _locationUpdates.add(
            location_service.LocationPosition(
              latitude: position.coords!.latitude!,
              longitude: position.coords!.longitude!,
              accuracy: position.coords!.accuracy,
              altitude: position.coords!.altitude,
              heading: position.coords!.heading,
              speed: position.coords!.speed,
              timestamp: DateTime.now(),
            ),
          );
        },
        (error) {
          print('❌ Erreur de suivi de position: ${error.message}');
        },
        {'enableHighAccuracy': true, 'timeout': 10000, 'maximumAge': 0},
      );
      
      // Nettoyer le watch quand le stream est fermé
      _locationUpdates.onCancel = () {
        html.window.navigator.geolocation.clearWatch(watchId);
      };
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du suivi de position: $e');
    }
    
    return _locationUpdates.stream;
  }

  @override
  double calculateDistance(
    double startLatitude, 
    double startLongitude, 
    double endLatitude, 
    double endLongitude
  ) {
    const int earthRadius = 6371000; // en mètres
    
    double lat1Rad = startLatitude * (math.pi / 180);
    double lat2Rad = endLatitude * (math.pi / 180);
    double lon1Rad = startLongitude * (math.pi / 180);
    double lon2Rad = endLongitude * (math.pi / 180);
    
    double latDiff = lat2Rad - lat1Rad;
    double lonDiff = lon2Rad - lon1Rad;
    
    double a = math.sin(latDiff / 2) * math.sin(latDiff / 2) +
               math.cos(lat1Rad) * math.cos(lat2Rad) *
               math.sin(lonDiff / 2) * math.sin(lonDiff / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    
    return earthRadius * c;
  }
}