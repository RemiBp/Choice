import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'producerLeisure_screen.dart';
import 'eventLeisure_screen.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

class EventLeisureScreen extends StatelessWidget {
  final Map<String, dynamic> eventData;

  const EventLeisureScreen({Key? key, required this.eventData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(eventData['intitulé'] ?? 'Détails Événement'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header : Image, Note, et Cœur
            _buildHeader(),

            const SizedBox(height: 16),

            // Détails principaux
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainDetails(context),

                  const SizedBox(height: 16),

                  // Prix par catégories
                  _buildPriceDetails(),

                  const SizedBox(height: 16),

                  // Notes globales
                  _buildGlobalNotes(),

                  const SizedBox(height: 16),

                  // Boutons pour événements similaires et même catégorie
                  _buildSimilarAndCategoryButtons(context),

                  const SizedBox(height: 16),

                  // Lien pour réserver
                  if (eventData['purchase_url'] != null)
                    _buildPurchaseButton(eventData['purchase_url']),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Map avec localisation
            _buildMap(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Header avec image, note et cœur
  
  Widget _buildHeader() {
    return Stack(
      children: [
        if (eventData['image'] != null)
          Image.network(
            eventData['image'],
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image,
              size: 100,
            ),
          ),
        if (eventData['note'] != null && eventData['note'] is num)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.yellow, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${double.parse(eventData['note'].toString()).toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  const Text(
                    'Note non disponible',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  '0', // Statique pour l'instant
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Détails principaux (intitulé, description, catégorie, lieu)
  Widget _buildMainDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de l'événement
        Text(
          eventData['intitulé'] ?? 'Nom non spécifié',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Description de l'événement
        Text(
          eventData['détail'] ?? 'Description non spécifiée',
          style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
        ),
        const SizedBox(height: 16),

        // Catégorie avec navigation vers des événements similaires
        GestureDetector(
          onTap: () => _fetchEventsByCategory(context, eventData['catégorie']),
          child: Row(
            children: [
              const Icon(Icons.category, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Catégorie : ${eventData['catégorie']?.split('»').last.trim() ?? 'Non spécifiée'}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lieu avec navigation vers le producteur
        if (eventData['lieu'] != null)
          GestureDetector(
            onTap: () => _navigateToProducer(context, eventData['lieu']!), // Utilise 'lieu' au lieu de '_id'
            child: Row(
              children: [
                const Icon(Icons.place, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Lieu : ${eventData['lieu']}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Dates et horaires
        if (eventData['date_debut'] != null && eventData['date_fin'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Affichage des dates
                Text(
                  'Dates :',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${eventData['date_debut']} - ${eventData['date_fin']}',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 8),

                // Affichage des horaires
                if (eventData['horaires'] != null && eventData['horaires'] is List)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horaires :',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ...eventData['horaires'].map<Widget>((horaire) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '${horaire['jour']} : ${horaire['heure']}',
                            style: const TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                const SizedBox(height: 16),

                // Bouton Ajouter à l'agenda
                ElevatedButton.icon(
                  onPressed: () {
                    if (eventData['date_debut'] != null && eventData['date_fin'] != null) {
                      _addToCalendar(eventData);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Ajouter à mon agenda'),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 14),
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    backgroundColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }


  /// Prix par catégories
  Widget _buildPriceDetails() {
    final categoriesPrix = eventData['catégories_prix'] ?? [];
    if (categoriesPrix.isEmpty) {
      return const Text(
        'Prix : Non disponible',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prix par catégories :',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ...categoriesPrix.map<Widget>((category) {
          final prices = category['Prix']?.map((p) => p.toString()).join(', ') ?? 'Non spécifié';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${category["Catégorie"]}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  prices,
                  style: const TextStyle(fontSize: 16, color: Colors.green),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  /// Notes globales, émotions et appréciation globale
  Widget _buildGlobalNotes() {
    final notes = eventData['notes_globales'] ?? {};
    final emotions = eventData['emotions'] ?? [];
    final appreciation = eventData['notes_globales']?['appréciation_globale'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes globales :',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (notes.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNoteRow('Mise en scène', notes['mise_en_scene']),
              _buildNoteRow('Jeu des acteurs', notes['jeu_acteurs']),
              _buildNoteRow('Scénario', notes['scenario']),
              const SizedBox(height: 8),
              const Text('Émotions :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: emotions
                    .map<Widget>((emotion) => Chip(label: Text(emotion)))
                    .toList(),
              ),
              if (appreciation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Appréciation globale : $appreciation',
                    style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                  ),
                ),
            ],
          )
        else
          const Text('Non disponible', style: TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

  /// Afficher une ligne pour une note
  Widget _buildNoteRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label : ',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            value != null ? '${double.parse(value.toString()).toStringAsFixed(1)}' : 'Non disponible',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Boutons pour afficher les événements similaires et de la même catégorie
  Widget _buildSimilarAndCategoryButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => _fetchSimilarEvents(context),
          icon: const Icon(Icons.search),
          label: const Text('Voir événements similaires'),
        ),
        ElevatedButton.icon(
          onPressed: () => _fetchEventsByCategory(context, eventData['catégorie']),
          icon: const Icon(Icons.category),
          label: const Text('Voir par catégorie'),
        ),
      ],
    );
  }

  /// Carte avec position de l'événement
  Widget _buildMap() {
    final location = eventData['location']?['coordinates'];
    if (location == null || location.length != 2) {
      return const Center(child: Text('Localisation non disponible.'));
    }

    return Container(
      height: 300,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(location[1], location[0]),
          zoom: 14.0,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('event_location'),
            position: LatLng(location[1], location[0]),
            infoWindow: InfoWindow(
              title: eventData['intitulé'],
              snippet: eventData['lieu'],
            ),
          ),
        },
      ),
    );
  }

  /// Bouton pour acheter un billet
  Widget _buildPurchaseButton(String url) {
    return ElevatedButton.icon(
      onPressed: () => _launchURL(url),
      icon: const Icon(Icons.shopping_cart),
      label: const Text('Réserver un billet'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
      ),
    );
  }

  /// Rechercher des événements similaires
  Future<void> _fetchSimilarEvents(BuildContext context) async {
    final category = eventData['catégorie']?.split('»').last.trim();
    final emotions = (eventData['emotions'] ?? []).join(',');

    final uri = Uri.parse(
        'http://10.0.2.2:5000/api/events/advanced-search?category=$category&emotions=$emotions');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        Navigator.pop(context); // Ferme l'indicateur de chargement
        final events = json.decode(response.body) as List<dynamic>;
        _showSimilarEventsBottomSheet(context, events);
      } else {
        Navigator.pop(context); // Ferme l'indicateur de chargement
        _showError(context, 'Aucun événement similaire trouvé.');
      }
    } catch (e) {
      Navigator.pop(context); // Ferme l'indicateur de chargement
      _showError(context, 'Erreur réseau.');
    }
  }

  /// Rechercher des événements de la même catégorie
  Future<void> _fetchEventsByCategory(BuildContext context, String? category) async {
    if (category == null) return;

    final uri = Uri.parse(
        'http://10.0.2.2:5000/api/events/advanced-search?category=${category.split('»').last.trim()}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        Navigator.pop(context); // Ferme l'indicateur de chargement
        final events = json.decode(response.body) as List<dynamic>;
        _showCategoryEventsBottomSheet(context, events);
      } else {
        Navigator.pop(context); // Ferme l'indicateur de chargement
        _showError(context, 'Aucun événement trouvé dans cette catégorie.');
      }
    } catch (e) {
      Navigator.pop(context); // Ferme l'indicateur de chargement
      _showError(context, 'Erreur réseau.');
    }
  }

  /// Afficher les événements similaires dans une bottom sheet
  void _showSimilarEventsBottomSheet(BuildContext context, List<dynamic> events) {
    _showEventsBottomSheet(context, events, 'Événements similaires');
  }

  /// Afficher les événements par catégorie dans une bottom sheet
  void _showCategoryEventsBottomSheet(BuildContext context, List<dynamic> events) {
    _showEventsBottomSheet(context, events, 'Événements par catégorie');
  }

  /// Générique pour afficher des événements dans une bottom sheet
  void _showEventsBottomSheet(BuildContext context, List<dynamic> events, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: event['image'] != null
                              ? Image.network(
                                  event['image'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image),
                                )
                              : const Icon(Icons.event),
                          title: Text(event['intitulé'] ?? 'Titre non disponible'),
                          subtitle: Text(event['catégorie'] ?? 'Catégorie non disponible'),
                          onTap: () {
                            Navigator.pop(context); // Fermer la bottom sheet
                            _navigateEvent(context, event['_id']); // Naviguer avec l'ID
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addToCalendar(Map<String, dynamic> eventData) {
    // Parse les dates
    final startDate = DateTime.parse(eventData['date_debut']);
    final endDate = DateTime.parse(eventData['date_fin']);

    // Crée l'événement
    final event = Event(
      title: eventData['intitulé'] ?? 'Événement',
      description: eventData['détail'] ?? 'Pas de description disponible',
      location: eventData['lieu'] ?? 'Lieu non spécifié',
      startDate: startDate,
      endDate: endDate,
      allDay: false,
    );

    // Ajoute l'événement à l'agenda
    Add2Calendar.addEvent2Cal(event).then((success) {
      if (success) {
        print("Événement ajouté à l'agenda avec succès !");
      } else {
        print("Échec de l'ajout à l'agenda.");
      }
    });
  }


  /// Naviguer vers un événement à partir de son ID
  Future<void> _navigateEvent(BuildContext context, String id) async {
    final uri = Uri.parse('http://10.0.2.2:5000/api/events/$id');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(uri);

      Navigator.pop(context); // Fermer l'indicateur de chargement

      if (response.statusCode == 200) {
        final eventData = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventLeisureScreen(eventData: eventData),
          ),
        );
      } else {
        _showError(context, 'Événement non trouvé.');
      }
    } catch (e) {
      Navigator.pop(context); // Fermer l'indicateur de chargement
      _showError(context, 'Erreur réseau.');
    }
  }

  /// Recherche du producteur lié via le nom du lieu
  Future<void> _navigateToProducer(BuildContext context, String lieu) async {
    final searchUrl = Uri.parse('http://10.0.2.2:5000/api/unified/search?query=$lieu');
    print('🔍 Recherche du producteur pour le lieu : $lieu');

    try {
      // Étape 1 : Effectuer la recherche initiale avec le lieu
      final response = await http.get(searchUrl);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        // Ajout de logs pour les résultats
        print('🔍 Résultats de la recherche initiale : $results');

        // Étape 2 : Vérifier si des résultats existent
        if (results.isNotEmpty) {
          // Étape 3 : Filtrer pour obtenir un producteur de type 'leisureProducer' et avec le bon lieu
          final producer = results.firstWhere(
            (result) =>
                result['type'] == 'leisureProducer' &&
                result['lieu'] == lieu, // Validation supplémentaire
            orElse: () => null,
          );

          if (producer != null) {
            // Étape 4 : Extraire l'ID du producteur et chercher ses détails
            final producerId = producer['_id'];
            print('✅ Producteur trouvé : $producer');
            await _navigateToProducerDetails(context, producerId);
          } else {
            // Aucun producteur trouvé correspondant au lieu
            _showError(context, "Aucun producteur trouvé pour le lieu : $lieu.");
          }
        } else {
          // Aucun résultat trouvé dans la recherche initiale
          _showError(context, "Aucun résultat trouvé pour le lieu : $lieu.");
        }
      } else {
        // Erreur dans la requête de recherche
        _showError(context, "Erreur lors de la recherche : ${response.body}");
      }
    } catch (e) {
      // Gestion des erreurs réseau
      _showError(context, "Erreur réseau : $e");
    }
  }

  /// Navigation vers le profil du producteur avec l'ID
  Future<void> _navigateToProducerDetails(BuildContext context, String id) async {
    print('🔍 Navigation vers le producteur avec ID : $id');

    try {
      // URL directement pour les producteurs
      final url = Uri.parse('http://10.0.2.2:5000/api/leisureProducers/$id');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Navigation vers la page du producteur
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerData: data),
          ),
        );
      } else {
        _showError(context, "Erreur lors de la récupération du producteur : ${response.body}");
      }
    } catch (e) {
      _showError(context, "Erreur réseau : $e");
    }
  }

  /// Lancer une URL
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Impossible d\'ouvrir $url';
    }
  }

  /// Afficher une erreur
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
