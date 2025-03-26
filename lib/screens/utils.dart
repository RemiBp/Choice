// screens/utils.dart (Gestion des imports conditionnels)
// Properly handle platform-specific exports with mutual exclusion
// When compiling for web, only utils_web.dart should be included
// When compiling for mobile/desktop, only utils_io.dart should be included
export 'utils_stub.dart'
    if (dart.library.html) 'utils_web.dart'
    if (dart.library.io) 'utils_io.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

/// Récupère l'URL de base pour les appels API en fonction de l'environnement
String getBaseUrl() {
  // En mode web
  if (kIsWeb) {
    return 'http://localhost:5000';
  }
  
  // Sur un émulateur Android
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:5000';
  }
  
  // Sur un émulateur iOS ou macOS
  if (Platform.isIOS || Platform.isMacOS) {
    return 'http://localhost:5000';
  }
  
  // Par défaut
  return 'http://localhost:5000';
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