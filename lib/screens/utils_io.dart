// screens/utils_io.dart (Mobile & Desktop)
import 'dart:io';
import 'utils.dart'; // ✅ Import du fichier principal pour garder la cohérence

String getBaseUrl() {
  return "https://api.choiceapp.fr"; // Plus d'utilisation de 10.0.2.2:5000
}

/// Vérifie si l'application tourne sur un mobile
bool isMobile() {
  return Platform.isAndroid || Platform.isIOS;
}

/// Vérifie si l'application tourne sur un desktop (Windows, Mac, Linux)
bool isDesktop() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Vérifie si la plateforme supporte `dart:io`
bool supportsIO() {
  return true; // `dart:io` est bien disponible ici
}
