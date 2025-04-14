// screens/utils_io.dart (Mobile & Desktop)
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Pour utiliser `defaultTargetPlatform`
import 'dart:io' show Platform;
import '../utils/constants.dart' as constants; // Import constants.dart pour la cohérence
// Removed circular import of utils.dart

// ✅ ACTIVER le mode développement local pour les tests
const bool _useLocalServer = true; // Utiliser le serveur local pour tous les appareils
// Adresse IP de la machine sur le réseau local (pour appareil physique Android)
const String LOCAL_MACHINE_IP = "api.choiceapp.fr";

// Déterminer si l'application est en mode production
const bool isProduction = bool.fromEnvironment('dart.vm.product', defaultValue: false);

/// Récupère l'URL de base pour les appels API en fonction de l'environnement
/// ⚠️ OBSOLÈTE: Utilisez constants.getBaseUrl() directement
String getBaseUrl() {
  print("⚠️ [utils_io.dart] ATTENTION: Version dépréciée de getBaseUrl() utilisée.");
  print("⚠️ [utils_io.dart] Veuillez modifier votre code pour utiliser constants.getBaseUrl() directement.");
  
  // Utiliser la même fonction que dans constants.dart
  return constants.getBaseUrlSync();
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
