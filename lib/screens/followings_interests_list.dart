import 'package:flutter/material.dart';
import '../utils/map_colors.dart' as mapcolors;

class FollowingsInterestsList extends StatelessWidget {
  final Map<String, dynamic> followingsData;
  final VoidCallback onClose;

  const FollowingsInterestsList({
    Key? key,
    required this.followingsData,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extraire les données
    final List<dynamic> interests = followingsData['interests'] ?? [];
    final List<dynamic> choices = followingsData['choices'] ?? [];
    final List<dynamic> followings = followingsData['followings'] ?? [];
    
    // Créer un dictionnaire pour un accès rapide aux infos du following
    final Map<String, Map<String, dynamic>> followingsMap = {};
    for (final following in followings) {
      followingsMap[following['id'].toString()] = {
        'name': following['name'] ?? 'Utilisateur',
        'photo_url': following['photo_url'] ?? '',
      };
    }

    return Column(
      children: [
        // En-tête avec titre et bouton de fermeture
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: mapcolors.MapColors.leisurePrimary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amis intéressés',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        
        // Contenu avec les listes
        Expanded(
          child: interests.isEmpty && choices.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (interests.isNotEmpty) ...[
                          _buildSectionTitle('Intéressés', Icons.favorite_border),
                          _buildFollowingsList(interests, followingsMap, isInterest: true),
                          SizedBox(height: 24),
                        ],
                        
                        if (choices.isNotEmpty) ...[
                          _buildSectionTitle('Ont visité', Icons.check_circle_outline),
                          _buildFollowingsList(choices, followingsMap, isInterest: false),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
  
  // Affichage d'état vide
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 72,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Aucun ami intéressé par ce lieu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Soyez le premier à partager ce lieu avec vos amis !',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Titre de section
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: mapcolors.MapColors.leisurePrimary,
          size: 20,
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: mapcolors.MapColors.leisurePrimary,
          ),
        ),
      ],
    );
  }
  
  // Liste des followings
  Widget _buildFollowingsList(List<dynamic> items, Map<String, Map<String, dynamic>> followingsMap, {required bool isInterest}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final userId = item['userId'].toString();
        final following = followingsMap[userId];
        
        if (following == null) {
          return SizedBox.shrink(); // Skip if following info not found
        }
        
        final name = following['name'];
        final photoUrl = following['photo_url'];
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              backgroundColor: mapcolors.MapColors.leisurePrimary.withOpacity(0.2),
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(Icons.person, color: mapcolors.MapColors.leisurePrimary)
                  : null,
            ),
            title: Text(
              name ?? 'Utilisateur',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isInterest
                  ? 'Est intéressé(e) par ce lieu'
                  : 'A déjà visité ce lieu',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.message, color: mapcolors.MapColors.leisurePrimary),
              onPressed: () {
                // TODO: Envoyer un message au following
              },
              tooltip: 'Envoyer un message',
            ),
          ),
        );
      },
    );
  }
} 