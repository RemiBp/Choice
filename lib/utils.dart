// Utility functions for the app
import 'dart:io' show Platform;
import 'utils/constants.dart' as constants;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Returns the base URL for API requests
String getBaseUrl() {
  print("! [utils.dart] ATTENTION: Version dépréciée de getBaseUrl() utilisée.");
  print("! [utils.dart] Veuillez modifier votre code pour utiliser constants.getBaseUrl() directement.");
  
  // Retourner l'URL de production
  return 'https://api.choiceapp.fr';
}

/// Fonction pour savoir si on est en environnement mobile
bool isMobile() {
  return constants.isMobile();
}

/// Vérifie si une chaîne est un ID MongoDB valide
/// Accepte les formats suivants:
/// - 24 caractères hexadécimaux (format standard)
/// - ObjectId sous forme de Map avec un champ "$oid"
/// - ID encapsulé dans un objet
bool isValidMongoId(dynamic id) {
  if (id == null) return false;
  
  // Cas 1: Chaîne directe de 24 caractères hexadécimaux
  if (id is String) {
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id);
  }
  
  // Cas 2: ObjectId sous forme de Map avec un champ "$oid"
  if (id is Map) {
    if (id.containsKey('\$oid') && id['\$oid'] is String) {
      return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id['\$oid']);
    }
    
    // Cas 3: ID dans un autre format de Map
    if (id.containsKey('_id')) {
      return isValidMongoId(id['_id']);
    }
    
    if (id.containsKey('id')) {
      return isValidMongoId(id['id']);
    }
  }
  
  return false;
}

/// Convertit n'importe quel format d'ID MongoDB en chaîne de 24 caractères hexadécimaux
String convertToMongoIdString(dynamic id) {
  if (id == null) return '';
  
  // Cas 1: Déjà une chaîne
  if (id is String) {
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
      return id;
    }
    // Essayer de parser la chaîne comme JSON au cas où ce serait un ObjectId sérialisé
    try {
      final parsed = json.decode(id);
      return convertToMongoIdString(parsed);
    } catch (e) {
      return id; // Retourner la chaîne si elle ne peut pas être parsée
    }
  }
  
  // Cas 2: ObjectId sous forme de Map avec un champ "$oid"
  if (id is Map) {
    if (id.containsKey('\$oid') && id['\$oid'] is String) {
      return id['\$oid'];
    }
    
    // Cas 3: ID dans un autre format de Map
    if (id.containsKey('_id')) {
      return convertToMongoIdString(id['_id']);
    }
    
    if (id.containsKey('id')) {
      return convertToMongoIdString(id['id']);
    }
  }
  
  // Fallback: convertir en chaîne
  return id.toString();
}

// Aide et support
const String SUPPORT_EMAIL = 'support@choiceapp.fr';
const String WEBSITE_URL = 'https://choiceapp.fr';
const String TERMS_URL = 'https://choiceapp.fr/terms';
const String PRIVACY_URL = 'https://choiceapp.fr/privacy';

/// Helper to get the correct ImageProvider from a string (network, base64, or null)
/// 
/// Cette fonction centralisée analyse une chaîne représentant une source d'image et retourne 
/// le bon ImageProvider selon son format:
/// 
/// - URL réseau (commençant par "http"): Utilise NetworkImage
/// - Image encodée en Base64 (commençant par "data:image"): Décode et utilise MemoryImage
/// - Null ou chaîne vide: Retourne null (l'appelant peut afficher une icône de remplacement)
/// - Autre format: Retourne null et affiche une erreur
/// 
/// Exemple d'utilisation:
/// ```dart
/// final imageProvider = getImageProvider(imageSource);
/// return Container(
///   child: imageProvider != null 
///     ? Image(image: imageProvider, fit: BoxFit.cover)
///     : Icon(Icons.image), // Image de remplacement
/// );
/// ```
/// 
/// Cette fonction gère également les erreurs de décodage et émet des logs appropriés.
ImageProvider? getImageProvider(String? imageSource) {
  // Liste de valeurs non valides à filtrer
  final invalidValues = [
    null, '', 'Exemple', 'N/A', 'null', 'undefined', 'none', 
    'example', 'fake', 'test', 'placeholder', 'default'
  ];
  
  if (imageSource == null || imageSource.isEmpty || invalidValues.contains(imageSource.trim().toLowerCase())) {
    // Retourner une image de remplacement depuis internet (ne nécessite pas d'assets locaux)
    return NetworkImage('https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80');
  }

  if (imageSource.startsWith('data:image')) {
    try {
      final commaIndex = imageSource.indexOf(',');
      if (commaIndex != -1) {
        final base64String = imageSource.substring(commaIndex + 1);
        final Uint8List bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } else {
        print('❌ Invalid Base64 Data URL format in getImageProvider');
        return NetworkImage('https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80');
      }
    } catch (e) {
      print('❌ Error decoding Base64 image in getImageProvider: $e');
      return NetworkImage('https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80');
    }
  } else if (imageSource.startsWith('http')) {
    // Assume it's a network URL
    try {
      return NetworkImage(imageSource);
    } catch (e) {
      print('❌ Error creating NetworkImage in getImageProvider: $e');
      return NetworkImage('https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80');
    }
  } else {
    print('❌ Unknown image source format in getImageProvider: $imageSource');
    return NetworkImage('https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80');
  }
}