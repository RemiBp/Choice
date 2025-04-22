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
  
  // Configuration des endpoints
  static const Map<String, String> endpoints = {
    'wellness': '/api/beauty_wellness',
    'producers': '/api/producers',
    'places': '/api/beauty_places',
    'hotspots': '/api/location-history/hotspots',
    'auth': '/api/wellness/auth',
    'users': '/api/users',
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
      final token = await AuthService.getToken();
      
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
  static const String WELLNESS_ENDPOINT = '/api/wellness';
  static const String WELLNESS_AUTH_ENDPOINT = '/api/wellness/auth';
  static const String WELLNESS_BOOKINGS_ENDPOINT = '/api/wellness/bookings';
  static const String WELLNESS_SERVICES_ENDPOINT = '/api/wellness/services';
} 