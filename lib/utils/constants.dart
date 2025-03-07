import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:io' show Platform;

// Commenter/décommenter selon l'environnement
const bool useNgrok = false; // Désactivé
const String ngrokUrl = "https://cfae-195-220-106-83.ngrok-free.app"; // Non utilisé
const String localUrl = "http://10.0.2.2:5000"; // Pour émulateur Android
const String directUrl = "http://localhost:5000"; // Pour Windows/Web
const String cloudUrl = "https://api.choiceapp.fr"; // Pour les appareils physiques

String getBaseUrl() {
  if (kIsWeb || Platform.isWindows) {
    return directUrl;  // Utilise localhost pour Windows
  }
  
  // Détection d'émulateur vs appareil physique
  if (isMobile()) {
    // Vérifier si on est dans un émulateur ou sur un appareil physique
    bool isEmulator = false;
    
    // Sur Android, 10.0.2.2 est l'adresse pour accéder au localhost de la machine hôte depuis l'émulateur
    if (Platform.isAndroid) {
      try {
        // Vérification simplifiée pour les émulateurs Android
        isEmulator = Platform.environment.containsKey('ANDROID_EMULATOR');
      } catch (e) {
        // En cas d'erreur, considérer comme appareil physique
        isEmulator = false;
      }
    }
    
    // Sur iOS, on peut détecter les simulateurs mais c'est plus complexe
    // Pour simplifier, on utilise toujours l'URL cloud sur iOS physique
    
    if (isEmulator) {
      return localUrl;  // Utilise 10.0.2.2 pour émulateur Android
    }
    
    return cloudUrl;  // Utilise l'URL cloud pour les appareils physiques
  }
  
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
