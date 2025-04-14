import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

/// Formats event date for display based on various possible source formats
/// Handles formats like DD/MM/YYYY, text descriptions (e.g., "ven 7 mars"), etc.
String formatEventDate(dynamic dateInput) {
  if (dateInput == null) return 'Date non disponible';
  
  // If already a string, clean it up
  String dateStr = dateInput.toString();
  if (dateStr.isEmpty || dateStr == 'Dates non disponibles') {
    return 'Date non disponible';
  }
  
  try {
    // Vérifier s'il s'agit d'une plage de dates
    if (dateStr.contains('-') && !dateStr.contains('/')) {
      final parts = dateStr.split('-');
      if (parts.length == 2) {
        String startDate = formatEventDate(parts[0].trim());
        String endDate = formatEventDate(parts[1].trim());
        return '$startDate - $endDate';
      }
    }
    
    // Try to parse different date formats
    DateTime? parsedDate;
    
    // Try DD/MM/YYYY format (e.g., "10/01/2025")
    if (dateStr.contains('/')) {
      try {
        List<String> parts = dateStr.split('/');
        if (parts.length == 3) {
          parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
          return DateFormat('d MMMM yyyy', 'fr_FR').format(parsedDate);
        }
      } catch (e) {
        // Continue to other formats
      }
    }
    
    // Try YYYY-MM-DD format (ISO format)
    if (dateStr.contains('-') && dateStr.length >= 8) {
      try {
        parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        return DateFormat('d MMMM yyyy', 'fr_FR').format(parsedDate);
      } catch (e) {
        // Continue to other formats
      }
    }

    // Handle MongoDB date format "date_debut: 10/01/2025" or date_fin/date_debut fields
    if (dateStr.toLowerCase().contains('date_debut') || dateStr.toLowerCase().contains('date_fin')) {
      final dateRegex = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})');
      final match = dateRegex.firstMatch(dateStr);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);
        parsedDate = DateTime(year, month, day);
        return DateFormat('d MMMM yyyy', 'fr_FR').format(parsedDate);
      }
    }
    
    // Handle text descriptions like "ven 14 févr." or "ven 7 mars"
    List<String> months = [
      'janv', 'févr', 'mars', 'avr', 'mai', 'juin', 
      'juil', 'août', 'sept', 'oct', 'nov', 'déc'
    ];
    
    for (int i = 0; i < months.length; i++) {
      if (dateStr.toLowerCase().contains(months[i])) {
        // This is likely a text description with month, return as is but capitalize
        return _capitalizeFirstLetter(dateStr);
      }
    }
    
    // If we can't parse it as a date but it seems to be a date description
    if (dateStr.contains('ven') || 
        dateStr.contains('sam') || 
        dateStr.contains('dim') || 
        dateStr.contains('lun') || 
        dateStr.contains('mar') || 
        dateStr.contains('mer') || 
        dateStr.contains('jeu')) {
      return _capitalizeFirstLetter(dateStr);
    }
    
    // Try to extract any date pattern from the string
    final dateRegExp = RegExp(r'(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})');
    final match = dateRegExp.firstMatch(dateStr);
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        if (year < 100) year += 2000; // Assume 2-digit years are in the 2000s
        
        parsedDate = DateTime(year, month, day);
        return DateFormat('d MMMM yyyy', 'fr_FR').format(parsedDate);
      } catch (e) {
        print('⚠️ Error creating DateTime from regex match: $e');
      }
    }
    
    // If we couldn't parse or identify it, return as is but capitalized
    return _capitalizeFirstLetter(dateStr);
  } catch (e) {
    print('⚠️ Error formatting date: $e');
    return dateStr; // Return original string if parsing fails
  }
}

