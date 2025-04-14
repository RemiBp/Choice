// screens/utils_web.dart (Flutter Web)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html';
import '../utils/constants.dart' as constants; // Import constants.dart pour la cohérence

String getBaseUrl() {
  print("🔄 [utils_web.dart] getBaseUrl() appelé");
  
  // Utiliser la même fonction que dans constants.dart  
  return constants.getBaseUrl();
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
