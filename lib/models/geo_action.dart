import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Représente une action géolocalisée lancée par un producteur
class GeoAction {
  /// Identifiant unique de l'action
  final String id;
  
  /// Type d'action (notification, promotion, etc.)
  final String type;
  
  /// ID du producteur ayant lancé l'action
  final String producerId;
  
  /// Nom de la zone ciblée
  final String zoneName;
  
  /// Message de l'action
  final String message;
  
  /// Titre de l'offre (optionnel)
  final String? offerTitle;
  
  /// Date et heure de l'action
  final DateTime timestamp;
  
  /// Coordonnées de la zone ciblée
  final LatLng targetLocation;
  
  /// Rayon de la zone ciblée en mètres
  final double radius;
  
  /// Statistiques de l'action
  final ActionStats? stats;
  
  /// Crée une nouvelle action géolocalisée
  GeoAction({
    required this.id,
    required this.type,
    required this.producerId,
    required this.zoneName,
    required this.message,
    this.offerTitle,
    required this.timestamp,
    required this.targetLocation,
    required this.radius,
    this.stats,
  });
  
  /// Crée une action à partir de données JSON
  factory GeoAction.fromJson(Map<String, dynamic> json) {
    return GeoAction(
      id: json['id'] ?? '',
      type: json['type'] ?? 'notification',
      producerId: json['producerId'] ?? '',
      zoneName: json['zoneName'] ?? '',
      message: json['message'] ?? '',
      offerTitle: json['offerTitle'],
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp']) 
        : DateTime.now(),
      targetLocation: json['targetLocation'] != null 
        ? LatLng(
            json['targetLocation']['latitude'] ?? 0.0,
            json['targetLocation']['longitude'] ?? 0.0,
          )
        : const LatLng(0, 0),
      radius: (json['radius'] is num) ? json['radius'].toDouble() : 500.0,
      stats: json['stats'] != null ? ActionStats.fromJson(json['stats']) : null,
    );
  }
  
  /// Convertit l'action en map JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'producerId': producerId,
      'zoneName': zoneName,
      'message': message,
      'offerTitle': offerTitle,
      'timestamp': timestamp.toIso8601String(),
      'targetLocation': {
        'latitude': targetLocation.latitude,
        'longitude': targetLocation.longitude,
      },
      'radius': radius,
      'stats': stats?.toJson(),
    };
  }
  
  /// Crée une copie de cette action avec les modifications spécifiées
  GeoAction copyWith({
    String? id,
    String? type,
    String? producerId,
    String? zoneName,
    String? message,
    String? offerTitle,
    DateTime? timestamp,
    LatLng? targetLocation,
    double? radius,
    ActionStats? stats,
  }) {
    return GeoAction(
      id: id ?? this.id,
      type: type ?? this.type,
      producerId: producerId ?? this.producerId,
      zoneName: zoneName ?? this.zoneName,
      message: message ?? this.message,
      offerTitle: offerTitle ?? this.offerTitle,
      timestamp: timestamp ?? this.timestamp,
      targetLocation: targetLocation ?? this.targetLocation,
      radius: radius ?? this.radius,
      stats: stats ?? this.stats,
    );
  }
  
  /// Retourne une couleur associée au type d'action
  Color get color {
    switch (type) {
      case 'promotion':
        return Colors.orange;
      case 'event':
        return Colors.purple;
      case 'notification':
      default:
        return Colors.blue;
    }
  }
  
  /// Retourne une icône associée au type d'action
  IconData get icon {
    switch (type) {
      case 'promotion':
        return Icons.local_offer;
      case 'event':
        return Icons.event;
      case 'notification':
      default:
        return Icons.notifications;
    }
  }
}

/// Représente les statistiques d'une action
class ActionStats {
  /// Nombre d'utilisateurs ciblés
  final int sent;
  
  /// Nombre d'utilisateurs ayant vu l'action
  final int viewed;
  
  /// Nombre d'utilisateurs ayant interagi avec l'action
  final int engaged;
  
  /// Crée de nouvelles statistiques
  ActionStats({
    required this.sent,
    required this.viewed,
    required this.engaged,
  });
  
  /// Crée des statistiques à partir de données JSON
  factory ActionStats.fromJson(Map<String, dynamic> json) {
    return ActionStats(
      sent: json['sent'] ?? 0,
      viewed: json['viewed'] ?? 0,
      engaged: json['engaged'] ?? 0,
    );
  }
  
  /// Convertit les statistiques en map JSON
  Map<String, dynamic> toJson() {
    return {
      'sent': sent,
      'viewed': viewed,
      'engaged': engaged,
    };
  }
  
  /// Calcule le taux d'ouverture (pourcentage de vues)
  double get openRate => sent > 0 ? (viewed / sent) * 100 : 0;
  
  /// Calcule le taux d'engagement (pourcentage d'interactions parmi les vues)
  double get engagementRate => viewed > 0 ? (engaged / viewed) * 100 : 0;
  
  /// Calcule le taux de conversion global (pourcentage d'interactions parmi les envois)
  double get conversionRate => sent > 0 ? (engaged / sent) * 100 : 0;
}

/// Représente une action à créer
class GeoActionRequest {
  /// ID du producteur
  final String producerId;
  
  /// ID de la zone ciblée
  final String zoneId;
  
  /// Message de l'action
  final String message;
  
  /// Titre de l'offre (optionnel)
  final String? offerTitle;
  
  /// Rayon de la zone ciblée en mètres
  final double radius;
  
  /// Crée une nouvelle requête d'action
  GeoActionRequest({
    required this.producerId,
    required this.zoneId,
    required this.message,
    this.offerTitle,
    this.radius = 500,
  });
  
  /// Convertit la requête en map JSON
  Map<String, dynamic> toJson() {
    return {
      'producerId': producerId,
      'zoneId': zoneId,
      'message': message,
      'offerTitle': offerTitle,
      'radius': radius,
    };
  }
} 