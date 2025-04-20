import 'dart:convert';

/// Modèle de base pour les lieux sur les cartes
class Place {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final String image;
  final String category;
  final Map<String, dynamic>? details;
  
  // Propriétés supplémentaires pour place_info_card.dart
  final int? choicesCount;
  final String? priceRange;
  final String? description;
  final List<String>? openingHours;
  final List<String>? emotions;
  
  // Données brutes pour passage vers d'autres écrans
  final Map<String, dynamic> rawData;
  
  // Événements liés au lieu (pour les lieux avec plusieurs événements)
  final List<Map<String, dynamic>>? events;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating = 0,
    this.image = '',
    this.category = '',
    this.details,
    this.choicesCount,
    this.priceRange,
    this.description,
    this.openingHours,
    this.emotions,
    Map<String, dynamic>? rawData,
    this.events,
  }) : this.rawData = rawData ?? {
         'id': id,
         'name': name,
         'address': address,
         'latitude': latitude,
         'longitude': longitude,
         'rating': rating,
         'image': image,
         'category': category,
       };

  /// Crée une instance de Place à partir d'une Map
  factory Place.fromMap(Map<String, dynamic> map) {
    // Extraire les événements si présents
    List<Map<String, dynamic>>? events;
    if (map['events'] != null && map['events'] is List) {
      events = List<Map<String, dynamic>>.from(
        map['events'].map((e) => e is Map<String, dynamic> ? e : {}));
    }
    
    return Place(
      id: map['_id'] ?? map['id'] ?? '',
      name: map['name'] ?? map['title'] ?? map['intitulé'] ?? 'Sans nom',
      address: map['address'] ?? map['adresse'] ?? 'Adresse non disponible',
      latitude: _parseDouble(map['latitude']) ?? 
               (_parseDouble(map['location']?['coordinates']?[1]) ?? 0),
      longitude: _parseDouble(map['longitude']) ?? 
                (_parseDouble(map['location']?['coordinates']?[0]) ?? 0),
      rating: _parseDouble(map['rating']) ?? _parseDouble(map['note']) ?? 0,
      image: map['image'] ?? map['photo'] ?? map['photo_url'] ?? map['cover_image'] ?? '',
      category: map['category'] ?? map['catégorie'] ?? '',
      details: map['details'] as Map<String, dynamic>?,
      choicesCount: map['choicesCount'] ?? map['choices_count'],
      priceRange: map['priceRange'] ?? map['price_range'],
      description: map['description'] != null ? map['description'] : (map['détail'] != null ? map['détail'] : null),
      openingHours: map['openingHours'] is List ? List<String>.from(map['openingHours']) : null,
      emotions: map['emotions'] is List ? List<String>.from(map['emotions']) : null,
      rawData: Map<String, dynamic>.from(map),
      events: events,
    );
  }

  /// Crée une instance de Place à partir d'une chaîne JSON
  factory Place.fromJson(String source) => Place.fromMap(json.decode(source));

  /// Convertit l'instance en Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'image': image,
      'category': category,
      'details': details,
      'choicesCount': choicesCount,
      'priceRange': priceRange,
      'description': description,
      'openingHours': openingHours,
      'emotions': emotions,
      'events': events,
    };
  }

  /// Convertit l'instance en chaîne JSON
  String toJson() => json.encode(toMap());

  /// Utilitaire pour analyser correctement une valeur double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Crée une copie de l'instance avec certaines propriétés modifiées
  Place copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? rating,
    String? image,
    String? category,
    Map<String, dynamic>? details,
    int? choicesCount,
    String? priceRange,
    String? description,
    List<String>? openingHours,
    List<String>? emotions,
    Map<String, dynamic>? rawData,
    List<Map<String, dynamic>>? events,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      image: image ?? this.image,
      category: category ?? this.category,
      details: details ?? this.details,
      choicesCount: choicesCount ?? this.choicesCount,
      priceRange: priceRange ?? this.priceRange,
      description: description ?? this.description,
      openingHours: openingHours ?? this.openingHours,
      emotions: emotions ?? this.emotions,
      rawData: rawData ?? this.rawData,
      events: events ?? this.events,
    );
  }
  
  // Getter pour l'URL de l'image (pour faciliter l'accès)
  String get imageUrl => image;
} 