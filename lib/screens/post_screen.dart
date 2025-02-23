import 'package:flutter/material.dart';
import 'package:choice_app/screens/profile_screen.dart'; // Import correct du fichier ProfileScreen
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';

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
    final url = Uri.parse('${getBaseUrl()}/api/posts/query/$userId');
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
    final String title = post['title']?.toString() ?? 'Titre non spécifié';
    final String content = post['content']?.toString() ?? 'Contenu non disponible';
    final String? mediaUrl = (post['media'] as List?)?.isNotEmpty == true ? post['media'][0]?.toString() : null;
    final String? authorId = post['producer_id']?.toString() ?? post['user_id']?.toString();
    final bool isProducer = post['producer_id'] != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mediaUrl != null)
            GestureDetector(
              onTap: () => _showPostDetail(post),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
                child: Image.network(
                  mediaUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (authorId != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(userId: authorId),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(
                              'https://via.placeholder.com/150'), // Image par défaut
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Auteur : $authorId', // Remplacez avec des données utilisateur si disponibles
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
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
