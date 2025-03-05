import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../models/post.dart';
import '../utils/constants.dart';

class ShareService {
  Future<void> sharePost(Post post) async {
    String shareText;
    if (post.producerId != null) {
      shareText = 'Découvrez ${post.authorName} sur Choice:\n\n${post.content}';
      if (post.mediaUrl != null) {
        shareText += '\n\nPhoto: ${post.mediaUrl}';
      }
    } else {
      shareText = '${post.content}\n\nPartagé via Choice';
    }
    
    await Share.share(shareText);
  }

  Future<bool> savePost(String userId, String postId) async {
    final url = Uri.parse('${getBaseUrl()}/api/share/save');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'postId': postId,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du post : $e');
      return false;
    }
  }

  Future<List<Post>> getSavedPosts(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/users/$userId/saved-posts');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Post.fromJson(json)).toList();
      }
      throw Exception('Failed to load saved posts');
    } catch (e) {
      print('❌ Erreur lors de la récupération des posts sauvegardés : $e');
      rethrow;
    }
  }
}
