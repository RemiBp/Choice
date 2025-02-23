import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'eventLeisure_screen.dart'; // Import nécessaire pour afficher les événements
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';

class ProducerLeisureScreen extends StatelessWidget {
  final Map<String, dynamic> producerData;

  const ProducerLeisureScreen({Key? key, required this.producerData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final events = producerData['evenements'] ?? [];
    final coordinates = producerData['location']?['coordinates'];

    return Scaffold(
      appBar: AppBar(
        title: Text(producerData['lieu'] ?? 'Détails Producteur'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(producerData),
              const Divider(height: 20, thickness: 2),
              _buildProfileActions(producerData),
              const Divider(height: 20, thickness: 2),
              if (events.isNotEmpty) ...[
                _buildUpcomingEvents(events, context),
                const Divider(height: 20, thickness: 2),
              ],
              if (coordinates != null) _buildMap(coordinates),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(
              data['photo'] ?? 'https://via.placeholder.com/100',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['lieu'] ?? 'Nom non spécifié',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  data['description'] ?? 'Description non spécifiée',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adresse : ${data['adresse'] ?? 'Non spécifiée'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActions(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '${data['nombre_evenements'] ?? 0}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text('Événements'),
            ],
          ),
          Column(
            children: [
              Text(
                '4.5', // Remplacez par une variable si la note globale est calculée.
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text('Note'),
            ],
          ),
          Column(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.favorite, color: Colors.red),
              ),
              const Text('Favoris'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents(List<dynamic> events, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Événements à venir',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...events.map<Widget>((event) {
          // Extraction de l'ID de l'événement à partir de "lien_evenement"
          final eventId = event['lien_evenement']?.split('/').last;
          return GestureDetector(
            onTap: () {
              if (eventId != null) {
                _navigateToEventDetails(context, eventId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Impossible de charger l'événement."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                leading: const Icon(Icons.event, color: Colors.purple),
                title: Text(
                  event['intitulé'] ?? 'Nom non spécifié',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Catégorie : ${event['catégorie'] ?? 'Non spécifiée'}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _navigateToEventDetails(BuildContext context, String id) async {
    print('🔍 Navigation vers l\'événement avec ID : $id');

    try {
      // URL directement pour les événements
      final url = Uri.parse('${getBaseUrl()}/api/events/$id');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Décodage des données de l'événement
        final data = json.decode(response.body);

        // Navigation vers la page de l'événement
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(eventData: data),
          ),
        );
      } else {
        // Erreur lors de la récupération des détails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la récupération des détails : ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Gestion des erreurs réseau
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur réseau : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMap(List<dynamic> coordinates) {
    final latLng = LatLng(coordinates[1], coordinates[0]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emplacement',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
            markers: {Marker(markerId: MarkerId('producer'), position: latLng)},
          ),
        ),
      ],
    );
  }
}
