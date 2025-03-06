import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Implémentation pour les plateformes mobiles/desktop utilisant geolocator
class LocationService implements location_service.LocationService {
  @override
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<location_service.LocationPermission> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<location_service.LocationPermission> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<location_service.LocationPosition> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    return location_service.LocationPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      heading: position.heading,
      speed: position.speed,
      timestamp: position.timestamp,
    );
  }

  // Convertit les constantes de permission du package geolocator 
  // vers notre propre enum LocationPermission
  location_service.LocationPermission _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return location_service.LocationPermission.denied;
      case LocationPermission.deniedForever:
        return location_service.LocationPermission.deniedForever;
      case LocationPermission.whileInUse:
        return location_service.LocationPermission.whileInUse;
      case LocationPermission.always:
        return location_service.LocationPermission.always;
      default:
        return location_service.LocationPermission.denied;
    }
  }
}