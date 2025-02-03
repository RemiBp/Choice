import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/producer_screen.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostCard({required this.post, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.network(
                post['image_url'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  size: 100,
                ),
              ),
            ),
          ListTile(
            leading: CircleAvatar(
              backgroundImage: post['author_photo'] != null
                  ? NetworkImage(post['author_photo'])
                  : null,
              child: post['author_photo'] == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            title: Text(post['author_type'] == 'user' ? 'Utilisateur' : 'Producteur'),
            subtitle: Text('Posté par ${post['author_name'] ?? post['author_id']}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => post['author_type'] == 'user'
                      ? ProfileScreen(userId: post['author_id'])
                      : ProducerScreen(producerId: post['author_id']),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(post['description'] ?? 'Description non disponible'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Wrap(
              spacing: 8.0,
              children: (post['tags'] ?? []).map<Widget>((tag) {
                return Chip(
                  label: Text('#$tag'),
                  backgroundColor: Colors.blue.shade100,
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post ajouté aux favoris')),
                    );
                  },
                ),
                Text(
                  'Posté le ${post['time_posted'] ?? 'Inconnu'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

