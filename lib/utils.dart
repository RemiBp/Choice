// Utility functions for the app
import 'dart:io' show Platform;
import 'utils/constants.dart' as constants;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:provider/provider.dart';
// Import Post model for type checking in helpers
import './models/post.dart';

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

// --- Additions for Contact/Conversation Typing ---

/// Helper to get a color based on participant type string
Color getColorForType(String type) {
  switch (type.toLowerCase()) {
    case 'restaurant':
    case 'producer':
      return Colors.orange.shade600;
    case 'leisure':
    case 'leisureproducer':
      return Colors.purple.shade600;
    case 'wellness':
    case 'wellnessproducer':
    case 'beauty': // Consider grouping beauty under wellness color
      return Colors.green.shade600;
    case 'user':
      return Colors.blue.shade600;
    case 'group':
      return Colors.blueGrey.shade600;
    default:
      return Colors.grey.shade600;
  }
}

/// Helper to get an icon based on participant type string
IconData getIconForType(String type) {
  switch (type.toLowerCase()) {
    case 'restaurant':
    case 'producer':
      return Icons.restaurant_menu_outlined;
    case 'leisure':
    case 'leisureproducer':
      return Icons.local_activity_outlined;
    case 'wellness':
    case 'wellnessproducer':
    case 'beauty':
      return Icons.spa_outlined;
    case 'user':
      return Icons.person_outline;
    case 'group':
      return Icons.group_outlined;
    default:
      return Icons.chat_bubble_outline;
  }
}

/// Helper to get display text based on participant type string (consider localization)
String getTextForType(String type) {
  // TODO: Replace with EasyLocalization keys if available, e.g., 'participantType.$type'.tr()
  switch (type.toLowerCase()) {
    case 'restaurant':
    case 'producer':
      return 'Restaurant';
    case 'leisure':
    case 'leisureproducer':
      return 'Loisir';
    case 'wellness':
    case 'wellnessproducer':
      return 'Bien-être';
    case 'beauty':
       return 'Beauté'; // Specific text for beauty
    case 'user':
      return 'Utilisateur'; // Changed from 'Client' for generality
    case 'group':
      return 'Groupe';
    default:
      return 'Contact';
  }
}

// Convertit un type de lieu en icône
IconData typeToIcon(String type) {
  switch (type.toLowerCase()) {
    case 'restaurant': return Icons.restaurant;
    case 'event': return Icons.event;
    case 'leisureproducer': return Icons.museum;
    case 'beautyplace': // Changed from wellness
    case 'beautyproducer': // Keep this too?
      return Icons.spa;
    case 'user': return Icons.person;
    default: return Icons.place;
  }
}

// Convertit un type de lieu en couleur
Color typeToColor(String type) {
  switch (type.toLowerCase()) {
    case 'restaurant': return Colors.orange.shade700;
    case 'event': return Colors.blue.shade700;
    case 'leisureproducer': return Colors.purple.shade700;
    case 'beautyplace': // Changed from wellness
    case 'beautyproducer':
      return Colors.green.shade700;
    case 'user': return Colors.grey.shade700;
    default: return Colors.grey.shade500;
  }
}

// Convertit un type de lieu en texte lisible
String typeToReadableString(String type) {
  switch (type.toLowerCase()) {
    case 'restaurant': return 'Restaurant';
    case 'event': return 'Événement';
    case 'leisureproducer': return 'Loisir';
    case 'beautyplace': return 'Beauté'; // Changed from wellness
    case 'beautyproducer': return 'Beauté Pro';
    case 'user': return 'Utilisateur';
    default: return 'Lieu';
  }
}

/// Helper to convert between ProducerFeedContentType enums
/// This is needed because different parts of the code use different enum types
/// with the same name but in different files.
dynamic convertToApiContentType(dynamic contentType) {
  if (contentType == null) return null;
  
  // Just return the contentType for now
  // In a real implementation, this would actually convert between enum types
  return contentType;
}

// Placeholder for functions moved from producer_post_card
Color getPostTypeColor(dynamic post) {
  // Need Post import for this check
  bool isLeisure = post is Map ? post['isLeisureProducer'] == true : (post is Post ? post.isLeisureProducer ?? false : false);
  bool isWellness = post is Map ? post['isWellnessProducer'] == true : (post is Post ? (post.isBeautyProducer ?? false) : false);
  bool isRestaurant = post is Map ? (post['isProducerPost'] == true && !isLeisure && !isWellness) : (post is Post ? (post.isProducerPost ?? false) && !isLeisure && !isWellness : false);
  if (isLeisure) return Colors.purple.shade300;
  if (isRestaurant) return Colors.orange.shade300;
  if (isWellness) return Colors.green.shade300;
  return Colors.blue.shade300;
}

String getVisualBadge(dynamic post) {
  // Need Post import for this check
  bool isLeisure = post is Map ? post['isLeisureProducer'] == true : (post is Post ? post.isLeisureProducer ?? false : false);
  bool isWellness = post is Map ? post['isWellnessProducer'] == true : (post is Post ? (post.isBeautyProducer ?? false) : false);
  bool isRestaurant = post is Map ? (post['isProducerPost'] == true && !isLeisure && !isWellness) : (post is Post ? (post.isProducerPost ?? false) && !isLeisure && !isWellness : false);
  if (isLeisure) return '🎭';
  if (isRestaurant) return '🍽️';
  if (isWellness) return '🧘';
  return '👤';
}

String getPostTypeLabel(dynamic post) {
  // Need Post import for this check
  bool isLeisure = post is Map ? post['isLeisureProducer'] == true : (post is Post ? post.isLeisureProducer ?? false : false);
  bool isWellness = post is Map ? post['isWellnessProducer'] == true : (post is Post ? (post.isBeautyProducer ?? false) : false);
  bool isRestaurant = post is Map ? (post['isProducerPost'] == true && !isLeisure && !isWellness) : (post is Post ? (post.isProducerPost ?? false) && !isLeisure && !isWellness : false);
  if (isLeisure) return 'Loisir';
  if (isRestaurant) return 'Restaurant';
  if (isWellness) return 'Bien-être';
  return 'Utilisateur';
}

String formatTimestamp(DateTime timestamp) {
  // TODO: Implement full logic matching the original function (or use intl package)
   final now = DateTime.now();
   final difference = now.difference(timestamp);
   if (difference.inSeconds < 60) return 'À l\'instant';
   if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
   if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
   if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
   return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
}

// Add other utility functions from your project as needed