import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/event_calendar_service.dart';
import '../services/calendar_service.dart';
import '../services/analytics_service.dart';
import '../widgets/event_calendar_widget.dart';
import 'eventLeisure_screen.dart';
import '../utils/constants.dart' as constants;
import '../models/event_data.dart';
import '../../utils.dart' show getImageProvider;

class LeisureEventsCalendarScreen extends StatefulWidget {
  final String? producerId;
  final String? producerName;
  final bool showAllEvents;

  const LeisureEventsCalendarScreen({
    Key? key,
    this.producerId,
    this.producerName,
    this.showAllEvents = false,
  }) : super(key: key);

  @override
  State<LeisureEventsCalendarScreen> createState() => _LeisureEventsCalendarScreenState();
}

class _LeisureEventsCalendarScreenState extends State<LeisureEventsCalendarScreen> with SingleTickerProviderStateMixin {
  late EventCalendarService _calendarService;
  late AnalyticsService _analyticsService;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _upcomingEvents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calendarService = EventCalendarService();
    _analyticsService = AnalyticsService();
    _tabController = TabController(length: 2, vsync: this);
    
    _loadEvents();
    
    // Enregistrer la vue d'écran pour analytics
    _analyticsService.logEvent(
      name: 'screen_view',
      parameters: {
        'screen_name': 'LeisureEventsCalendar',
        'screen_class': 'LeisureEventsCalendarScreen',
      },
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      if (widget.producerId != null) {
        // Charger les événements d'un producteur spécifique
        await _fetchProducerEvents(widget.producerId!);
      } else {
        // Charger tous les événements ou une liste générale
        await _fetchAllEvents();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des événements: $e';
      });
      print('❌ Erreur: $_errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _fetchProducerEvents(String producerId) async {
    try {
      // Construire l'URL pour la recherche des événements du producteur
      final baseUrl = await constants.getBaseUrlSync();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/leisureProducers/$producerId/events');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/leisureProducers/$producerId/events');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Mise à jour des événements dans la vue calendrier
        if (data is List) {
          // Convertir les données en List<Map<String, dynamic>>
          final eventsList = List<Map<String, dynamic>>.from(
            data.map((item) => item is Map<String, dynamic> ? item : {})
          );
          
          setState(() {
            _upcomingEvents = eventsList;
          });
          
          // Convertir directement la liste de Map en liste d'objets EventData
          List<EventData> eventDataList = eventsList.map((e) => EventData.fromJson(e)).toList();
          _calendarService.addEvents(eventDataList);
        }
      } else {
        setState(() {
          _errorMessage = 'Erreur API: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des événements du producteur: $e');
      rethrow;
    }
  }
  
  Future<void> _fetchAllEvents() async {
    try {
      // Construire l'URL pour récupérer tous les événements
      final baseUrl = await constants.getBaseUrlSync();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/events/upcoming');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/events/upcoming');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Mise à jour des événements dans la vue calendrier
        if (data is List) {
          // Convertir les données en List<Map<String, dynamic>>
          final eventsList = List<Map<String, dynamic>>.from(
            data.map((item) => item is Map<String, dynamic> ? item : {})
          );
          
          setState(() {
            _upcomingEvents = eventsList;
          });
          
          // Convertir directement la liste de Map en liste d'objets EventData
          List<EventData> eventDataList = eventsList.map((e) => EventData.fromJson(e)).toList();
          _calendarService.addEvents(eventDataList);
        }
      } else {
        setState(() {
          _errorMessage = 'Erreur API: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des événements: $e');
      rethrow;
    }
  }
  
  void _navigateToEventDetails(String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventLeisureScreen(
          id: eventId,
        ),
      ),
    );
    
    // Enregistrer l'interaction pour analytics
    _analyticsService.logEvent(
      name: 'event_interaction',
      parameters: {
        'action_type': 'select_event',
        'item_id': eventId,
      },
    );
  }
  
  void _handleCalendarEventTap(dynamic event) {
    // Si event est un Map, on utilise directement l'ID
    if (event is Map<String, dynamic> && event['id'] != null) {
      _navigateToEventDetails(event['id']);
    } 
    // Si c'est un objet avec une propriété id accessible
    else if (event != null) {
      try {
        final id = event.id ?? '';
        if (id.isNotEmpty) {
          _navigateToEventDetails(id);
        }
      } catch (e) {
        print('Erreur lors de l\'accès à l\'ID de l\'événement: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer la couleur basée sur le type de page
    final themeColor = widget.producerId != null ? Colors.purple : Colors.teal;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.producerId != null 
            ? 'Événements: ${widget.producerName}' 
            : 'Calendrier des événements'),
        backgroundColor: themeColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Calendrier'),
            Tab(text: 'Liste'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet Calendrier
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: EventCalendarWidget(
              producerId: widget.producerId,
              showAllEvents: widget.showAllEvents,
              onEventTap: (event) => _handleCalendarEventTap(event),
            ),
          ),
          
          // Onglet Liste d'événements
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
                  : _upcomingEvents.isEmpty
                      ? Center(child: Text('Aucun événement à venir'))
                      : RefreshIndicator(
                          onRefresh: _loadEvents,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _upcomingEvents.length,
                            itemBuilder: (context, index) {
                              final event = _upcomingEvents[index];
                              return _buildEventCard(context, event, themeColor);
                            },
                          ),
                        ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEvents,
        backgroundColor: themeColor,
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event, Color themeColor) {
    final String title = event['intitulé'] ?? 'Sans titre';
    final String location = event['lieu'] ?? 'Lieu non spécifié';
    final String imageUrl = event['image'] ?? '';
    
    // Formatage des dates
    String dateStr = 'Date non spécifiée';
    if (event['date_debut'] != null) {
      final date = DateTime.parse(event['date_debut']);
      final dateFormat = DateFormat('EEEE d MMMM', 'fr_FR');
      dateStr = dateFormat.format(date);
    } else if (event['prochaines_dates'] != null) {
      dateStr = event['prochaines_dates'];
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      elevation: 3.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: () => _navigateToEventDetails(event['_id']),
        child: Stack(
          children: [
            Builder(
              builder: (context) {
                final imageProvider = getImageProvider(imageUrl);
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: imageProvider != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image(
                          image: imageProvider,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print("❌ Error loading event image: $error");
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  event['type'] == 'concert' ? Icons.music_note : Icons.event,
                                  size: 50,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            event['type'] == 'concert' ? Icons.music_note : Icons.event,
                            size: 50,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                );
              }
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: themeColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16.0, color: Colors.white),
                        const SizedBox(width: 4.0),
                        Expanded(child: Text(location, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                    
                    // Catégorie de l'événement
                    if (event['catégorie'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.category, size: 16.0, color: Colors.white),
                            const SizedBox(width: 4.0),
                            Text(
                              event['catégorie'],
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 