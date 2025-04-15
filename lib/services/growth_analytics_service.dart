import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
// Import the refined models
import '../models/growth_analytics_models.dart';

class GrowthAnalyticsService {
  static final GrowthAnalyticsService _instance = GrowthAnalyticsService._internal();
  factory GrowthAnalyticsService() => _instance;
  GrowthAnalyticsService._internal();

  // Use the new base URL structure
  final String _apiBaseUrl = '${constants.getBaseUrlSync()}/api/analytics';

  /// Récupère un aperçu global des statistiques de croissance
  /// Returns GrowthOverview on success, null on failure.
  Future<GrowthOverview?> getOverview(String producerId, {String period = '30d'}) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$producerId/overview?period=$period');
      final response = await http.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        // Use the refined GrowthOverview model
        return GrowthOverview.fromJson(json.decode(response.body));
      } else {
        print('❌ Erreur API [getOverview]: ${response.statusCode} - ${response.body}');
        // Return null instead of mock data
        return null;
      }
    } catch (e) {
      print('❌ Exception [getOverview]: $e');
      // Return null on exception
      return null;
    }
  }

  /// Récupère les tendances temporelles des performances
  /// Returns GrowthTrends on success, null on failure.
  Future<GrowthTrends?> getTrends(String producerId, {List<String> metrics = const ['followers', 'profileViews'], String period = '30d'}) async {
    try {
      // Construct the metrics query parameter
      final metricsParam = metrics.join(',');
      final url = Uri.parse('$_apiBaseUrl/$producerId/trends?period=$period&metrics=$metricsParam');
      final response = await http.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        // Use the refined GrowthTrends model
        return GrowthTrends.fromJson(json.decode(response.body));
      } else {
        print('❌ Erreur API [getTrends]: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception [getTrends]: $e');
      return null;
    }
  }

  /// Récupère les recommandations stratégiques
  /// Returns GrowthRecommendations on success, null on failure.
  Future<GrowthRecommendations?> getRecommendations(String producerId) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$producerId/recommendations');
      final response = await http.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        // Use the refined GrowthRecommendations model
        return GrowthRecommendations.fromJson(json.decode(response.body));
      } else {
        print('❌ Erreur API [getRecommendations]: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception [getRecommendations]: $e');
      return null;
    }
  }

  // --- Methods for Premium Features ---

  /// Fetches demographic data (Premium)
  /// Returns DemographicsData on success, null on failure.
  Future<DemographicsData?> getDemographics(String producerId, {String period = '30d'}) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$producerId/demographics?period=$period');
      final response = await http.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        return DemographicsData.fromJson(json.decode(response.body));
      } else if (response.statusCode == 403) {
        print('🔒 Access Denied [getDemographics]: Premium feature required.');
        return null; // Indicate access denied
      } else {
        print('❌ Erreur API [getDemographics]: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception [getDemographics]: $e');
      return null;
    }
  }

  /// Fetches growth predictions (Premium)
  /// Returns GrowthPredictions on success, null on failure.
  Future<GrowthPredictions?> getPredictions(String producerId, {String horizon = '30d'}) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$producerId/predictions?horizon=$horizon');
      final response = await http.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        return GrowthPredictions.fromJson(json.decode(response.body));
      } else if (response.statusCode == 403) {
        print('🔒 Access Denied [getPredictions]: Premium feature required.');
        return null;
      } else {
        print('❌ Erreur API [getPredictions]: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception [getPredictions]: $e');
      return null;
    }
  }

  /// Fetches competitor analysis data (Premium)
  /// Returns CompetitorAnalysis on success, null on failure.
  Future<CompetitorAnalysis?> getCompetitorAnalysis(String producerId, {String period = '30d'}) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$producerId/competitor-analysis?period=$period');
      final response = await http.get(url, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        return CompetitorAnalysis.fromJson(json.decode(response.body));
      } else if (response.statusCode == 403) {
        print('🔒 Access Denied [getCompetitorAnalysis]: Premium feature required.');
        return null;
      } else {
        print('❌ Erreur API [getCompetitorAnalysis]: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception [getCompetitorAnalysis]: $e');
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