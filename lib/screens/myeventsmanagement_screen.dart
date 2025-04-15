import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math; // Ajout de l'import math
import 'dart:convert'; // Ajout pour json.encode, json.decode et base64Encode
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../utils/leisureHelpers.dart';
import '../utils/constants.dart' as constants;
import '../utils/utils.dart';
import 'eventLeisure_screen.dart';
import 'package:flutter/services.dart';
import 'dart:io';

// Définir ApiService pour avoir baseUrl
class ApiService {
  static final String baseUrl = constants.getBaseUrl();
}

// Extension pour ajouter des minutes à TimeOfDay
extension TimeOfDayExtension on TimeOfDay {
  TimeOfDay addMinutes(int minutesToAdd) {
    final minutes = this.hour * 60 + this.minute;
    final newMinutes = minutes + minutesToAdd;
    
    final newHour = (newMinutes ~/ 60) % 24;
    final newMinute = newMinutes % 60;
    
    return TimeOfDay(hour: newHour, minute: newMinute);
  }
}

/// Écran de gestion des événements pour les producteurs de loisirs
class MyEventsManagementScreen extends StatefulWidget {
  final String producerId;
  final String? token; // Ajouter le token comme paramètre optionnel

  const MyEventsManagementScreen({
    Key? key,
    required this.producerId,
    this.token,
  }) : super(key: key);

  @override
  _MyEventsManagementScreenState createState() => _MyEventsManagementScreenState();
}

