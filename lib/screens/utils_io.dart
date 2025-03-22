// screens/utils_io.dart (Mobile & Desktop)
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Pour utiliser `defaultTargetPlatform`
import 'dart:io' show Platform;
// Removed circular import of utils.dart

// ❌ Désactiver le mode développement local pour la production
const bool _useLocalServer = false; // Utiliser le serveur de production pour les appareils physiques

String getBaseUrl() {
  // Mode développement activé: retourne toujours l'URL locale
  if (_useLocalServer) {
    if (!kIsWeb && Platform.isAndroid) {
      // Sur Android, utiliser l'adresse spéciale pour accéder à localhost de l'hôte
      return "http://10.0.2.2:5000";
    } else {
      // Sur iOS et autres plateformes, utiliser localhost standard
      return "http://localhost:5000";
    }
  } 
  
  // Mode production (normal)
  else {
  // Cas spécifique: Émulateur Android uniquement
    if (!kIsWeb && Platform.isAndroid) {
      // Pour les tests de développement, toujours considérer comme émulateur
      // ⚠️ IMPORTANT: Mettre à true pour les tests sur émulateur, false pour le déploiement
      const bool forceEmulatorMode = false;
      
      bool isEmulator = forceEmulatorMode;
      
      if (!forceEmulatorMode) {
        try {
          // Méthode de détection améliorée pour les émulateurs Android
          String androidModel = Platform.operatingSystemVersion.toLowerCase();
          
          // Liste plus complète des indicateurs d'émulateur
          isEmulator = androidModel.contains('sdk') || 
                      androidModel.contains('emulator') || 
                      androidModel.contains('virtual') ||
                      androidModel.contains('genymotion') ||
                      androidModel.contains('nox') ||
                      androidModel.contains('bluestacks') ||
                      androidModel.contains('android studio');
        } catch (e) {
          // En cas d'erreur, on suppose que ce n'est pas un émulateur
          isEmulator = false;
        }
      }
      
      if (isEmulator) {
        print("🔧 Émulateur Android détecté - Utilisation de l'URL locale: http://10.0.2.2:5000");
        // Pour l'émulateur Android, utiliser l'adresse spéciale pour accéder au localhost de l'hôte
        return "http://10.0.2.2:5000";
      } else {
        print("🔗 Appareil Android physique détecté - Utilisation de l'URL cloud: https://api.choiceapp.fr");
      }
    }
    
    // Pour tous les autres cas (web, iOS, Android réel, etc.)
    return "https://api.choiceapp.fr";
  }
}

/// Vérifie si l'application tourne sur un mobile
bool isMobile() {
  if (kIsWeb) return false; // Sur Web, pas de mobile physique
  return defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS;
}

/// Vérifie si l'application tourne sur un desktop (Windows, Mac, Linux)
bool isDesktop() {
  if (kIsWeb) return false; // Sur Web, on n'est jamais sur un desktop natif
  return defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.linux; // ✅ Correction ici
}

/// Vérifie si l'IO est supporté
bool supportsIO() {
  return !kIsWeb; // Web ne supporte pas `dart:io`
}
