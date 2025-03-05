import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:io' show Platform;

// Commenter/décommenter selon l'environnement
const bool useNgrok = false; // Désactivé
const String ngrokUrl = "https://cfae-195-220-106-83.ngrok-free.app"; // Non utilisé
const String localUrl = "http://10.0.2.2:5000"; // Pour émulateur Android
const String directUrl = "http://localhost:5000"; // Pour Windows/Web

String getBaseUrl() {
  if (kIsWeb || Platform.isWindows) {
    return directUrl;  // Utilise localhost pour Windows
  }
  if (isMobile()) {
    return localUrl;   // Utilise 10.0.2.2 pour émulateur Android
  }
  return "https://api.choiceapp.fr";
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
