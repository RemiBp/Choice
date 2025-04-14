import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user_hotspot.dart';

/// Classe utilitaire pour générer des données de test
class FakerData {
  static final math.Random _random = math.Random();
  
  /// Génère un nombre aléatoire entre min et max
  static double randomDouble(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }
  
  /// Génère un entier aléatoire entre min et max
  static int randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }
  
  /// Génère une liste d'utilisateurs fictifs
  static List<Map<String, dynamic>> generateFakeUsers(int count) {
    final List<String> firstNames = [
      'Marie', 'Jean', 'Sophie', 'Thomas', 'Camille', 'Lucas', 'Léa', 'Julien',
      'Emma', 'Antoine', 'Chloé', 'Louis', 'Inès', 'Hugo', 'Sarah', 'Maxime'
    ];
    
    final List<String> lastNames = [
      'Martin', 'Bernard', 'Dubois', 'Thomas', 'Robert', 'Richard', 'Petit',
      'Durand', 'Leroy', 'Moreau', 'Simon', 'Laurent', 'Lefebvre', 'Michel'
    ];
    
    return List.generate(count, (index) {
      final String firstName = firstNames[_random.nextInt(firstNames.length)];
      final String lastName = lastNames[_random.nextInt(lastNames.length)];
      
      return {
        'id': 'user_${index + 1}',
        'name': '$firstName $lastName',
        'username': firstName.toLowerCase() + _random.nextInt(999).toString(),
        'email': '${firstName.toLowerCase()}.${lastName.toLowerCase()}@example.com',
        'avatar': 'https://randomuser.me/api/portraits/${_random.nextBool() ? 'women' : 'men'}/${_random.nextInt(100)}.jpg',
        'bio': 'Bio de $firstName $lastName',
        'following_count': randomInt(10, 500),
        'followers_count': randomInt(10, 1000),
        'posts_count': randomInt(5, 100),
        'joined_date': DateTime.now().subtract(Duration(days: randomInt(30, 1000))).toIso8601String(),
        'location': 'Paris, France',
        'website': _random.nextBool() ? 'https://${firstName.toLowerCase()}.com' : null,
      };
    });
  }
  
  /// Génère une liste de posts fictifs
  static List<Map<String, dynamic>> generateFakePosts(List<Map<String, dynamic>> users, int count) {
    final List<String> contentTemplates = [
      "J'ai découvert ce super restaurant aujourd'hui ! #foodie",
      "Superbe expérience au musée, je recommande !",
      "Soirée parfaite à {venue}, l'ambiance était incroyable",
      "Moment détente à {venue}, exactement ce dont j'avais besoin",
      "J'ai adoré la cuisine de {venue}, quelle découverte !",
      "Visite culturelle enrichissante à {venue}",
      "Petit café tranquille à {venue}, parfait pour travailler",
      "Journée shopping réussie à {venue}",
      "Concert inoubliable à {venue} hier soir",
      "Dégustation exceptionnelle à {venue}"
    ];
    
    final List<String> venues = [
      "La Belle Époque", "Le Petit Café", "Musée d'Art Moderne", 
      "Bistrot du Coin", "Galerie Lafayette", "Le Club Parisien",
      "Théâtre du Chatelet", "Centre Pompidou", "La Rotonde",
      "Café de Paris", "Le Grand Rex", "La Maison Bleue"
    ];
    
    final List<String> categories = [
      "Restaurant", "Café", "Bar", "Musée", "Galerie", 
      "Théâtre", "Cinéma", "Shopping", "Concert", "Parc"
    ];
    
    return List.generate(count, (index) {
      final user = users[_random.nextInt(users.length)];
      final String venue = venues[_random.nextInt(venues.length)];
      String content = contentTemplates[_random.nextInt(contentTemplates.length)];
      content = content.replaceAll('{venue}', venue);
      
      // Paris coordinates for random locations
      final double baseLat = 48.8566;
      final double baseLng = 2.3522;
      final double lat = baseLat + randomDouble(-0.05, 0.05);
      final double lng = baseLng + randomDouble(-0.05, 0.05);
      
      return {
        'id': 'post_${index + 1}',
        'user_id': user['id'],
        'user_name': user['name'],
        'user_avatar': user['avatar'],
        'content': content,
        'likes_count': randomInt(0, 100),
        'comments_count': randomInt(0, 30),
        'created_at': DateTime.now().subtract(Duration(hours: randomInt(1, 720))).toIso8601String(),
        'images': _random.nextBool() ? [
          'https://source.unsplash.com/random/400x300?${categories[_random.nextInt(categories.length)].toLowerCase()}'
        ] : [],
        'location': {
          'name': venue,
          'category': categories[_random.nextInt(categories.length)],
          'address': '${randomInt(1, 100)} rue de ${venues[_random.nextInt(venues.length)]}, Paris',
          'coordinates': [lng, lat],
        },
      };
    });
  }
  
  /// Génère une liste de hotspots fictifs pour la heatmap
  static List<UserHotspot> generateFakeHotspots(LatLng center, int count, {double maxRadius = 5000}) {
    final List<String> zoneNames = [
      'Quartier Montmartre', 'Quartier Latin', 'Opéra', 'Marais', 
      'Saint-Germain', 'Bastille', 'Belleville', 'Champs-Élysées',
      'République', 'Montparnasse', 'La Défense', 'Batignolles',
      'Bercy', 'Canal Saint-Martin'
    ];
    
    return List.generate(count, (index) {
      // Calculer des coordonnées aléatoires dans le rayon
      final double radius = randomDouble(0, maxRadius);
      final double angle = randomDouble(0, 2 * math.pi);
      final double lat = center.latitude + (radius / 111320) * math.sin(angle);
      final double lng = center.longitude + (radius / (111320 * math.cos(center.latitude * math.pi / 180))) * math.cos(angle);
      
      // Générer des distributions temporelles
      final Map<String, double> timeDistribution = {
        'morning': randomDouble(0.1, 0.4),
        'afternoon': randomDouble(0.2, 0.5),
        'evening': randomDouble(0.2, 0.6),
      };
      
      // Normaliser pour que la somme soit égale à 1.0
      final double timeSum = timeDistribution.values.reduce((a, b) => a + b);
      timeDistribution.forEach((key, value) {
        timeDistribution[key] = value / timeSum;
      });
      
      // Générer des distributions par jour
      final Map<String, double> dayDistribution = {
        'monday': randomDouble(0.05, 0.15),
        'tuesday': randomDouble(0.05, 0.15),
        'wednesday': randomDouble(0.1, 0.2),
        'thursday': randomDouble(0.1, 0.2),
        'friday': randomDouble(0.15, 0.25),
        'saturday': randomDouble(0.15, 0.3),
        'sunday': randomDouble(0.1, 0.25),
      };
      
      // Normaliser pour que la somme soit égale à 1.0
      final double daySum = dayDistribution.values.reduce((a, b) => a + b);
      dayDistribution.forEach((key, value) {
        dayDistribution[key] = value / daySum;
      });
      
      return UserHotspot(
        id: 'hotspot_${index + 1}',
        latitude: lat,
        longitude: lng,
        zoneName: zoneNames[_random.nextInt(zoneNames.length)],
        intensity: randomDouble(0.2, 1.0),
        visitorCount: randomInt(10, 500),
        timeDistribution: timeDistribution,
        dayDistribution: dayDistribution,
      );
    });
  }
} 