import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Retourne l'URL du backend en fonction de la plateforme
String getBaseUrl() {
  return kIsWeb ? "https://api.choiceapp.fr" : "http://10.0.2.2:5000";
}

/// Vérifie si on est sur mobile (évite les erreurs `dart:io` sur Web)
bool isMobile() {
  return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
