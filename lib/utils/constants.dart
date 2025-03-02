import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

String getBaseUrl() {
  if (isMobile() && !kIsWeb) {
    return "http://10.0.2.2:5000"; // Pour l'émulateur Android
  }
  return "https://api.choiceapp.fr"; // URL de production
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
