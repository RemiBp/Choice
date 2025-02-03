import 'package:flutter/material.dart';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(post['title'] ?? 'Détail du Post'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['title'] ?? 'Titre non spécifié',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(post['content'] ?? 'Contenu non disponible'),
            const SizedBox(height: 20),
            if (post['media'] != null && (post['media'] as List).isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: (post['media'] as List).length,
                  itemBuilder: (context, index) {
                    final mediaUrl = (post['media'] as List)[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Image.network(mediaUrl, fit: BoxFit.cover),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