/// Determines if an event has already passed based on its date information
bool isEventPassed(Map<String, dynamic> event) {
  // Current date for comparison
  final now = DateTime.now();
  
  // Try to determine end date from various fields
  String? dateStr = event['date_fin'];
  if (dateStr == null || dateStr.isEmpty) {
    dateStr = event['date_debut'];
  }
  if (dateStr == null || dateStr.isEmpty) {
    dateStr = event['prochaines_dates']?.toString();
  }
  
  // If no date information, consider it as not passed (upcoming)
  if (dateStr == null || dateStr.isEmpty || dateStr == 'Dates non disponibles') {
    return false;
  }
  
  try {
    // Try different date formats
    DateTime? eventDate;
    
    // Check for DD/MM/YYYY format
    if (dateStr.contains('/')) {
      try {
        eventDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      } catch (e) {
        // Continue to next format
      }
    }
    
    // Check for YYYY-MM-DD format
    if (eventDate == null && dateStr.contains('-')) {
      try {
        eventDate = DateFormat('yyyy-MM-dd').parse(dateStr);
      } catch (e) {
        // Continue to next format
      }
    }
    
    // If we have a parseable date, check if it's in the past
    if (eventDate != null) {
      // Add 1 day to handle events that end today
      final adjustedDate = eventDate.add(const Duration(days: 1));
      return adjustedDate.isBefore(now);
    }
    
    // Handle text descriptions like "ven 7 mars"
    // Extract the month and day if possible
    List<String> frenchMonths = [
      'janv', 'févr', 'mars', 'avr', 'mai', 'juin', 
      'juil', 'août', 'sept', 'oct', 'nov', 'déc'
    ];
    
    for (int i = 0; i < frenchMonths.length; i++) {
      if (dateStr.toLowerCase().contains(frenchMonths[i])) {
        // Try to extract the day from string like "ven 7 mars"
        final dayMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(dateStr);
        if (dayMatch != null) {
          final day = int.parse(dayMatch.group(1)!);
          // Month is 0-based in DateTime, but 1-based in our list
          final month = i + 1;
          // Use current year or next year if the month is earlier than current month
          int year = now.year;
          if (month < now.month) {
            year = now.year + 1; // It's likely next year's date
          }
          
          final approximateDate = DateTime(year, month, day);
          return approximateDate.isBefore(now);
        }
      }
    }
    
    // If we can't parse the date, default to not passed
    return false;
  } catch (e) {
    print('⚠️ Error determining if event passed: $e');
    return false; // Default to not passed if we encounter an error
  }
}

/// Gets an appropriate image URL for a producer, handling null or empty values
String getProducerImageUrl(Map<String, dynamic> producer) {
  // Check if there's a direct image URL
  if (producer['image'] != null && producer['image'].toString().isNotEmpty && 
      !producer['image'].toString().contains('placeholder')) {
    final imageStr = producer['image'].toString();
    
    // Traiter les images en base64
    if (imageStr.startsWith('data:image')) {
      // L'image est déjà au format base64, la retourner telle quelle
      return imageStr;
    } else if (imageStr.startsWith('http')) {
      // URL normale, la retourner telle quelle
      return imageStr;
    }
  }
  
  // Check for photo in alternate fields
  if (producer['photo'] != null && producer['photo'].toString().isNotEmpty && 
      !producer['photo'].toString().contains('placeholder')) {
    return producer['photo'].toString();
  }
  
  // Check for photos array
  if (producer['photos'] != null && producer['photos'] is List && (producer['photos'] as List).isNotEmpty) {
    final firstPhoto = producer['photos'][0];
    if (firstPhoto != null && firstPhoto.toString().isNotEmpty) {
      return firstPhoto.toString();
    }
  }
  
  // Try to get image from first event if available
  if (producer['evenements'] != null && producer['evenements'] is List && 
      (producer['evenements'] as List).isNotEmpty) {
    final firstEvent = producer['evenements'][0];
    if (firstEvent != null) {
      // Essayer d'abord le champ image directement dans l'événement
      if (firstEvent['image'] != null && firstEvent['image'].toString().isNotEmpty) {
        return firstEvent['image'].toString();
      }
      
      // Sinon, essayer de récupérer l'ID de l'événement et construire une URL d'image
      if (firstEvent['lien_evenement'] != null) {
        final eventId = extractEventId(firstEvent['lien_evenement'].toString());
        if (eventId.isNotEmpty) {
          return 'https://www.billetreduc.com/zg/n100/$eventId.jpeg';
        }
      }
    }
  }
  
  // If no image found, return a placeholder with producer name
  String producerName = producer['lieu'] ?? producer['name'] ?? 'Lieu';
  return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(producerName)}&background=random&size=200';
}

/// Gets an appropriate image URL for an event, handling null or empty values
String getEventImageUrl(Map<String, dynamic> event) {
  // Vérifier les champs image dans l'ordre de priorité
  final imageCandidates = [
    'image',
    'image_url',
    'photo',
    'thumbnail',
    'cover',
    'cover_image',
    'banner'
  ];
  
  for (String field in imageCandidates) {
    if (event[field] != null && 
        event[field].toString().isNotEmpty && 
        !event[field].toString().contains('placeholder')) {
      final imageStr = event[field].toString();
      
      // Traiter correctement les images en base64
      if (imageStr.startsWith('data:image')) {
        return imageStr; // Déjà en base64, retourner telle quelle
      } else if (imageStr.startsWith('http')) {
        return imageStr; // URL normale, retourner telle quelle
      }
    }
  }
  
  // Traiter les cas spéciaux de Shotgun Live
  if (event['site_url'] != null && event['site_url'].toString().contains('shotgun.live')) {
    // Chercher dans lineup[].image ou d'autres champs imbriqués
    if (event['lineup'] != null && event['lineup'] is List && (event['lineup'] as List).isNotEmpty) {
      final firstArtist = event['lineup'][0];
      if (firstArtist != null && firstArtist['image'] != null && 
          firstArtist['image'].toString().isNotEmpty) {
        return firstArtist['image'].toString();
      }
    }
  }
  
  // Special case for billetreduc URLs 
  if (event['site_url'] != null && event['site_url'].toString().contains('billetreduc.com')) {
    String eventId = event['site_url'].toString().split('/').last.replaceAll('evt.htm', '');
    if (eventId.isNotEmpty) {
      return 'https://www.billetreduc.com/zg/n100/$eventId.jpeg';
    }
  }
  
  // Chercher dans tous les champs pour trouver des URL d'images
  for (var key in event.keys) {
    final value = event[key];
    if (value is String && 
        value.isNotEmpty && 
        (value.startsWith('http') || value.startsWith('https')) &&
        (value.endsWith('.jpg') || value.endsWith('.jpeg') || 
         value.endsWith('.png') || value.endsWith('.webp'))) {
      return value;
    }
  }
  
  // If no image found, return a placeholder
  String eventName = event['intitulé'] ?? event['title'] ?? 'Événement';
  return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(eventName)}&background=random&size=200';
}

