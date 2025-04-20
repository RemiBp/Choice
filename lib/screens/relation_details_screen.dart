import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; // Import for Provider
import '../services/auth_service.dart';   // Import for AuthService
import '../utils/constants.dart' as constants;
import 'profile_screen.dart';
import 'producer_screen.dart';
import 'producerLeisure_screen.dart';

class RelationDetailsScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> profiles; // Liste des profils validés

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
        backgroundColor: Colors.teal, // Harmonize with ProducerScreen AppBar
      ),
      body: profiles.isNotEmpty
          ? ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                try {
                  final profile = profiles[index];
                  if (profile == null || profile is! Map<String, dynamic>) {
                    print('❌ Profil invalide à l\'index $index');
                    return const SizedBox.shrink(); // Ignore invalid entries
                  }

                  // --- Safe Data Extraction ---
                  final userId = profile['_id']?.toString();
                  // Check for producer-specific ID fields (like place_id or a dedicated producerId field)
                  final producerId = profile['producerId']?.toString() ??
                                      profile['place_id']?.toString() ??
                                      (profile['type'] == 'producer' || profile['type'] == 'restaurant' || profile['type'] == 'leisure' ? profile['_id']?.toString() : null); // Infer producerId if type matches

                  // Check if producerData exists and is a Map
                  final producerData = profile['producerData'] is Map
                      ? profile['producerData'] as Map<String, dynamic>
                      : null; // Used for leisure producers specifically

                   // Determine profile type more robustly
                   final profileType = profile['type']?.toString()?.toLowerCase();
                   final bool isUser = profileType == 'user' || (userId != null && producerId == null && producerData == null);
                   final bool isProducer = profileType == 'producer' || profileType == 'restaurant' || (producerId != null && !isUser);
                   final bool isLeisureProducer = profileType == 'leisure' || (producerData != null && !isUser && !isProducer);


                  // Get photo URL safely
                  String photoUrl = 'https://via.placeholder.com/150';
                  List<String> photoKeys = ['photo', 'photo_url', 'avatar', 'image'];
                  // Special handling for Google Places photo references
                  if (profile['photos'] is List && (profile['photos'] as List).isNotEmpty) {
                      var firstPhoto = (profile['photos'] as List)[0];
                      if (firstPhoto is Map && firstPhoto['photo_reference'] != null) {
                           photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=150&photoreference=${firstPhoto['photo_reference']}&key=${constants.getGoogleApiKey()}'; // Use constant for key
                      } else if (firstPhoto is String && firstPhoto.isNotEmpty) {
                         photoUrl = firstPhoto;
                      }
                  }
                   // Fallback to standard keys if no Google photo ref found
                  if (photoUrl == 'https://via.placeholder.com/150') {
                     for (var key in photoKeys) {
                        if (profile[key] != null && profile[key].toString().isNotEmpty) {
                          photoUrl = profile[key].toString();
                          break;
                        }
                     }
                  }


                  // Get name safely
                  String name = 'Nom inconnu';
                  List<String> nameKeys = ['name', 'username', 'displayName', 'title', 'nom'];
                  for (var key in nameKeys) {
                    if (profile[key] != null && profile[key].toString().isNotEmpty) {
                      name = profile[key].toString();
                      break;
                    }
                  }

                  // Get description safely
                  String description = ''; // Default to empty for cleaner look
                  List<String> descKeys = ['description', 'bio', 'about', 'summary', 'category'];
                   if (isProducer && profile['category'] is List && (profile['category'] as List).isNotEmpty) {
                     description = (profile['category'] as List).join(', '); // Use categories for producers
                   } else {
                      for (var key in descKeys) {
                        if (profile[key] != null && profile[key].toString().isNotEmpty) {
                           description = profile[key].toString();
                           break;
                         }
                       }
                   }


                  // Basic validation check
                  if ((!isUser && !isProducer && !isLeisureProducer) || (isUser && userId == null) || (isProducer && producerId == null) || (isLeisureProducer && producerData == null)) {
                    print('❌ Profil non valide ou données manquantes à l\'index $index');
                    return const SizedBox.shrink(); // Ignore invalid entries
                  }

                  // --- Build ListTile ---
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(photoUrl),
                        onBackgroundImageError: (_, __) {
                          print('⚠️ Erreur de chargement d\'image pour le profil: $name');
                        },
                        backgroundColor: Colors.grey[300],
                        child: photoUrl == 'https://via.placeholder.com/150'
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        description,
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 1, // Keep it concise
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () => _navigateToProfile(context, userId, producerId, profile, isUser, isProducer, isLeisureProducer), // Pass full profile data
                    ),
                  );
                } catch (e) {
                  print('❌ Erreur de rendu pour le profil à l\'index $index: $e');
                  return const SizedBox.shrink(); // Handle potential errors gracefully
                }
              },
            )
          : Center(
              child: Text(
                'Aucun profil disponible.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
    );
  }

  // --- Navigation Logic ---
  void _navigateToProfile(
    BuildContext context,
    String? userId,
    String? producerId,
    Map<String, dynamic> profileData, // Pass the full profile map
    bool isUser,
    bool isProducer,
    bool isLeisureProducer
  ) async {
     final String? currentUserId = Provider.of<AuthService>(context, listen: false).userId;

    try {
      if (isUser && userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: userId),
          ),
        );
        return;
      }

      if (isProducer && producerId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: producerId,
              userId: currentUserId, // Pass current user ID
            ),
          ),
        );
        return;
      }

      if (isLeisureProducer && producerId != null) { // Leisure producers might also have an ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(
               // Pass ID if available, otherwise the full data might suffice depending on LeisureScreen implementation
               producerId: producerId,
               producerData: profileData,
               userId: currentUserId, // Pass current user ID
            ),
          ),
        );
        return;
      }

      // Fallback error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir ce profil: type inconnu ou données manquantes'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('❌ Erreur de navigation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la navigation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 