import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'eventLeisure_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';

class MyProducerLeisureProfileScreen extends StatefulWidget {
  final String userId;

  const MyProducerLeisureProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyProducerLeisureProfileScreen> createState() => _MyProducerLeisureProfileScreenState();
}

class _MyProducerLeisureProfileScreenState extends State<MyProducerLeisureProfileScreen> {
  late Future<Map<String, dynamic>> producerData;

  @override
  void initState() {
    super.initState();
    producerData = _fetchProducerData(widget.userId);
  }

  Future<Map<String, dynamic>> _fetchProducerData(String userId) async {
    final url = Uri.parse('${getBaseUrl()}/api/producers/$userId'); // URL API
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur lors de la récupération des données : ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails Producteur'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: producerData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Erreur : ${snapshot.error}'),
            );
          }

          final data = snapshot.data!;
          final events = data['evenements'] ?? [];
          final coordinates = data['location']?['coordinates'];

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(data),
                  const Divider(height: 20, thickness: 2),
                  _buildProfileActions(data),
                  const Divider(height: 20, thickness: 2),
                  if (events.isNotEmpty) ...[
                    _buildUpcomingEvents(events, context),
                    const Divider(height: 20, thickness: 2),
                  ],
                  if (coordinates != null) _buildMap(coordinates),
                ],
              ),
            ),
          );
        },
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
    final url = Uri.parse('${getBaseUrl()}/api/events/$id');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(eventData: data),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la récupération des détails : ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur réseau : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMap(List<dynamic> coordinates) {
    try {
      // Vérification que les coordonnées sont valides
      if (coordinates.length < 2) {
        print('❌ Coordonnées invalides: longueur insuffisante');
        return _buildMapErrorWidget('Coordonnées incomplètes');
      }
      
      // Vérification que les coordonnées sont numériques
      if (coordinates[0] == null || coordinates[1] == null || 
          !(coordinates[0] is num) || !(coordinates[1] is num)) {
        print('❌ Coordonnées invalides: valeurs non numériques');
        return _buildMapErrorWidget('Coordonnées non numériques');
      }
      
      // Convertir en double de manière sécurisée
      final double longitude = coordinates[0].toDouble();
      final double latitude = coordinates[1].toDouble();
      
      // Vérifier que les coordonnées sont dans les limites valides
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        print('❌ Coordonnées invalides: hors limites (lat: $latitude, lon: $longitude)');
        return _buildMapErrorWidget('Coordonnées hors limites');
      }
      
      final latLng = LatLng(latitude, longitude);

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
              markers: {Marker(markerId: const MarkerId('producer'), position: latLng)},
            ),
          ),
        ],
      );
    } catch (e) {
      print('❌ Erreur lors de l\'affichage de la carte: $e');
      return _buildMapErrorWidget('Impossible d\'afficher la carte');
    }
  }
  
  // Widget de remplacement en cas d'erreur de carte
  Widget _buildMapErrorWidget(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emplacement',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