/// Normalizes collection routes for consistent API access
String normalizeCollectionRoute(String collectionType, String id) {
  // Fonction helper pour essayer des routes alternatives si la première échoue
  switch (collectionType.toLowerCase()) {
    case 'event':
    case 'events':
    case 'evenement':
    case 'evenements':
    case 'loisir_paris_evenements':
      return '/api/events/$id';
      
    case 'producer':
    case 'producers':
    case 'producteur':
    case 'producteurs':
      // Retourner à la fois l'endpoint producer et leisureProducer pour tester les deux
      return '/api/producers/$id';
      
    case 'leisureproducer':
    case 'leisure_producer':
    case 'leisure_producers':
    case 'leisureproducers':
    case 'producerloisir':
    case 'producersloisir':
    case 'loisir_paris_producers':
      return '/api/leisureProducers/$id';
      
    default:
      // Si le type n'est pas reconnu, essayer de déduire le type basé sur l'ID
      if (id.length == 24) { // Format MongoDB ObjectId typique
        // Essayer les deux endpoints pour éviter les 404
        return '/api/producers/$id';
      }
      return '/api/$collectionType/$id';
  }
}

/// Extracts an event ID from a link or event reference
/// Handles formats like "/Loisir_Paris_Evenements/676d7734bc725bb6e91c51ea"
String extractEventId(String link) {
  if (link == null || link.isEmpty) {
    return '';
  }
  
  // Si c'est un ID MongoDB complet, le retourner directement
  if (RegExp(r'^[a-f0-9]{24}$').hasMatch(link)) {
    return link;
  }
  
  // Handle typical format: "/Loisir_Paris_Evenements/676d7734bc725bb6e91c51ea"
  if (link.contains('/')) {
    final parts = link.split('/');
    // Parcourir de droite à gauche et trouver le premier segment qui ressemble à un ID MongoDB
    for (int i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) {
        // Vérifier si c'est un ObjectId MongoDB (24 caractères hex)
        if (RegExp(r'^[a-f0-9]{24}$').hasMatch(parts[i])) {
          return parts[i];
        }
        // Sinon retourner le dernier segment non vide
        return parts[i];
      }
    }
  }
  
  // Si aucune barre oblique n'est trouvée, retourner l'original
  return link;
}

/// Fonction utilitaire pour tester les deux endpoints de producteurs (normal et loisir)
/// Utiliser cette fonction dans les écrans pour éviter les erreurs 404
/// Le paramètre baseUrl peut être une String ou Future<String>
Future<Map<String, dynamic>?> fetchProducerWithFallback(String producerId, http.Client client, dynamic baseUrl) async {
  // Résoudre baseUrl si c'est un Future
  String resolvedBaseUrl;
  if (baseUrl is Future<String>) {
    resolvedBaseUrl = await baseUrl;
  } else {
    resolvedBaseUrl = baseUrl.toString();
  }
  
  // D'abord essayer l'endpoint producer standard
  try {
    final standardUrl = '$resolvedBaseUrl/api/producers/$producerId';
    final response = await client.get(Uri.parse(standardUrl));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
  } catch (e) {
    print('⚠️ Error fetching from standard producer endpoint: $e');
  }
  
  // Si échec, essayer l'endpoint leisureProducer
  try {
    final leisureUrl = '$resolvedBaseUrl/api/leisureProducers/$producerId';
    final response = await client.get(Uri.parse(leisureUrl));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
  } catch (e) {
    print('⚠️ Error fetching from leisure producer endpoint: $e');
  }
  
  // Si les deux échouent, retourner null
  return null;
}

/// Capitalizes the first letter of a string
String _capitalizeFirstLetter(String text) {
  if (text.isEmpty) return '';
  return text[0].toUpperCase() + text.substring(1);
}