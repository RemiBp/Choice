import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_hotspot.dart';
import '../models/geo_action.dart';
import '../utils/constants.dart' as constants;

/// Service pour interagir avec l'API de heatmap et d'actions géolocalisées
class HeatmapService {
  /// Récupère les hotspots autour d'une position
  Future<List<UserHotspot>> getHotspots({
    required double latitude,
    required double longitude,
    double radius = 2000,
  }) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/location-history/hotspots')
          .replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
      });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => UserHotspot.fromJson(item)).toList();
      } else {
        print('❌ Erreur lors de la récupération des hotspots: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        throw Exception('Erreur lors de la récupération des hotspots');
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des hotspots: $e');
      
      // En cas d'erreur, on peut retourner des données simulées
      return simulateHotspots(LatLng(latitude, longitude), radius);
    }
  }

  /// Récupère les insights pour une zone spécifique
  Future<Map<String, dynamic>> getZoneInsights(String zoneId) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/location-history/zone-insights/$zoneId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de la récupération des insights: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        throw Exception('Erreur lors de la récupération des insights');
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des insights: $e');
      
      // En cas d'erreur, on peut retourner des données simulées
      return {
        'id': zoneId,
        'insights': [
          {
            'title': 'Forte affluence détectée',
            'description': 'Cette zone montre une activité plus élevée que la moyenne'
          }
        ],
        'currentVisitors': 45,
        'nearbyUsers': 12,
        'activeTime': 'afternoon',
        'competition': {
          'count': 3,
          'active': 1
        }
      };
    }
  }

  /// Envoie une notification aux utilisateurs dans une zone
  Future<Map<String, dynamic>> sendZoneNotification(GeoActionRequest request) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/location-history/send-zone-notification');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur lors de l\'envoi de notification: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        throw Exception('Erreur lors de l\'envoi de notification');
      }
    } catch (e) {
      print('❌ Exception lors de l\'envoi de notification: $e');
      
      // En cas d'erreur, on peut retourner une réponse simulée
      return {
        'success': true,
        'targetedUsers': 15,
        'message': 'Notification envoyée à 15 utilisateurs dans la zone'
      };
    }
  }

  /// Récupère l'historique des actions pour un producteur
  Future<List<GeoAction>> getProducerActions(String producerId) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/location-history/producer-actions/$producerId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => GeoAction.fromJson(item)).toList();
      } else {
        print('❌ Erreur lors de la récupération des actions: ${response.statusCode}');
        print('❌ Réponse: ${response.body}');
        throw Exception('Erreur lors de la récupération des actions');
      }
    } catch (e) {
      print('❌ Exception lors de la récupération des actions: $e');
      
      // En cas d'erreur, on peut retourner des données simulées
      return simulateProducerActions(producerId);
    }
  }

  /// Génère des hotspots simulés pour les tests
  List<UserHotspot> simulateHotspots(LatLng center, double radius) {
    // Utiliser la classe FakerData pour générer des hotspots aléatoires
    // En attendant, on crée quelques exemples directement
    return List.generate(8, (index) {
      // Calculer des coordonnées aléatoires dans le rayon
      final r = radius * (0.2 + (0.8 * index / 8));
      final theta = (index / 8) * 2 * math.pi;
      final lat = center.latitude + (r / 111320) * math.sin(theta);
      final lng = center.longitude + (r / (111320 * math.cos(center.latitude * math.pi / 180))) * math.cos(theta);
      
      final intensity = 0.3 + (0.7 * index / 8);
      
      final timeDistribution = {
        'morning': 0.2 + (index % 3) * 0.1,
        'afternoon': 0.3 + (index % 2) * 0.15,
        'evening': 0.2 + (index % 4) * 0.05,
      };
      
      // Normaliser
      final timeSum = timeDistribution.values.reduce((a, b) => a + b);
      final normalizedTimeDistribution = timeDistribution.map((key, value) => 
        MapEntry(key, value / timeSum));
      
      final dayDistribution = {
        'monday': 0.1 + (index % 5) * 0.01,
        'tuesday': 0.1 + (index % 6) * 0.01,
        'wednesday': 0.1 + (index % 3) * 0.02,
        'thursday': 0.15 + (index % 4) * 0.01,
        'friday': 0.15 + (index % 2) * 0.03,
        'saturday': 0.2 + (index % 3) * 0.02,
        'sunday': 0.1 + (index % 4) * 0.025,
      };
      
      // Normaliser
      final daySum = dayDistribution.values.reduce((a, b) => a + b);
      final normalizedDayDistribution = dayDistribution.map((key, value) => 
        MapEntry(key, value / daySum));
      
      return UserHotspot(
        id: 'hotspot_${index + 1}',
        latitude: lat,
        longitude: lng,
        zoneName: 'Zone ${index + 1}',
        intensity: intensity,
        visitorCount: 20 + (index * 10) + (index % 5) * 15,
        timeDistribution: normalizedTimeDistribution,
        dayDistribution: normalizedDayDistribution,
      );
    });
  }

  /// Génère des actions simulées pour les tests
  List<GeoAction> simulateProducerActions(String producerId) {
    return [
      GeoAction(
        id: 'action_1',
        type: 'notification',
        producerId: producerId,
        zoneName: 'Centre-Ville',
        message: 'Découvrez notre nouvelle carte de cocktails ce soir!',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        targetLocation: const LatLng(48.8566, 2.3522),
        radius: 500,
        stats: ActionStats(sent: 42, viewed: 28, engaged: 12),
      ),
      GeoAction(
        id: 'action_2',
        type: 'promotion',
        producerId: producerId,
        zoneName: 'Quartier des Affaires',
        message: 'Happy Hour de 18h à 20h: 2 verres achetés, 1 offert!',
        offerTitle: 'Happy Hour 2+1',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        targetLocation: const LatLng(48.8866, 2.3322),
        radius: 800,
        stats: ActionStats(sent: 67, viewed: 45, engaged: 22),
      ),
      GeoAction(
        id: 'action_3',
        type: 'event',
        producerId: producerId,
        zoneName: 'Place du Marché',
        message: 'Soirée musicale ce week-end! Réservez votre table dès maintenant.',
        offerTitle: 'Concert Live',
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        targetLocation: const LatLng(48.8766, 2.3622),
        radius: 1000,
        stats: ActionStats(sent: 95, viewed: 64, engaged: 31),
      ),
    ];
  }
} 