import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../services/calendar_service.dart';
import '../services/event_calendar_service.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import 'eventLeisure_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final CalendarEvent event;
  final String producerId;
  final String producerName;
  final Color themeColor;

  const EventDetailsScreen({
    Key? key,
    required this.event,
    required this.producerId,
    required this.producerName,
    required this.themeColor,
  }) : super(key: key);

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late EventCalendarService _calendarService;
  late AnalyticsService _analyticsService;
  late AuthService _authService;
  
  bool _isLoading = false;
  bool _isRegistered = false;
  String? _errorMessage;
  String? _userId;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _calendarService = EventCalendarService();
    _analyticsService = AnalyticsService();
    _authService = AuthService();
    
    _checkRegistrationStatus();
    _loadUserData();
    
    // Enregistrer la vue d'écran pour analytics
    _analyticsService.logScreenView(
      screenName: 'EventDetailsScreen',
      screenClass: 'EventDetailsScreen',
    );
    
    // Enregistrer l'interaction avec l'événement
    _analyticsService.logContentInteraction(
      contentType: 'event', 
      itemId: widget.event.id, 
      actionType: 'view_details'
    );
    
    // Si c'est un événement de loisir, rediriger vers EventLeisureScreen
    if (widget.event.source == 'api' || widget.producerId.contains('leisure')) {
      // Utiliser un Timer pour permettre l'initialisation complète
      Timer(const Duration(milliseconds: 100), _redirectToLeisureScreen);
    }
  }
  
  void _redirectToLeisureScreen() {
    if (_redirecting) return; // Éviter les redirections multiples
    setState(() => _redirecting = true);
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EventLeisureScreen(
          eventId: widget.event.id,
        ),
      ),
    );
  }
  
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _userId = user.uid;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des données utilisateur: $e');
    }
  }
  
  Future<void> _checkRegistrationStatus() async {
    // Cette méthode vérifierait si l'utilisateur est déjà inscrit à l'événement
    // Pour l'instant, nous simulons une réponse
    setState(() {
      _isRegistered = false;
    });
  }
  
  Future<void> _registerForEvent() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour vous inscrire')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await _calendarService.registerForEvent(_userId!, widget.event.id);
      
      if (success) {
        setState(() {
          _isRegistered = true;
        });
        
        // Enregistrer la conversion pour analytics
        _analyticsService.logConversion(
          conversionType: 'event_register', 
          itemId: widget.event.id,
          additionalParams: {
            'producer_id': widget.producerId,
          },
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscription réussie !')),
        );
      } else {
        setState(() {
          _errorMessage = 'Erreur lors de l\'inscription';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _addToCalendar() {
    final event = Event(
      title: widget.event.title,
      description: widget.event.description ?? '',
      location: widget.event.location ?? '',
      startDate: widget.event.start,
      endDate: widget.event.end,
      allDay: widget.event.isAllDay,
    );
    
    Add2Calendar.addEvent2Cal(event);
    
    // Enregistrer l'interaction pour analytics
    _analyticsService.logContentInteraction(
      contentType: 'event', 
      itemId: widget.event.id, 
      actionType: 'add_to_calendar'
    );
  }
  
  void _shareEvent() {
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFormat = DateFormat.Hm();
    
    final String shareText = '''
🎉 Événement: ${widget.event.title}
📅 Date: ${dateFormat.format(widget.event.start)}
${widget.event.isAllDay ? '⏰ Toute la journée' : '⏰ Horaire: ${timeFormat.format(widget.event.start)} - ${timeFormat.format(widget.event.end)}'}
📍 Lieu: ${widget.event.location ?? 'Non précisé'}
🏢 Par: ${widget.producerName}

${widget.event.description ?? ''}

Rejoins-moi à cet événement via Choice App!
''';
    
    Share.share(shareText);
    
    // Enregistrer l'interaction pour analytics
    _analyticsService.logContentInteraction(
      contentType: 'event', 
      itemId: widget.event.id, 
      actionType: 'share'
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si nous sommes en train de rediriger, montrer un indicateur de chargement
    if (_redirecting) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chargement des détails...'),
          backgroundColor: widget.themeColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFormat = DateFormat.Hm();
    final isAllDay = widget.event.isAllDay;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de l\'événement'),
        backgroundColor: widget.themeColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareEvent,
            tooltip: 'Partager',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête avec date et heure
            Container(
              color: widget.themeColor.withOpacity(0.1),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    dateFormat.format(widget.event.start),
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: widget.themeColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    isAllDay
                        ? 'Toute la journée'
                        : '${timeFormat.format(widget.event.start)} - ${timeFormat.format(widget.event.end)}',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: widget.themeColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Titre de l'événement
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.event.title,
                style: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Organisateur
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.business, color: widget.themeColor),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Organisé par ${widget.producerName}',
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Lieu
            if (widget.event.location != null && widget.event.location!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: widget.themeColor),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        widget.event.location!,
                        style: const TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Description
            if (widget.event.description != null && widget.event.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: widget.themeColor,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      widget.event.description!,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ],
                ),
              ),
            
            // Boutons d'action
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRegistered ? null : (_isLoading ? null : _registerForEvent),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_isRegistered ? Icons.check : Icons.event_available),
                    label: Text(_isRegistered ? 'Inscrit' : 'S\'inscrire à l\'événement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRegistered ? Colors.grey : widget.themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  OutlinedButton.icon(
                    onPressed: _addToCalendar,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Ajouter à mon calendrier'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.themeColor,
                      side: BorderSide(color: widget.themeColor),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  TextButton.icon(
                    onPressed: _shareEvent,
                    icon: const Icon(Icons.share),
                    label: const Text('Partager'),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.themeColor,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                  
                  // Bouton pour voir les détails complets (redirection vers EventLeisureScreen)
                  if (widget.event.source == 'api')
                    TextButton.icon(
                      onPressed: _redirectToLeisureScreen,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Voir les détails complets'),
                      style: TextButton.styleFrom(
                        foregroundColor: widget.themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
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