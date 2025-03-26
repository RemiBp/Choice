import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:io' show Platform;

// Configuration des URL serveur - NE PAS MODIFIER en production
const bool useNgrok = false; // Désactivé
const String ngrokUrl = "https://cfae-195-220-106-83.ngrok-free.app"; // Non utilisé
const String localUrl = "http://10.0.2.2:5000"; // Pour émulateur Android
const String directUrl = "http://localhost:5000"; // Pour Windows/Web
const String cloudUrl = "https://api.choiceapp.fr"; // Pour les appareils physiques

String getBaseUrl() {
  // Solution plus directe pour iOS - toujours utiliser l'URL cloud
  if (Platform.isIOS) {
    print("🔗 iOS détecté - Utilisation de l'URL cloud: $cloudUrl");
    return cloudUrl;
  }
  
  // Pour le web et Windows, utiliser localhost
  if (kIsWeb || Platform.isWindows) {
    print("🔗 Web/Windows détecté - Utilisation de l'URL directe: $directUrl");
    return directUrl;
  }
  
  // Pour Android, différencier émulateur et appareil physique
  if (Platform.isAndroid) {
    // On considère que c'est un appareil physique par défaut
    bool isEmulator = false;
    
    try {
      // Méthode améliorée pour détecter un émulateur Android
      String androidModel = Platform.operatingSystemVersion.toLowerCase();
      isEmulator = androidModel.contains('sdk') || 
                  androidModel.contains('emulator') || 
                  androidModel.contains('virtual');
                  
      // Vérification additionnelle pour certains modèles d'émulateurs
      if (!isEmulator) {
        String? model = Platform.environment['ANDROID_MODEL'];
        isEmulator = model != null && (
          model.contains('sdk') || 
          model.contains('emulator') || 
          model.contains('Android SDK')
        );
      }
    } catch (e) {
      print("⚠️ Erreur lors de la détection d'émulateur: $e");
      isEmulator = false;
    }
    
    if (isEmulator) {
      print("🔗 Émulateur Android détecté - Utilisation de l'URL locale: $localUrl");
      return localUrl;
    } else {
      print("🔗 Appareil Android physique détecté - Utilisation de l'URL cloud: $cloudUrl");
      return cloudUrl;
    }
  }
  
  // Par défaut, TOUJOURS utiliser l'URL cloud pour éviter les erreurs de connexion
  print("🔗 Plateforme par défaut - Utilisation de l'URL cloud: $cloudUrl");
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
