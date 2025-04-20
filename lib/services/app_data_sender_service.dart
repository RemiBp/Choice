// Placeholder Service: Represents the logic in the main user app
// for sending location and activity data to the backend.
// IMPLEMENT THE ACTUAL LOGIC IN YOUR MAIN USER APPLICATION.

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart' as constants;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng; // Or your location model

class AppDataSenderService {

  // --- Location History --- 

  /// Placeholder: Called periodically by the user app to send location.
  static Future<void> sendLocationUpdate(String userId, LatLng location, double? accuracy) async {
    print('⚠️ AppDataSenderService.sendLocationUpdate() called - Placeholder implementation!');
    print('   User: $userId, Location: $location, Accuracy: $accuracy');
    
    // Construct GeoJSON
    final geoJsonLocation = {
      'type': 'Point',
      'coordinates': [location.longitude, location.latitude] // [lon, lat]
    };

    final url = Uri.parse('${constants.getBaseUrl()}/api/ingest/location-history');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
          'location': geoJsonLocation,
          'accuracy': accuracy,
          // Add other relevant fields like speed, activity if available
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        print('   ✅ Location update sent successfully.');
      } else {
        print('   ❌ Failed to send location update: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Exception sending location update: $e');
    }
  }

  // --- User Activity --- 

  /// Placeholder: Called by the user app when a relevant action occurs.
  static Future<void> sendActivityLog({
    required String userId,
    required String action, // e.g., 'search', 'view'
    required LatLng location,
    String? query,          // For search actions
    String? producerId,     // ID of viewed/clicked producer
    String? producerType,   // Type of producer
    Map<String, dynamic>? metadata, // Other details
  }) async {
    print('⚠️ AppDataSenderService.sendActivityLog() called - Placeholder implementation!');
    print('   User: $userId, Action: $action, Query: $query, Producer: $producerId');

    final geoJsonLocation = {
      'type': 'Point',
      'coordinates': [location.longitude, location.latitude]
    };

    final url = Uri.parse('${constants.getBaseUrl()}/api/ingest/user-activity');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'action': action,
          'timestamp': DateTime.now().toIso8601String(),
          'location': geoJsonLocation,
          if (query != null) 'query': query,
          if (producerId != null) 'producerId': producerId,
          if (producerType != null) 'producerType': producerType,
          if (metadata != null) 'metadata': metadata,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        print('   ✅ Activity log sent successfully.');
      } else {
        print('   ❌ Failed to send activity log: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Exception sending activity log: $e');
    }
  }
} 