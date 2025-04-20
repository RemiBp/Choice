import '../utils/constants.dart' as constants;
import 'package:http/http.dart' as http;
import 'dart:convert';

class FeedService {
  // Méthode pour récupérer les posts du feed
  Future<List<Map<String, dynamic>>> getFeedPosts() async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/feed'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        // Gestion des différents formats de réponse possibles
        if (data is List) {
          // Si c'est directement une liste de posts
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map<String, dynamic> && data.containsKey('posts')) {
          // Si c'est un objet contenant une clé 'posts'
          final posts = data['posts'];
          if (posts is List) {
            return List<Map<String, dynamic>>.from(posts);
          }
        }
        
        // Si le format ne correspond à aucun des cas ci-dessus, retourner une liste vide
        return [];
      } else {
        print('❌ Error fetching feed posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching feed posts: $e');
      
      // En cas d'erreur de type, retourner une liste vide
      if (e.toString().contains("is not a subtype of type 'String")) {
        print('⚠️ Type conversion error detected in feed posts, returning empty list');
      }
      
      return [];
    }
  }
}
