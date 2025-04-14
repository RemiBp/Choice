// Utility functions for the app
import 'dart:io' show Platform;
import 'utils/constants.dart' as constants;
import 'package:flutter/material.dart';
import 'dart:convert';

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