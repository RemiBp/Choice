import 'package:flutter/material.dart';
import 'package:choice_app/screens/profile_screen.dart'; // Import correct du fichier ProfileScreen
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';
import '../widgets/profile_post_card.dart'; // Import du widget ProfilePostCard

class PostScreen extends StatefulWidget {
  final String userId;

  const PostScreen({required this.userId, Key? key}) : super(key: key);

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late Future<List<dynamic>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  /// Récupère les posts de l'utilisateur
  void _fetchPosts() {
    setState(() {
      _postsFuture = _getPostsData(widget.userId);
    });
  }

  /// Effectue la requête HTTP pour récupérer les posts
  Future<List<dynamic>> _getPostsData(String userId) async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/posts/query/$userId');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/posts/query/$userId');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/posts/query/$userId');
    }
    
    try {
      print('🔍 Requête vers : $url');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📩 Réponse reçue : ${data.length} posts');
        return data;
      } else {
        print('❌ Erreur lors de la récupération des posts : ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur réseau : $e');
      return [];
    }
  }

  /// Construit la carte d'un post
  Widget _buildPostCard(Map<String, dynamic> post) {
    return ProfilePostCard(
      post: post,
      userId: widget.userId,
      onRefresh: () {
        _fetchPosts();
      },
    );
  }

  void _showPostDetail(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post['title'] ?? 'Titre non spécifié',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                post['content'] ?? 'Contenu non disponible',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Posts'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun post trouvé.'));
          }

          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildPostCard(post);
            },
          );
        },
      ),
    );
  }
}
