import 'location_service.dart';

/// Implémentation de secours (stub) qui lance des exceptions
/// Cette classe est utilisée lorsqu'aucune implémentation spécifique à la plateforme n'est disponible
class LocationService implements location_service.LocationService {
  @override
  Future<bool> isLocationServiceEnabled() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }

  @override
  Future<location_service.LocationPermission> requestPermission() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }

  @override
  Future<location_service.LocationPermission> checkPermission() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }

  @override
  Future<location_service.LocationPosition> getCurrentPosition() {
    throw UnsupportedError('Aucune implémentation de localisation disponible pour cette plateforme');
  }
}