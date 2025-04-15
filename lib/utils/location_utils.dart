import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

/// Utility class for location-related functions.
class LocationUtils {

  /// Attempts to get the current device location.
  /// 
  /// Handles permissions and returns LatLng or null if unable to get location.
  static Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('LocationUtils: Location services are disabled.');
      // Optionally prompt the user to enable location services.
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('LocationUtils: Location permissions are denied.');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      print('LocationUtils: Location permissions are permanently denied, we cannot request permissions.');
      return null;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Balance accuracy and battery
        timeLimit: const Duration(seconds: 10), // Timeout for getting location
      );
      print('LocationUtils: Current location obtained: (${position.latitude}, ${position.longitude})');
      return LatLng(position.latitude, position.longitude);
    } on LocationServiceDisabledException {
       print('LocationUtils: Location Service Disabled Exception caught.');
       return null;
    } on TimeoutException {
       print('LocationUtils: Timeout getting location.');
       return null;
    } catch (e) {
      print('LocationUtils: Error getting current location: $e');
      return null;
    }
  }

  /// Default location (e.g., Paris) if current location cannot be obtained.
  static LatLng defaultLocation() {
    return const LatLng(48.8566, 2.3522);
  }
} 