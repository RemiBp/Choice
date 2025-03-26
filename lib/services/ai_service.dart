import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import '../screens/utils.dart';

/// Service permettant d'accéder à l'IA avec accès direct aux données MongoDB
/// Ce service encapsule les appels aux endpoints AI et gère les profils extraits
class AIService {
  /// Singleton pattern
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  /// URL de base des API
  final String _baseUrl = getBaseUrl();

  /// Journalisation des opérations
  void _log(String message) {
    developer.log('[AIService] $message');
  }

  /// Formate correctement une URL en gérant les doublons de slash
  Uri _formatUrl(String endpoint) {
    String baseUrl = _baseUrl;
    
    // Nettoyer le baseUrl s'il termine par un slash
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    
    // Nettoyer l'endpoint s'il commence par un slash
    if (endpoint.startsWith('/')) {
      endpoint = endpoint.substring(1);
    }
    
    final fullUrl = '$baseUrl/$endpoint';
    _log('URL formatée: $fullUrl');
    
    return Uri.parse(fullUrl);
  }

  /// Effectue une requête simple sans authentification
  /// 
  /// Exemple: "Restaurants avec du saumon"
  Future<AIQueryResponse> simpleQuery(String query) async {
    try {
      _log('Requête simple: "$query"');
      
      final response = await http.post(
        _formatUrl('api/ai/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
        }),
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Réponse reçue: ${response.body.length} caractères');
        
        // Vérifier si la réponse est directement à la racine ou dans data
        final responseData = data.containsKey('data') ? data['data'] : data;
        return AIQueryResponse.fromJson(responseData);
      } else {
        _log('Erreur HTTP: ${response.statusCode}, Corps: ${response.body}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Exception: $e');
      return AIQueryResponse(
        query: query,
        intent: 'unknown',
        entities: {},
        resultCount: 0,
        executionTimeMs: 0,
        response: 'Erreur lors de la requête: $e',
        profiles: [],
        error: e.toString(),
      );
    }
  }

  /// Recherche spécifique de plats
  /// 
  /// Exemple: "saumon", "pizza", "végétarien"
  Future<AIQueryResponse> searchDish(String dishName) async {
    try {
      _log('Recherche du plat: "$dishName"');
      
      final response = await http.post(
        _formatUrl('api/ai/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': 'Donne-moi les restaurants qui proposent du $dishName',
        }),
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Réponse reçue: ${response.body.length} caractères');
        
        // Gérer le cas où la réponse est directement à la racine
        final responseData = data.containsKey('data') ? data['data'] : data;
        return AIQueryResponse.fromJson(responseData);
      } else {
        _log('Erreur HTTP: ${response.statusCode}, Corps: ${response.body}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Exception: $e');
      return AIQueryResponse(
        query: 'Recherche de $dishName',
        intent: 'restaurant_search',
        entities: {'cuisine_type': dishName},
        resultCount: 0,
        executionTimeMs: 0,
        response: 'Erreur lors de la recherche: $e',
        profiles: [],
        error: e.toString(),
      );
    }
  }
  

  /// Effectue une requête utilisateur en langage naturel
  /// 
  /// Exemple: "Propose-moi un spectacle fun ce soir"
  Future<AIQueryResponse> userQuery(String userId, String query) async {
    try {
      _log('Requête utilisateur: "$query" (userId: $userId)');
      
      final response = await http.post(
        _formatUrl('api/ai/user/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'query': query,
        }),
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Réponse reçue: ${response.body.length} caractères');
        
        // Gérer le cas où la réponse est directement à la racine
        final responseData = data.containsKey('data') ? data['data'] : data;
        return AIQueryResponse.fromJson(responseData);
      } else {
        _log('Erreur HTTP: ${response.statusCode}, Corps: ${response.body}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Exception: $e');
      
      
      return AIQueryResponse(
        query: query,
        intent: 'unknown',
        entities: {},
        resultCount: 0,
        executionTimeMs: 0,
        response: 'Erreur lors de la requête: $e',
        profiles: [],
        error: e.toString(),
      );
    }
  }

