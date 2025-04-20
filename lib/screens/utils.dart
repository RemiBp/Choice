// screens/utils.dart (Gestion des imports conditionnels)
// Properly handle platform-specific exports with mutual exclusion
// When compiling for web, only utils_web.dart should be included
// When compiling for mobile/desktop, only utils_io.dart should be included
export 'utils_stub.dart'
    if (dart.library.html) 'utils_web.dart'
    if (dart.library.io) 'utils_io.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart' as constants; // Import de constants.dart pour rediriger

// Adresse IP pour les environnements de développement (obsolète)
const String LOCAL_MACHINE_IP = "api.choiceapp.fr"; // Force l'adresse de production

/// Récupère l'URL de base pour les appels API en fonction de l'environnement
/// ⚠️ DÉPRÉCIÉ: Utilisez plutôt constants.getBaseUrl() directement
Future<String> getBaseUrl() async {
  print("⚠️ [utils.dart] ATTENTION: Version dépréciée de getBaseUrl() utilisée.");
  print("⚠️ [utils.dart] Veuillez modifier votre code pour utiliser constants.getBaseUrl() directement.");
  
  // Rediriger vers la version officielle dans constants.dart
  return constants.getBaseUrl();
}

/// Formate un nombre pour l'affichage (ex: 1200 -> 1.2K)
String formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  } else {
    return number.toString();
  }
}

/// Convertit une date ISO en format lisible
String formatDate(String isoDate) {
  try {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${diff.inMinutes} min';
      }
      return 'Il y a ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  } catch (e) {
    return 'Date inconnue';
  }
}