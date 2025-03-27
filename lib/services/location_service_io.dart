import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'dart:math' as math;
import 'location_service.dart' as location_service;

/// Implémentation native (Android/iOS) du service de localisation
class LocationService implements location_service.LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  final Location _location = Location();

  @override
  Future<bool> isLocationServiceEnabled() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
    }
    return serviceEnabled;
  }

  @override
  Future<bool> checkAndRequestPermission() async {
    PermissionStatus permission = await _location.hasPermission();
    
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    
    return permission == PermissionStatus.granted || 
           permission == PermissionStatus.grantedLimited;
  }

  @override
  Future<location_service.LocationPosition?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      bool permissionGranted = await checkAndRequestPermission();
      if (!permissionGranted) {
        return null;
      }

      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 10000,
        distanceFilter: 10,
      );

      LocationData locationData = await _location.getLocation();
      
      if (locationData.latitude != null && locationData.longitude != null) {
        return location_service.LocationPosition(
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

  @override
  Stream<location_service.LocationPosition> getPositionStream() {
    return _location.onLocationChanged.map((locationData) {
      return location_service.LocationPosition(
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