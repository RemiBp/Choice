import '../utils/constants.dart';

class FeedService {
  final String _baseUrl = getBaseUrl();
  
  Future<List<Map<String, dynamic>>> getFeedPosts() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/feed'),
      // ...existing code...
    );
  }
}
