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
    // Helper to safely get nested values
    dynamic getNested(List<String> keys) {
      dynamic current = json;
      for (String key in keys) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          return null;
        }
      }
      return current;
    }
    
    // Extraire les coordonnées GPS correctement selon les différents formats possibles
    GpsCoordinates coordinates;
    dynamic gpsData = getNested(['gps_coordinates']) ?? getNested(['location', 'coordinates']) ?? getNested(['location']);
    if (gpsData != null) {
        try {
             coordinates = GpsCoordinates.fromJson(gpsData);
        } catch (e) {
            print("⚠️ Error parsing coordinates: $e, Data: $gpsData");
            coordinates = GpsCoordinates(latitude: 48.8566, longitude: 2.3522); // Fallback
        }
    } else {
      coordinates = GpsCoordinates(latitude: 48.8566, longitude: 2.3522); // Fallback
    }
    
    // Safely extract rating values
    double ratingValue = 0.0;
    int ratingCount = 0;
    dynamic ratingData = getNested(['rating']);
    if (ratingData is Map) {
      ratingValue = (ratingData['average'] as num?)?.toDouble() ?? 0.0;
      ratingCount = (ratingData['count'] as num?)?.toInt() ?? 0;
    } else if (ratingData is num) {
       ratingValue = ratingData.toDouble();
       ratingCount = (getNested(['user_ratings_total']) as num?)?.toInt() ?? 0; // Try separate field
    } else {
        ratingCount = (getNested(['user_ratings_total']) as num?)?.toInt() ?? 0; // Try separate field if rating is missing
    }

    // Safely extract lists, converting elements if necessary
    List<String> parseStringList(dynamic listData) {
      if (listData is List) {
        return List<String>.from(listData.map((e) => e.toString()));
      }
      return <String>[];
    }
    
    List<Map<String, dynamic>> parseMapList(dynamic listData) {
       if (listData is List) {
           // Ensure all elements are Maps before converting
           return List<Map<String, dynamic>>.from(listData.whereType<Map<String, dynamic>>());
       }
       return <Map<String, dynamic>>[];
    }
    
    // Extract service names from list of service objects
     List<String> parseServiceNames(dynamic listData) {
        if (listData is List) {
            return listData
                .whereType<Map<String, dynamic>>() // Only consider maps
                .map((service) => service['name']?.toString()) // Extract name
                .where((name) => name != null && name.isNotEmpty) // Filter null/empty names
                .toList()
                .cast<String>(); // Cast to List<String>
        }
        return <String>[];
     }


    return WellnessProducer(
      id: getNested(['_id'])?.toString() ?? getNested(['id'])?.toString() ?? getNested(['place_id'])?.toString() ?? '',
      name: getNested(['name'])?.toString() ?? '',
      description: getNested(['description'])?.toString() ?? '',
      // Extract address from location object
      address: getNested(['location', 'address'])?.toString() ?? getNested(['address'])?.toString() ?? getNested(['full_address'])?.toString() ?? '',
      // Extract contact info from contact object
      phone: getNested(['contact', 'phone'])?.toString() ?? getNested(['phone'])?.toString() ?? getNested(['international_phone_number'])?.toString() ?? '',
      email: getNested(['contact', 'email'])?.toString() ?? getNested(['email'])?.toString() ?? '',
      website: getNested(['contact', 'website'])?.toString() ?? getNested(['website'])?.toString() ?? '',
      category: getNested(['category'])?.toString() ?? '',
      sous_categorie: getNested(['sous_categorie'])?.toString() ?? getNested(['sub_category'])?.toString() ?? getNested(['sousCategory'])?.toString() ?? '',
      // Extract service names
      services: parseServiceNames(getNested(['services'])),
      // Check both 'photos' and 'images'
      photos: parseStringList(getNested(['photos']) ?? getNested(['images'])),
      // Check multiple profile photo keys including 'avatar'
      profilePhoto: getNested(['profile_photo'])?.toString() ?? getNested(['profilePhoto'])?.toString() ?? getNested(['photo'])?.toString() ?? getNested(['avatar'])?.toString() ?? '',
      gpsCoordinates: coordinates,
      // Ensure location is a Map
      location: getNested(['location']) is Map ? Map<String, dynamic>.from(getNested(['location'])) : {},
      // Check multiple opening hours keys
      openingHours: getNested(['openingHours']) ?? getNested(['opening_hours']) ?? getNested(['business_hours']) ?? {},
      rating: ratingValue,
      userRatingsTotal: ratingCount,
      // Ensure notes is a Map
      notes: getNested(['notes']) is Map ? Map<String, dynamic>.from(getNested(['notes'])) : {},
      tripadvisor_url: getNested(['tripadvisor_url'])?.toString() ?? '',
      google_maps_url: getNested(['maps_url'])?.toString() ?? getNested(['google_maps_url'])?.toString() ?? '',
      // Parse user ID lists
      choices: parseStringList(getNested(['choiceUsers'])),
      interests: parseStringList(getNested(['interestedUsers'])),
      followers: parseStringList(getNested(['followers'])),
      // Parse posts list
      posts: parseMapList(getNested(['posts'])),
      score: (getNested(['score']) as num?)?.toDouble() ?? 0.0,
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
  
  // --- Nouveaux compteurs --- 
  int get choiceCountFromData => location['choice_count'] ?? 0;
  int get interestCountFromData => location['interest_count'] ?? 0;
  int get favoriteCountFromData => location['favorite_count'] ?? 0;

  // Setters pour éditer les propriétés
  set setName(String value) => name = value;
  set setDescription(String value) => description = value;
  set setAddress(String value) => address = value;
  set setPhone(String value) => phone = value;
  set setEmail(String value) => email = value;
  set setWebsite(String value) => website = value;
} 