import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'producerLeisure_screen.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'utils.dart'; // Utilise le mécanisme d'exports conditionnels pour la bonne implémentation selon la plateforme
import 'package:intl/intl.dart';
import '../utils/leisureHelpers.dart';
import '../utils/constants.dart' as constants;

class EventLeisureScreen extends StatefulWidget {
  final dynamic eventData;
  final String? id;
  final bool isEditMode;

  const EventLeisureScreen({
    Key? key,
    this.eventData,
    this.id,
    this.isEditMode = false,
  }) : super(key: key);

  @override
  _EventLeisureScreenState createState() => _EventLeisureScreenState();
}

class _EventLeisureScreenState extends State<EventLeisureScreen> {
  Map<String, dynamic>? _eventData;
  bool _isLoading = true;
  String? _error;
  late String _eventId;
  
  // Mappings détaillés pour l'analyse AI par catégorie
  final Map<String, Map<String, dynamic>> CATEGORY_MAPPINGS_DETAILED = {
    "Théâtre": {
      "aspects": ["mise en scène", "jeu des acteurs", "texte", "scénographie"],
      "emotions": ["intense", "émouvant", "captivant", "enrichissant", "profond"]
    },
    "Théâtre contemporain": {
      "aspects": ["mise en scène", "jeu des acteurs", "texte", "originalité", "message"],
      "emotions": ["provocant", "dérangeant", "stimulant", "actuel", "profond"]
    },
    "Comédie": {
      "aspects": ["humour", "jeu des acteurs", "rythme", "dialogue"],
      "emotions": ["drôle", "amusant", "divertissant", "léger", "enjoué"]
    },
    "Spectacle musical": {
      "aspects": ["performance musicale", "mise en scène", "chant", "chorégraphie"],
      "emotions": ["entraînant", "mélodieux", "festif", "rythmé", "touchant"]
    },
    "One-man-show": {
      "aspects": ["humour", "présence scénique", "texte", "interaction"],
      "emotions": ["drôle", "mordant", "spontané", "énergique", "incisif"]
    },
    "Concert": {
      "aspects": ["performance", "répertoire", "son", "ambiance"],
      "emotions": ["électrisant", "envoûtant", "festif", "énergique", "intense"]
    },
    "Musique électronique": {
      "aspects": ["dj", "ambiance", "son", "rythme"],
      "emotions": ["festif", "énergique", "immersif", "exaltant", "hypnotique"]
    },
    "Danse": {
      "aspects": ["chorégraphie", "technique", "expressivité", "musique"],
      "emotions": ["gracieux", "puissant", "fluide", "émouvant", "esthétique"]
    },
    "Cirque": {
      "aspects": ["performance", "mise en scène", "acrobaties", "créativité"],
      "emotions": ["impressionnant", "magique", "époustouflant", "spectaculaire", "poétique"]
    },
    "Default": {  // Catégorie par défaut si non reconnue
      "aspects": ["qualité générale", "intérêt", "originalité"],
      "emotions": ["agréable", "intéressant", "divertissant", "satisfaisant"]
    }
  };
  
  // Cartographie standardisée des catégories
  final Map<String, String> CATEGORY_MAPPING = {
    "default": "Autre",
    "deep": "Musique » Électronique",
    "techno": "Musique » Électronique",
    "house": "Musique » Électronique",
    "hip hop": "Musique » Hip-Hop",
    "rap": "Musique » Hip-Hop",
    "rock": "Musique » Rock",
    "indie": "Musique » Indie",
    "pop": "Musique » Pop",
    "jazz": "Musique » Jazz",
    "soul": "Musique » Soul",
    "funk": "Musique » Funk",
    "dj set": "Musique » DJ Set",
    "club": "Musique » Club",
    "festival": "Festival",
    "concert": "Concert",
    "live": "Concert",
    "comédie": "Théâtre » Comédie",
    "spectacle": "Spectacles",
    "danse": "Spectacles » Danse",
    "exposition": "Exposition",
    "conférence": "Conférence",
    "stand-up": "Spectacles » One-man-show",
    "one-man-show": "Spectacles » One-man-show",
    "théâtre": "Théâtre",
    "cinéma": "Cinéma",
    "projection": "Cinéma",
  };
  
