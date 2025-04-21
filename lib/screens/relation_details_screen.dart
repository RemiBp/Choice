import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; // Import for Provider
import '../services/auth_service.dart';   // Import for AuthService
import '../utils/constants.dart' as constants;
import '../utils.dart' show getImageProvider;
import 'profile_screen.dart';
import 'producer_screen.dart';
import 'producerLeisure_screen.dart';

class RelationDetailsScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> profiles;

  const RelationDetailsScreen({
    Key? key,
    required this.title,
    required this.profiles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orangeAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: profiles.isEmpty
          ? _buildEmptyState()
          : _buildProfilesList(context),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForTitle(),
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun profil à afficher',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final userId = profile['_id'] ?? '';
        final name = profile['name'] ?? profile['username'] ?? 'Sans nom';
        final description = profile['description'] ?? profile['bio'] ?? '';
        final photoUrl = profile['photo'] ?? profile['profile_picture'];
        final isVerified = profile['verified'] == true;
        final isFeatured = profile['featured'] == true;
        final isProducer = profile['place_id'] != null;
        final isLeisureProducer = isProducer && 
            (profile['category'] as List<dynamic>?)?.contains('leisure') == true;

                  return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToProfile(context, profile),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar avec badge selon type de profil
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getProfileColor(isProducer, isLeisureProducer),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: photoUrl != null
                            ? Image(
                                image: getImageProvider(photoUrl) ??
                                    NetworkImage('https://via.placeholder.com/60'),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      _getProfileIcon(isProducer, isLeisureProducer),
                                      color: Colors.grey[400],
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  _getProfileIcon(isProducer, isLeisureProducer),
                                  color: Colors.grey[400],
                                ),
                              ),
                        ),
                      ),
                      if (isVerified)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Icon(
                              Icons.verified,
                              size: 16,
                              color: _getProfileColor(isProducer, isLeisureProducer),
                            ),
                          ),
                        ),
                      if (isFeatured && !isVerified)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Infos profil
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                        name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              _getProfileIcon(isProducer, isLeisureProducer),
                              size: 16,
                              color: _getProfileColor(isProducer, isLeisureProducer),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                        description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                          ),
                        // Chips pour afficher des infos
                        if (isProducer)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                if (profile['ratings'] != null)
                                  _buildInfoChip(
                                    Icons.star,
                                    Colors.amber,
                                    (profile['rating'] ?? 0.0).toString(),
                                  ),
                                if (profile['followers'] != null)
                                  _buildInfoChip(
                                    Icons.people,
                                    Colors.blue,
                                    '${profile['followers']['count'] ?? 0}',
                                  ),
                                if (profile['address'] != null)
                                  _buildInfoChip(
                                    Icons.location_on,
                                    Colors.red,
                                    'Voir',
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper pour naviguer vers le profil approprié
  void _navigateToProfile(BuildContext context, Map<String, dynamic> profile) {
    final userId = profile['_id'] ?? '';
    if (userId.isEmpty) return;

    final isProducer = profile['place_id'] != null;
    final isLeisureProducer = isProducer && 
        (profile['category'] as List<dynamic>?)?.contains('leisure') == true;

    if (isProducer) {
      if (isLeisureProducer) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerId: userId),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(producerId: userId),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: userId),
        ),
      );
    }
  }

  // Helpers pour la UI et UX
  IconData _getProfileIcon(bool isProducer, bool isLeisureProducer) {
    if (isProducer) {
      return isLeisureProducer ? Icons.attractions : Icons.restaurant;
    }
    return Icons.person;
  }

  Color _getProfileColor(bool isProducer, bool isLeisureProducer) {
    if (isProducer) {
      return isLeisureProducer ? Colors.purple : Colors.orange;
    }
    return Colors.blue;
  }

  IconData _getIconForTitle() {
    switch (title.toLowerCase()) {
      case 'followers':
        return Icons.people;
      case 'following':
        return Icons.person_add;
      case 'interested':
        return Icons.emoji_objects;
      case 'choices':
        return Icons.check_circle;
      default:
        return Icons.people;
    }
  }

  String _getEmptyStateMessage() {
    switch (title.toLowerCase()) {
      case 'followers':
        return 'Vous n\'avez pas encore de followers.\nPartagez votre profil pour en obtenir !';
      case 'following':
        return 'Vous ne suivez personne pour le moment.\nExplorez et suivez des profils qui vous intéressent !';
      case 'interested':
        return 'Personne n\'a encore marqué son intérêt.\nContinuez à partager du contenu attractif !';
      case 'choices':
        return 'Personne n\'a encore fait de vous son choix.\nContinuez à offrir une expérience de qualité !';
      default:
        return 'Aucun profil n\'est disponible actuellement.';
    }
  }
} 