import 'dart:convert';
import 'package:http/http.dart' as http;

class RestaurantService {
  final String baseUrl = 'http://localhost:5000/api/search';

  Future<List<dynamic>> rechercherLieux(Map<String, dynamic> criteres) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(criteres),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération des lieux');
    }
  }
}
