import 'dart:convert';

class GpsCoordinates {
  final double latitude;
  final double longitude;

  GpsCoordinates({
    required this.latitude,
    required this.longitude,
  });

  factory GpsCoordinates.fromJson(Map<String, dynamic> json) {
    if (json['lat'] != null && json['lng'] != null) {
      return GpsCoordinates(
        latitude: json['lat'].toDouble(),
        longitude: json['lng'].toDouble(),
      );
    } else if (json['latitude'] != null && json['longitude'] != null) {
      return GpsCoordinates(
        latitude: json['latitude'].toDouble(),
        longitude: json['longitude'].toDouble(),
      );
    } else if (json is List && json.length >= 2) {
      return GpsCoordinates(
        latitude: json[1].toDouble(),
        longitude: json[0].toDouble(),
      );
    } else {
      return GpsCoordinates(
        latitude: 48.8566,
        longitude: 2.3522,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class WellnessProducer {
  final String id;
  String name;
  String description;
  String address;
  String phone;
  String email;
  String website;
  final String category;
  final String sous_categorie;
  final List<String> services;
  final List<String> photos;
  final String profilePhoto;
  final GpsCoordinates gpsCoordinates;
  final Map<String, dynamic> location;
  final Map<String, dynamic> openingHours;
  final double rating;
  final int userRatingsTotal;
  final Map<String, dynamic> notes;
  final String tripadvisor_url;
  final String google_maps_url;
  final List<String> choices;
  final List<String> interests;
  final List<String> followers;
  final List<Map<String, dynamic>> posts;
  final double score;

  WellnessProducer({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
    required this.category,
    required this.sous_categorie,
    required this.services,
    required this.photos,
    required this.profilePhoto,
    required this.gpsCoordinates,
    required this.location,
    required this.openingHours,
    required this.rating,
    required this.userRatingsTotal,
    required this.notes,
    required this.tripadvisor_url,
    required this.google_maps_url,
    required this.choices,
    required this.interests,
    required this.followers,
    required this.posts,
    required this.score,
  });

  factory WellnessProducer.fromJson(Map<String, dynamic> json) {
    // Extraire les coordonnées GPS correctement selon les différents formats possibles
    GpsCoordinates coordinates;
    if (json['gps_coordinates'] != null) {
      coordinates = GpsCoordinates.fromJson(json['gps_coordinates']);
    } else if (json['location'] != null && 
               (json['location']['coordinates'] != null || 
                (json['location']['lat'] != null && json['location']['lng'] != null))) {
      coordinates = json['location']['coordinates'] != null 
          ? GpsCoordinates.fromJson(json['location']['coordinates'])
          : GpsCoordinates.fromJson(json['location']);
    } else {
      coordinates = GpsCoordinates(latitude: 48.8566, longitude: 2.3522);
    }

    return WellnessProducer(
      id: json['place_id'] ?? json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? json['full_address'] ?? '',
      phone: json['phone'] ?? json['international_phone_number'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      category: json['category'] ?? '',
      sous_categorie: json['sub_category'] ?? json['sous_categorie'] ?? json['sousCategory'] ?? '',
      services: json['services'] != null 
          ? List<String>.from(json['services']) 
          : <String>[],
      photos: json['photos'] != null 
          ? (json['photos'] is List ? List<String>.from(json['photos']) : <String>[])
          : <String>[],
      profilePhoto: json['profile_photo'] ?? json['profilePhoto'] ?? json['photo'] ?? '',
      gpsCoordinates: coordinates,
      location: json['location'] is Map ? json['location'] : {},
      openingHours: json['openingHours'] ?? json['opening_hours'] ?? {},
      rating: (json['rating'] is num) ? json['rating'].toDouble() : 0.0,
      userRatingsTotal: (json['user_ratings_total'] is num) ? json['user_ratings_total'] : 0,
      notes: json['notes'] is Map ? json['notes'] : {},
      tripadvisor_url: json['tripadvisor_url'] ?? '',
      google_maps_url: json['maps_url'] ?? json['google_maps_url'] ?? '',
      choices: json['choiceUsers'] != null 
          ? List<String>.from(json['choiceUsers']) 
          : <String>[],
      interests: json['interestedUsers'] != null 
          ? List<String>.from(json['interestedUsers']) 
          : <String>[],
      followers: json['followers'] != null 
          ? List<String>.from(json['followers']) 
          : <String>[],
      posts: json['posts'] != null 
          ? (json['posts'] is List<Map<String, dynamic>> 
              ? json['posts'] 
              : <Map<String, dynamic>>[])
          : <Map<String, dynamic>>[],
      score: json['score'] is num ? json['score'].toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': id,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'category': category,
      'sous_categorie': sous_categorie,
      'services': services,
      'photos': photos,
      'profile_photo': profilePhoto,
      'gps_coordinates': gpsCoordinates.toJson(),
      'location': location,
      'openingHours': openingHours,
      'rating': rating,
      'user_ratings_total': userRatingsTotal,
      'notes': notes,
      'tripadvisor_url': tripadvisor_url,
      'google_maps_url': google_maps_url,
      'choiceUsers': choices,
      'interestedUsers': interests,
      'followers': followers,
      'posts': posts,
    };
  }

  // Getters pour assurer la rétrocompatibilité 
  String get sousCategory => sous_categorie;
  String get city => location['city'] ?? '';
  String get postalCode => location['postalCode'] ?? '';
  int get followersCount => followers.length;
  int get choicesCount => choices.length;
  int get interestsCount => interests.length;
  int get postsCount => posts.length;
  
  // Setters pour éditer les propriétés
  set setName(String value) => name = value;
  set setDescription(String value) => description = value;
  set setAddress(String value) => address = value;
  set setPhone(String value) => phone = value;
  set setEmail(String value) => email = value;
  set setWebsite(String value) => website = value;
} 