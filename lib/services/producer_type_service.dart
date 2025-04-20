import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producer_type.dart';
import '../utils/constants.dart' as constants;

/// Service responsable de la gestion des différents types de producteurs
/// et de leur interaction avec les différentes collections MongoDB
class ProducerTypeService {
  static final ProducerTypeService _instance = ProducerTypeService._internal();
  factory ProducerTypeService() => _instance;
  ProducerTypeService._internal();

  String getBaseUrl() {
    return constants.getBaseUrlSync();
  }

  /// Détermine la collection MongoDB associée à un type de producteur
  String getDatabaseCollection(ProducerType type) {
    switch (type) {
      case ProducerType.restaurant:
        return 'Restauration_Officielle.producers';
      case ProducerType.leisureProducer:
        return 'Loisir&Culture.Loisir_Paris_Producers';
      case ProducerType.event:
        return 'Loisir&Culture.Loisir_Paris_Evenements';
      case ProducerType.wellnessProducer:
        return 'Beauty_Wellness.BeautyPlaces';
      case ProducerType.user:
        return 'choice_app.Users';
    }
  }

  /// Récupère les détails d'un producteur par son ID et son type
  Future<Map<String, dynamic>> getProducerDetails(String id, ProducerType type) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/${type.apiPath}/$id');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Gérer le cas où l'API renvoie une liste
        if (data is List && data.isNotEmpty) {
          return data[0];
        } else if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Format de données inattendu');
        }
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur de récupération des détails du producteur: $e');
      rethrow;
    }
  }

  /// Détecte le type de producteur à partir d'un objet de données
  ProducerType detectProducerType(Map<String, dynamic> data) {
    // Vérifier d'abord un champ 'type' explicite
    if (data['type'] != null) {
      final typeString = data['type'].toString().toLowerCase();
      
      if (typeString.contains('restaurant')) {
        return ProducerType.restaurant;
      } else if (typeString.contains('leisure') || typeString.contains('loisir')) {
        return ProducerType.leisureProducer;
      } else if (typeString.contains('event') || typeString.contains('événement')) {
        return ProducerType.event;
      } else if (typeString.contains('wellness') || typeString.contains('bien') && typeString.contains('être')) {
        return ProducerType.wellnessProducer;
      } else if (typeString.contains('user') || typeString.contains('utilisateur')) {
        return ProducerType.user;
      }
    }
    
    // Analyser les champs spécifiques à chaque type de producteur
    if (data['establishment_type'] != null || data['cuisine_type'] != null || 
        data['menu'] != null || data['restaurant_type'] != null) {
      return ProducerType.restaurant;
    }
    
    if (data['événement'] != null || data['date_début'] != null || 
        data['organisateur'] != null || data['participants'] != null) {
      return ProducerType.event;
    }
    
    if (data['activité'] != null || data['lieu_type'] != null || 
        data['horaires_ouverture'] != null) {
      return ProducerType.leisureProducer;
    }
    
    if (data['services'] != null || data['treatments'] != null || 
        data['bien_être'] != null || data['beauté'] != null || data['spa'] != null) {
      return ProducerType.wellnessProducer;
    }
    
    if (data['followers'] != null || data['following'] != null || 
        data['preferences'] != null || data['email'] != null) {
      return ProducerType.user;
    }
    
    // Par défaut, considérer comme restaurant (le plus courant)
    return ProducerType.restaurant;
  }
  
  /// Récupère la liste des producteurs par type avec pagination
  Future<List<Map<String, dynamic>>> getProducersByType(
    ProducerType type, {
    int page = 1,
    int limit = 20,
    Map<String, dynamic>? filters,
  }) async {
    try {
      String queryParams = 'page=$page&limit=$limit';
      
      // Ajouter des filtres si présents
      if (filters != null && filters.isNotEmpty) {
        final encodedFilters = Uri.encodeComponent(json.encode(filters));
        queryParams += '&filters=$encodedFilters';
      }
      
      final url = Uri.parse('${getBaseUrl()}/api/${type.apiPath}?$queryParams');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur de récupération des producteurs par type: $e');
      return [];
    }
  }

  /// Recherche des producteurs dans différentes collections selon leur type
  Future<List<Map<String, dynamic>>> searchProducers(String query, {List<ProducerType>? types}) async {
    try {
      // Si aucun type spécifié, rechercher dans tous les types
      final searchTypes = types ?? ProducerType.values;
      
      // Construire l'URL avec les types dans les paramètres
      final typeParams = searchTypes.map((t) => 'types=${t.value}').join('&');
      final url = Uri.parse('${getBaseUrl()}/api/unified/search-public?query=$query&$typeParams');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur de recherche des producteurs: $e');
      return [];
    }
  }
} 