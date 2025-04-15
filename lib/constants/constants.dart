import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, kDebugMode;
import 'package:flutter/widgets.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Configuration des URL serveur - NE PAS MODIFIER en production
const bool useNgrok = false; // Désactivé
const String ngrokUrl = "https://cfae-195-220-106-83.ngrok-free.app"; // Non utilisé
const String localUrl = "http://10.0.2.2:5000"; // Pour émulateur Android
const String directUrl = "http://localhost:5000"; // Pour Windows/Web
const String localNetworkUrl = "http://192.168.1.20:5000"; // IP de votre machine actuelle
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
  // 1. Web: toujours utiliser l'URL de production
  if (kIsWeb) {
    print('🌐 Mode Web, utilisation de l\'API de production');
    return cloudUrl;
  }
  
  // 2. Mode debug
  if (kDebugMode) {
    print('🔧 Mode DÉVELOPPEMENT');
    
    // 2.1 Android
    if (Platform.isAndroid) {
      // Détection d'émulateur
      bool isEmulator = false;
      try {
        isEmulator = Platform.environment.containsKey('ANDROID_EMULATOR') || 
                     Platform.environment.containsKey('ANDROID_SDK_ROOT');
      } catch (e) {
        print('⚠️ Erreur lors de la détection d\'émulateur: $e');
      }
      
      if (isEmulator) {
        print('📱 Émulateur Android - URL: $localUrl');
        return localUrl; // 10.0.2.2:5000
      } else {
        // Si connecté en USB debugging
        print('📱 Appareil Android physique - URL: $localNetworkUrl');
        // Tentative de connexion au serveur local
        return localNetworkUrl; // IP locale
        
        // Note: Si l'appareil ne peut pas atteindre localNetworkUrl,
        // il devrait automatiquement utiliser l'URL de secours dans testApiConnection()
      }
    }
    
    // 2.2 iOS
    if (Platform.isIOS) {
      // Détection de simulateur (si possible)
      bool isSimulator = false;
      try {
        isSimulator = Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') || 
                      Platform.environment.containsKey('SIMULATOR_HOST_HOME');
      } catch (e) {
        print('⚠️ Erreur lors de la détection de simulateur: $e');
      }
      
      if (isSimulator) {
        print('📱 Simulateur iOS - URL: $directUrl');
        return directUrl; // localhost:5000
      } else {
        print('📱 Appareil iOS physique - URL: $localNetworkUrl');
        // Tentative de connexion au serveur local
        return localNetworkUrl; // IP locale
      }
    }
    
    return localNetworkUrl; // Fallback en dev
  }
  
  // 3. Production (non-debug): toujours utiliser l'URL de production
  print('🚀 Mode PRODUCTION, utilisation de l\'API de production');
  return cloudUrl;
}

/// Fonction synchrone qui retourne l'URL de base pour certains cas où l'async n'est pas possible
String getBaseUrlSync() {
  return getBaseUrl();
}

// ADDED: Function to test API Connection and fallback to production if local fails
Future<String> getReliableBaseUrl() async {
  // Obtenir l'URL par défaut selon la configuration
  final baseUrl = getBaseUrl();
  
  // Si c'est déjà l'URL de production, pas besoin de tester
  if (baseUrl == cloudUrl) {
    return cloudUrl;
  }
  
  // Tester si l'URL locale est accessible
  try {
    print('🔄 Test de connexion à: $baseUrl');
    final response = await http.get(
      Uri.parse('$baseUrl/api/ping'),
      headers: {'Connection': 'keep-alive'}
    ).timeout(Duration(seconds: 3));
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('✅ Serveur local accessible ($baseUrl)');
      return baseUrl;
    }
  } catch (e) {
    print('❌ Serveur local non accessible: $e');
  }
  
  // Fallback vers l'URL de production
  print('🔄 Utilisation de l\'URL de production (fallback): $cloudUrl');
  return cloudUrl;
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
const int API_TIMEOUT_SECONDS = 15;
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
  print('🌐 URL Base sélectionnée: ${getBaseUrlSync()}');
}

// Vérifier si le backend est accessible
// Utilisé pour diagnostiquer les problèmes de connexion
Future<bool> isBackendAccessible() async {
  final String url = getBaseUrlSync();
  try {
    // Tester avec un endpoint simple comme /api/status ou health-check
    final healthEndpoint = '$url/api/health-check';
    print('🔍 Vérification de la connectivité backend à $healthEndpoint');
    
    final response = await http.get(
      Uri.parse(healthEndpoint),
      headers: {'Connection': 'keep-alive'}
    ).timeout(
      Duration(seconds: 5), 
      onTimeout: () {
        print('⏱️ Timeout lors de la vérification de la connectivité backend');
        return http.Response('Timeout', 408);
      }
    );
    
    final bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    
    print(isSuccess 
      ? '✅ Backend accessible avec statut ${response.statusCode}'
      : '❌ Backend inaccessible avec statut ${response.statusCode}');
    
    return isSuccess;
  } catch (e) {
    print('❌ Erreur lors de la vérification de la connectivité backend: $e');
    return false;
  }
}

// Obtenir une URL alternative en cas d'indisponibilité du backend
// Utilisé pour les ressources comme les images
String getFallbackUrl(String originalUrl, {String type = 'image'}) {
  if (type == 'image') {
    // Hash de l'URL originale pour obtenir une image de remplacement cohérente
    final int seed = originalUrl.hashCode.abs() % 1000;
    return 'https://picsum.photos/seed/$seed/800/600';
  }
  
  return originalUrl; // Par défaut, renvoyer l'URL originale
}

// Couleur primaire pour l'application
final Color primaryColor = Colors.purple; 