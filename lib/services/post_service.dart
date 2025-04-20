import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;

class Post {
  final String id;
  final String userId;
  final String content;
  final List<String> media;
  final DateTime createdAt;
  final int likes;
  final int comments;

  Post({
    required this.id,
    required this.userId,
    required this.content,
    required this.media,
    required this.createdAt,
    required this.likes,
    required this.comments,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      media: (json['media'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      likes: json['likes_count'] ?? 0,
      comments: json['comments_count'] ?? 0,
    );
  }
}

class PostService {
  Future<List<Post>> getUserPosts(String? userId) async {
    if (userId == null) return [];
    
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/users/$userId/posts'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((postJson) => Post.fromJson(postJson)).toList();
      } else {
        print('Error fetching posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching posts: $e');
      return [];
    }
  }
  
  Future<Post?> getPostById(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/posts/$postId'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Post.fromJson(data);
      } else {
        print('Error fetching post: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception fetching post: $e');
      return null;
    }
  }
  
  Future<bool> likePost(String postId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/posts/$postId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Exception liking post: $e');
      return false;
    }
  }
  
  Future<bool> createPost(String userId, String content, List<String> media) async {
    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/posts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'content': content,
          'media': media,
        }),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      print('Exception creating post: $e');
      return false;
    }
  }
} 