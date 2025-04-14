import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Configuration des URL serveur - NE PAS MODIFIER en production
const bool useNgrok = false; // Désactivé
const String ngrokUrl = "https://cfae-195-220-106-83.ngrok-free.app"; // Non utilisé
const String localUrl = "http://10.0.2.2:5000"; // Pour émulateur Android
const String directUrl = "http://localhost:5000"; // Pour Windows/Web
const String localNetworkUrl = "http://192.168.1.23:5000"; // Pour téléphone connecté en filaire
const String cloudUrl = "https://api.choiceapp.fr"; // Pour les appareils physiques

// Déterminer si l'application est en mode production
// NOTE: Cette valeur est normalement définie dans vos variables d'environnement de build
const bool isProduction = false; // Changé à false pour le développement local

/// Fonction dédiée pour déterminer si l'application est en mode production
/// Cette méthode est plus fiable que la simple constante bool.fromEnvironment
bool isProductionMode() {
  // Retourner false pour le développement local
  return false;
}

/// Retourne l'URL de base pour les requêtes API
/// Cette fonction est cruciale car elle détermine vers quel serveur les requêtes sont envoyées
String getBaseUrl() {
  if (kIsWeb) {
    return 'https://api.choiceapp.fr';
  } else if (isDebugMode) {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      return 'http://localhost:3000';
    }
  }
  return 'https://api.choiceapp.fr';
}

// Alias pour maintenir la compatibilité
String getBaseUrlSync() => getBaseUrl();

/// Teste la connectivité à l'API
Future<bool> testApiConnection() async {
  try {
    final baseUrl = getBaseUrl();
    print('🔄 Test de connexion à: $baseUrl');
    
    final response = await http.get(Uri.parse('$baseUrl/api/ping'))
        .timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      print('✅ Connexion à l\'API réussie');
      return true;
    } else {
      print('⚠️ Connexion à l\'API échouée: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('❌ Erreur de connexion à l\'API: $e');
    return false;
  }
}

bool isMobile() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS;
}

// Modifier l'URL par défaut pour utiliser Dicebear (un service d'avatar par défaut)
String getDefaultAvatarUrl(String userId) {
  return 'https://api.dicebear.com/6.x/initials/png?seed=$userId';
}

// Constantes pour l'application
const String APP_NAME = 'Choice App';
const String APP_VERSION = '1.0.0';

// Clés de préférences partagées
const String PREF_USER_ID = 'userId';
const String PREF_TOKEN = 'token';
const String PREF_USER_DATA = 'user_data';
const String PREF_ACCOUNT_TYPE = 'accountType';
const String PREF_ONBOARDING_COMPLETED = 'hasCompletedOnboarding';

// Délais et timeouts
const int API_TIMEOUT_SECONDS = 30;
const int LOCATION_UPDATE_INTERVAL_SECONDS = 30;
const int MARKER_DOUBLE_TAP_TIMEOUT_SECONDS = 3;

// Rayons de recherche par défaut (en mètres)
const double DEFAULT_SEARCH_RADIUS = 5000.0;
const double MIN_SEARCH_RADIUS = 500.0;
const double MAX_SEARCH_RADIUS = 20000.0;

// Filtres par défaut
const double DEFAULT_MIN_RATING = 0.0;
const double DEFAULT_MAX_PRICE = 1000.0;

// Clés d'API (à remplacer par les vraies clés en production)
const String GOOGLE_MAPS_API_KEY = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

// URL de l'API pour être utilisée dans les plugins
const String API_URL = cloudUrl;

// Formats de date
const String DATE_FORMAT = 'dd/MM/yyyy';
const String TIME_FORMAT = 'HH:mm';
const String DATETIME_FORMAT = 'dd/MM/yyyy HH:mm';

/// Fonction de test pour vérifier la configuration de l'URL en fonction de l'appareil
/// À utiliser uniquement pour le débogage, à supprimer en production
void testUrlConfiguration() {
  print('🔍 TEST DE CONFIGURATION URL');
  print('📱 Type d\'appareil:');
  print('   - Web: ${kIsWeb}');
  if (!kIsWeb) {
    print('   - Android: ${Platform.isAndroid}');
    print('   - iOS: ${Platform.isIOS}');
    
    // Environnement Android
    if (Platform.isAndroid) {
      print('📊 Variables d\'environnement Android:');
      print('   - ANDROID_EMULATOR: ${Platform.environment.containsKey('ANDROID_EMULATOR')}');
      print('   - ANDROID_SDK_ROOT: ${Platform.environment.containsKey('ANDROID_SDK_ROOT')}');
    }
    
    // Environnement iOS
    if (Platform.isIOS) {
      print('📊 Variables d\'environnement iOS:');
      print('   - SIMULATOR_DEVICE_NAME: ${Platform.environment.containsKey('SIMULATOR_DEVICE_NAME')}');
      print('   - SIMULATOR_HOST_HOME: ${Platform.environment.containsKey('SIMULATOR_HOST_HOME')}');
    }
  }
  print('🌐 URL Base sélectionnée: ${getBaseUrl()}');
}

// Couleur primaire pour l'application
final Color primaryColor = Colors.purple;

// Constantes globales pour l'application

// URL de base pour l'API
const String apiBaseUrl = "https://api.choiceapp.fr"; 

// Autres constantes utiles
const int defaultPageSize = 20;
const int defaultCacheTimeMinutes = 10;
const String appName = "Choice App";

// Délais
const Duration defaultTimeoutDuration = Duration(seconds: 30);
const Duration defaultAnimationDuration = Duration(milliseconds: 300);

/// Récupère l'ID de l'utilisateur courant depuis SharedPreferences
String? getCurrentUserId() {
  // Cette fonction devrait être implémentée pour récupérer l'ID utilisateur
  // depuis SharedPreferences. Pour l'instant, elle renvoie null.
  // Dans une implémentation complète, elle utiliserait SharedPreferences
  return null;
}

/// Récupère le token d'authentification depuis SharedPreferences
String? getToken() {
  // Cette fonction devrait être implémentée pour récupérer le token
  // depuis SharedPreferences. Pour l'instant, elle renvoie une chaîne vide.
  // Dans une implémentation complète, elle utiliserait SharedPreferences
  return '';
}

// Remplacer kDebugMode par une vérification appropriée
bool get isDebugMode {
  return false; // À remplacer par la logique appropriée
}
