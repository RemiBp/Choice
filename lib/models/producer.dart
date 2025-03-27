class Producer {
  final String id;
  final String name;
  final String? address;
  final Map<String, dynamic>? gpsCoordinates;
  final double? rating;
  final String? photo;
  final String? description;
  final List<dynamic>? categories;
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

  factory Producer.fromJson(Map<String, dynamic> json) {
    return Producer(
      id: json['_id'],
      name: json['name'],
      address: json['address'],
      gpsCoordinates: json['gps_coordinates'],
      rating: json['rating']?.toDouble(),
      photo: json['photo'],
      description: json['description'],
      categories: json['category'],
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