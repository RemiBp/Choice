import 'package:flutter/foundation.dart';

@immutable
class PostLocation {
  final String name;
  final String? address;
  final List<double> coordinates;

  PostLocation({
    required this.name,
    this.address,
    required this.coordinates,
  });

  // Safe constructor from potentially problematic JSON
  factory PostLocation.fromJson(dynamic jsonData) {
    // Handle case where location is a string instead of a Map
    if (jsonData is String) {
      return PostLocation(
        name: jsonData,
        address: null,
        coordinates: [],
      );
    }
    
    // If not a map or string, return default
    if (jsonData == null || jsonData is! Map<String, dynamic>) {
      return PostLocation(
        name: 'Localisation inconnue',
        address: null,
        coordinates: [],
      );
    }
    
    // Now we can safely use as Map
    Map<String, dynamic> json = jsonData;
    List<double> safeCoordinates = [];
    
    try {
      final rawCoordinates = json['coordinates'];
      
      // Validate coordinates exist and are a list
      if (rawCoordinates != null && rawCoordinates is List && rawCoordinates.isNotEmpty) {
        // Ensure all values are valid numbers and convert to double
        for (var i = 0; i < rawCoordinates.length; i++) {
          if (rawCoordinates[i] != null && rawCoordinates[i] is num) {
            double coord = (rawCoordinates[i] as num).toDouble();
            
            // Validate latitude/longitude ranges if this is a standard geo coordinate pair
            if (i == 0 && coord >= -180 && coord <= 180) {
              safeCoordinates.add(coord); // Longitude
            } else if (i == 1 && coord >= -90 && coord <= 90) {
              safeCoordinates.add(coord); // Latitude
            } else if (i >= 2) {
              // Additional coordinates (altitude, etc) if present
              safeCoordinates.add(coord);
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error parsing coordinates: $e');
      // Return empty coordinates list on error
    }
    
    return PostLocation(
      name: json['name'] ?? 'Localisation inconnue',
      address: json['address'],
      coordinates: safeCoordinates,
    );
  }
} 