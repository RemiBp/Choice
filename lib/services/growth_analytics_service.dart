import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
// Import the refined models
import '../models/growth_analytics_models.dart';
import './auth_service.dart'; // Import AuthService
import '../models/producer_type.dart'; // Import ProducerType enum

class GrowthAnalyticsService {
  static final GrowthAnalyticsService _instance = GrowthAnalyticsService._internal();
  factory GrowthAnalyticsService() => _instance;
  GrowthAnalyticsService._internal();

  // Use the new base URL structure
  final String _apiBaseUrl = '${constants.getBaseUrlSync()}/api/analytics';

  /// Récupère un aperçu global des statistiques de croissance
  /// Requires producerType to correctly fetch data (e.g., choices).
  Future<GrowthOverview?> getOverview(String producerId, {required ProducerType producerType, String period = '30d'}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }
      // Convert enum to string for the query parameter
      final typeString = producerType.toString().split('.').last;
      final url = Uri.parse('$_apiBaseUrl/$producerId/overview?period=$period&producerType=$typeString');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        return GrowthOverview.fromJson(json.decode(response.body));
      } else {
        print('❌ Erreur API [getOverview]: ${response.statusCode} - ${response.body}');
        // Re-throw exception to be caught by the calling screen
        throw Exception('Erreur API [getOverview]: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception [getOverview]: $e');
      // Re-throw the exception so the UI can handle it (e.g., show error message)
      rethrow; 
    }
  }

  /// Récupère les tendances temporelles des performances
  /// Requires producerType if 'choices' metric is included.
  Future<GrowthTrends?> getTrends(String producerId, {required ProducerType producerType, List<String> metrics = const ['followers', 'profileViews', 'choices'], String period = '30d'}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }
      final metricsParam = metrics.join(',');
      // Convert enum to string for the query parameter
      final typeString = producerType.toString().split('.').last;
      // Include producerType in the URL
      final url = Uri.parse('$_apiBaseUrl/$producerId/trends?period=$period&metrics=$metricsParam&producerType=$typeString');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        return GrowthTrends.fromJson(json.decode(response.body));
      } else {
        print('❌ Erreur API [getTrends]: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur API [getTrends]: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception [getTrends]: $e');
      rethrow;
    }
  }

  /// Récupère les recommandations stratégiques
  /// Returns GrowthRecommendations on success, null on failure.
  Future<GrowthRecommendations?> getRecommendations(String producerId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }
      final url = Uri.parse('$_apiBaseUrl/$producerId/recommendations');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        return GrowthRecommendations.fromJson(json.decode(response.body));
      } else {
        print('❌ Erreur API [getRecommendations]: ${response.statusCode} - ${response.body}');
         throw Exception('Erreur API [getRecommendations]: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception [getRecommendations]: $e');
      rethrow;
    }
  }

  // --- Methods for Premium Features ---

  /// Fetches demographic data (Premium)
  /// Returns DemographicsData on success, null on failure.
  Future<DemographicsData?> getDemographics(String producerId, {required ProducerType producerType, String period = '30d'}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }
      final typeString = producerType.toString().split('.').last;
      // Include producerType if needed by backend demographics logic
      final url = Uri.parse('$_apiBaseUrl/$producerId/demographics?period=$period&producerType=$typeString');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        return DemographicsData.fromJson(json.decode(response.body));
      } else if (response.statusCode == 403) {
        print('🔒 Access Denied [getDemographics]: Premium feature required.');
        return null; // Specific handling for 403 (access denied)
      } else {
        print('❌ Erreur API [getDemographics]: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur API [getDemographics]: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception [getDemographics]: $e');
      // Propagate specific exceptions or handle them
      if (e.toString().contains('Authentication token is missing')) rethrow;
      return null; // Return null for other general exceptions
    }
  }

  /// Fetches growth predictions (Premium)
  /// Returns GrowthPredictions on success, null on failure.
  Future<GrowthPredictions?> getPredictions(String producerId, {required ProducerType producerType, String horizon = '30d'}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }
      final typeString = producerType.toString().split('.').last;
      // Include producerType if needed by backend prediction logic
      final url = Uri.parse('$_apiBaseUrl/$producerId/predictions?horizon=$horizon&producerType=$typeString');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        return GrowthPredictions.fromJson(json.decode(response.body));
      } else if (response.statusCode == 403) {
        print('🔒 Access Denied [getPredictions]: Premium feature required.');
        return null;
      } else {
        print('❌ Erreur API [getPredictions]: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur API [getPredictions]: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception [getPredictions]: $e');
      if (e.toString().contains('Authentication token is missing')) rethrow;
      return null;
    }
  }

  /// Fetches competitor analysis data (Premium)
  /// Returns CompetitorAnalysis on success, null on failure.
  Future<CompetitorAnalysis?> getCompetitorAnalysis(String producerId, {required ProducerType producerType, String period = '30d'}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }
       final typeString = producerType.toString().split('.').last;
      // Include producerType if needed by backend competitor logic
      final url = Uri.parse('$_apiBaseUrl/$producerId/competitor-analysis?period=$period&producerType=$typeString');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        return CompetitorAnalysis.fromJson(json.decode(response.body));
      } else if (response.statusCode == 403) {
        print('🔒 Access Denied [getCompetitorAnalysis]: Premium feature required.');
        return null;
      } else {
        print('❌ Erreur API [getCompetitorAnalysis]: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur API [getCompetitorAnalysis]: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception [getCompetitorAnalysis]: $e');
      if (e.toString().contains('Authentication token is missing')) rethrow;
      return null;
    }
  }

  // --- REMOVE MOCK DATA GENERATION --- 
  /*
  Map<String, dynamic> _getMockOverview(String producerId, String period) {
    // ... removed ...
  }

  Map<String, dynamic> _getMockTrends(String period) {
    // ... removed ...
  }

  Map<String, dynamic> _getMockRecommendations() {
    // ... removed ...
  }
  */
} 