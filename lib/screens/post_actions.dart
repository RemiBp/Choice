import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';

class PostActions {
  static Future<void> likePost(String postId, String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/like');
    final body = {'user_id': userId};

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Post liké avec succès');
      } else {
        print('❌ Erreur lors du like : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors du like : $e');
    }
  }

  static Future<void> addChoice(String postId, String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/choice');
    final body = {'user_id': userId};

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Choice ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout aux choices : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout aux choices : $e');
    }
  }

  static Future<void> addComment(String postId, String userId, String content) async {
    final url = Uri.parse('${getBaseUrl()}/api/posts/$postId/comments');
    final body = {
      'user_id': userId,
      'content': content,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        print('✅ Commentaire ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout du commentaire : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour l\'ajout du commentaire : $e');
    }
  }
}
