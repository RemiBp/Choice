// screens/utils_io.dart (Temporaire pour Web Build)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'utils.dart'; // ✅ Import du fichier principal pour garder la cohérence

String getBaseUrl() {
  return "https://api.choiceapp.fr"; // URL pour le Web
}

/// Vérifie si l'application tourne sur un mobile
bool isMobile() {
  return false; // Web n'est pas un mobile
}

/// Vérifie si l'application tourne sur un desktop (Windows, Mac, Linux)
bool isDesktop() {
  return false; // Web n'est pas un desktop natif
}

/// Vérifie si la plateforme supporte `dart:io`
bool supportsIO() {
  return false; // `dart:io` n'est pas disponible sur Web
}
