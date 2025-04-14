class Producer {
  final String id;
  final String name;
  final String? address;
  final Map<String, dynamic>? gpsCoordinates;
  final double? rating;
  final String? photo;
  final String? description;
  final List<String>? categories;
  final List<dynamic>? dishTypes;
  final Map<String, dynamic>? notesGlobales;

  Producer({
    required this.id,
    required this.name,
    this.address,
    this.gpsCoordinates,
    this.rating,
    this.photo,
    this.description,
    this.categories,
    this.dishTypes,
    this.notesGlobales,
  });

  // Getter pour obtenir la première catégorie
  String? get category => categories != null && categories!.isNotEmpty ? categories![0] : null;

  // Fonction utilitaire pour convertir une note qui peut être au format français
  static double? parseRating(dynamic value) {
    if (value == null) return null;
    
    // Si c'est déjà un double ou un int, le retourner directement
    if (value is double) return value;
    if (value is int) return value.toDouble();
    
    // Si c'est une chaîne, essayer de la convertir
    if (value is String) {
      // Supprimer tout caractère non numérique sauf le point et la virgule
      String sanitized = value.replaceAll(RegExp(r'[^0-9.,]'), '');
      
      // Remplacer la virgule par un point pour le format standard
      sanitized = sanitized.replaceAll(',', '.');
      
      try {
        return double.parse(sanitized);
      } catch (e) {
        print('Erreur de conversion de note: $value - $e');
        return null;
      }
    }
    
    return null;
  }

  factory Producer.fromJson(Map<String, dynamic> json) {
    // Handle different category formats
    List<String>? categoriesList;
    if (json['category'] != null) {
      if (json['category'] is List) {
        // If category is already a list, convert it to List<String>
        categoriesList = List<String>.from(
          (json['category'] as List).map((item) => item.toString())
        );
      } else if (json['category'] is String) {
        // If category is a single string, create a list with that single item
        categoriesList = [json['category'] as String];
      }
    }

    return Producer(
      id: json['_id'],
      name: json['name'],
      address: json['address'],
      gpsCoordinates: json['gps_coordinates'],
      rating: parseRating(json['rating']),
      photo: json['photo'],
      description: json['description'],
      categories: categoriesList,
      dishTypes: json['dish_types'],
      notesGlobales: json['notes_globales'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'address': address,
      'gps_coordinates': gpsCoordinates,
      'rating': rating,
      'photo': photo,
      'description': description,
      'category': categories,
      'dish_types': dishTypes,
      'notes_globales': notesGlobales,
    };
  }
} 