  /// Effectue une requête producteur en langage naturel
  /// 
  /// Exemple: "Aide-moi à améliorer ma carte en comparaison des autres restaurants du quartier"
  Future<AIQueryResponse> producerQuery(String producerId, String query) async {
    try {
      _log('Requête producteur: "$query" (producerId: $producerId)');
      
      final response = await http.post(
        _formatUrl('api/ai/producer/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'producerId': producerId,
          'query': query,
        }),
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Réponse reçue: ${response.body.length} caractères');
        
        // Gérer le cas où la réponse est directement à la racine
        final responseData = data.containsKey('data') ? data['data'] : data;
        return AIQueryResponse.fromJson(responseData);
      } else {
        _log('Erreur HTTP: ${response.statusCode}, Corps: ${response.body}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Exception: $e');
      return AIQueryResponse(
        query: query,
        intent: 'unknown',
        entities: {},
        resultCount: 0,
        executionTimeMs: 0,
        response: 'Erreur lors de la requête: $e',
        profiles: [],
        error: e.toString(),
      );
    }
  }

  /// Récupère des insights personnalisés pour un utilisateur
  Future<AIQueryResponse> getUserInsights(String userId) async {
    try {
      _log('Récupération des insights pour l\'utilisateur: $userId');
      
      final response = await http.get(
        _formatUrl('api/ai/insights/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Réponse reçue: ${response.body.length} caractères');
        
        // Gérer le cas où la réponse est directement à la racine
        final responseData = data.containsKey('data') ? data['data'] : data;
        return AIQueryResponse.fromJson(responseData);
      } else {
        _log('Erreur HTTP: ${response.statusCode}, Corps: ${response.body}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Exception: $e');
      return AIQueryResponse(
        query: 'Insights utilisateur',
        intent: 'user_insights',
        entities: {},
        resultCount: 0,
        executionTimeMs: 0,
        response: 'Erreur lors de la récupération des insights: $e',
        profiles: [],
        error: e.toString(),
      );
    }
  }

  /// Récupère des insights commerciaux pour un producteur
  Future<AIQueryResponse> getProducerInsights(String producerId) async {
    try {
      _log('Récupération des insights pour le producteur: $producerId');
      
      final response = await http.get(
        _formatUrl('api/ai/insights/producer/$producerId'),
        headers: {'Content-Type': 'application/json'},
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Réponse reçue: ${response.body.length} caractères');
        
        // Gérer le cas où la réponse est directement à la racine
        final responseData = data.containsKey('data') ? data['data'] : data;
        return AIQueryResponse.fromJson(responseData);
      } else {
        _log('Erreur HTTP: ${response.statusCode}, Corps: ${response.body}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('Exception: $e');
      return AIQueryResponse(
        query: 'Insights producteur',
        intent: 'producer_insights',
        entities: {},
        resultCount: 0,
        executionTimeMs: 0,
        response: 'Erreur lors de la récupération des insights: $e',
        profiles: [],
        error: e.toString(),
      );
    }
  }

  /// Vérifie l'état de santé du service IA
  Future<bool> checkHealth() async {
    try {
      _log('Vérification de l\'état de santé du service IA');
      
      final response = await http.get(
        _formatUrl('api/ai/health'),
        headers: {'Content-Type': 'application/json'},
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isOperational = data['success'] == true && data['status'] == 'operational';
        _log('Service IA opérationnel: $isOperational');
        return isOperational;
      } else {
        _log('Service IA non opérationnel (code ${response.statusCode})');
        return false;
      }
    } catch (e) {
      _log('Exception lors de la vérification de santé: $e');
      return false;
    }
  }
  
  /// Génère une cartographie sensorielle basée sur une ambiance ou émotion
  /// 
  /// Exemple: vibe = "chaleureux et convivial", location = "Paris 11"
  Future<Map<String, dynamic>?> generateVibeMap({
    required String userId,
    required String vibe,
    String? location,
  }) async {
    try {
      _log('Génération de cartographie sensorielle: "$vibe" ${location != null ? 'à $location' : ''} (userId: $userId)');
      
      final response = await http.post(
        _formatUrl('api/ai/vibe-map'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'vibe': vibe,
          'location': location,
        }),
      ).timeout(const Duration(seconds: 30));

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Réponse reçue: ${response.body.length} caractères');
        
        // Gérer le cas où la réponse est directement à la racine
        final responseData = data.containsKey('data') ? data['data'] : data;
        return responseData;
      } else {
        _log('Erreur HTTP: ${response.statusCode}, Corps: ${response.body}');
        return null;
      }
    } catch (e) {
      _log('Exception lors de la génération de la cartographie sensorielle: $e');
      return null;
    }
  }
  
  /// Permet de tester la connexion à MongoDB et la disponibilité du service IA
  Future<bool> testMongoConnection() async {
    try {
      _log('Test de connexion au service IA et MongoDB');
      
      final response = await http.get(
        _formatUrl('api/ai/health'),
        headers: {'Content-Type': 'application/json'},
      );

      _log('Statut de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final connected = data['success'] == true && data['status'] == 'operational';
        _log('Connexion service IA et MongoDB: $connected');
        return connected;
      } else {
        _log('Échec de connexion au service IA (code ${response.statusCode})');
        return false;
      }
    } catch (e) {
      _log('Exception lors du test de connexion: $e');
      return false;
    }
  }
  
  /// Extrait et traite les liens cliquables d'un message IA
  /// Retourne à la fois le texte avec des spans cliquables et la liste des actions
  static List<InlineSpan> parseMessageWithLinks(String message, Function(String type, String id) onProfileTap) {
    List<InlineSpan> spans = [];
    
    // Regex pour détecter les liens au format [texte](profile:type:id)
    final RegExp profileLinkRegex = RegExp(r'\[(.*?)\]\(profile:(.*?):(.*?)\)');
    
    int lastMatchEnd = 0;
    
    // Trouver tous les liens dans le message
    for (Match match in profileLinkRegex.allMatches(message)) {
      // Ajouter le texte avant le lien
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: message.substring(lastMatchEnd, match.start),
        ));
      }
      
