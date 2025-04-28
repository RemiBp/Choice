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

class RelationDetailsScreen extends StatefulWidget {
  final String producerId;
  final String relationType; // 'followers' or 'following'

  const RelationDetailsScreen({
    Key? key,
    required this.producerId,
    required this.relationType,
  }) : super(key: key);

  @override
  _RelationDetailsScreenState createState() => _RelationDetailsScreenState();
}

class _RelationDetailsScreenState extends State<RelationDetailsScreen> {
  late Future<List<Map<String, dynamic>>> _relationsFuture;

  @override
  void initState() {
    super.initState();
    _relationsFuture = _fetchRelations();
  }

  Future<List<Map<String, dynamic>>> _fetchRelations() async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/relations');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Extraire la liste correcte ('followers' ou 'following')
        final List<dynamic>? usersList = data[widget.relationType]?['users'];
        
        if (usersList != null) {
          // Filtrer et convertir en List<Map<String, dynamic>>
          return usersList
              .whereType<Map<String, dynamic>>() // Garder uniquement les Map<String, dynamic>
              .toList();
        } else {
          print('⚠️ La clé "${widget.relationType}" ou "users" est manquante ou nulle.');
          return []; // Retourner une liste vide si la structure est incorrecte
        }
      } else {
        print('❌ Erreur API relations: ${response.statusCode}');
        throw Exception('Impossible de charger les relations');
      }
    } catch (e) {
      print('❌ Erreur réseau ou décodage (relations): $e');
      throw Exception('Erreur réseau ou de décodage');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.relationType == 'followers' ? 'Followers' : 'Following'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _relationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
    return Center(
                child: Text(
                    'Aucun utilisateur trouvé pour "${widget.relationType}".'));
          }

          final relations = snapshot.data!;

    return ListView.builder(
            itemCount: relations.length,
      itemBuilder: (context, index) {
              final user = relations[index];
              final userId = user['_id'] as String?;
              final userName = user['name'] ?? user['username'] ?? 'Utilisateur inconnu';
              final userImage = user['profileImage'] ?? constants.getDefaultAvatarUrl();

              if (userId == null) {
                print('⚠️ Utilisateur sans ID trouvé à l\'index $index: $user');
                return const SizedBox.shrink(); 
              }
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(userImage),
                  onBackgroundImageError: (exception, stackTrace) {
                     print('⚠️ Erreur de chargement de l\'image pour $userName: $exception');
                  },
                  child: userImage == constants.getDefaultAvatarUrl() 
                         ? const Icon(Icons.person)
                         : null,
                ),
                title: Text(userName),
                onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: userId),
        ),
      );
                },
              );
            },
          );
        },
      ),
    );
  }
} 