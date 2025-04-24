import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:constants/constants.dart';

class MapService {
  /// Appelle l'API avancée pour la recherche de restaurants (GET /api/producers/advanced-search)
  Future<Map<String, dynamic>> fetchAdvancedRestaurants(Map<String, String> queryParams) async {
    final baseUrl = constants.getBaseUrl();
    final uri = Uri.parse(baseUrl + '/api/producers/advanced-search').replace(queryParameters: queryParams);
    print('🔍 [fetchAdvancedRestaurants] GET $uri');
    
    try {
      // Ajouter un timeout pour éviter les attentes trop longues
      final client = http.Client();
      final request = http.Request('GET', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';
      
      // Ajouter un timeout de 15 secondes
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          client.close();
          throw TimeoutException('La requête a mis trop de temps à s'exécuter');
        },
      );
      
      // Lire la réponse en streaming pour les gros résultats
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('❌ Erreur API: ${response.statusCode} - ${response.body.substring(0, min(200, response.body.length))}...');
        return {'success': false, 'message': 'Erreur API', 'results': []};
      }
    } catch (e) {
      print('❌ Erreur réseau: $e');
      return {'success': false, 'message': 'Erreur réseau: ${e.toString()}', 'results': []};
    }
  }
} 