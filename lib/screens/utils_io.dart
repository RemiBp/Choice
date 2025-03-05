// screens/utils_io.dart (Mobile & Desktop)
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Pour utiliser `defaultTargetPlatform`
import 'dart:io' show Platform;
import 'utils.dart'; // ✅ Import du fichier principal pour garder la cohérence

String getBaseUrl() {
  // Cas spécifique: Émulateur Android uniquement
  if (!kIsWeb && Platform.isAndroid) {
    // Vérifier si c'est un émulateur Android
    bool isEmulator = false;
    
    try {
      // Cette vérification est assez basique mais fonctionne dans la plupart des cas
      // Les émulateurs Android ont généralement des noms de modèles spécifiques
      String androidModel = Platform.operatingSystemVersion.toLowerCase();
      isEmulator = androidModel.contains('sdk') || 
                  androidModel.contains('emulator') || 
                  androidModel.contains('virtual');
    } catch (e) {
      // En cas d'erreur, on suppose que ce n'est pas un émulateur
      isEmulator = false;
    }
    
    if (isEmulator) {
      // Pour l'émulateur Android uniquement, utiliser l'adresse spéciale
      return "http://10.0.2.2:5000";
    }
  }
  
  // Pour tous les autres cas (web, iOS, Android réel, etc.)
  return "https://api.choiceapp.fr";
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
