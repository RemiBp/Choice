import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producer_type.dart';
import '../utils/constants.dart' as constants;

/// Service pour la gestion des campagnes marketing
class MarketingCampaignService {
  static final MarketingCampaignService _instance = MarketingCampaignService._internal();
  factory MarketingCampaignService() => _instance;
  MarketingCampaignService._internal();

  String getBaseUrl() {
    return constants.getBaseUrlSync();
  }

  /// Récupère la liste des campagnes marketing actives et passées
  Future<List<Map<String, dynamic>>> getCampaigns(String producerId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/marketing/campaigns?producerId=$producerId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des campagnes: $e');
      // Pour éviter de bloquer l'interface en cas d'erreur, on retourne une liste vide
      return [];
    }
  }

  /// Récupère les détails d'une campagne
  Future<Map<String, dynamic>> getCampaignDetails(String campaignId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/marketing/campaigns/$campaignId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des détails de campagne: $e');
      rethrow;
    }
  }

  /// Crée une nouvelle campagne marketing
  Future<Map<String, dynamic>> createCampaign({
    required String producerId,
    required String type,
    required String title,
    required Map<String, dynamic> parameters,
    required double budget,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? targetAudience,
    String? description,
  }) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/marketing/campaigns');
      
      // Construire le corps de la requête
      final campaignData = {
        'producerId': producerId,
        'type': type,
        'title': title,
        'parameters': parameters,
        'budget': budget,
        'status': 'pending', // Par défaut en attente de validation
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Ajouter les champs optionnels s'ils sont présents
      if (startDate != null) campaignData['startDate'] = startDate.toIso8601String();
      if (endDate != null) campaignData['endDate'] = endDate.toIso8601String();
      if (targetAudience != null) campaignData['targetAudience'] = targetAudience;
      if (description != null) campaignData['description'] = description;
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(campaignData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la création de la campagne: $e');
      rethrow;
    }
  }

  /// Annule une campagne
  Future<void> cancelCampaign(String campaignId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/marketing/campaigns/$campaignId/cancel');
      final response = await http.post(url);

      if (response.statusCode != 200) {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'annulation de la campagne: $e');
      rethrow;
    }
  }

  /// Récupère les statistiques d'une campagne
  Future<Map<String, dynamic>> getCampaignStats(String campaignId) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/marketing/campaigns/$campaignId/stats');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques de campagne: $e');
      rethrow;
    }
  }

  /// Récupère les types de campagnes disponibles pour un type de producteur spécifique
  Future<List<Map<String, dynamic>>> getAvailableCampaignTypes(ProducerType producerType) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/marketing/campaign-types?producerType=${producerType.value}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des types de campagne: $e');
      // En cas d'erreur, retourner des types de campagne par défaut
      return _getDefaultCampaignTypes(producerType);
    }
  }

  /// Obtient les audiences disponibles pour le ciblage
  Future<List<Map<String, dynamic>>> getTargetAudiences(ProducerType producerType) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/marketing/target-audiences?producerType=${producerType.value}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des audiences cibles: $e');
      // En cas d'erreur, retourner des audiences par défaut
      return _getDefaultTargetAudiences();
    }
  }

  /// Types de campagne par défaut
  List<Map<String, dynamic>> _getDefaultCampaignTypes(ProducerType producerType) {
    final List<Map<String, dynamic>> defaultTypes = [
      {
        'id': 'local_visibility',
        'name': 'Visibilité locale',
        'description': 'Augmentez votre visibilité auprès des utilisateurs à proximité de votre établissement',
        'price': 29.99,
        'duration': 7, // jours
        'estimatedReach': '2 500 - 3 000 utilisateurs',
        'estimatedEngagement': '300 - 450 interactions',
        'estimatedConversion': '30 - 50 visites',
      },
      {
        'id': 'national_boost',
        'name': 'Boost national',
        'description': 'Élargissez votre portée à l\'échelle nationale pour attirer une nouvelle clientèle',
        'price': 59.99,
        'duration': 14, // jours
        'estimatedReach': '8 000 - 10 000 utilisateurs',
        'estimatedEngagement': '800 - 1 200 interactions',
        'estimatedConversion': '70 - 100 visites',
      },
      {
        'id': 'special_promotion',
        'name': 'Promotion spéciale',
        'description': 'Mettez en avant vos offres et promotions exceptionnelles',
        'price': 39.99,
        'duration': 7, // jours
        'estimatedReach': '4 000 - 5 000 utilisateurs',
        'estimatedEngagement': '500 - 700 interactions',
        'estimatedConversion': '50 - 70 visites',
      },
      {
        'id': 'upcoming_event',
        'name': 'Événement à venir',
        'description': 'Faites la promotion de vos événements à venir pour maximiser la participation',
        'price': 49.99,
        'duration': 10, // jours
        'estimatedReach': '5 000 - 6 000 utilisateurs',
        'estimatedEngagement': '600 - 800 interactions',
        'estimatedConversion': '60 - 80 réservations',
      },
    ];

    // Ajouter des types spécifiques selon le type de producteur
    if (producerType == ProducerType.restaurant) {
      defaultTypes.add({
        'id': 'menu_highlight',
        'name': 'Mise en avant du menu',
        'description': 'Mettez en valeur vos plats phares et votre nouvelle carte',
        'price': 34.99,
        'duration': 7, // jours
        'estimatedReach': '3 000 - 4 000 utilisateurs',
        'estimatedEngagement': '400 - 600 interactions',
        'estimatedConversion': '40 - 60 visites',
      });
    } else if (producerType == ProducerType.leisureProducer) {
      defaultTypes.add({
        'id': 'activity_promotion',
        'name': 'Promotion d\'activité',
        'description': 'Mettez en avant une activité spécifique et attirez plus de participants',
        'price': 44.99,
        'duration': 7, // jours
        'estimatedReach': '3 500 - 4 500 utilisateurs',
        'estimatedEngagement': '450 - 650 interactions',
        'estimatedConversion': '45 - 65 réservations',
      });
    } else if (producerType == ProducerType.wellnessProducer) {
      defaultTypes.add({
        'id': 'wellness_package',
        'name': 'Forfait bien-être',
        'description': 'Promouvez vos forfaits bien-être et attirez plus de clients',
        'price': 39.99,
        'duration': 7, // jours
        'estimatedReach': '3 200 - 4 200 utilisateurs',
        'estimatedEngagement': '420 - 620 interactions',
        'estimatedConversion': '42 - 62 réservations',
      });
    }

    return defaultTypes;
  }

  /// Audiences cibles par défaut
  List<Map<String, dynamic>> _getDefaultTargetAudiences() {
    return [
      {
        'id': 'age_18_24',
        'name': '18-24 ans',
        'type': 'age',
        'priceMultiplier': 1.0
      },
      {
        'id': 'age_25_34',
        'name': '25-34 ans',
        'type': 'age',
        'priceMultiplier': 1.1
      },
      {
        'id': 'age_35_44',
        'name': '35-44 ans',
        'type': 'age',
        'priceMultiplier': 1.1
      },
      {
        'id': 'age_45_plus',
        'name': '45 ans et plus',
        'type': 'age',
        'priceMultiplier': 1.05
      },
      {
        'id': 'local',
        'name': 'Proximité (5km)',
        'type': 'location',
        'priceMultiplier': 1.0
      },
      {
        'id': 'city',
        'name': 'Ville entière',
        'type': 'location',
        'priceMultiplier': 1.2
      },
      {
        'id': 'region',
        'name': 'Région',
        'type': 'location',
        'priceMultiplier': 1.5
      },
      {
        'id': 'interested',
        'name': 'Intéressés par votre secteur',
        'type': 'interest',
        'priceMultiplier': 1.15
      },
      {
        'id': 'previous_visitors',
        'name': 'Visiteurs précédents',
        'type': 'behavior',
        'priceMultiplier': 0.9
      },
      {
        'id': 'new_users',
        'name': 'Nouveaux utilisateurs',
        'type': 'behavior',
        'priceMultiplier': 1.25
      }
    ];
  }
} 