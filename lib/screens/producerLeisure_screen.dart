import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils_io.dart'; // Use utils_io.dart for getBaseUrl

import 'eventLeisure_screen.dart'; // Import nécessaire pour afficher les événements

class ProducerLeisureScreen extends StatefulWidget {
  final String producerId;
  final Map<String, dynamic>? producerData;

  // Constructor that accepts either producerId or producerData
  const ProducerLeisureScreen({
    Key? key, 
    this.producerId = '', 
    this.producerData,
  }) : super(key: key);

  @override
  _ProducerLeisureScreenState createState() => _ProducerLeisureScreenState();
}

class _ProducerLeisureScreenState extends State<ProducerLeisureScreen> {
  Map<String, dynamic>? _producerData;
  bool _isLoading = true;
  String? _error;
  late String _producerId;

  @override
  void initState() {
    super.initState();
    
    // If producerData is provided, use it directly
    if (widget.producerData != null) {
      setState(() {
        _producerData = widget.producerData;
        _isLoading = false;
        // Extract the producer ID from producerData if needed
        _producerId = widget.producerData!['_id'] ?? '';
      });
    } else {
      // Otherwise, use the provided producerId and fetch data
      _producerId = widget.producerId;
      _fetchProducerDetails();
    }
  }

  Future<void> _fetchProducerDetails() async {
    try {
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/leisureProducers/$_producerId');
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/leisureProducers/$_producerId');
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl/api/leisureProducers/$_producerId');
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _producerData = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur lors de la récupération des données: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur réseau: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Afficher un indicateur de chargement
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Détails Producteur'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Afficher un message d'erreur
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erreur'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _fetchProducerDetails();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    // Si les données sont chargées mais nulles
    if (_producerData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Données non disponibles'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(child: Text('Aucune donnée disponible pour ce producteur')),
      );
    }

    // Afficher les données du producteur
    final events = _producerData!['evenements'] ?? [];
    final coordinates = _producerData!['location']?['coordinates'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_producerData!['lieu'] ?? 'Détails Producteur'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(_producerData!),
              const Divider(height: 20, thickness: 2),
              _buildProfileActions(_producerData!),
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
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/events/$id');
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/events/$id');
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl/api/events/$id');
      }
      
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
