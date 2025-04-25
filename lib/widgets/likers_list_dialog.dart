import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Ou votre solution d'image
import '../screens/profile_screen.dart'; // Pour la navigation utilisateur
// Importez d'autres écrans de profil producteur si nécessaire

class LikersListDialog extends StatelessWidget {
  final List<Map<String, dynamic>> likers;

  const LikersListDialog({Key? key, required this.likers}) : super(key: key);

  void _navigateToUserProfile(BuildContext context, String userId) {
     print("Navigating to user profile: $userId");
     // Assurez-vous que ProfileScreen existe et prend userId
     Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Limiter la hauteur maximale pour éviter qu'elle ne prenne tout l'écran
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de titre
          Text(
            'Likes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          // Liste des likers
          Expanded(
            child: likers.isEmpty
                ? const Center(child: Text('Personne n\'a encore aimé ce post.'))
                : ListView.builder(
                    itemCount: likers.length,
                    itemBuilder: (context, index) {
                      final liker = likers[index];
                      final String name = liker['name'] ?? 'Utilisateur inconnu';
                      final String? avatarUrl = liker['avatar'];
                      final String userId = liker['id'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300], // Placeholder color
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? CachedNetworkImageProvider(avatarUrl) // Utilisez votre provider d'image
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white) // Placeholder icon
                              : null,
                        ),
                        title: Text(name),
                        onTap: userId.isNotEmpty
                            ? () {
                                // Fermer la modale avant de naviguer
                                Navigator.pop(context);
                                _navigateToUserProfile(context, userId);
                              }
                            : null, // Désactiver le tap si pas d'ID
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 