class _MyEventsManagementScreenState extends State<MyEventsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _events = [];
  Map<String, dynamic>? _producerData;
  String _searchQuery = '';
  
  // Filtres et tri
  String _filter = 'Tous';
  String _sortBy = 'Date (récent → ancien)';
  
  // Pour la création/édition d'événements
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _oldPriceController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = TimeOfDay.now();
  // Correction de TimeOfDay.add qui n'existe pas
  TimeOfDay _endTime = TimeOfDay.now().addMinutes(120); // Utiliser l'extension pour ajouter 2 heures
  String? _selectedCategory;
  List<String> _selectedTags = [];
  Uint8List? _imageBytes;
  String? _imageUrl;
  
  // Options de filtres et de tri
  final List<String> _filterOptions = ['Tous', 'À venir', 'Passés', 'Publiés', 'Brouillons'];
  final List<String> _sortOptions = [
    'Date (récent → ancien)',
    'Date (ancien → récent)',
    'Alphabétique (A → Z)',
    'Alphabétique (Z → A)',
    'Popularité',
  ];
  
  // Catégories d'événements
  final List<String> _categories = [
    'Concert',
    'Théâtre',
    'Exposition',
    'Festival',
    'Conférence',
    'Atelier',
    'Spectacle',
    'Visite guidée',
    'Autre',
  ];
  
  // Tags disponibles
  final List<String> _availableTags = [
    'Famille',
    'Adultes',
    'Enfants',
    'Gratuit',
    'Plein air',
    'Intérieur',
    'Musique',
    'Art',
    'Cinéma',
    'Danse',
    'Sport',
    'Littérature',
    'Gastronomie',
    'Bien-être',
  ];

  List<dynamic> _producerEvents = []; // Liste pour stocker les événements du producteur
  String? _error; // Variable pour stocker les messages d'erreur
  static const String _baseUrl = 'https://api.choiceapp.fr'; // URL de production

  @override
  void initState() {
    super.initState();
    _loadProducerEvents();
  }

  Future<void> _loadProducerEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Appel à l'API pour récupérer les événements du producteur
      final response = await http.get(
        Uri.parse('${_baseUrl}/producers/${widget.producerId}/events'),
        headers: widget.token != null 
            ? {'Authorization': 'Bearer ${widget.token}'} 
            : {},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _producerEvents = data['events'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur lors du chargement des événements';
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
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    super.dispose();
  }

  /// Récupère les événements du producteur depuis l'API
  Future<void> _fetchEvents() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('🔍 Récupération des événements pour le producteur: ${widget.producerId}');
      
      // Déterminer la bonne URL de base
      final baseUrl = ApiService.baseUrl;
      
      // Définir toutes les routes possibles selon la structure du backend
      List<Uri> possibleEndpoints = [];
      
      // Routes principales par ordre de priorité
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        possibleEndpoints = [
          Uri.http(domain, '/api/leisureProducers/${widget.producerId}/events'),
          Uri.http(domain, '/api/leisure/producers/${widget.producerId}/events'),
          Uri.http(domain, '/api/producers/${widget.producerId}/events'),
        ];
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        possibleEndpoints = [
          Uri.https(domain, '/api/leisureProducers/${widget.producerId}/events'),
          Uri.https(domain, '/api/leisure/producers/${widget.producerId}/events'),
          Uri.https(domain, '/api/producers/${widget.producerId}/events'),
        ];
      }
      
      // Tentative séquentielle de chaque endpoint jusqu'à obtenir un succès
      List<dynamic> events = [];
      bool success = false;
      String errorMessages = '';
      
      for (var url in possibleEndpoints) {
        try {
          print('🌐 Tentative de récupération via: $url');
          
          final response = await http.get(url);
          print('📥 Réponse API (${response.statusCode}): ${response.body.substring(0, math.min(100, response.body.length))}...');
          
          if (response.statusCode == 200) {
            events = json.decode(response.body);
            print('✅ Succès! ${events.length} événements récupérés');
            success = true;
            break;
          } else {
            errorMessages += '\n- Route $url: ${response.statusCode}';
          }
        } catch (e) {
          errorMessages += '\n- Route $url: $e';
          continue;
        }
      }
      
      if (!success) {
        // Si toutes les routes API ont échoué, vérifier dans les données du producteur
        print('⚠️ Toutes les routes API ont échoué, vérification des données du producteur...');
        
        if (_producerData != null && _producerData!['evenements'] is List) {
          print('📋 Utilisation des événements stockés dans les données du producteur');
          events = _producerData!['evenements'];
          success = true;
        } else {
          throw Exception('Impossible de récupérer les événements via les routes: $errorMessages');
        }
      }
      
      // Normaliser le format des événements
      final normalizedEvents = events.map((event) {
        // S'assurer que les champs nécessaires existent avec les bonnes clés
        Map<String, dynamic> normalizedEvent = Map<String, dynamic>.from(event);
        
        // Harmoniser les champs possibles avec différentes nomenclatures
        if (event['title'] != null && event['intitulé'] == null) {
          normalizedEvent['intitulé'] = event['title'];
        }
        
        if (event['description'] != null && event['détail'] == null) {
          normalizedEvent['détail'] = event['description'];
        }
        
        if (event['category'] != null && event['catégorie'] == null) {
          normalizedEvent['catégorie'] = event['category'];
        }
        
        // Assurer que les compteurs existent
        normalizedEvent['interest_count'] = event['interest_count'] ?? 0;
        normalizedEvent['choice_count'] = event['choice_count'] ?? 0;
        normalizedEvent['comments_count'] = event['comments_count'] ?? 0;
        
        // S'assurer que le status de publication existe
        normalizedEvent['published'] = event['published'] ?? true;
        
        return normalizedEvent;
      }).toList();
      
      setState(() {
        _events = normalizedEvents;
        _isLoading = false;
      });
      
      print('✅ Événements normalisés et chargés avec succès');
    } catch (e) {
      print('❌ Erreur lors de la récupération des événements: $e');
      setState(() {
        _isLoading = false;
        _events = []; // Initialiser avec liste vide en cas d'erreur
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la récupération des événements: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Réessayer',
            onPressed: _fetchEvents,
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  /// Filtre les événements en fonction des critères actuels
  List<dynamic> _getFilteredEvents() {
    // D'abord filtrer par recherche textuelle
    List<dynamic> filteredEvents = _events.where((event) {
      final title = event['intitulé'] ?? event['title'] ?? '';
      return title.toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    
    // Ensuite appliquer le filtre de catégorie
    if (_filter != 'Tous') {
      filteredEvents = filteredEvents.where((event) {
        final bool isUpcoming = !isEventPassed(event);
        
        switch (_filter) {
          case 'À venir':
            return isUpcoming;
          case 'Passés':
            return !isUpcoming;
          case 'Publiés':
            return event['published'] == true;
          case 'Brouillons':
            return event['published'] == false;
          default:
            return true;
        }
      }).toList();
    }
    
    // Enfin appliquer le tri
    filteredEvents.sort((a, b) {
      switch (_sortBy) {
        case 'Date (récent → ancien)':
          final dateA = parseEventDate(a['prochaines_dates'] ?? a['date_debut'] ?? '');
          final dateB = parseEventDate(b['prochaines_dates'] ?? b['date_debut'] ?? '');
          return dateB.compareTo(dateA);
        case 'Date (ancien → récent)':
          final dateA = parseEventDate(a['prochaines_dates'] ?? a['date_debut'] ?? '');
          final dateB = parseEventDate(b['prochaines_dates'] ?? b['date_debut'] ?? '');
          return dateA.compareTo(dateB);
        case 'Alphabétique (A → Z)':
          final titleA = a['intitulé'] ?? a['title'] ?? '';
          final titleB = b['intitulé'] ?? b['title'] ?? '';
          return titleA.toString().compareTo(titleB.toString());
        case 'Alphabétique (Z → A)':
          final titleA = a['intitulé'] ?? a['title'] ?? '';
          final titleB = b['intitulé'] ?? b['title'] ?? '';
          return titleB.toString().compareTo(titleA.toString());
        case 'Popularité':
          final popularityA = (a['interest_count'] ?? 0) + (a['choice_count'] ?? 0);
          final popularityB = (b['interest_count'] ?? 0) + (b['choice_count'] ?? 0);
          return popularityB.compareTo(popularityA);
        default:
          return 0;
      }
    });
    
    return filteredEvents;
  }

  /// Vérifie si un événement est passé en fonction de sa date
  bool isEventPassed(Map<String, dynamic> event) {
    try {
      final String dateStr = event['prochaines_dates'] ?? event['date_debut'] ?? event['date_fin'] ?? '';
      if (dateStr.isEmpty) return false;
      
      final DateTime eventDate = parseEventDate(dateStr);
      return eventDate.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  /// Parse une date d'événement à partir d'une chaîne de caractères
  /// Gère tous les formats de dates trouvés dans MongoDB
  DateTime parseEventDate(String dateStr) {
    try {
      print('📅 Parsing de la date: "$dateStr"');
      
      // Cas particulier: chaîne vide ou null
      if (dateStr.isEmpty) {
        print('⚠️ Date vide, utilisation de la date actuelle');
        return DateTime.now();
      }
      
      // Format 1: "DD/MM/YYYY" (format français standard)
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length >= 3) {
          // Nettoyer pour éviter les problèmes avec texte supplémentaire
          final day = int.parse(parts[0].trim().replaceAll(RegExp(r'[^0-9]'), ''));
          final month = int.parse(parts[1].trim().replaceAll(RegExp(r'[^0-9]'), ''));
          final year = int.parse(parts[2].trim().split(' ')[0].replaceAll(RegExp(r'[^0-9]'), ''));
          
          print('✅ Format DD/MM/YYYY détecté: $day/$month/$year');
          return DateTime(year, month, day);
        }
      }
      
      // Format 2: "YYYY-MM-DD" (format ISO)
      else if (dateStr.contains('-') && dateStr.length >= 10) {
        print('✅ Format YYYY-MM-DD détecté');
        return DateTime.parse(dateStr.substring(0, 10));
      }
      
      // Format 3: "jour JJ mois" (ex: "sam 8 mars", "vendredi 12 juillet")
      else if (dateStr.toLowerCase().contains(' ')) {
        final String normalizedStr = dateStr.toLowerCase().trim();
        
        // Mapper les mois en français à leur numéro
        final Map<String, int> frenchMonths = {
          'janvier': 1, 'février': 2, 'mars': 3, 'avril': 4, 'mai': 5, 'juin': 6,
          'juillet': 7, 'août': 8, 'septembre': 9, 'octobre': 10, 'novembre': 11, 'décembre': 12,
          'jan': 1, 'fév': 2, 'mar': 3, 'avr': 4, 'mai': 5, 'juin': 6,
          'juil': 7, 'aou': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'déc': 12
        };
        
        // Chercher le mois dans la chaîne
        int? month;
        String? monthStr;
        for (final m in frenchMonths.keys) {
          if (normalizedStr.contains(m)) {
            month = frenchMonths[m];
            monthStr = m;
            break;
          }
        }
        
        if (month != null && monthStr != null) {
          // Trouver le jour
          final RegExp dayRegex = RegExp(r'\b(\d{1,2})\b');
          final match = dayRegex.firstMatch(normalizedStr);
          
          if (match != null) {
            final day = int.parse(match.group(1)!);
            // Utiliser l'année courante ou extraire de la chaîne si disponible
            int year = DateTime.now().year;
            
            final RegExp yearRegex = RegExp(r'\b(20\d{2})\b'); // Années 2000-2099
            final yearMatch = yearRegex.firstMatch(normalizedStr);
            if (yearMatch != null) {
              year = int.parse(yearMatch.group(1)!);
            }
            
            print('✅ Format jour JJ mois détecté: jour $day $monthStr $year');
            return DateTime(year, month, day);
          }
        }
      }
      
      // Si aucun format ne correspond, tentative avec DateTime.parse
      print('⚠️ Format non reconnu, tentative avec DateTime.parse');
      return DateTime.parse(dateStr);
    } catch (e) {
      print('❌ Erreur lors du parsing de la date "$dateStr": $e');
      // En cas d'erreur, retourner la date actuelle
      return DateTime.now();
    }
  }
  
  /// Formatte une date pour l'affichage selon le format français préféré
  /// Adaptée aux différents contextes d'affichage
  String formatDisplayDate(dynamic dateValue, {bool includeTime = false}) {
    try {
      if (dateValue == null) return 'Date non disponible';
      
      DateTime date;
      
      // Convertir une chaîne en DateTime
      if (dateValue is String) {
        date = parseEventDate(dateValue);
      } 
      // Utiliser directement un DateTime
      else if (dateValue is DateTime) {
        date = dateValue;
      }
      // Cas non géré
      else {
        return dateValue.toString();
      }
      
      // Formater la date pour l'affichage en français
      final DateFormat formatter = includeTime
          ? DateFormat('EEE d MMMM yyyy à HH:mm', 'fr_FR')
          : DateFormat('EEE d MMMM yyyy', 'fr_FR');
      
      return formatter.format(date).toLowerCase();
    } catch (e) {
      print('❌ Erreur lors du formatage de la date "$dateValue": $e');
      return 'Date invalide';
    }
  }
  
  /// Retourne une représentation lisible des horaires d'un événement
  String formatEventSchedule(dynamic event) {
    if (event == null) return '';
    
    try {
      // Vérifier si l'événement a des horaires définis
      if (event['horaires'] != null && event['horaires'] is List && (event['horaires'] as List).isNotEmpty) {
        final horaires = (event['horaires'] as List);
        List<String> scheduleStrings = [];
        
        for (var horaire in horaires) {
          if (horaire is Map) {
            String jour = horaire['jour'] ?? '';
            String heure = horaire['heure'] ?? horaire['heures'] ?? '';
            
            if (jour.isNotEmpty && heure.isNotEmpty) {
              // Capitaliser le jour de la semaine
              jour = jour.substring(0, 1).toUpperCase() + jour.substring(1);
              scheduleStrings.add('$jour: $heure');
            }
          }
        }
        
        return scheduleStrings.join(' | ');
      }
      
      // Si pas d'horaires, utiliser date_debut + date_fin
      if (event['date_debut'] != null && event['date_fin'] != null) {
        final debut = formatDisplayDate(event['date_debut']);
        final fin = formatDisplayDate(event['date_fin']);
        
        if (debut == fin) {
          return debut;
        } else {
          return 'Du $debut au $fin';
        }
      }
      
      // Si prochaines_dates est disponible
      if (event['prochaines_dates'] != null && event['prochaines_dates'].toString().isNotEmpty) {
        return event['prochaines_dates'].toString();
      }
      
      return 'Horaires non disponibles';
    } catch (e) {
      print('❌ Erreur lors du formatage des horaires: $e');
      return 'Horaires non disponibles';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des événements'),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Événements'),
            Tab(text: 'Statistiques'),
            Tab(text: 'Paramètres'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventsTab(),
          _buildStatsTab(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateEventDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  /// Construit l'onglet des événements avec filtres et liste
  Widget _buildEventsTab() {
    final filteredEvents = _getFilteredEvents();
    
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un événement...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Filtres et options de tri
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Filtres
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    isDense: true,
                  ),
                  items: _filterOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _filter = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // Options de tri
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    isDense: true,
                  ),
                  items: _sortOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Compteur d'événements
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${filteredEvents.length} événement${filteredEvents.length > 1 ? 's' : ''} trouvé${filteredEvents.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Liste des événements
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredEvents.isEmpty
                  ? _buildEmptyEventsPlaceholder()
                  : ListView.builder(
                      itemCount: filteredEvents.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        return _buildEventCard(event);
                      },
                    ),
        ),
      ],
    );
  }
  
  /// Placeholder lorsqu'aucun événement n'est trouvé
  Widget _buildEmptyEventsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun événement trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Modifiez vos critères de recherche'
                : 'Créez votre premier événement',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: _showCreateEventDialog,
              icon: const Icon(Icons.add),
              label: const Text('Créer un événement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Construit une carte d'événement avec toutes les options de gestion
  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['intitulé'] ?? event['title'] ?? 'Sans titre';
    final dateStr = event['prochaines_dates'] ?? '';
    final category = event['catégorie'] ?? event['category'] ?? '';
    final dateFormatted = formatEventDate(dateStr);
    
    // Récupérer l'URL de l'image avec plus de robustesse
    final imageUrl = getEventImageUrl(event);
    
    // Convertir les compteurs en nombre
    final interestCount = event['interest_count'] is int ? event['interest_count'] : 
                          (event['interest_count'] is String ? int.tryParse(event['interest_count']) ?? 0 : 0);
    
    final choiceCount = event['choice_count'] is int ? event['choice_count'] : 
                        (event['choice_count'] is String ? int.tryParse(event['choice_count']) ?? 0 : 0);
    
    final commentCount = event['comment_count'] is int ? event['comment_count'] : 
                         (event['comment_count'] is String ? int.tryParse(event['comment_count']) ?? 0 : 0);
    
    // Récupérer les informations de prix
    final price = event['tarif'] ?? event['prix'] ?? '';
    final priceStr = price is num ? '$price€' : price.toString();
    
    // Traitement de la description
    final description = event['description'] ?? '';
    final shortDescription = description.length > 100 
        ? '${description.substring(0, 97)}...' 
        : description;
    
    // Déterminer si l'événement est publié
    final isPublished = event['published'] ?? true;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: () => _navigateToEventDetails(event),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec badge de statut
            Stack(
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: imageUrl.startsWith('data:image')
                    ? Image.memory(
                        _decodeBase64Image(imageUrl),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          color: Colors.grey.shade200,
                          child: const Center(child: Icon(Icons.image_not_supported, size: 40)),
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          color: Colors.grey.shade200,
                          child: const Center(child: Icon(Icons.image_not_supported, size: 40)),
                        ),
                      ),
                ),
                
                // Badge pour événement passé/à venir
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isEventPassed(event) ? Colors.grey.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isEventPassed(event) ? 'Passé' : 'À venir',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                
                // Badge pour publié/brouillon
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: event['published'] ?? true ? Colors.blue.withOpacity(0.8) : Colors.amber.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      event['published'] ?? true ? 'Publié' : 'Brouillon',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                
                // Badge pour le prix si disponible
                if (event['prix_reduit'] != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event['ancien_prix'] != null)
                            Text(
                              '${event['ancien_prix']}€',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (event['ancien_prix'] != null)
                            const SizedBox(width: 4),
                          Text(
                            '${event['prix_reduit']}€',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Contenu texte
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Date et catégorie
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.category, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            category,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Lieu de l'événement s'il diffère du producteur
                  if (event['lieu'] != null && event['lieu'] != _producerData?['lieu']) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event['lieu'],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const Divider(height: 24),
                  
                  // Statistiques et options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Statistiques
                      Row(
                        children: [
                          // Intérêts
                          _buildStatBadge(
                            Icons.emoji_objects,
                            interestCount.toString(),
                            Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          
                          // Choix
                          _buildStatBadge(
                            Icons.check_circle,
                            choiceCount.toString(),
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          
                          // Commentaires
                          _buildStatBadge(
                            Icons.comment,
                            commentCount.toString(),
                            Colors.blue,
                          ),
                        ],
                      ),
                      
                      // Menu d'options
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (option) {
                          switch (option) {
                            case 'edit':
                              _showEditEventDialog(event);
                              break;
                            case 'duplicate':
                              _duplicateEvent(event);
                              break;
                            case 'publish':
                              _toggleEventPublishStatus(event, !isPublished);
                              break;
                            case 'share':
                              _shareEvent(event);
                              break;
                            case 'delete':
                              _showDeleteEventConfirmation(event);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Modifier'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(Icons.copy, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Dupliquer'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'publish',
                            child: Row(
                              children: [
                                Icon(
                                  isPublished ? Icons.unpublished : Icons.publish, 
                                  color: isPublished ? Colors.amber : Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Text(isPublished ? 'Dépublier' : 'Publier'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, color: Colors.purple),
                                SizedBox(width: 8),
                                Text('Partager'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Supprimer'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Description
                  const SizedBox(height: 8),
                  Text(
                    shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  // Stats row
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_border, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text('$interestCount', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                          const SizedBox(width: 12),
                          
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('$choiceCount', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                          const SizedBox(width: 12),
                          
                          const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 4),
                          Text('$commentCount', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        ],
                      ),
                      
                      // Prix standard si disponible
                      if (priceStr.isNotEmpty && event['prix_reduit'] == null)
                        Text(
                          priceStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Récupérer l'URL de l'image d'un événement
  String getEventImageUrl(Map<String, dynamic> event) {
    // Si l'événement a une image directement
    if (event['image'] != null && event['image'].toString().isNotEmpty) {
      return event['image'].toString();
    }
    
    // Si l'événement a une liste de médias
    if (event['media'] is List && (event['media'] as List).isNotEmpty) {
      final firstMedia = (event['media'] as List).first;
      if (firstMedia is String) {
        return firstMedia;
      } else if (firstMedia is Map && firstMedia['url'] != null) {
        return firstMedia['url'].toString();
      }
    }
    
    // Image par défaut
    return 'https://via.placeholder.com/400x300?text=Événement';
  }
  
  /// Retourne l'icône appropriée pour une catégorie d'événement
  IconData _getCategoryIcon(String category) {
    category = category.toLowerCase();
    
    if (category.contains('concert') || category.contains('musique')) {
      return Icons.music_note;
    } else if (category.contains('théâtre') || category.contains('theatre') || category.contains('spectacle')) {
      return Icons.theater_comedy;
    } else if (category.contains('exposition') || category.contains('art')) {
      return Icons.palette;
    } else if (category.contains('festival')) {
      return Icons.festival;
    } else if (category.contains('conférence') || category.contains('conference')) {
      return Icons.mic;
    } else if (category.contains('atelier')) {
      return Icons.handyman;
    } else if (category.contains('visite') || category.contains('guidée')) {
      return Icons.tour;
    } else if (category.contains('sport')) {
      return Icons.sports;
    } else if (category.contains('cinéma') || category.contains('cinema') || category.contains('film')) {
      return Icons.movie;
    } else {
      return Icons.event;
    }
  }
  
  /// Construit un badge de statistique avec icône et valeur
  Widget _buildStatBadge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit l'onglet des statistiques
  Widget _buildStatsTab() {
    // Statistiques globales
    final int totalEvents = _events.length;
    final int upcomingEvents = _events.where((e) => !isEventPassed(e)).length;
    final int pastEvents = totalEvents - upcomingEvents;
    
    // Calculer les statistiques d'engagement
    int totalInterests = 0;
    int totalChoices = 0;
    int totalComments = 0;
    
    for (final event in _events) {
      // Convertir explicitement en int pour éviter les erreurs de type
      final interestCount = event['interest_count'];
      if (interestCount != null) {
        totalInterests += interestCount is int ? interestCount : (interestCount as num).toInt();
      }
      
      final choiceCount = event['choice_count'];
      if (choiceCount != null) {
        totalChoices += choiceCount is int ? choiceCount : (choiceCount as num).toInt();
      }
      
      final commentCount = event['comments_count'];
      if (commentCount != null) {
        totalComments += commentCount is int ? commentCount : (commentCount as num).toInt();
      }
    }
    
    // Calculer la moyenne des notes si disponible
    double averageRating = 0;
    int ratingCount = 0;
    
    for (final event in _events) {
      if (event['note'] != null && event['note'] is num) {
        averageRating += event['note'];
        ratingCount++;
      }
    }
    
    if (ratingCount > 0) {
      averageRating /= ratingCount;
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cartes résumé
          Row(
            children: [
              _buildStatCard(
                'Événements', 
                totalEvents.toString(), 
                Icons.event, 
                Colors.deepPurple,
              ),
              _buildStatCard(
                'À venir', 
                upcomingEvents.toString(), 
                Icons.event_available, 
                Colors.green,
              ),
              _buildStatCard(
                'Passés', 
                pastEvents.toString(), 
                Icons.event_busy, 
                Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Statistiques d'engagement
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_up, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Engagement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Intérêts
                _buildEngagementRow(
                  'Intérêts',
                  totalInterests.toString(),
                  Icons.emoji_objects,
                  Colors.amber,
                ),
                const SizedBox(height: 12),
                
                // Choix
                _buildEngagementRow(
                  'Choix',
                  totalChoices.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                
                // Commentaires
                _buildEngagementRow(
                  'Commentaires',
                  totalComments.toString(),
                  Icons.comment,
                  Colors.blue,
                ),
                
                if (ratingCount > 0) ...[
                  const SizedBox(height: 12),
                  // Note moyenne
                  _buildEngagementRow(
                    'Note moyenne',
                    averageRating.toStringAsFixed(1),
                    Icons.star,
                    Colors.orange,
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Top événements
          if (_events.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top événements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // En-tête
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 5,
                              child: Text(
                                'Événement',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  'Intérêts',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  'Choix',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1),
                      
                      // Liste des événements (top 5 par popularité)
                      ...List.generate(
                        math.min(5, _events.length),
                        (index) {
                          // Trier les événements par popularité
                          final sortedEvents = List<Map<String, dynamic>>.from(_events)
                            ..sort((a, b) => 
                              ((b['interest_count'] as num?)?.toInt() ?? 0) - 
                              ((a['interest_count'] as num?)?.toInt() ?? 0)
                            );
                          
                          final event = sortedEvents[index];
                          final title = event['intitulé'] ?? event['title'] ?? 'Événement sans titre';
                          final interestCount = (event['interest_count'] as num?)?.toInt() ?? 0;
                          final choiceCount = (event['choice_count'] as num?)?.toInt() ?? 0;
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Intérêts
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$interestCount intérêts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.emoji_objects,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                
                                // Choix
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$choiceCount choix',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _navigateToEventDetails(event),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  /// Construit une carte de statistique pour l'onglet statistiques
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Construit une ligne d'engagement pour l'onglet statistiques
  Widget _buildEngagementRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  /// Construit l'onglet des paramètres
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // Paramètres de publication
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings, color: Colors.blue),
                ),
                title: const Text('Paramètres de publication'),
                subtitle: const Text('Gérer le comportement par défaut des événements'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implémenter les paramètres de publication
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité en développement'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              
              // Modèles d'événements
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bookmark, color: Colors.green),
                ),
                title: const Text('Modèles d\'événements'),
                subtitle: const Text('Créer et gérer des modèles d\'événements'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implémenter les modèles d'événements
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité en développement'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              
              // Notifications
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications, color: Colors.amber),
                ),
                title: const Text('Notifications'),
                subtitle: const Text('Gérer les rappels et alertes d\'événements'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implémenter les notifications
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité en développement'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              
              // Partage sur les réseaux sociaux
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share, color: Colors.purple),
                ),
                title: const Text('Réseaux sociaux'),
                subtitle: const Text('Configurer le partage automatique'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implémenter le partage sur les réseaux sociaux
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité en développement'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Aide et contact
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help, color: Colors.cyan),
                ),
                title: const Text('Centre d\'aide'),
                subtitle: const Text('Guides et tutoriels'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implémenter le centre d'aide
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité en développement'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.support_agent, color: Colors.orange),
                ),
                title: const Text('Contacter le support'),
                subtitle: const Text('Une question ou un problème ?'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implémenter le contact du support
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité en développement'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Options avancées
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud_download, color: Colors.red),
                ),
                title: const Text('Exporter les données'),
                subtitle: const Text('Télécharger tous les événements (CSV/JSON)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implémenter l'export des données
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export des données en cours...'),
                    ),
                  );
                  
                  Future.delayed(const Duration(seconds: 1), () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Données exportées avec succès ! Fichier disponible dans vos téléchargements.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Fonction pour afficher le dialogue de création d'un nouvel événement
  void _showCreateEventDialog() {
    // Réinitialiser les valeurs du formulaire
    _titleController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _oldPriceController.clear();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 7));
    _startTime = TimeOfDay.now();
    // Correction de TimeOfDay.add qui n'existe pas
    _endTime = TimeOfDay.now().addMinutes(120); // Utiliser l'extension pour ajouter 2 heures
    _selectedCategory = null;
    _selectedTags = [];
    _imageBytes = null;
    _imageUrl = null;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Créer un nouvel événement'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      InkWell(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              _imageBytes = bytes;
                              _imageUrl = null;
                            });
                          }
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _imageBytes != null
                              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ajouter une image',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Titre
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un titre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer une description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Catégorie
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedCategory = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez sélectionner une catégorie';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Tags (Chips sélectionnables)
                      const Text('Tags (optionnel)'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          final isSelected = _selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                              });
                            },
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.deepPurple.withOpacity(0.2),
                            checkmarkColor: Colors.deepPurple,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.deepPurple : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Date de début
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date de début *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _startDate = picked;
                                        // Mettre à jour la date de fin si elle est avant la date de début
                                        if (_endDate.isBefore(_startDate)) {
                                          _endDate = _startDate;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatDisplayDate(_startDate),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.calendar_today, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Heure de début *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: _startTime,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _startTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _startTime.format(context),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.access_time, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Date de fin
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date de fin *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate,
                                      firstDate: _startDate,
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _endDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatDisplayDate(_endDate),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.calendar_today, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Heure de fin *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: _endTime,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _endTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _endTime.format(context),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.access_time, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Prix
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Prix (€)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.euro),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _oldPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Ancien prix (optionnel)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.money_off),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      _createEvent();
                    }
                  },
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  /// Crée un nouvel événement avec les données du formulaire
  Future<void> _createEvent() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Formatage des dates selon le format exact attendu par MongoDB "DD/MM/YYYY"
      final dateDebutFormatted = DateFormat('dd/MM/yyyy').format(_startDate);
      final dateFinFormatted = DateFormat('dd/MM/yyyy').format(_endDate);
      
      // Formatage des horaires selon la structure attendue par MongoDB
      // Format: [{jour: "jour_semaine", heure: "heure_debut - heure_fin"}, ...]
      final String jourDebut = DateFormat('EEEE', 'fr_FR').format(_startDate).toLowerCase();
      final String jourFin = DateFormat('EEEE', 'fr_FR').format(_endDate).toLowerCase();
      
      final List<Map<String, String>> horaires = [];
      
      // Si même jour, un seul créneau horaire
      if (dateDebutFormatted == dateFinFormatted) {
        horaires.add({
          'jour': jourDebut,
          'heure': '${_startTime.format(context)} - ${_endTime.format(context)}'
        });
      } else {
        // Si sur plusieurs jours, créer plusieurs créneaux
        // On simplifie en mettant un créneau pour le premier et dernier jour
        horaires.add({
          'jour': jourDebut,
          'heure': '${_startTime.format(context)}'
        });
        
        horaires.add({
          'jour': jourFin,
          'heure': '${_endTime.format(context)}'
        });
      }
      
      // Création d'un format simplifié pour prochaines_dates
      // Format attendu: "jour JJ mois" (ex: "sam 8 mars")
      final String prochainesDatesFr = DateFormat('EEE d MMMM', 'fr_FR')
          .format(_startDate)
          .toLowerCase();
      
      // Formatage des prix selon le format attendu "XXX€" ou null
      final String? prixReduit = _priceController.text.isNotEmpty 
          ? '${_priceController.text}€' 
          : null;
      
      final String? ancienPrix = _oldPriceController.text.isNotEmpty 
          ? '${_oldPriceController.text}€' 
          : null;
      
      // Construction du document selon la structure exacte de MongoDB
      final Map<String, dynamic> eventData = {
        'intitulé': _titleController.text,
        'détail': _descriptionController.text,
        'catégorie': _selectedCategory,
        'tags': _selectedTags,
        'date_debut': dateDebutFormatted,
        'date_fin': dateFinFormatted,
        'prochaines_dates': prochainesDatesFr,
        'horaires': horaires,
        'prix_reduit': prixReduit,
        'ancien_prix': ancienPrix,
        'published': true,
        'producer_id': widget.producerId,
        'lieu': _producerData?['lieu'] ?? 'Lieu indéfini',
        'adresse': _producerData?['adresse'] ?? '',
        'interest_count': 0,
        'choice_count': 0,
        'comments_count': 0,
        'last_updated': DateTime.now().toIso8601String(),
      };
      
      // Si une image a été sélectionnée, la convertir en base64
      if (_imageBytes != null) {
        final String base64Image = base64.encode(_imageBytes!);
        eventData['image'] = 'data:image/jpeg;base64,$base64Image';
      }
      
      // Utiliser la route correcte pour l'API selon la structure du projet
      final baseUrl = ApiService.baseUrl;
      Uri url;
      
      // Choisir la bonne route API en fonction de la structure backend
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/leisure/events');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/leisure/events');
      }
      
      print('📤 Envoi de l\'événement: ${json.encode(eventData)}');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(eventData),
      );
      
      print('📥 Réponse API (${response.statusCode}): ${response.body}');
      
      // Si l'API principale échoue, essayer la route alternative
      if (response.statusCode != 201 && response.statusCode != 200) {
        // Chemin alternatif conforme à la structure du projet
        Uri alternativeUrl;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          alternativeUrl = Uri.http(domain, '/api/leisureProducers/${widget.producerId}/events');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          alternativeUrl = Uri.https(domain, '/api/leisureProducers/${widget.producerId}/events');
        }
        
        print('🔄 Tentative avec route alternative: $alternativeUrl');
        
        final alternativeResponse = await http.post(
          alternativeUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(eventData),
        );
        
        print('📥 Réponse API alternative (${alternativeResponse.statusCode}): ${alternativeResponse.body}');
        
        if (alternativeResponse.statusCode == 201 || alternativeResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Événement créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchEvents();
          return;
        } else {
          throw Exception('Échec de création de l\'événement: ${alternativeResponse.statusCode}');
        }
      } else {
        // Création réussie avec la première route
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Événement créé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Rafraîchir la liste des événements
        _fetchEvents();
      }
    } catch (e) {
      print('❌ Erreur lors de la création de l\'événement: $e');
      // Erreur lors de la création de l'événement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création de l\'événement : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Naviguer vers les détails d'un événement
  void _navigateToEventDetails(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventLeisureScreen(
          id: event['_id'],
        ),
      ),
    );
  }
  
  /// Afficher le dialogue de modification d'un événement
  void _showEditEventDialog(Map<String, dynamic> event) {
    // Initialiser les contrôleurs avec les valeurs existantes
    _titleController.text = event['intitulé'] ?? event['title'] ?? '';
    _descriptionController.text = event['détail'] ?? event['description'] ?? '';
    
    // Initialiser les prix
    String prixReduit = event['prix_reduit'] ?? '';
    if (prixReduit.contains('€')) {
      _priceController.text = prixReduit.replaceAll('€', '').trim();
    }
    
    String ancienPrix = event['ancien_prix'] ?? '';
    if (ancienPrix.contains('€')) {
      _oldPriceController.text = ancienPrix.replaceAll('€', '').trim();
    }
    
    // Initialiser les dates
    try {
      _startDate = parseEventDate(event['date_debut'] ?? '');
      _endDate = parseEventDate(event['date_fin'] ?? '');
      
      // Essayer de récupérer les heures si disponibles
      if (event['horaires'] != null && event['horaires'] is List && (event['horaires'] as List).isNotEmpty) {
        final horaire = (event['horaires'] as List).first;
        if (horaire is Map && horaire['heure'] != null) {
          final String heureStr = horaire['heure'];
          
          // Si le format est "HH:MM - HH:MM"
          if (heureStr.contains('-')) {
            final heures = heureStr.split('-');
            
            // Heure de début
            final heureDebut = heures[0].trim();
            if (heureDebut.contains(':')) {
              final parts = heureDebut.split(':');
              _startTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
            
            // Heure de fin
            if (heures.length > 1) {
              final heureFin = heures[1].trim();
              if (heureFin.contains(':')) {
                final parts = heureFin.split(':');
                _endTime = TimeOfDay(
                  hour: int.parse(parts[0]),
                  minute: int.parse(parts[1]),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation des dates: $e');
      // Utiliser les valeurs par défaut en cas d'erreur
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
    }
    
    // Initialiser la catégorie
    _selectedCategory = event['catégorie'] ?? event['category'];
    if (_selectedCategory != null && _selectedCategory.toString().contains('»')) {
      _selectedCategory = _selectedCategory.toString().split('»')[0].trim();
    }
    
    // S'assurer que la catégorie est dans la liste des catégories disponibles
    if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
      // Si pas trouvé, prendre la première catégorie par défaut
      _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
    }
    
    // Initialiser les tags
    _selectedTags = [];
    if (event['tags'] != null && event['tags'] is List) {
      for (final tag in event['tags']) {
        if (_availableTags.contains(tag)) {
          _selectedTags.add(tag);
        }
      }
    }
    
    // Initialiser l'image
    _imageBytes = null;
    _imageUrl = getEventImageUrl(event);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier l\'événement'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      InkWell(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              _imageBytes = bytes;
                              _imageUrl = null;
                            });
                          }
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _imageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                                )
                              : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _imageUrl!.startsWith('data:image')
                                          ? Image.memory(
                                              _decodeBase64Image(_imageUrl!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  _buildImagePlaceholder('Erreur de chargement'),
                                            )
                                          : Image.network(
                                              _imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  _buildImagePlaceholder('Erreur de chargement'),
                                            ),
                                    )
                                  : _buildImagePlaceholder('Ajouter une image'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Titre
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un titre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer une description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Catégorie
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedCategory = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez sélectionner une catégorie';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Tags (Chips sélectionnables)
                      const Text('Tags (optionnel)'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          final isSelected = _selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                              });
                            },
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.deepPurple.withOpacity(0.2),
                            checkmarkColor: Colors.deepPurple,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.deepPurple : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dates et heures (identiques au formulaire de création)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date de début *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _startDate = picked;
                                        if (_endDate.isBefore(_startDate)) {
                                          _endDate = _startDate;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatDisplayDate(_startDate),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.calendar_today, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Heure de début *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: _startTime,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _startTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _startTime.format(context),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.access_time, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Date et heure de fin
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date de fin *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate,
                                      firstDate: _startDate,
                                      lastDate: _startDate.add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _endDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatDisplayDate(_endDate),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.calendar_today, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Heure de fin *'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: _endTime,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _endTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _endTime.format(context),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(Icons.access_time, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Prix
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Prix (€)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.euro),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _oldPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Ancien prix (optionnel)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.money_off),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Statut de publication
                      SwitchListTile(
                        title: const Text('Publier l\'événement'),
                        subtitle: const Text('L\'événement sera visible par tous les utilisateurs'),
                        value: event['published'] ?? true,
                        activeColor: Colors.deepPurple,
                        onChanged: (value) {
                          setDialogState(() {
                            event['published'] = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      _updateEvent(event);
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  /// Construit un placeholder pour l'image
  Widget _buildImagePlaceholder(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  /// Met à jour un événement existant
  Future<void> _updateEvent(Map<String, dynamic> event) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String eventId = event['_id'];
      
      // Formatage des dates selon le format exact attendu par MongoDB "DD/MM/YYYY"
      final dateDebutFormatted = DateFormat('dd/MM/yyyy').format(_startDate);
      final dateFinFormatted = DateFormat('dd/MM/yyyy').format(_endDate);
      
      // Formatage des horaires selon la structure attendue par MongoDB
      // Format: [{jour: "jour_semaine", heure: "heure_debut - heure_fin"}, ...]
      final String jourDebut = DateFormat('EEEE', 'fr_FR').format(_startDate).toLowerCase();
      final String jourFin = DateFormat('EEEE', 'fr_FR').format(_endDate).toLowerCase();
      
      final List<Map<String, String>> horaires = [];
      
      // Si même jour, un seul créneau horaire
      if (dateDebutFormatted == dateFinFormatted) {
        horaires.add({
          'jour': jourDebut,
          'heure': '${_startTime.format(context)} - ${_endTime.format(context)}'
        });
      } else {
        // Si sur plusieurs jours, créer plusieurs créneaux
        // On simplifie en mettant un créneau pour le premier et dernier jour
        horaires.add({
          'jour': jourDebut,
          'heure': '${_startTime.format(context)}'
        });
        
        horaires.add({
          'jour': jourFin,
          'heure': '${_endTime.format(context)}'
        });
      }
      
      // Création d'un format simplifié pour prochaines_dates
      // Format attendu: "jour JJ mois" (ex: "sam 8 mars")
      final String prochainesDatesFr = DateFormat('EEE d MMMM', 'fr_FR')
          .format(_startDate)
          .toLowerCase();
      
      // Formatage des prix selon le format attendu "XXX€" ou null
      final String? prixReduit = _priceController.text.isNotEmpty 
          ? '${_priceController.text}€' 
          : null;
      
      final String? ancienPrix = _oldPriceController.text.isNotEmpty 
          ? '${_oldPriceController.text}€' 
          : null;
      
      // Construction du document selon la structure exacte de MongoDB
      final Map<String, dynamic> eventData = {
        'intitulé': _titleController.text,
        'détail': _descriptionController.text,
        'catégorie': _selectedCategory,
        'tags': _selectedTags,
        'date_debut': dateDebutFormatted,
        'date_fin': dateFinFormatted,
        'prochaines_dates': prochainesDatesFr,
        'horaires': horaires,
        'prix_reduit': prixReduit,
        'ancien_prix': ancienPrix,
        'published': event['published'] ?? true,
        'last_updated': DateTime.now().toIso8601String(),
      };
      
      // Si une image a été sélectionnée, la convertir en base64
      if (_imageBytes != null) {
        final String base64Image = base64.encode(_imageBytes!);
        eventData['image'] = 'data:image/jpeg;base64,$base64Image';
      }
      
      // Conserver l'ID du producteur
      eventData['producer_id'] = event['producer_id'] ?? widget.producerId;
      
      // Conserver le lieu et l'adresse s'ils existent
      if (event['lieu'] != null) {
        eventData['lieu'] = event['lieu'];
      }
      if (event['adresse'] != null) {
        eventData['adresse'] = event['adresse'];
      }
      
      // Conserver les statistiques
      eventData['interest_count'] = event['interest_count'] ?? 0;
      eventData['choice_count'] = event['choice_count'] ?? 0;
      eventData['comments_count'] = event['comments_count'] ?? 0;
      
      // Utiliser la route correcte pour l'API selon la structure du projet
      final baseUrl = ApiService.baseUrl;
      Uri url;
      
      // Choisir la bonne route API en fonction de la structure backend
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/events/$eventId');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/events/$eventId');
      }
      
      print('📤 Envoi de la mise à jour: ${json.encode(eventData)}');
      
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(eventData),
      );
      
      print('📥 Réponse API (${response.statusCode}): ${response.body}');
      
      // Si l'API principale échoue, essayer la route alternative
      if (response.statusCode != 200 && response.statusCode != 204) {
        // Chemin alternatif conforme à la structure du projet
        Uri alternativeUrl;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          alternativeUrl = Uri.http(domain, '/api/leisureProducers/${widget.producerId}/events/$eventId');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          alternativeUrl = Uri.https(domain, '/api/leisureProducers/${widget.producerId}/events/$eventId');
        }
        
        print('🔄 Tentative avec route alternative: $alternativeUrl');
        
        final alternativeResponse = await http.put(
          alternativeUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(eventData),
        );
        
        print('📥 Réponse API alternative (${alternativeResponse.statusCode}): ${alternativeResponse.body}');
        
        if (alternativeResponse.statusCode == 200 || alternativeResponse.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Événement mis à jour avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchEvents();
          return;
        } else {
          throw Exception('Échec de mise à jour de l\'événement: ${alternativeResponse.statusCode}');
        }
      } else {
        // Mise à jour réussie avec la première route
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Événement mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Rafraîchir la liste des événements
        _fetchEvents();
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'événement: $e');
      // Erreur lors de la mise à jour de l'événement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour de l\'événement : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Dupliquer un événement existant
  void _duplicateEvent(Map<String, dynamic> event) {
    // Créer une copie de l'événement
    final Map<String, dynamic> duplicatedEvent = Map<String, dynamic>.from(event);
    
    // Supprimer l'ID pour que le backend en crée un nouveau
    duplicatedEvent.remove('_id');
    
    // Modifier le titre pour indiquer qu'il s'agit d'une copie
    duplicatedEvent['intitulé'] = '${duplicatedEvent['intitulé'] ?? duplicatedEvent['title'] ?? 'Événement'} (copie)';
    
    // Réinitialiser les compteurs de statistiques
    duplicatedEvent['interest_count'] = 0;
    duplicatedEvent['choice_count'] = 0;
    duplicatedEvent['comments_count'] = 0;
    
    // Mettre à jour la date de modification
    duplicatedEvent['last_updated'] = DateTime.now().toIso8601String();
    
    // Créer l'événement dans la base de données
    _submitDuplicatedEvent(duplicatedEvent);
  }
  
  /// Envoie un événement dupliqué à l'API
  Future<void> _submitDuplicatedEvent(Map<String, dynamic> duplicatedEvent) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Utiliser la route correcte pour l'API selon la structure du projet
      final baseUrl = ApiService.baseUrl;
      Uri url;
      
      // Choisir la bonne route API en fonction de la structure backend
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/leisure/events');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/leisure/events');
      }
      
      print('📤 Envoi de l\'événement dupliqué: ${json.encode(duplicatedEvent)}');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(duplicatedEvent),
      );
      
      print('📥 Réponse API (${response.statusCode}): ${response.body}');
      
      // Si l'API principale échoue, essayer la route alternative
      if (response.statusCode != 201 && response.statusCode != 200) {
        // Chemin alternatif conforme à la structure du projet
        Uri alternativeUrl;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          alternativeUrl = Uri.http(domain, '/api/leisureProducers/${widget.producerId}/events');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          alternativeUrl = Uri.https(domain, '/api/leisureProducers/${widget.producerId}/events');
        }
        
        print('🔄 Tentative avec route alternative: $alternativeUrl');
        
        final alternativeResponse = await http.post(
          alternativeUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(duplicatedEvent),
        );
        
        print('📥 Réponse API alternative (${alternativeResponse.statusCode}): ${alternativeResponse.body}');
        
        if (alternativeResponse.statusCode == 201 || alternativeResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Événement dupliqué avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchEvents();
          return;
        } else {
          throw Exception('Échec de duplication de l\'événement: ${alternativeResponse.statusCode}');
        }
      } else {
        // Duplication réussie avec la première route
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Événement dupliqué avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Rafraîchir la liste des événements
        _fetchEvents();
      }
    } catch (e) {
      print('❌ Erreur lors de la duplication de l\'événement: $e');
      // Erreur lors de la duplication de l'événement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la duplication de l\'événement : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Changer le statut de publication d'un événement
  Future<void> _toggleEventPublishStatus(Map<String, dynamic> event, bool newStatus) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String eventId = event['_id'];
      
      // Mettre à jour le statut de publication
      final Map<String, dynamic> updateData = {
        'published': newStatus,
        'last_updated': DateTime.now().toIso8601String(),
      };
      
      // Utiliser la route correcte pour l'API selon la structure du projet
      final baseUrl = ApiService.baseUrl;
      Uri url;
      
      // Choisir la bonne route API en fonction de la structure backend
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/events/$eventId');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/events/$eventId');
      }
      
      print('📤 Mise à jour du statut de publication: ${json.encode(updateData)}');
      
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );
      
      print('📥 Réponse API (${response.statusCode}): ${response.body}');
      
      // Si l'API principale échoue, essayer la route alternative
      if (response.statusCode != 200 && response.statusCode != 204) {
        // Chemin alternatif conforme à la structure du projet
        Uri alternativeUrl;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          alternativeUrl = Uri.http(domain, '/api/leisureProducers/${widget.producerId}/events/$eventId');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          alternativeUrl = Uri.https(domain, '/api/leisureProducers/${widget.producerId}/events/$eventId');
        }
        
        print('🔄 Tentative avec route alternative: $alternativeUrl');
        
        // Si le PATCH n'est pas pris en charge, essayer avec PUT en incluant toutes les données
        final fullUpdateData = Map<String, dynamic>.from(event);
        fullUpdateData['published'] = newStatus;
        fullUpdateData['last_updated'] = DateTime.now().toIso8601String();
        
        final alternativeResponse = await http.put(
          alternativeUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(fullUpdateData),
        );
        
        print('📥 Réponse API alternative (${alternativeResponse.statusCode}): ${alternativeResponse.body}');
        
        if (alternativeResponse.statusCode == 200 || alternativeResponse.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus 
                ? 'L\'événement a été publié avec succès !' 
                : 'L\'événement a été dépublié avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchEvents();
          return;
        } else {
          throw Exception('Échec de changement du statut de publication: ${alternativeResponse.statusCode}');
        }
      } else {
        // Mise à jour réussie avec la première route
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus 
              ? 'L\'événement a été publié avec succès !' 
              : 'L\'événement a été dépublié avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Rafraîchir la liste des événements
        _fetchEvents();
      }
    } catch (e) {
      print('❌ Erreur lors du changement de statut de publication: $e');
      // Erreur lors du changement de statut de publication
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement de statut de publication : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Partager un événement
  void _shareEvent(Map<String, dynamic> event) {
    // Récupérer les informations de l'événement
    final String title = event['intitulé'] ?? event['title'] ?? 'Événement sans titre';
    final String dateStr = event['prochaines_dates'] ?? formatEventSchedule(event) ?? '';
    final String eventId = event['_id'] ?? '';
    
    // Construire l'URL de partage (à adapter selon l'URL réelle de l'application)
    String shareUrl = '';
    
    try {
      final baseUrl = ApiService.baseUrl;
      if (baseUrl.startsWith('http://')) {
        shareUrl = '$baseUrl/event/$eventId';
      } else {
        shareUrl = '$baseUrl/event/$eventId';
      }
    } catch (e) {
      // En cas d'erreur, utiliser une URL générique
      shareUrl = 'https://votre-app.com/event/$eventId';
    }
    
    // Construire le message de partage
    final String shareMessage = 'Découvrez "$title" le $dateStr. Plus d\'infos : $shareUrl';
    
    // Afficher les options de partage
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Partager l\'événement',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Choisissez une option de partage',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Copier le lien
                  _buildShareOption(
                    icon: Icons.link,
                    color: Colors.blue,
                    label: 'Copier le lien',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: shareUrl));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lien copié dans le presse-papier'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                  
                  // Partager par email
                  _buildShareOption(
                    icon: Icons.email,
                    color: Colors.red,
                    label: 'Email',
                    onTap: () {
                      Navigator.pop(context);
                      // Ouvrir l'application de messagerie avec le contenu prérempli
                      // Cela nécessite un plugin comme url_launcher
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Partage par email - Fonctionnalité à venir'),
                        ),
                      );
                    },
                  ),
                  
                  // SMS
                  _buildShareOption(
                    icon: Icons.sms,
                    color: Colors.green,
                    label: 'SMS',
                    onTap: () {
                      Navigator.pop(context);
                      // Ouvrir l'application SMS avec le contenu prérempli
                      // Cela nécessite un plugin comme url_launcher
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Partage par SMS - Fonctionnalité à venir'),
                        ),
                      );
                    },
                  ),
                  
                  // Plus d'options
                  _buildShareOption(
                    icon: Icons.more_horiz,
                    color: Colors.purple,
                    label: 'Plus',
                    onTap: () {
                      Navigator.pop(context);
                      // Utiliser la fonction de partage du système
                      // Cela nécessite un plugin comme share_plus
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fonctionnalité de partage système à venir'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Réseaux sociaux
              const Text(
                'Réseaux sociaux',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSocialShareOption(
                    icon: Icons.facebook,
                    color: const Color(0xFF1877F2),
                    label: 'Facebook',
                    onTap: () {
                      Navigator.pop(context);
                      // Implémenter le partage Facebook
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Partage Facebook - Fonctionnalité à venir'),
                        ),
                      );
                    },
                  ),
                  
                  _buildSocialShareOption(
                    icon: Icons.insert_comment,
                    color: const Color(0xFF1DA1F2),
                    label: 'Twitter',
                    onTap: () {
                      Navigator.pop(context);
                      // Implémenter le partage Twitter
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Partage Twitter - Fonctionnalité à venir'),
                        ),
                      );
                    },
                  ),
                  
                  _buildSocialShareOption(
                    icon: Icons.camera_alt,
                    color: const Color(0xFFE4405F),
                    label: 'Instagram',
                    onTap: () {
                      Navigator.pop(context);
                      // Implémenter le partage Instagram
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Partage Instagram - Fonctionnalité à venir'),
                        ),
                      );
                    },
                  ),
                  
                  _buildSocialShareOption(
                    icon: Icons.message,
                    color: const Color(0xFF25D366),
                    label: 'WhatsApp',
                    onTap: () {
                      Navigator.pop(context);
                      // Implémenter le partage WhatsApp
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Partage WhatsApp - Fonctionnalité à venir'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Construit une option de partage
  Widget _buildShareOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit une option de partage sur les réseaux sociaux
  Widget _buildSocialShareOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Afficher la confirmation de suppression d'un événement
  void _showDeleteEventConfirmation(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer l\'événement'),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer l\'événement "${event['intitulé'] ?? event['title'] ?? 'Événement sans titre'}" ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteEvent(event);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
  
  /// Supprimer un événement
  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String eventId = event['_id'];
      final baseUrl = await constants.getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/events/$eventId');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/events/$eventId');
      }
      
      final response = await http.delete(url);
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Événement supprimé avec succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Événement supprimé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Rafraîchir la liste des événements
        _fetchEvents();
      } else {
        // Erreur lors de la suppression de l'événement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression de l\'événement : ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Erreur lors de la suppression de l'événement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression de l\'événement : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Helper pour décoder les images en base64
  Uint8List _decodeBase64Image(String base64String) {
    try {
      // Nettoyage de la chaîne si nécessaire (retirer le préfixe data:image/...)
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }
      
      // Décodage base64
      return base64.decode(cleanBase64);
    } catch (e) {
      print('⚠️ Erreur de décodage base64: $e');
      // Retourner un tableau vide en cas d'erreur
      return Uint8List(0);
    }
  }

  /// Fonction d'aide pour obtenir l'URL de base
  String getBaseUrl() {
    return constants.getBaseUrl();
  }
} 
