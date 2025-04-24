import 'constants.dart' as constants;
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils.dart' as root_utils;

/// Returns the base URL for API requests
String getBaseUrl() {
  print("! [utils.dart] ATTENTION: Version dépréciée de getBaseUrl() utilisée.");
  print("! [utils.dart] Veuillez modifier votre code pour utiliser constants.getBaseUrlSync() directement.");
  
  // Retourner l'URL de production en utilisant la méthode synchrone
  return constants.getBaseUrlSync();
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

// Pour le service spécifique (était précédemment localhost:3000)
String getServiceUrl() {
  return 'https://api.choiceapp.fr';
}

// Version asynchrone ajoutée pour harmoniser avec recover_producer.dart
Future<String> getBaseUrlAsync() async {
  // On utilise également getBaseUrlSync() mais on la wrap dans une Future pour
  // avoir la même signature que dans recover_producer.dart
  print("✅ [utils.dart] Utilisation de getBaseUrlAsync()");
  
  // Retourner l'URL depuis constants
  final url = constants.getBaseUrlSync();
  
  // Option: Tester la connectivité
  try {
    await http.get(Uri.parse('$url/api/ping'))
      .timeout(const Duration(seconds: 3));
    print("✅ [utils.dart] API accessible: $url");
  } catch (e) {
    print("⚠️ [utils.dart] Avertissement: L'API $url n'est peut-être pas accessible: $e");
    // On continue quand même avec l'URL
  }
  
  return url;
}

/// Redirection vers la fonction getImageProvider dans le fichier principal utils.dart
/// pour éviter les duplications et maintenir la cohérence
ImageProvider? getImageProvider(String? imageSource) {
  // Rediriger vers l'implémentation principale dans utils.dart
  return root_utils.getImageProvider(imageSource);
}

// Autres fonctions utilitaires...