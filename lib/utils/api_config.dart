import 'package:flutter/material.dart';
import 'constants.dart' as constants;
import '../services/auth_service.dart';

class ApiConfig {
  static const bool isDevelopment = false;
  
  // URL de base en fonction de l'environnement
  static String get baseUrl => constants.getBaseUrlSync();
  
  // Timeout pour les requêtes HTTP (en secondes)
  static const int timeout = 30;
  
  // Nombre maximum de tentatives de reconnexion
  static const int maxRetries = 3;
  
  // Délai entre les tentatives de reconnexion (en secondes)
  static const int retryDelay = 2;
  
  // Constants for endpoints
  static const String RESTAURANTS_ENDPOINT = '/api/producers';
  static const String LEISURE_ENDPOINT = '/api/leisure';
  static const String LEISURE_PRODUCERS_ENDPOINT = '/api/leisure-producers';
  static const String WELLNESS_ENDPOINT = '/api/wellness';
  static const String UNIFIED_ENDPOINT = '/api/unified';

  // Map for easy access - ensure keys match expected types
  static const Map<String, String> endpoints = {
    'restaurant': RESTAURANTS_ENDPOINT,
    'leisure': LEISURE_ENDPOINT,
    'leisureProducer': LEISURE_PRODUCERS_ENDPOINT,
    'wellness': WELLNESS_ENDPOINT,
    'unified': UNIFIED_ENDPOINT,
  };
  
  // Nom de la collection MongoDB (pour référence)
  static const String collectionName = "Beauty_Wellness";
  
  // Configuration des headers par défaut
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Configuration des messages d'erreur
  static const Map<String, String> errorMessages = {
    'connection': 'Erreur de connexion au serveur',
    'timeout': 'La requête a expiré',
    'notFound': 'Ressource non trouvée',
    'unauthorized': 'Non autorisé',
    'forbidden': 'Accès interdit',
    'serverError': 'Erreur serveur',
  };

  // Clé API Google Maps (utilisée dans le backend)
  static const String googleMapsApiKey = "AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE";
  
  static const String token = '';
  
  // Méthode pour obtenir les headers d'authentification
  static Future<Map<String, String>> getAuthHeaders() async {
    // Pour le moment, nous retournons simplement les headers par défaut
    // Dans une implémentation réelle, on récupérerait le token depuis SharedPreferences
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    try {
      // Get token directly from AuthService static method
      final token = await AuthService.getTokenStatic();
      
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      print('❌ Error getting auth token for headers: $e');
    }
    
    return headers;
  }

  // Valeur du mode de production
  static bool get isProduction => true;

  // Fonction wrapper pour compatibilité
  static String getBaseUrl() {
    print("🔄 [api_config.dart] getBaseUrl() appelé (compatibilité)");
    return "https://api.choiceapp.fr";
  }

  // API endpoints - à adapter selon les besoins de la partie wellness
  static const String WELLNESS_AUTH_ENDPOINT = '/api/wellness/auth';
  static const String WELLNESS_BOOKINGS_ENDPOINT = '/api/wellness/bookings';
  static const String WELLNESS_SERVICES_ENDPOINT = '/api/wellness/services';

  // --- Endpoints --- (Exemple, adapter à votre structure)
  static const String BASE_URL_ENV_KEY = 'BASE_URL';
  static const String USERS_ENDPOINT = '/api/users';
  static const String EVENTS_ENDPOINT = '/api/events';
  static const String CHOICES_ENDPOINT = '/api/choices';
  static const String INTERESTS_ENDPOINT = '/api/interests';
  static const String FRIENDS_ENDPOINT = '/api/friends';
  static const String AUTH_ENDPOINT = '/api/auth';
  static const String POSTS_ENDPOINT = '/api/posts';
  static const String CONVERSATIONS_ENDPOINT = '/api/conversations';
  static const String AI_ENDPOINT = '/api/ai'; // Endpoint de base pour l'IA

  // --- Mapping Type -> Endpoint ---
  static String getEndpointForType(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant': return RESTAURANTS_ENDPOINT;
      case 'leisureproducer': return LEISURE_PRODUCERS_ENDPOINT;
      case 'event': return EVENTS_ENDPOINT;
      case 'wellnessproducer':
         return WELLNESS_ENDPOINT;
      case 'user': return USERS_ENDPOINT;
      default: throw ArgumentError('Type de producteur inconnu: $type');
    }
  }
} 