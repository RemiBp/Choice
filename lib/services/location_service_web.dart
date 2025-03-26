import 'dart:async';
import 'dart:html' as html;
import 'location_service.dart' as location_service;

/// Implémentation pour le web utilisant l'API HTML5 Geolocation
class LocationService implements location_service.LocationService {
  @override
  Future<bool> isLocationServiceEnabled() async {
    // Sur le web, nous ne pouvons pas vraiment vérifier si le service est activé
    // avant de demander la permission
    return true;
  }

  @override
  Future<location_service.LocationPermission> requestPermission() async {
    try {
      // Demander la permission en essayant d'obtenir la position
      final completer = Completer<location_service.LocationPermission>();
      html.window.navigator.geolocation.getCurrentPosition(
        (position) {
          completer.complete(location_service.LocationPermission.whileInUse);
        },
        (error) {
          if (error.code == 1) { // PERMISSION_DENIED
            completer.complete(location_service.LocationPermission.denied);
          } else {
            completer.complete(location_service.LocationPermission.denied);
          }
        },
      );
      return await completer.future;
    } catch (e) {
      return location_service.LocationPermission.denied;
    }
  }

  @override
  Future<location_service.LocationPermission> checkPermission() async {
    // L'API HTML5 Geolocation ne permet pas de vérifier la permission sans l'utiliser
    // Nous retournons donc une valeur par défaut
    return location_service.LocationPermission.whileInUse;
  }

  @override
  Future<location_service.LocationPosition> getCurrentPosition() async {
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
  }
}