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
  
  /// Recommendations for the hotspot
  final List<Map<String, dynamic>> recommendations;
  
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
    this.recommendations = const [],
  });
  
  /// Creates a LatLng object for Google Maps
  LatLng get latLng => LatLng(latitude, longitude);
  
  /// Creates a UserHotspot from JSON data
  factory UserHotspot.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse doubles
    double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper to safely parse distribution maps
    Map<String, double> _parseDistribution(dynamic map) {
      if (map is Map) {
        return map.map((key, value) => MapEntry(key.toString(), _parseDouble(value)));
      }
      return {};
    }

    // Helper to safely parse recommendations list
    List<Map<String, dynamic>> _parseRecommendations(dynamic list) {
      if (list is List) {
        return List<Map<String, dynamic>>.from(list.whereType<Map<String, dynamic>>());
      }
      return [];
    }

    return UserHotspot(
      id: json['id'] as String? ?? 'unknown_id',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      zoneName: json['zoneName'] as String? ?? 'Zone Inconnue',
      intensity: _parseDouble(json['intensity'], 0.5), // Default intensity if missing
      visitorCount: json['visitorCount'] as int? ?? 0,
      weight: (json['weight'] is num) ? json['weight'].toDouble() : null,
      address: json['address'],
      timeDistribution: _parseDistribution(json['timeDistribution']),
      dayDistribution: _parseDistribution(json['dayDistribution']),
      recommendations: _parseRecommendations(json['recommendations']), // <-- Parse recommendations
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
      'recommendations': recommendations,
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