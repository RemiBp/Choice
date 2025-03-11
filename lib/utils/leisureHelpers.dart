import 'package:intl/intl.dart';

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
    // Try to parse different date formats
    DateTime? parsedDate;
    
    // Try DD/MM/YYYY format (e.g., "29/04/2025")
    if (dateStr.contains('/')) {
      try {
        parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
        return DateFormat('d MMMM yyyy', 'fr_FR').format(parsedDate);
      } catch (e) {
        // Continue to other formats
      }
    }
    
    // Try YYYY-MM-DD format
    if (dateStr.contains('-')) {
      try {
        parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        return DateFormat('d MMMM yyyy', 'fr_FR').format(parsedDate);
      } catch (e) {
        // Continue to other formats
      }
    }

    // Handle text descriptions like "ven 7 mars"
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
    
    // If we couldn't parse or identify it, return as is
    return dateStr;
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

/// Gets an appropriate image URL for an event, handling null or empty values
String getEventImageUrl(Map<String, dynamic> event) {
  // Check if there's a direct image URL (primary field)
  if (event['image'] != null && event['image'].toString().isNotEmpty && 
      !event['image'].toString().contains('placeholder')) {
    return event['image'].toString();
  }
  
  // Check for image in alternate fields
  if (event['image_url'] != null && event['image_url'].toString().isNotEmpty && 
      !event['image_url'].toString().contains('placeholder')) {
    return event['image_url'].toString();
  }
  
  // Special case for billetreduc URLs 
  if (event['site_url'] != null && event['site_url'].toString().contains('billetreduc.com')) {
    String eventId = event['site_url'].toString().split('/').last.replaceAll('evt.htm', '');
    if (eventId.isNotEmpty) {
      return 'https://www.billetreduc.com/zg/n100/$eventId.jpeg';
    }
  }
  
  // If no image found, return a placeholder
  return 'https://via.placeholder.com/400x200?text=Événement';
}

/// Gets an appropriate image URL for a producer, handling null or empty values
String getProducerImageUrl(Map<String, dynamic> producer) {
  // Check if there's a direct image URL
  if (producer['image'] != null && producer['image'].toString().isNotEmpty && 
      !producer['image'].toString().contains('placeholder')) {
    return producer['image'].toString();
  }
  
  // Check for photo in alternate fields
  if (producer['photo'] != null && producer['photo'].toString().isNotEmpty && 
      !producer['photo'].toString().contains('placeholder')) {
    return producer['photo'].toString();
  }
  
  // Try to get image from first event if available
  if (producer['evenements'] != null && producer['evenements'] is List && 
      (producer['evenements'] as List).isNotEmpty) {
    final firstEvent = producer['evenements'][0];
    if (firstEvent != null && firstEvent['image'] != null) {
      return firstEvent['image'].toString();
    }
  }
  
  // If no image found, return a placeholder with producer name
  String producerName = producer['lieu'] ?? 'Lieu';
  return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(producerName)}&background=random&size=200';
}

/// Normalizes collection routes for consistent API access
String normalizeCollectionRoute(String collectionType, String id) {
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
      return '/api/producers/$id';
      
    case 'leisureproducer':
    case 'leisureproducers':
    case 'producerloisir':
    case 'producersloisir':
    case 'loisir_paris_producers':
      return '/api/leisureProducers/$id';
      
    default:
      return '/api/$collectionType/$id';
  }
}

/// Extracts an event ID from a link or event reference
/// Handles formats like "/Loisir_Paris_Evenements/676d7734bc725bb6e91c51ea"
String extractEventId(String link) {
  if (link == null || link.isEmpty) {
    return '';
  }
  
  // Handle typical format: "/Loisir_Paris_Evenements/676d7734bc725bb6e91c51ea"
  if (link.contains('/')) {
    final parts = link.split('/');
    // Get the last non-empty segment
    for (int i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) {
        return parts[i];
      }
    }
  }
  
  // If no slashes found, return the original (might be an ID directly)
  return link;
}

/// Capitalizes the first letter of a string
String _capitalizeFirstLetter(String text) {
  if (text.isEmpty) return '';
  return text[0].toUpperCase() + text.substring(1);
}