      // Récupérer les informations du lien
      final linkText = match.group(1) ?? "";
      final profileType = match.group(2) ?? "";
      final profileId = match.group(3) ?? "";
      
      // Ajouter le lien cliquable
      spans.add(TextSpan(
        text: linkText,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => onProfileTap(profileType, profileId),
      ));
      
      lastMatchEnd = match.end;
    }
    
    // Ajouter le reste du texte après le dernier lien
    if (lastMatchEnd < message.length) {
      spans.add(TextSpan(
        text: message.substring(lastMatchEnd),
      ));
    }
    
    return spans;
  }
}

/// Modèle pour la réponse d'une requête IA
class AIQueryResponse {
  final String query;
  final String intent;
  final Map<String, dynamic> entities;
  final int resultCount;
  final int executionTimeMs;
  final String response;
  final List<ProfileData> profiles;
  final dynamic analysisResults;
  final String? error;
  final List<String>? suggestions;

  AIQueryResponse({
    required this.query,
    required this.intent,
    required this.entities,
    required this.resultCount,
    required this.executionTimeMs,
    required this.response,
    required this.profiles,
    this.analysisResults,
    this.error,
    this.suggestions,
  });

  factory AIQueryResponse.fromJson(Map<String, dynamic> json) {
    // Journalisation pour debug
    developer.log('[AIQueryResponse] Parsing JSON: ${json.keys}');
    
    // Extraire les profils de lieux s'ils existent
    List<ProfileData> profiles = [];
    if (json['profiles'] != null) {
      profiles = (json['profiles'] as List)
          .map((profile) => ProfileData.fromJson(profile))
          .toList();
    }
    
    // Parse suggestions if they exist
    List<String>? suggestions;
    if (json['suggestions'] != null) {
      suggestions = (json['suggestions'] as List)
          .map((suggestion) => suggestion.toString())
          .toList();
    }
    
    return AIQueryResponse(
      query: json['query'] ?? '',
      intent: json['intent'] ?? 'unknown',
      entities: json['entities'] ?? {},
      resultCount: json['resultCount'] ?? 0,
      executionTimeMs: json['executionTimeMs'] ?? 0,
      response: json['response'] ?? '',
      profiles: profiles,
      analysisResults: json['analysisResults'],
      error: json['error'],
      suggestions: suggestions,
    );
  }

