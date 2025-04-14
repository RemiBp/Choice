import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Modèle représentant un producteur sur la carte
class MapProducer {
  final String id;
  final String name;
  final String address;
  final String? description;
  final String? category;
  final String? imageUrl;
  final LatLng location;
  final double? rating;
  final Map<String, dynamic>? additionalData;
  final String type; // Type de producteur (restaurant, leisure, wellness)
  final Color color; // Couleur associée au type de producteur

  MapProducer({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    this.category,
    this.imageUrl,
    required this.location,
    this.rating,
    this.additionalData,
    required this.type,
    required this.color,
  });

  /// Crée un MapProducer à partir d'un JSON
  factory MapProducer.fromJson(Map<String, dynamic> json) {
    // Obtenir la localisation
    LatLng location;
    if (json['location'] != null && json['location'] is Map) {
      location = LatLng(
        json['location']['lat'] ?? 0.0, 
        json['location']['lng'] ?? 0.0
      );
    } else if (json['localisation'] != null && json['localisation'] is Map) {
      if (json['localisation']['coordinates'] != null && json['localisation']['coordinates'] is List) {
        // Format GeoJSON : [longitude, latitude]
        var coords = json['localisation']['coordinates'] as List;
        if (coords.length >= 2) {
          location = LatLng(
            coords[1].toDouble(), // latitude
            coords[0].toDouble()  // longitude
          );
        } else {
          location = const LatLng(0, 0);
        }
      } else {
        location = const LatLng(0, 0);
      }
    } else if (json['gps_coordinates'] != null && json['gps_coordinates'] is Map) {
      if (json['gps_coordinates']['coordinates'] != null && json['gps_coordinates']['coordinates'] is List) {
        var coords = json['gps_coordinates']['coordinates'] as List;
        if (coords.length >= 2) {
          location = LatLng(
            coords[1].toDouble(), // latitude
            coords[0].toDouble()  // longitude
          );
        } else {
          location = const LatLng(0, 0);
        }
      } else {
        location = const LatLng(0, 0);
      }
    } else {
      location = const LatLng(0, 0);
    }

    // Déterminer le type et la couleur associée
    String type = json['type'] ?? 'default';
    
    if (json['category'] != null && json['category'].toString().toLowerCase().contains('restaurant')) {
      type = 'restaurant';
    } else if (json['primary_category'] != null && json['primary_category'].toString().toLowerCase().contains('restaurant')) {
      type = 'restaurant';
    } else if (type.toLowerCase().contains('leisure') || 
        (json['category'] != null && json['category'].toString().toLowerCase().contains('loisir'))) {
      type = 'leisure';
    } else if (type.toLowerCase().contains('wellness') || 
        (json['category'] != null && json['category'].toString().toLowerCase().contains('bien-être'))) {
      type = 'wellness';
    }
    
    // Attribuer la couleur selon le projet context
    Color color;
    switch (type) {
      case 'restaurant':
        color = const Color(0xFFFF9800); // Orange pour les restaurants
        break;
      case 'leisure':
        color = const Color(0xFF9C27B0); // Violet pour les loisirs
        break;
      case 'wellness':
        color = const Color(0xFF4CAF50); // Vert pour le bien-être
        break;
      default:
        color = const Color(0xFF2196F3); // Bleu par défaut
        break;
    }

    return MapProducer(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['titre'] ?? json['intitulé'] ?? 'Sans nom',
      address: json['address'] ?? json['adresse'] ?? 'Adresse non disponible',
      description: json['description'] ?? '',
      category: json['category'] ?? json['catégorie'] ?? json['primary_category'] ?? '',
      imageUrl: json['image_url'] ?? json['photo'] ?? json['photos']?[0] ?? null,
      location: location,
      rating: json['rating']?.toDouble() ?? json['note']?.toDouble() ?? 0.0,
      additionalData: json,
      type: type,
      color: color,
    );
  }

  /// Convertit le MapProducer en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'rating': rating,
      'type': type,
    };
  }
  
  /// Crée un BitmapDescriptor personnalisé pour le marker selon le type de producteur
  Future<BitmapDescriptor> getMarkerIcon() async {
    // Par défaut, utilisez des couleurs simples selon le type
    switch (type) {
      case 'restaurant':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'leisure':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      case 'wellness':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }
} 