import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';  // Corriger l'import
import '../screens/profile_screen.dart';
import '../screens/producer_screen.dart';
import '../utils.dart' show getImageProvider;

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
              child: Builder(
                builder: (context) {
                  final imageUrl = post['image_url'];
                  final imageProvider = getImageProvider(imageUrl);
                  
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[200], // Background placeholder
                    child: imageProvider != null 
                      ? Image(
                          image: imageProvider,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print("❌ Error loading post image: $error");
                            return Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[600]));
                          },
                        )
                      : Center(child: Icon(Icons.image, size: 50, color: Colors.grey[500])),
                  );
                }
              ),
            ),
          ListTile(
            leading: CircleAvatar(
              backgroundImage: post['author_photo'] != null
                  ? getImageProvider(post['author_photo'])
                  : null,
              backgroundColor: Colors.grey[300],
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

