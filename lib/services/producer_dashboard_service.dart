import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producer_type.dart';
import '../utils/constants.dart' as constants;

/// Service pour le dashboard des producteurs qui gère les données personnalisées
/// selon le type de producteur (restaurant, loisir, bien-être)
class ProducerDashboardService {
  static final ProducerDashboardService _instance = ProducerDashboardService._internal();
  factory ProducerDashboardService() => _instance;
  ProducerDashboardService._internal();

  String getBaseUrl() {
    return constants.getBaseUrl();
  }

  /// Récupère les statistiques du tableau de bord adaptées au type de producteur
  Future<Map<String, dynamic>> getDashboardStats(
    String producerId, 
    ProducerType producerType,
    {String period = '30'}
  ) async {
    try {
      // URL personnalisée selon le type de producteur
      final endpoint = _getStatsEndpoint(producerType);
      final url = Uri.parse('${getBaseUrl()}/api/$endpoint/$producerId?period=$period');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Erreur API: ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des statistiques (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception: $e');
      // En cas d'erreur, renvoyer des données mockées pour démonstration
      return _getMockDashboardStats(producerId, producerType);
    }
  }

  /// Récupère les KPIs spécifiques au type de producteur
  Future<List<Map<String, dynamic>>> getTypeSpecificKPIs(
    String producerId, 
    ProducerType producerType
  ) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/${producerType.apiPath}/$producerId/kpis');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur de récupération des KPIs: $e');
      // En cas d'erreur, renvoyer des données mockées
      return _getMockKPIs(producerType);
    }
  }

  /// Obtient des recommandations personnalisées selon le type de producteur
  Future<List<Map<String, dynamic>>> getTypeSpecificRecommendations(
    String producerId, 
    ProducerType producerType
  ) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/${producerType.apiPath}/$producerId/recommendations');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur de récupération des recommandations: $e');
      // En cas d'erreur, renvoyer des données mockées
      return _getMockRecommendations(producerType);
    }
  }

  /// Récupère les données de concurrence spécifiques au type
  Future<List<Map<String, dynamic>>> getTypeSpecificCompetitors(
    String producerId, 
    ProducerType producerType,
    {int limit = 5}
  ) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/${producerType.apiPath}/$producerId/competitors?limit=$limit');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur de récupération des concurrents: $e');
      // En cas d'erreur, renvoyer des données mockées
      return _getMockCompetitors(producerType);
    }
  }

  /// Endpoint personnalisé selon le type de producteur
  String _getStatsEndpoint(ProducerType type) {
    switch (type) {
      case ProducerType.restaurant:
        return 'restaurant-analytics';
      case ProducerType.leisureProducer:
        return 'leisure-analytics';
      case ProducerType.wellnessProducer:
        return 'wellness-analytics';
      default:
        return 'growth-analytics';
    }
  }

  /// Données mockées pour le dashboard, personnalisées selon le type
  Map<String, dynamic> _getMockDashboardStats(String producerId, ProducerType type) {
    final Map<String, dynamic> baseStats = {
      "period": 30,
      "views": {
        "total": 1250,
        "previous": 980,
        "growth": 27.6
      },
      "engagement": {
        "total": 342,
        "previous": 256,
        "growth": 33.6
      },
      "followers": {
        "total": 125,
        "new": 18,
        "growth": 16.8
      },
      "conversion": {
        "total": 42,
        "previous": 35,
        "growth": 20.0
      }
    };
    
    // Ajouter des métriques spécifiques selon le type
    switch (type) {
      case ProducerType.restaurant:
        baseStats["specific_metrics"] = {
          "reservations": {
            "total": 75,
            "previous": 62,
            "growth": 21.0
          },
          "average_bill": {
            "value": 32.5,
            "previous": 30.2,
            "growth": 7.6
          },
          "menu_views": {
            "total": 420,
            "previous": 380,
            "growth": 10.5
          }
        };
        break;
        
      case ProducerType.leisureProducer:
        baseStats["specific_metrics"] = {
          "bookings": {
            "total": 48,
            "previous": 42,
            "growth": 14.3
          },
          "event_views": {
            "total": 350,
            "previous": 310,
            "growth": 12.9
          },
          "repeat_visitors": {
            "total": 22,
            "previous": 18,
            "growth": 22.2
          }
        };
        break;
        
      case ProducerType.wellnessProducer:
        baseStats["specific_metrics"] = {
          "appointments": {
            "total": 65,
            "previous": 54,
            "growth": 20.4
          },
          "service_popularity": {
            "most_popular": "Massage",
            "views": 180,
            "growth": 15.2
          },
          "gift_cards": {
            "total": 12,
            "previous": 8,
            "growth": 50.0
          }
        };
        break;
        
      default:
        // Cas par défaut, pas de métriques spécifiques
        break;
    }
    
    return baseStats;
  }

  /// KPIs mockés spécifiques au type de producteur
  List<Map<String, dynamic>> _getMockKPIs(ProducerType type) {
    switch (type) {
      case ProducerType.restaurant:
        return [
          {
            "title": "Taux d'occupation",
            "value": 78.5,
            "unit": "%",
            "trend": 5.2,
            "description": "Pourcentage moyen de tables occupées"
          },
          {
            "title": "Durée moyenne de repas",
            "value": 86,
            "unit": "min",
            "trend": -2.3,
            "description": "Temps moyen passé par les clients"
          },
          {
            "title": "Commandes en ligne",
            "value": 42,
            "unit": "",
            "trend": 15.8,
            "description": "Nombre de commandes via l'application"
          }
        ];
        
      case ProducerType.leisureProducer:
        return [
          {
            "title": "Taux de participation",
            "value": 83.2,
            "unit": "%",
            "trend": 3.8,
            "description": "Pourcentage de réservations honorées"
          },
          {
            "title": "Durée moyenne de visite",
            "value": 124,
            "unit": "min",
            "trend": 7.5,
            "description": "Temps moyen passé sur le lieu"
          },
          {
            "title": "Activités par visite",
            "value": 2.3,
            "unit": "",
            "trend": 5.2,
            "description": "Nombre moyen d'activités par visite"
          }
        ];
        
      case ProducerType.wellnessProducer:
        return [
          {
            "title": "Taux de fidélisation",
            "value": 68.5,
            "unit": "%",
            "trend": 4.2,
            "description": "Clients revenant dans les 60 jours"
          },
          {
            "title": "Panier moyen",
            "value": 85.6,
            "unit": "€",
            "trend": 8.3,
            "description": "Montant moyen dépensé par visite"
          },
          {
            "title": "Services par visite",
            "value": 1.7,
            "unit": "",
            "trend": 6.5,
            "description": "Nombre moyen de services par visite"
          }
        ];
        
      default:
        return [
          {
            "title": "Engagement",
            "value": 12.5,
            "unit": "%",
            "trend": 3.2,
            "description": "Taux d'engagement sur les publications"
          }
        ];
    }
  }

  /// Recommandations mockées spécifiques au type de producteur
  List<Map<String, dynamic>> _getMockRecommendations(ProducerType type) {
    switch (type) {
      case ProducerType.restaurant:
        return [
          {
            "title": "Ajoutez votre carte des vins",
            "description": "Les clients recherchent vos suggestions de vins",
            "impact": "Augmentation potentielle de 15% du panier moyen",
            "difficulty": "Facile",
            "urgency": "Moyenne"
          },
          {
            "title": "Créez une offre du midi en semaine",
            "description": "Potentiel inexploité pour la clientèle professionnelle",
            "impact": "Augmentation potentielle de 25% de fréquentation en semaine",
            "difficulty": "Moyenne",
            "urgency": "Élevée"
          }
        ];
        
      case ProducerType.leisureProducer:
        return [
          {
            "title": "Proposez des offres pour groupes",
            "description": "Demande croissante pour les activités en groupe",
            "impact": "Potentiel de 30% d'augmentation des réservations",
            "difficulty": "Moyenne",
            "urgency": "Élevée"
          },
          {
            "title": "Créez des évènements thématiques",
            "description": "Les évènements spéciaux génèrent plus d'engagement",
            "impact": "Jusqu'à 40% de partages supplémentaires",
            "difficulty": "Moyenne",
            "urgency": "Moyenne"
          }
        ];
        
      case ProducerType.wellnessProducer:
        return [
          {
            "title": "Proposez des forfaits saisonniers",
            "description": "Les clients recherchent des soins adaptés à la saison",
            "impact": "Augmentation potentielle de 20% des réservations",
            "difficulty": "Facile",
            "urgency": "Élevée"
          },
          {
            "title": "Lancez un programme de fidélité",
            "description": "Les clients fidèles dépensent 60% de plus",
            "impact": "Amélioration de 40% du taux de retour client",
            "difficulty": "Moyenne",
            "urgency": "Moyenne"
          }
        ];
        
      default:
        return [
          {
            "title": "Complétez votre profil",
            "description": "Un profil complet génère plus de confiance",
            "impact": "Jusqu'à 30% de vues supplémentaires",
            "difficulty": "Facile",
            "urgency": "Élevée"
          }
        ];
    }
  }

  /// Concurrents mockés spécifiques au type de producteur
  List<Map<String, dynamic>> _getMockCompetitors(ProducerType type) {
    switch (type) {
      case ProducerType.restaurant:
        return [
          {
            "name": "Bistro Parisien",
            "photo": "https://picsum.photos/id/429/200/200",
            "rating": 4.5,
            "followers": 248,
            "price_level": "€€",
            "distance": 1.2,
            "specialty": "Cuisine française"
          },
          {
            "name": "La Bonne Table",
            "photo": "https://picsum.photos/id/431/200/200",
            "rating": 4.2,
            "followers": 186,
            "price_level": "€€€",
            "distance": 0.8,
            "specialty": "Gastronomique"
          }
        ];
        
      case ProducerType.leisureProducer:
        return [
          {
            "name": "Escape Game Paris",
            "photo": "https://picsum.photos/id/439/200/200",
            "rating": 4.7,
            "followers": 312,
            "price_level": "€€",
            "distance": 1.5,
            "specialty": "Jeux d'évasion"
          },
          {
            "name": "Atelier Créatif",
            "photo": "https://picsum.photos/id/441/200/200",
            "rating": 4.3,
            "followers": 175,
            "price_level": "€€",
            "distance": 0.7,
            "specialty": "Ateliers d'art"
          }
        ];
        
      case ProducerType.wellnessProducer:
        return [
          {
            "name": "Spa Harmonie",
            "photo": "https://picsum.photos/id/451/200/200",
            "rating": 4.8,
            "followers": 287,
            "price_level": "€€€",
            "distance": 1.8,
            "specialty": "Soins spa"
          },
          {
            "name": "Zen Massage",
            "photo": "https://picsum.photos/id/452/200/200",
            "rating": 4.4,
            "followers": 196,
            "price_level": "€€",
            "distance": 1.2,
            "specialty": "Massages"
          }
        ];
        
      default:
        return [
          {
            "name": "Concurrent",
            "photo": "https://picsum.photos/id/433/200/200",
            "rating": 4.1,
            "followers": 145,
            "distance": 1.0
          }
        ];
    }
  }
} 