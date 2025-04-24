import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/offer_model.dart'; // Importer le modèle Offer
import '../utils/constants.dart' as constants;
import '../utils/api_config.dart'; // Pour obtenir les headers d'authentification

class OfferService {
  Future<List<Offer>> fetchReceivedOffers({String? status}) async {
    print(' Service: Fetching received offers...');
    try {
      final headers = await ApiConfig.getAuthHeaders();
      if (headers == null) {
        throw Exception('Authentication token not found.');
      }

      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final url = Uri.parse('${constants.getBaseUrl()}/api/offers/received')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Offer> offers = data.map((item) => Offer.fromJson(item as Map<String, dynamic>)).toList();
        print(' Service: Fetched ${offers.length} offers.');
        return offers;
      } else {
        print(' Service: Error fetching offers - Status ${response.statusCode} - Body: ${response.body}');
        // Tenter de décoder le message d'erreur du backend
        String errorMessage = 'Failed to load offers (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Ignorer l'erreur de décodage, utiliser le message par défaut
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(' Service: Exception fetching offers: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Méthode pour accepter une offre
  Future<Offer> acceptOffer(String offerId) async {
    print(' Service: Accepting offer $offerId...');
    try {
      final headers = await ApiConfig.getAuthHeaders();
      if (headers == null) {
        throw Exception('Authentication token not found.');
      }

      final url = Uri.parse('${constants.getBaseUrl()}/api/offers/$offerId/accept');
      
      final response = await http.post(
        url, 
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Offer updatedOffer = Offer.fromJson(data['offer']);
        print(' Service: Offer $offerId accepted successfully.');
        return updatedOffer;
      } else {
        print(' Service: Error accepting offer - Status ${response.statusCode} - Body: ${response.body}');
        String errorMessage = 'Failed to accept offer (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Ignorer l'erreur de décodage
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(' Service: Exception accepting offer: $e');
      throw Exception('Failed to accept offer: $e');
    }
  }

  // Méthode pour rejeter une offre
  // Note: Cette fonctionnalité pourrait nécessiter l'ajout d'un endpoint "reject" dans le backend
  Future<Offer> rejectOffer(String offerId) async {
    print(' Service: Rejecting offer $offerId...');
    try {
      final headers = await ApiConfig.getAuthHeaders();
      if (headers == null) {
        throw Exception('Authentication token not found.');
      }

      // Utilisation d'un path paramètre pour l'ID
      final url = Uri.parse('${constants.getBaseUrl()}/api/offers/$offerId/reject');
      
      final response = await http.post(
        url, 
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Offer updatedOffer = Offer.fromJson(data['offer']);
        print(' Service: Offer $offerId rejected successfully.');
        return updatedOffer;
      } else {
        print(' Service: Error rejecting offer - Status ${response.statusCode} - Body: ${response.body}');
        String errorMessage = 'Failed to reject offer (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Ignorer l'erreur de décodage
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(' Service: Exception rejecting offer: $e');
      throw Exception('Failed to reject offer: $e');
    }
  }

  // Ajouter d'autres méthodes de service pour les offres ici si nécessaire
  // Par exemple : acceptOffer(String offerId), rejectOffer(String offerId), etc.
} 