  // Helper method to standardize a category
  String _getStandardCategory(String rawCategory) {
    if (rawCategory.isEmpty) return CATEGORY_MAPPING["default"]!;
    
    // Convertir en minuscules pour une correspondance insensible à la casse
    String lowerCategory = rawCategory.toLowerCase();
    
    // Vérifier dans le mapping
    for (var entry in CATEGORY_MAPPING.entries) {
      if (lowerCategory.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Si aucune correspondance, renvoyer la catégorie par défaut
    return CATEGORY_MAPPING["default"]!;
  }
  
  // Helper method to get category details
  Map<String, dynamic> _getCategoryDetails(String category) {
    if (category.isEmpty) return CATEGORY_MAPPINGS_DETAILED["Default"]!;
    
    // Extraire la catégorie principale (avant le »)
    final mainCategory = category.split('»')[0].trim();
    
    // Chercher les détails de la catégorie
    if (CATEGORY_MAPPINGS_DETAILED.containsKey(mainCategory)) {
      return CATEGORY_MAPPINGS_DETAILED[mainCategory]!;
    } else if (CATEGORY_MAPPINGS_DETAILED.containsKey(category)) {
      return CATEGORY_MAPPINGS_DETAILED[category]!;
    }
    
    // Si aucune correspondance exacte, chercher une correspondance partielle
    for (final entry in CATEGORY_MAPPINGS_DETAILED.entries) {
      if (mainCategory.contains(entry.key) || entry.key.contains(mainCategory)) {
        return entry.value;
      }
    }
    
    return CATEGORY_MAPPINGS_DETAILED["Default"]!;
  }
  
  // Helper method to get emoji for emotion
  String _getEmojiForEmotion(String emotion) {
    emotion = emotion.toLowerCase();
    if (emotion.contains('drôle') || emotion.contains('amusant')) return '😂';
    if (emotion.contains('émouvant') || emotion.contains('touchant')) return '😢';
    if (emotion.contains('intense')) return '😲';
    if (emotion.contains('captivant')) return '👀';
    if (emotion.contains('profond')) return '🤔';
    if (emotion.contains('provocant') || emotion.contains('dérangeant')) return '😳';
    if (emotion.contains('stimulant')) return '💡';
    if (emotion.contains('festif') || emotion.contains('enjoué')) return '🎉';
    if (emotion.contains('léger')) return '✨';
    if (emotion.contains('entraînant') || emotion.contains('rythmé')) return '🎵';
    if (emotion.contains('mélodieux')) return '🎼';
    if (emotion.contains('gracieux')) return '💃';
    if (emotion.contains('puissant')) return '💪';
    if (emotion.contains('fluide')) return '🌊';
    if (emotion.contains('esthétique')) return '🎨';
    if (emotion.contains('impressionnant') || emotion.contains('époustouflant')) return '😮';
    if (emotion.contains('magique') || emotion.contains('spectaculaire')) return '✨';
    if (emotion.contains('poétique')) return '📝';
    if (emotion.contains('hypnotique') || emotion.contains('immersif')) return '🌀';
    if (emotion.contains('électrisant') || emotion.contains('énergique')) return '⚡';
    if (emotion.contains('envoûtant')) return '✨';
    return '👍';
  }
  
  // Helper to capitalize first letter of a string
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    
    // If eventData is provided, use it directly
    if (widget.eventData != null) {
      setState(() {
        _eventData = widget.eventData;
        _isLoading = false;
        // Extract the event ID from eventData if needed
        _eventId = widget.eventData!['_id'] ?? '';
      });
    } else {
      // Otherwise, use the provided eventId and fetch data
      _eventId = widget.eventData!['_id'] ?? '';
      _fetchEventDetails();
    }
  }

  Future<void> _fetchEventDetails() async {
    final http.Client client = http.Client();
    
    try {
      Uri url;
      final String baseUrl = await constants.getBaseUrl();
      bool success = false;
      Map<String, dynamic>? responseData;
      
      // Tentative 1: /api/events/$_eventId (route principale standardisée)
      try {
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/events/$_eventId');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/events/$_eventId');
        }
        
        print('🔗 Tentative 1: $url');
        final response = await client.get(url).timeout(
          const Duration(seconds: 10),
          onTimeout: () => http.Response('{"error":"timeout"}', 408),
        );

        if (response.statusCode == 200) {
          responseData = json.decode(response.body);
          success = true;
          print('✅ Événement trouvé via /api/events/');
        } else {
          print('⚠️ Échec avec le statut: ${response.statusCode}');
        }
      } catch (e) {
        print('⚠️ Erreur lors de la première tentative: $e');
      }
      
      // Tentative 2: /api/evenements/$_eventId (pour la compatibilité backwards)
      if (!success) {
        try {
          if (baseUrl.startsWith('http://')) {
            final domain = baseUrl.replaceFirst('http://', '');
            url = Uri.http(domain, '/api/evenements/$_eventId');
          } else {
            final domain = baseUrl.replaceFirst('https://', '');
            url = Uri.https(domain, '/api/evenements/$_eventId');
          }
          
          print('🔗 Tentative 2 (fallback): $url');
          final response = await client.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('{"error":"timeout"}', 408),
          );

          if (response.statusCode == 200) {
            responseData = json.decode(response.body);
            success = true;
            print('✅ Événement trouvé via /api/evenements/ (fallback)');
          } else {
            print('⚠️ Échec avec le statut: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Erreur lors de la deuxième tentative: $e');
        }
      }
      
      // Si l'une des tentatives a réussi, formater les données
      if (success && responseData != null) {
        setState(() {
          _eventData = {
            ...responseData!,
            'date_formatted': formatEventDate(responseData['date_debut'] ?? responseData['prochaines_dates']),
            'is_passed': isEventPassed(responseData),
            'image': getEventImageUrl(responseData),
          };
          _isLoading = false;
        });
      } else {
        // Si toutes les tentatives ont échoué
        setState(() {
          _error = 'Erreur lors de la récupération des données de l\'événement';
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
          title: const Text('Détails Événement'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Afficher un message d'erreur
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erreur'),
          backgroundColor: Colors.teal,
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
                  _fetchEventDetails();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    // Si les données sont chargées mais nulles
    if (_eventData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Données non disponibles'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(child: Text('Aucune donnée disponible pour cet événement')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_eventData!['intitulé'] ?? 'Détails Événement'),
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
                  
                  // Amis intéressés
                  _buildFriendsInterests(),
                  
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
                  if (_eventData!['purchase_url'] != null)
                    _buildPurchaseButton(_eventData!['purchase_url']),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Map avec localisation
            _buildMap(),

            const SizedBox(height: 16),
            
            // Lineup (si disponible)
            if (_eventData!['lineup'] != null && _eventData!['lineup'] is List && (_eventData!['lineup'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildLineup(),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Affiche le lineup de l'événement avec style amélioré
  Widget _buildLineup() {
    final lineup = _eventData!['lineup'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la section avec style amélioré
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.teal.withOpacity(0.3), width: 2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people, color: Colors.teal),
              ),
              const SizedBox(width: 12),
              Text(
                'Line-up (${lineup.length})',
                style: const TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Liste des artistes avec style amélioré
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lineup.length,
          itemBuilder: (context, index) {
            final artist = lineup[index];
            final String artistName = artist['nom'] ?? 'Artiste';
            final String? artistImage = artist['image'];
            
            // Générer une URL d'avatar si l'image est null, vide ou provient de placeholder.com
            final String imageUrl = (artistImage != null && 
                               artistImage.isNotEmpty && 
                               !artistImage.contains('placeholder.com')) 
                               ? artistImage 
                               : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(artistName)}&background=random&size=200';
            
            return InkWell(
              onTap: () => _searchEventsByArtist(context, artistName),
              child: Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.teal.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Photo de l'artiste avec effet
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.person, size: 40, color: Colors.grey),
                                  ),
                                ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Informations de l'artiste avec style amélioré
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artistName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event, size: 14, color: Colors.teal),
                                    SizedBox(width: 6),
                                    Text(
                                      'Voir tous les événements',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Flèche pour indiquer la navigation
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_ios, color: Colors.teal, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Recherche tous les événements d'un artiste avec meilleure gestion d'erreurs
  Future<void> _searchEventsByArtist(BuildContext context, String artistName) async {
    // Afficher une boîte de dialogue de chargement améliorée
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'Recherche d\'événements pour $artistName...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
    
    try {
      // Construire l'URL pour la recherche
      final baseUrl = await constants.getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/events/search-by-artist', {'artistName': artistName});
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/events/search-by-artist', {'artistName': artistName});
      } else {
        url = Uri.parse('$baseUrl/api/events/search-by-artist?artistName=$artistName');
      }
      
      // Log pour debugging
      print('🔍 Recherche d\'événements pour l\'artiste: $artistName');
      print('🔗 URL: $url');
      
      // Ajouter un timeout pour éviter que la requête ne reste bloquée
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Timeout lors de la requête vers $url');
          return http.Response('{"error": "timeout"}', 408);
        },
      );
      
      // Fermer la boîte de dialogue de chargement
      Navigator.of(context).pop();
      
      // Log de la réponse pour debugging
      print('📊 Statut de la réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final List<dynamic> events = json.decode(response.body);
          print('✅ Événements trouvés: ${events.length}');
          
          if (events.isEmpty) {
            _showInfo(context, 'Aucun événement trouvé', 'Aucun événement trouvé pour $artistName');
            return;
          }
          
          // Afficher la liste des événements
          _showArtistEventsSheet(context, events, artistName);
        } catch (jsonError) {
          print('❌ Erreur lors du décodage JSON: $jsonError');
          _showError(context, 'Erreur lors du traitement des données. Veuillez réessayer.');
        }
      } else if (response.statusCode == 408) {
        _showError(context, 'La requête a pris trop de temps. Veuillez réessayer.');
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        print('❌ Corps de la réponse: ${response.body}');
        _showError(context, 'Erreur lors de la recherche des événements (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception: $e');
      // Fermer la boîte de dialogue de chargement en cas d'erreur
      Navigator.of(context).pop();
      _showError(context, 'Impossible de se connecter au serveur. Veuillez vérifier votre connexion et réessayer.');
    }
  }

  /// Afficher un message d'information
  void _showInfo(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Affiche la liste des événements d'un artiste
  void _showArtistEventsSheet(BuildContext context, List<dynamic> events, String artistName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
                              builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
                                return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle pour faire glisser
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  
                  // Titre avec icône
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Événements avec $artistName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Liste des événements
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              // Fermer la bottom sheet
                              Navigator.pop(context);
                              
                              // Naviguer vers l'événement si ce n'est pas l'événement actuel
                              if (event['_id'] != _eventId) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventLeisureScreen(
                                      eventData: event,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                // Image de l'événement
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                  child: event['image'] != null
                                    ? Image.network(
                                        event['image'],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: Icon(Icons.broken_image, size: 40),
                                        ),
                                      )
                                    : Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.event, size: 40),
                                      ),
                                ),
                                
                                // Détails de l'événement
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event['intitulé'] ?? 'Événement sans titre',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (event['lieu'] != null) Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                event['lieu'],
                                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (event['prochaines_dates'] != null) Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              event['prochaines_dates'],
                                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Marqueur si c'est l'événement actuel
                                if (event['_id'] == _eventId) Container(
                                  width: 4,
                                  height: 100,
                                  color: Colors.teal,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Header avec image, note et cœur - design amélioré et moderne
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Image principale avec effet de dégradé
          if (_eventData!['image'] != null)
            ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.8)],
                ).createShader(rect);
              },
              blendMode: BlendMode.darken,
              child: Image.network(
                getEventImageUrl(_eventData!),
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 280,
                    color: Colors.grey[800],
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 280,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 60, color: Colors.white70),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 280,
              color: Colors.grey[800],
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 60, color: Colors.white70),
              ),
            ),
          
          // Information overlay at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catégorie et date en chips
                  Row(
                    children: [
                      if (_eventData!['catégorie'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _eventData!['catégorie']?.split('»').last.trim() ?? 'Catégorie',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (_eventData!['date_formatted'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _eventData!['is_passed'] == true 
                                ? Colors.grey.withOpacity(0.6) 
                                : Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _eventData!['is_passed'] == true 
                                    ? Icons.history 
                                    : Icons.calendar_today,
                                size: 12,
                                color: Colors.white
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _eventData!['date_formatted'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Badge de note
          if (_eventData!['note'] != null && _eventData!['note'] is num)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${double.parse(_eventData!['note'].toString()).toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_outline, color: Colors.white70, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'N/A',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
              
          // Badge d'interaction (coeur)
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              children: [
                // Bouton intérêt
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        '0',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                // Bouton Choice
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        '0',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Détails principaux (intitulé, description, catégorie, lieu) avec design amélioré
  Widget _buildMainDetails(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de l'événement avec style amélioré
          Text(
            _eventData!['intitulé'] ?? 'Nom non spécifié',
            style: const TextStyle(
              fontSize: 26, 
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Séparateur stylisé
          Container(
            height: 3,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          const SizedBox(height: 16),

          // Description de l'événement avec style amélioré
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Text(
              _eventData!['détail'] ?? 'Description non spécifiée',
              style: const TextStyle(
                fontSize: 16, 
                color: Colors.black87, 
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          // Catégorie avec navigation - design amélioré
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _fetchEventsByCategory(context, _eventData!['catégorie']),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Catégorie : ${_eventData!['catégorie']?.split('»').last.trim() ?? 'Non spécifiée'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Lieu avec navigation - design amélioré
          if (_eventData!['lieu'] != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToProducer(context, _eventData!['lieu']!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Lieu : ${_eventData!['lieu']}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 24),

          // Dates et horaires avec design amélioré
          if (_eventData!['date_debut'] != null && _eventData!['date_fin'] != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.teal.withOpacity(0.1),
                    Colors.blue.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête de section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.event, color: Colors.teal),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Dates et Horaires',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Dates avec icône
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.date_range, color: Colors.teal, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dates',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_eventData!['date_debut']} - ${_eventData!['date_fin']}',
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  // Horaires avec icône
                  if (_eventData!['horaires'] != null && _eventData!['horaires'] is List)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, color: Colors.teal, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Horaires',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _eventData!['horaires'].map<Widget>((horaire) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Colors.teal,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${horaire['jour']} : ${horaire['heure']}',
                                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 20),

                  // Bouton Ajouter à l'agenda avec style amélioré
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_eventData!['date_debut'] != null && _eventData!['date_fin'] != null) {
                          _addToCalendar(_eventData!);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('Ajouter à mon agenda'),
                      style: ElevatedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  /// Prix par catégories avec design amélioré
  Widget _buildPriceDetails() {
    final categoriesPrix = _eventData!['catégories_prix'] ?? [];
    if (categoriesPrix.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.euro, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            const Text(
              'Prix : Non disponible',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre avec icône
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.euro, color: Colors.green),
              ),
              const SizedBox(width: 12),
              const Text(
                'Prix par catégories',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Liste des prix
          ...categoriesPrix.map<Widget>((category) {
            final prices = category['Prix']?.map((p) => p.toString()).join(', ') ?? 'Non spécifié';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${category["Catégorie"]}',
                      style: const TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      prices,
                      style: const TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  /// Notes globales, émotions et appréciation globale avec design amélioré
  Widget _buildGlobalNotes() {
    final notes = _eventData!['notes_globales'] ?? {};
    final emotions = _eventData!['emotions'] ?? [];
    final appreciation = _eventData!['notes_globales']?['appréciation_globale'] ?? '';
    
    // Récupérer les statistiques d'interactions
    final int interestCount = _eventData!['interest_count'] ?? 0;
    final int choiceCount = _eventData!['choice_count'] ?? 0;
    
    // Déterminer la catégorie pour afficher des aspects spécifiques
    final String eventCategory = _eventData!['catégorie'] ?? '';
    final standardCategory = _getStandardCategory(eventCategory);
    final categoryDetails = _getCategoryDetails(standardCategory);
    final aspects = categoryDetails['aspects'] as List<dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre avec icône et catégorie
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.thumbs_up_down, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes & Émotions',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (eventCategory.isNotEmpty)
                      Text(
                        'Catégorie: ${eventCategory.split('»').last.trim()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // Statistiques des interactions utilisateurs
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Statistique des intérêts
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: const Icon(Icons.emoji_objects, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$interestCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const Text(
                      'Intérêts',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                
                // Ligne verticale de séparation
                Container(
                  height: 50,
                  width: 1,
                  color: Colors.grey.withOpacity(0.3),
                ),
                
                // Statistique des choix
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$choiceCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text(
                      'Choix',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (notes.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grille des notes avec style amélioré basée sur la catégorie
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Évaluation par aspects',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Parcourir dynamiquement les notes par aspects
                      ...notes.entries.where((entry) => 
                        entry.key != 'appréciation_globale' && 
                        entry.value is num
                      ).map((entry) {
                        final aspectKey = entry.key;
                        final aspectValue = entry.value;
                        
                        // Formatter le nom de l'aspect pour l'affichage
                        String displayName = aspectKey
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((word) => word.isNotEmpty 
                                ? '${word[0].toUpperCase()}${word.substring(1)}' 
                                : '')
                            .join(' ');
                            
                        // Couleur basée sur la valeur
                        Color barColor;
                        if (aspectValue >= 8) {
                          barColor = Colors.green;
                        } else if (aspectValue >= 6) {
                          barColor = Colors.amber;
                        } else if (aspectValue >= 4) {
                          barColor = Colors.orange;
                        } else {
                          barColor = Colors.red;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: barColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: barColor.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      aspectValue.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: barColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Stack(
                                children: [
                                  // Barre de fond
                                  Container(
                                    height: 8,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  // Barre de valeur
                                  Container(
                                    height: 8,
                                    width: MediaQuery.of(context).size.width * 0.7 * (aspectValue / 10),
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Émotions prédominantes
                if (emotions is List && emotions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Émotions prédominantes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: emotions.map<Widget>((emotion) {
                            final String emojiForEmotion = _getEmojiForEmotion(emotion);
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    emojiForEmotion,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _capitalizeFirstLetter(emotion.toString()),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Appréciation globale
                if (appreciation.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appréciation globale',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appreciation,
                          style: const TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.star_border, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Aucune note disponible pour le moment',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Afficher une ligne pour une note avec design amélioré
  Widget _buildNoteRowImproved(String label, dynamic value) {
    // Déterminer la couleur en fonction de la note
    Color getColorForRating(double rating) {
      if (rating >= 4.0) return Colors.green;
      if (rating >= 3.0) return Colors.amber;
      return Colors.orange;
    }
    
    // Conversion sécurisée de la valeur
    final double rating = value != null 
      ? double.tryParse(value.toString()) ?? 0.0 
      : 0.0;
      
    // Couleur basée sur la note
    final Color ratingColor = getColorForRating(rating);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: value != null
            ? Row(
                children: [
                  // Note en texte
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ratingColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ratingColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ratingColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Barre de progression
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: rating / 5.0,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(ratingColor),
                        minHeight: 8,
                      ),
                    ),
                  ),
                ],
              )
            : const Text(
                'N/A',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ),
        ],
      ),
    );
  }
  /// Boutons pour afficher les événements similaires et de la même catégorie avec design amélioré
  Widget _buildSimilarAndCategoryButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Titre de la section
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
            child: Text(
              'Explorer plus d\'événements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Les deux boutons avec design amélioré
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Bouton Événements similaires
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _fetchSimilarEvents(context),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Similaires'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
              
              // Bouton Événements par catégorie
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _fetchEventsByCategory(context, _eventData!['catégorie']),
                    icon: const Icon(Icons.category, size: 18),
                    label: const Text('Par catégorie'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Carte avec position de l'événement
  Widget _buildMap() {
    try {
      // Vérifier si location existe et contient des coordonnées
      final location = _eventData!['location']?['coordinates'];
      if (location == null || location.length != 2) {
        return const Center(child: Text('Localisation non disponible.'));
      }
      
      // Vérifier que les coordonnées sont numériques
      if (location[0] == null || location[1] == null || 
          !(location[0] is num) || !(location[1] is num)) {
        print('❌ Coordonnées invalides: valeurs non numériques');
        return const Center(child: Text('Coordonnées invalides.'));
      }
      
      // Convertir en double de manière sécurisée
      final double lon = location[0].toDouble();
      final double lat = location[1].toDouble();
      
      // Vérifier que les coordonnées sont dans les limites valides
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        print('❌ Coordonnées invalides: hors limites (lat: $lat, lon: $lon)');
        return const Center(child: Text('Coordonnées hors limites.'));
      }

      return Container(
        height: 300,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lon),
            zoom: 14.0,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('event_location'),
              position: LatLng(lat, lon),
              infoWindow: InfoWindow(
                title: _eventData!['intitulé'] ?? 'Événement',
                snippet: _eventData!['lieu'] ?? 'Lieu non spécifié',
              ),
            ),
          },
        ),
      );
    } catch (e) {
      print('❌ Erreur lors de l\'affichage de la carte: $e');
      return const Center(child: Text('Impossible d\'afficher la carte.'));
    }
  }

  /// Bouton pour acheter un billet avec design amélioré
  Widget _buildPurchaseButton(String url) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => _launchURL(url),
        icon: const Icon(Icons.shopping_cart, size: 20),
        label: const Text(
          'RÉSERVER UN BILLET',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  /// Rechercher des événements similaires
  Future<void> _fetchSimilarEvents(BuildContext context) async {
    final category = _eventData!['catégorie']?.split('»').last.trim();
    final emotions = (_eventData!['emotions'] ?? []).join(',');

    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = await constants.getBaseUrl();
    Uri uri;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      uri = Uri.http(domain, '/api/events/advanced-search', {
        'category': category,
        'emotions': emotions
      });
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      uri = Uri.https(domain, '/api/events/advanced-search', {
        'category': category,
        'emotions': emotions
      });
    } else {
      // Utiliser Uri.parse comme solution de secours
      uri = Uri.parse('$baseUrl/api/events/advanced-search?category=$category&emotions=$emotions');
    }

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

    final categoryParam = category.split('»').last.trim();
    
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = await constants.getBaseUrl();
    Uri uri;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      uri = Uri.http(domain, '/api/events/advanced-search', {'category': categoryParam});
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      uri = Uri.https(domain, '/api/events/advanced-search', {'category': categoryParam});
    } else {
      // Utiliser Uri.parse comme solution de secours
      uri = Uri.parse('$baseUrl/api/events/advanced-search?category=$categoryParam');
    }

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
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = await constants.getBaseUrl();
    Uri uri;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      uri = Uri.http(domain, '/api/events/$id');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      uri = Uri.https(domain, '/api/events/$id');
    } else {
      // Utiliser Uri.parse comme solution de secours
      uri = Uri.parse('$baseUrl/api/events/$id');
    }

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
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = await constants.getBaseUrl();
    Uri searchUrl;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      searchUrl = Uri.http(domain, '/api/unified/search', {'query': lieu});
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      searchUrl = Uri.https(domain, '/api/unified/search', {'query': lieu});
    } else {
      // Utiliser Uri.parse comme solution de secours
      searchUrl = Uri.parse('$baseUrl/api/unified/search?query=$lieu');
    }
    
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
      // Extraire le domaine et le protocole de l'URL complète
      final baseUrl = await constants.getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        // Si c'est http://
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/leisureProducers/$id');
      } else if (baseUrl.startsWith('https://')) {
        // Si c'est https://
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/leisureProducers/$id');
      } else {
        // Utiliser Uri.parse comme solution de secours
        url = Uri.parse('$baseUrl/api/leisureProducers/$id');
      }
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Navigation vers la page du producteur
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerId: id),
          ),
        );
      } else {
        _showError(context, "Erreur lors de la récupération du producteur : ${response.body}");
      }
    } catch (e) {
      _showError(context, "Erreur réseau : $e");
    }
  }

  /// Section avec les amis intéressés par l'événement
  Widget _buildFriendsInterests() {
    // Simuler des données pour les amis intéressés (à remplacer par des données réelles)
    // Dans une implémentation réelle, ces données proviendraient du backend
    final friendsData = _eventData!['friends_interested'] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de la section avec icône
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              const Text(
                'Qui y va ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // S'il y a des amis intéressés, les afficher
          if (friendsData.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatars des amis avec style
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: friendsData.length,
                    itemBuilder: (context, index) {
                      final friend = friendsData[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            // Avatar de l'ami
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.network(
                                  friend['avatarUrl'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(friend['name'] ?? 'User')}&background=random',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.person, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 4),
                            
                            // Nom de l'ami
                            Text(
                              friend['name'] ?? 'User',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Informations sur les intérêts
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.withOpacity(0.1),
                        Colors.blue.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      // Ligne pour les likes
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${_eventData!['likes_count'] ?? 0} personnes intéressées',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Ligne pour les participations
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${_eventData!['going_count'] ?? 0} personnes y participent',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Ligne pour les amis qui y vont
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.purple, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${friendsData.length} de vos amis y seront',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            // Message par défaut si aucun ami n'est intéressé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.people_outline, color: Colors.grey),
                  ),
                        const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Soyez le premier de vos amis à montrer de l\'intérêt pour cet événement !',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          // Bouton pour inviter des amis
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Logic to invite friends
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invitation envoyée !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Inviter des amis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                        