import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wellness_producer.dart';
import '../utils/api_config.dart';
import '../utils/constants.dart' as constants;

class WellnessService {
  String getBaseUrl() {
    return constants.getBaseUrl();
  }
  final String apiPath = "/api/wellness";

  WellnessService();

  // Récupérer toutes les catégories de bien-être
  Future<Map<String, dynamic>> getWellnessCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}${ApiConfig.endpoints['wellness']}/categories'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Erreur lors de la récupération des catégories');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer tous les producteurs de bien-être
  Future<List<WellnessProducer>> getWellnessProducers() async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}${ApiConfig.endpoints['places']}'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WellnessProducer.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des producteurs');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer un producteur par son ID
  Future<WellnessProducer> getWellnessProducer(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}${ApiConfig.endpoints['places']}/$id'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WellnessProducer.fromJson(data);
      } else {
        throw Exception('Erreur lors de la récupération du producteur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Créer un nouveau producteur
  Future<WellnessProducer> createWellnessProducer(Map<String, dynamic> producerData) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}${ApiConfig.endpoints['places']}'),
        headers: ApiConfig.defaultHeaders,
        body: json.encode(producerData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return WellnessProducer.fromJson(data);
      } else {
        throw Exception('Erreur lors de la création du producteur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour un producteur
  Future<Map<String, dynamic>> updateWellnessProducer(String id, Map<String, dynamic> producerData) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}${ApiConfig.endpoints['places']}/$id'),
        headers: ApiConfig.defaultHeaders,
        body: json.encode(producerData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Erreur lors de la mise à jour du producteur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer tous les établissements de bien-être
  Future<List<WellnessProducer>> getAllProducers() async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}$apiPath/places'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WellnessProducer.fromJson(json)).toList();
      } else {
        print('Erreur ${response.statusCode}: ${response.body}');
        throw Exception('Erreur lors de la récupération des producteurs');
      }
    } catch (e) {
      print('Exception: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer un établissement par son ID
  Future<WellnessProducer> getProducerById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}$apiPath/places/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WellnessProducer.fromJson(data);
      } else {
        throw Exception('Erreur lors de la récupération du producteur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<WellnessProducer> createProducer(WellnessProducer producer) async {
    try {
      final response = await http.post(
        Uri.parse(getBaseUrl()),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(producer.toJson()),
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return WellnessProducer.fromJson(data);
      } else {
        throw Exception('Erreur lors de la création du producteur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<WellnessProducer> updateProducer(String id, WellnessProducer producer) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(producer.toJson()),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WellnessProducer.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Producteur non trouvé');
      } else {
        throw Exception('Erreur lors de la mise à jour du producteur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<void> deleteProducer(String id) async {
    try {
      final response = await http.delete(Uri.parse('${getBaseUrl()}/$id'));
      
      if (response.statusCode != 204) {
        throw Exception('Erreur lors de la suppression du producteur');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<List<WellnessProducer>> searchByCategory(String category) async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/category/$category'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WellnessProducer.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la recherche par catégorie');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Trouver des établissements à proximité
  Future<List<WellnessProducer>> findNearby(
    double latitude,
    double longitude, {
    int radius = 5000,
    String? category,
    String? sousCategory,
    double? minRating,
    List<String>? services,
  }) async {
    try {
      String url = '${getBaseUrl()}$apiPath/places/nearby?lat=$latitude&lng=$longitude&radius=$radius';
      
      if (category != null && category != 'Tous') {
        url += '&category=${Uri.encodeComponent(category)}';
      }
      
      if (sousCategory != null) {
        url += '&sousCategory=${Uri.encodeComponent(sousCategory)}';
      }
      
      if (minRating != null) {
        url += '&minRating=$minRating';
      }
      
      if (services != null && services.isNotEmpty) {
        url += '&services=${Uri.encodeComponent(json.encode(services))}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WellnessProducer.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la recherche des établissements à proximité');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<String> updateProfilePhoto(String id, String photoUrl) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/$id/profile-photo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'photoUrl': photoUrl}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['profilePhoto'];
      } else if (response.statusCode == 404) {
        throw Exception('Producteur non trouvé');
      } else {
        throw Exception('Erreur lors de la mise à jour de la photo de profil');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<List<String>> addPhotos(String id, List<String> photoUrls) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/$id/photos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'photoUrls': photoUrls}),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<String>.from(data);
      } else if (response.statusCode == 404) {
        throw Exception('Producteur non trouvé');
      } else {
        throw Exception('Erreur lors de l\'ajout des photos');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<void> deletePhoto(String id, String photoUrl) async {
    try {
      final response = await http.delete(
        Uri.parse('${getBaseUrl()}/$id/photos/$photoUrl'),
      );
      
      if (response.statusCode != 204) {
        throw Exception('Erreur lors de la suppression de la photo');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<List<String>> updateServices(String id, List<String> services) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/$id/services'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'services': services}),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<String>.from(data);
      } else if (response.statusCode == 404) {
        throw Exception('Producteur non trouvé');
      } else {
        throw Exception('Erreur lors de la mise à jour des services');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<String> updateNotes(String id, String notes) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/$id/notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'notes': notes}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['notes'];
      } else if (response.statusCode == 404) {
        throw Exception('Producteur non trouvé');
      } else {
        throw Exception('Erreur lors de la mise à jour des notes');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<Map<String, dynamic>> updateWellnessProducerPhotos(
    String producerId,
    List<String> photos,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${getBaseUrl()}${ApiConfig.endpoints['places']}/$producerId'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({'photos': photos}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur lors de la mise à jour des photos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour des photos: $e');
    }
  }

  // Récupérer toutes les catégories disponibles
  Future<Map<String, List<String>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}$apiPath/categories'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return Map<String, List<String>>.from(json.decode(response.body));
      } else {
        throw Exception('Erreur lors de la récupération des catégories');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les services disponibles
  Future<List<String>> getAvailableServices() async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}$apiPath/services'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return List<String>.from(json.decode(response.body));
      } else {
        throw Exception('Erreur lors de la récupération des services');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
  
  // Ajouter un établissement aux favoris
  Future<bool> addToFavorites(String userId, String producerId) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}$apiPath/users/$userId/favorites'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'producerId': producerId}),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
  
  // Ajouter un choice pour un établissement
  Future<bool> addChoice(String userId, String producerId) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}$apiPath/users/$userId/choices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'producerId': producerId}),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
  
  // Ajouter un intérêt pour un établissement
  Future<bool> addInterest(String userId, String producerId) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}$apiPath/users/$userId/interests'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'producerId': producerId}),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
  
  // Récupérer les établissements populaires
  Future<List<WellnessProducer>> getPopularPlaces() async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}$apiPath/places/popular'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WellnessProducer.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des établissements populaires');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
} 