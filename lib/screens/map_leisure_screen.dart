import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'producerLeisure_screen.dart';
import 'eventLeisure_screen.dart';

class MapLeisureScreen extends StatefulWidget {
  const MapLeisureScreen({Key? key}) : super(key: key);

  @override
  _MapLeisureScreenState createState() => _MapLeisureScreenState();
}

class _MapLeisureScreenState extends State<MapLeisureScreen> {
  final LatLng _initialPosition = const LatLng(48.8566, 2.3522); // Paris
  late GoogleMapController _mapController;

  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isMapReady = false;

  // Filtres
  double _selectedRadius = 5000; // Rayon (5 km par défaut)
  String? _selectedProducerCategory;
  String? _selectedEventCategory;
  double _minMiseEnScene = 0;
  double _minJeuActeurs = 0;
  double _minScenario = 0;
  List<String> _selectedEmotions = [];
  double _minPrice = 0;
  double _maxPrice = 1000;
  BitmapDescriptor? _customMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
  }

  /// Charger une icône personnalisée pour les marqueurs
  Future<void> _loadCustomMarkerIcon() async {
    _customMarkerIcon = BitmapDescriptor.defaultMarker;
  }

  /// Appliquer les filtres de producteurs
  void _applyProducerFilters() {
    _fetchNearbyProducers(_initialPosition.latitude, _initialPosition.longitude);
    _showSnackBar("Recherche des producteurs mise à jour.");
  }

  /// Appliquer les filtres d'événements
  void _applyEventFilters() {
    _fetchEvents();
    _showSnackBar("Recherche des événements mise à jour.");
  }

  /// Récupérer les producteurs proches
  Future<void> _fetchNearbyProducers(double latitude, double longitude) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queryParameters = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': _selectedRadius.toString(),
        if (_selectedProducerCategory != null) 'category': _selectedProducerCategory,
      };

      final uri = Uri.http('10.0.2.2:5000', '/api/leisureProducers/nearby', queryParameters);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> producers = json.decode(response.body);

        setState(() {
          _markers = producers.map((producer) {
            final List coordinates = producer['location']['coordinates'];
            return Marker(
              markerId: MarkerId(producer['_id']),
              position: LatLng(coordinates[1], coordinates[0]),
              icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: producer['lieu'],
                snippet: producer['description'] ?? 'Pas de description',
                onTap: () {
                  _navigateToProducerDetails(producer);
                },
              ),
            );
          }).toSet();
        });
      } else {
        _showSnackBar("Erreur lors de la récupération des producteurs.");
      }
    } catch (e) {
      _showSnackBar("Erreur réseau. Veuillez vérifier votre connexion.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Récupérer les événements proches selon les critères
  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queryParameters = {
        if (_selectedEventCategory != null) 'category': _selectedEventCategory,
        if (_minMiseEnScene > 0) 'miseEnScene': _minMiseEnScene.toString(),
        if (_minJeuActeurs > 0) 'jeuActeurs': _minJeuActeurs.toString(),
        if (_minScenario > 0) 'scenario': _minScenario.toString(),
        if (_selectedEmotions.isNotEmpty) 'emotions': _selectedEmotions.join(','),
        'minPrice': _minPrice.toString(),
        'maxPrice': _maxPrice.toString(),
      };

      final uri = Uri.http('10.0.2.2:5000', '/api/events/advanced-search', queryParameters);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> events = json.decode(response.body);

        // Gestion des multiples événements au même endroit
        Map<LatLng, List<dynamic>> eventsGroupedByLocation = {};

        for (var event in events) {
          final coordinates = LatLng(event['location']['coordinates'][1], event['location']['coordinates'][0]);
          if (!eventsGroupedByLocation.containsKey(coordinates)) {
            eventsGroupedByLocation[coordinates] = [];
          }
          eventsGroupedByLocation[coordinates]!.add(event);
        }

        setState(() {
          _markers = eventsGroupedByLocation.entries.map((entry) {
            final LatLng position = entry.key;
            final List<dynamic> groupedEvents = entry.value;

            return Marker(
              markerId: MarkerId(groupedEvents.first['_id']),
              position: position,
              icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: "Lieu : ${groupedEvents.first['lieu']}",
                snippet: groupedEvents.length > 1
                    ? '${groupedEvents.length} événements disponibles'
                    : groupedEvents.first['intitulé'],
                onTap: () {
                  if (groupedEvents.length == 1) {
                    _navigateToEventDetails(groupedEvents.first['_id']);
                  } else {
                    _showEventSelectionDialog(groupedEvents);
                  }
                },
              ),
            );
          }).toSet();
        });
      } else {
        _showSnackBar("Erreur lors de la récupération des événements.");
      }
    } catch (e) {
      _showSnackBar("Erreur réseau. Veuillez vérifier votre connexion.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Afficher une boîte de dialogue pour sélectionner un événement parmi plusieurs
  void _showEventSelectionDialog(List<dynamic> events) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Sélectionnez un événement"),
          content: SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  title: Text(event['intitulé']),
                  subtitle: Text('Catégorie : ${event['catégorie']}'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEventDetails(event['_id']);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Navigation vers les détails du producteur
  void _navigateToProducerDetails(Map<String, dynamic> producer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProducerLeisureScreen(producerData: producer),
      ),
    );
  }

  /// Navigation vers les détails de l'événement
  void _navigateToEventDetails(String eventId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/events/$eventId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final eventData = json.decode(response.body);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(eventData: eventData),
          ),
        );
      } else {
        _showSnackBar("Erreur lors de la récupération des détails de l'événement.");
      }
    } catch (e) {
      _showSnackBar("Erreur réseau. Veuillez vérifier votre connexion.");
    }
  }

  /// Afficher une barre d'alerte
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des loisirs'),
      ),
      body: Column(
        children: [
          _buildProducerFilters(),
          _buildEventFilters(),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 12.0,
                  ),
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    setState(() {
                      _isMapReady = true;
                    });
                  },
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducerFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          DropdownButton<String>(
            hint: const Text('Catégorie producteur'),
            value: _selectedProducerCategory,
            items: ['Théâtre', 'Musique', 'Cinéma'].map((String category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProducerCategory = value;
              });
            },
          ),
          ElevatedButton(
            onPressed: _applyProducerFilters,
            child: const Text('Filtrer producteurs'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          DropdownButton<String>(
            hint: const Text('Catégorie événement'),
            value: _selectedEventCategory,
            items: ['Théâtre', 'Musique', 'Danse'].map((String category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedEventCategory = value;
              });
            },
          ),
          Slider(
            value: _minMiseEnScene,
            min: 0,
            max: 10,
            divisions: 10,
            label: 'Mise en scène : $_minMiseEnScene',
            onChanged: (value) {
              setState(() {
                _minMiseEnScene = value;
              });
            },
          ),
          Slider(
            value: _minJeuActeurs,
            min: 0,
            max: 10,
            divisions: 10,
            label: 'Jeu des acteurs : $_minJeuActeurs',
            onChanged: (value) {
              setState(() {
                _minJeuActeurs = value;
              });
            },
          ),
          Slider(
            value: _minScenario,
            min: 0,
            max: 10,
            divisions: 10,
            label: 'Scénario : $_minScenario',
            onChanged: (value) {
              setState(() {
                _minScenario = value;
              });
            },
          ),
          Wrap(
            children: ['drôle', 'émouvant', 'haletant', 'intense', 'poignant', 'réfléchi', 'joyeux']
                .map((emotion) => FilterChip(
                      label: Text(emotion),
                      selected: _selectedEmotions.contains(emotion),
                      onSelected: (isSelected) {
                        setState(() {
                          if (isSelected) {
                            _selectedEmotions.add(emotion);
                          } else {
                            _selectedEmotions.remove(emotion);
                          }
                        });
                      },
                    ))
                .toList(),
          ),
          ElevatedButton(
            onPressed: _applyEventFilters,
            child: const Text('Filtrer événements'),
          ),
        ],
      ),
    );
  }
}