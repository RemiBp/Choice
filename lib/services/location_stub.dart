import 'location_service.dart' as location_service;

/// Implémentation de secours (stub) qui lance des exceptions
/// Cette classe est utilisée lorsqu'aucune implémentation spécifique à la plateforme n'est disponible
class LocationService implements location_service.LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  @override
  Future<bool> isLocationServiceEnabled() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }

  @override
  Future<bool> checkAndRequestPermission() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }

  @override
  Future<location_service.LocationPosition?> getCurrentPosition() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }

  @override
  Stream<location_service.LocationPosition> getPositionStream() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }

  @override
  double calculateDistance(
    double startLatitude, 
    double startLongitude, 
    double endLatitude, 
    double endLongitude
  ) {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }
}