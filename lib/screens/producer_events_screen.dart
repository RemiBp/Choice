import 'package:flutter/material.dart';
import '../services/event_calendar_service.dart';
import '../services/calendar_service.dart';
import '../services/analytics_service.dart';
import '../widgets/event_calendar_widget.dart';
import 'event_details_screen.dart';

class ProducerEventsScreen extends StatefulWidget {
  final String producerId;
  final String producerName;
  final String? producerType; // 'restaurant', 'leisure', 'wellness'
  
  const ProducerEventsScreen({
    Key? key,
    required this.producerId,
    required this.producerName,
    this.producerType,
  }) : super(key: key);

  @override
  State<ProducerEventsScreen> createState() => _ProducerEventsScreenState();
}

class _ProducerEventsScreenState extends State<ProducerEventsScreen> with SingleTickerProviderStateMixin {
  late EventCalendarService _calendarService;
  late AnalyticsService _analyticsService;
  late TabController _tabController;
  
  List<CalendarEvent> _upcomingEvents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calendarService = EventCalendarService();
    _analyticsService = AnalyticsService();
    _tabController = TabController(length: 2, vsync: this);
    
    _loadUpcomingEvents();
    
    // Enregistrer la vue d'écran pour analytics
    _analyticsService.logScreenView(
      screenName: 'ProducerEventsScreen',
      screenClass: 'ProducerEventsScreen',
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUpcomingEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Charger les événements à venir du producteur
      final events = await _calendarService.getUpcomingEvents(widget.producerId, limit: 10);
      
      setState(() {
        _upcomingEvents = events;
      });
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
  
  Color _getThemeColor() {
    // Déterminer la couleur en fonction du type de producteur
    switch (widget.producerType) {
      case 'restaurant':
        return Colors.orange;
      case 'leisure':
        return Colors.purple;
      case 'wellness':
        return Colors.green;
      default:
        return Theme.of(context).primaryColor;
    }
  }
  
  void _navigateToEventDetails(CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(
          event: event,
          producerId: widget.producerId,
          producerName: widget.producerName,
          themeColor: _getThemeColor(),
        ),
      ),
    );
    
    // Enregistrer l'événement analytics
    _analyticsService.logContentInteraction(
      contentType: 'event', 
      itemId: event.id, 
      actionType: 'open_details'
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Événements: ${widget.producerName}'),
        backgroundColor: themeColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Calendrier'),
            Tab(text: 'À venir'),
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
              onEventTap: _navigateToEventDetails,
            ),
          ),
          
          // Onglet À venir
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
                  : _upcomingEvents.isEmpty
                      ? Center(child: Text('Aucun événement à venir'))
                      : RefreshIndicator(
                          onRefresh: _loadUpcomingEvents,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _upcomingEvents.length,
                            itemBuilder: (context, index) {
                              final event = _upcomingEvents[index];
                              return _buildUpcomingEventCard(event, themeColor);
                            },
                          ),
                        ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Rafraîchir les événements
          if (_tabController.index == 0) {
            // Rechargement du calendrier via EventCalendarWidget
            _calendarService.getProducerEvents(widget.producerId, forceRefresh: true);
          } else {
            // Rechargement des événements à venir
            _loadUpcomingEvents();
          }
          
          // Enregistrer l'événement analytics
          _analyticsService.logContentInteraction(
            contentType: 'events', 
            itemId: widget.producerId, 
            actionType: 'refresh'
          );
        },
        backgroundColor: themeColor,
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildUpcomingEventCard(CalendarEvent event, Color themeColor) {
    final dateFormat = DateFormat('EEEE d MMMM', 'fr_FR');
    final timeFormat = DateFormat.Hm();
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      elevation: 3.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: () => _navigateToEventDetails(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête coloré avec date
            Container(
              color: themeColor,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      dateFormat.format(event.start).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      event.isAllDay 
                          ? 'JOURNÉE'
                          : timeFormat.format(event.start),
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu de l'événement
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  if (event.location != null && event.location!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16.0, color: themeColor),
                          const SizedBox(width: 4.0),
                          Expanded(child: Text(event.location!)),
                        ],
                      ),
                    ),
                  if (event.description != null && event.description!.isNotEmpty)
                    Text(
                      event.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                ],
              ),
            ),
            
            // Pied de carte avec boutons d'action
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToEventDetails(event),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Détails'),
                    style: TextButton.styleFrom(
                      foregroundColor: themeColor,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Fonctionnalité d'inscription à l'événement
                      // À implémenter
                      
                      // Enregistrer l'événement analytics
                      _analyticsService.logConversion(
                        conversionType: 'event_register', 
                        itemId: event.id
                      );
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('S\'inscrire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 