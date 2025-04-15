import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_data_sender_service.dart';
import '../utils/location_utils.dart';
import 'package:geolocator/geolocator.dart';

/// A simple service to periodically send location updates.
/// NOTE: This is a basic implementation for demonstration within the 'backup' app.
/// A real application would need a more robust background location solution.
class LocationTrackingService {
  Timer? _locationTimer;
  final Duration _updateInterval = const Duration(minutes: 5); // Send location every 5 minutes
  String? _currentUserId;

  bool _isSending = false; // Flag to prevent concurrent sends

  /// Starts the periodic location sending.
  void startSendingLocation(String userId) {
    print('📍 LocationTrackingService: Starting for user $userId');
    _currentUserId = userId;
    // Cancel any existing timer
    _locationTimer?.cancel();
    // Send immediately first time
    _sendLocationUpdate(); 
    // Start periodic timer
    _locationTimer = Timer.periodic(_updateInterval, (_) => _sendLocationUpdate());
  }

  /// Stops the periodic location sending.
  void stopSendingLocation() {
    print('📍 LocationTrackingService: Stopping');
    _locationTimer?.cancel();
    _locationTimer = null;
    _currentUserId = null;
  }

  Future<void> _sendLocationUpdate() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      print('📍 LocationTrackingService: Cannot send location, user ID is null or empty.');
      return;
    }
    if (_isSending) {
      print('📍 LocationTrackingService: Already sending location, skipping this interval.');
      return; 
    }

    _isSending = true;
    print('📍 LocationTrackingService: Attempting to send location update for $_currentUserId');

    try {
      // Get current location
      final LatLng? currentLocation = await LocationUtils.getCurrentLocation();

      double? accuracyValue;
      if (currentLocation != null) {
          final LocationAccuracyStatus? accuracyStatus = await Geolocator.getLocationAccuracy();
          switch (accuracyStatus) {
             case LocationAccuracyStatus.precise:
               accuracyValue = 5.0; // Example: Represent precise with a low number (e.g., 5 meters)
               break;
             case LocationAccuracyStatus.reduced:
                accuracyValue = 500.0; // Example: Represent reduced with a high number (e.g., 500 meters)
                break;
             case null: // Handle case where status couldn't be determined
                accuracyValue = null;
                break;
             default:
                accuracyValue = null; // Unknown status
          }
      } else {
          accuracyValue = null;
      }

      if (currentLocation != null) {
        // Call the AppDataSenderService (fire and forget)
        AppDataSenderService.sendLocationUpdate(
          _currentUserId!,
          currentLocation,
          accuracyValue, // Send the converted double value
          // Add other fields like speed, activity if available from location plugin
        );
      } else {
        print('📍 LocationTrackingService: Could not get current location.');
      }
    } catch (e) {
       print('📍 LocationTrackingService: Error during location update: $e');
    } finally {
       _isSending = false;
    }
  }

  void dispose() {
    stopSendingLocation();
  }
} 