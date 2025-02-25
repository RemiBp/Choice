// screens/utils_io.dart (Mobile & Desktop)
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Pour utiliser `defaultTargetPlatform`
import 'utils.dart'; // ✅ Import du fichier principal pour garder la cohérence

String getBaseUrl() {
  return "https://api.choiceapp.fr"; // Plus d'utilisation de 10.0.2.2:5000
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
