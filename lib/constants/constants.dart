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
Future<String> getBaseUrl() async {
  if (isProductionMode()) {
    print('🚀 Mode PRODUCTION, utilisation de l\'API de production');
    return cloudUrl;
  } else {
    print('🔧 Mode DÉVELOPPEMENT, utilisation de l\'API locale');
    return localNetworkUrl;
  }
}

/// Fonction synchrone qui retourne l'URL de base pour certains cas où l'async n'est pas possible
/// À utiliser avec précaution et uniquement lorsque la fonction asynchrone ne peut pas être utilisée
String getBaseUrlSync() {
  if (isProductionMode()) {
    return cloudUrl;
  } else {
    return localNetworkUrl;
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