import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a location hotspot with user activity data
class UserHotspot {
  /// Unique identifier for the hotspot
  final String id;
  
  /// Geographical latitude
  final double latitude;
  
  /// Geographical longitude
  final double longitude;
  
  /// Name of the zone or area
  final String zoneName;
  
  /// Intensity of activity (0.0 to 1.0)
  final double intensity;
  
  /// Number of unique visitors in the time period
  final int visitorCount;
  
  /// Weight for heatmap visualization (0.0 to 1.0)
  final double? weight;
  
  /// Address or location description
  final String? address;
  
  /// Distribution of visits by time of day
  /// Keys are 'morning', 'afternoon', 'evening'
  /// Values are percentages (0.0 to 1.0)
  final Map<String, double> timeDistribution;
  
  /// Distribution of visits by day of week
  /// Keys are 'monday', 'tuesday', 'wednesday', etc.
  /// Values are percentages (0.0 to 1.0)
  final Map<String, double> dayDistribution;
  
  /// Creates a new hotspot
  UserHotspot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.zoneName,
    required this.intensity,
    required this.visitorCount,
    this.weight,
    this.address,
    required this.timeDistribution,
    required this.dayDistribution,
  });
  
  /// Creates a LatLng object for Google Maps
  LatLng get latLng => LatLng(latitude, longitude);
  
  /// Creates a UserHotspot from JSON data
  factory UserHotspot.fromJson(Map<String, dynamic> json) {
    // Parse time distribution
    Map<String, double> timeDistribution = {};
    if (json['timeDistribution'] != null) {
      final timeDist = json['timeDistribution'] as Map<String, dynamic>;
      timeDist.forEach((key, value) {
        timeDistribution[key] = (value is num) ? value.toDouble() : 0.0;
      });
    } else if (json['time_distribution'] != null) {
      final timeDist = json['time_distribution'] as Map<String, dynamic>;
      timeDist.forEach((key, value) {
        timeDistribution[key] = (value is num) ? value.toDouble() : 0.0;
      });
    } else {
      // Default time distribution if not provided
      timeDistribution = {
        'morning': 0.33,
        'afternoon': 0.33,
        'evening': 0.34,
        'night': 0.0,
      };
    }
    
    // Parse day distribution
    Map<String, double> dayDistribution = {};
    if (json['dayDistribution'] != null) {
      final dayDist = json['dayDistribution'] as Map<String, dynamic>;
      dayDist.forEach((key, value) {
        dayDistribution[key] = (value is num) ? value.toDouble() : 0.0;
      });
    } else if (json['day_distribution'] != null) {
      final dayDist = json['day_distribution'] as Map<String, dynamic>;
      dayDist.forEach((key, value) {
        dayDistribution[key] = (value is num) ? value.toDouble() : 0.0;
      });
    } else {
      // Default day distribution if not provided
      dayDistribution = {
        'monday': 0.14,
        'tuesday': 0.14,
        'wednesday': 0.14,
        'thursday': 0.14,
        'friday': 0.14,
        'saturday': 0.15,
        'sunday': 0.15,
      };
    }
    
    return UserHotspot(
      id: json['id'] ?? '',
      latitude: (json['latitude'] is num) ? json['latitude'].toDouble() : 0.0,
      longitude: (json['longitude'] is num) ? json['longitude'].toDouble() : 0.0,
      zoneName: json['zoneName'] ?? json['zone_name'] ?? 'Zone sans nom',
      intensity: (json['intensity'] is num) ? json['intensity'].toDouble() : 0.0,
      visitorCount: (json['visitorCount'] is num) ? json['visitorCount'] : 
                   (json['visitor_count'] is num) ? json['visitor_count'] : 0,
      weight: (json['weight'] is num) ? json['weight'].toDouble() : null,
      address: json['address'],
      timeDistribution: timeDistribution,
      dayDistribution: dayDistribution,
    );
  }
  
  /// Converts the hotspot to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude, 
      'zoneName': zoneName,
      'intensity': intensity,
      'visitorCount': visitorCount,
      'weight': weight,
      'address': address,
      'timeDistribution': timeDistribution,
      'dayDistribution': dayDistribution,
    };
  }
}

/// A weighted latitude/longitude point for heatmap generation
class WeightedLatLng {
  /// The geographical coordinates
  final LatLng point;
  
  /// The weight or intensity (0.0 to 1.0)
  final double weight;
  
  /// Creates a new weighted point
  const WeightedLatLng(this.point, {this.weight = 1.0});
}