  bool get hasError => error != null;
  bool get hasProfiles => profiles.isNotEmpty;

  @override
  String toString() {
    return 'AIQueryResponse{query: $query, intent: $intent, resultCount: $resultCount, profiles: ${profiles.length}}';
  }
}

/// Modèle pour représenter un profil de lieu extrait par l'IA
class ProfileData {
  final String id;
  final String type;
  final String name;
  final String? address;
  final String? description;
  final double? rating;
  final String? image;
  final List<String> category;
  final int? priceLevel;
  final String? highlightedItem;
  final List<MenuItem>? menuItems;
  final Map<String, dynamic>? structuredData;
  
  ProfileData({
    required this.id,
    required this.type,
    required this.name,
    this.address,
    this.description,
    this.rating,
    this.image,
    required this.category,
    this.priceLevel,
    this.highlightedItem,
    this.menuItems,
    this.structuredData,
  });
  
  factory ProfileData.fromJson(Map<String, dynamic> json) {
    // Journalisation pour debug
    developer.log('[ProfileData] Parsing JSON: ${json.keys}');
    
    List<String> parseCategories(dynamic categories) {
      if (categories == null) return [];
      if (categories is String) return [categories];
      if (categories is List) {
        return categories.map((c) => c.toString()).toList();
      }
      return [];
    }
    
    // Extraire les items de menu s'ils existent
    List<MenuItem>? menuItems;
    if (json['menu_items'] != null) {
      menuItems = (json['menu_items'] as List)
          .map((item) => MenuItem.fromJson(item))
          .toList();
    }
    
    return ProfileData(
      id: json['id'] ?? '',
      type: json['type'] ?? 'unknown',
      name: json['name'] ?? 'Sans nom',
      address: json['address'],
      description: json['description'],
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      image: json['image'],
      category: parseCategories(json['category']),
      priceLevel: json['price_level'] != null ? int.tryParse(json['price_level'].toString()) : null,
      highlightedItem: json['highlighted_item'] ?? json['highlightedItem'],
      menuItems: menuItems,
      structuredData: json['structured_data'] ?? json['structuredData'],
    );
  }
  
  /// Vérifie si ce profil contient un plat spécifique
  bool hasMenuItemWithKeyword(String keyword) {
    if (menuItems == null) return false;
    
    final lowercaseKeyword = keyword.toLowerCase();
    return menuItems!.any((item) => 
      (item.nom?.toLowerCase().contains(lowercaseKeyword) ?? false) ||
      (item.description?.toLowerCase().contains(lowercaseKeyword) ?? false)
    );
  }
}

/// Modèle pour représenter un item de menu
class MenuItem {
  final String? nom;
  final String? description;
  final dynamic prix;
  final double? note;
  
  MenuItem({this.nom, this.description, this.prix, this.note});
  
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      nom: json['nom'],
      description: json['description'],
      prix: json['prix'],
      note: json['note'] != null ? double.tryParse(json['note'].toString()) : null,
    );
  }
  
  @override
  String toString() {
    return '$nom${description != null ? ' - $description' : ''}${prix != null ? ' ($prix)' : ''}';
  }
}