import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/event_calendar_service.dart';
import '../services/calendar_service.dart';
import '../services/analytics_service.dart';
import '../models/event_data.dart';

// Type alias pour éviter la confusion
typedef CalendarEvent = EventData;

// Utiliser les types avec leurs alias pour éviter les conflits
typedef CalendarEventType = EventData;

class EventCalendarWidget extends StatefulWidget {
  final String? producerId;
  final bool showAllEvents;
  final Function(CalendarEvent)? onEventTap;
  final bool isInteractive;
  final Function(String)? onViewAllPressed;
  
  const EventCalendarWidget({
    Key? key,
    this.producerId,
    this.showAllEvents = false,
    this.onEventTap,
    this.isInteractive = true,
    this.onViewAllPressed,
  }) : super(key: key);

  @override
  State<EventCalendarWidget> createState() => _EventCalendarWidgetState();
}

class _EventCalendarWidgetState extends State<EventCalendarWidget> {
  late EventCalendarService _calendarService;
  late AnalyticsService _analyticsService;
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  
  List<EventData> _selectedEvents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    
    _calendarService = EventCalendarService();
    _analyticsService = AnalyticsService();
    
    _loadEvents();
  }
  
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      if (widget.producerId != null) {
        // Charger les événements d'un producteur spécifique
        await _calendarService.getProducerEvents(widget.producerId!);
        
        // Enregistrer l'événement analytics
        _analyticsService.logEvent(
          name: 'calendar_interaction',
          parameters: {
            'action_type': 'view_events',
            'producer_id': widget.producerId!,
          },
        );
      } else if (widget.showAllEvents) {
        // Charger tous les événements populaires
        await _calendarService.getPopularEvents(limit: 50);
        
        // Enregistrer l'événement analytics
        _analyticsService.logEvent(
          name: 'calendar_interaction',
          parameters: {
            'action_type': 'view_all_events',
            'type': 'all_events',
          },
        );
      }
      
      // Mettre à jour les événements sélectionnés
      _updateSelectedEvents();
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
  
  void _updateSelectedEvents() {
    setState(() {
      _selectedEvents = _calendarService.getEventsForDay(_selectedDay)
          .map((e) => EventData.fromCalendarEvent(e))
          .toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendrier
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 30)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          eventLoader: (day) => _calendarService.getEventsForDay(day),
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: widget.isInteractive,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          locale: 'fr_FR', // Locale française
          availableCalendarFormats: const {
            CalendarFormat.month: 'Mois',
            CalendarFormat.twoWeeks: '2 semaines',
            CalendarFormat.week: 'Semaine',
          },
          onDaySelected: widget.isInteractive ? (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _updateSelectedEvents();
            
            // Enregistrer l'événement analytics
            _analyticsService.logEvent(
              name: 'calendar_interaction',
              parameters: {
                'action_type': 'select_day',
                'day': DateFormat('yyyy-MM-dd').format(selectedDay),
              },
            );
          } : null,
          onFormatChanged: widget.isInteractive ? (format) {
            setState(() {
              _calendarFormat = format;
            });
            
            // Enregistrer l'événement analytics
            _analyticsService.logEvent(
              name: 'calendar_interaction',
              parameters: {
                'action_type': 'change_format',
                'format': format.toString(),
              },
            );
          } : null,
          onPageChanged: widget.isInteractive ? (focusedDay) {
            _focusedDay = focusedDay;
            
            // Enregistrer l'événement analytics
            _analyticsService.logEvent(
              name: 'calendar_interaction',
              parameters: {
                'action_type': 'change_month',
                'month': DateFormat('yyyy-MM').format(focusedDay),
              },
            );
          } : null,
        ),
        
        const SizedBox(height: 16.0),
        
        // Liste des événements pour le jour sélectionné
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null 
                  ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
                  : _selectedEvents.isEmpty
                      ? Center(child: Text('Aucun événement ce jour'))
                      : ListView.builder(
                          itemCount: _selectedEvents.length,
                          itemBuilder: (context, index) {
                            final event = _selectedEvents[index];
                            return EventTile(
                              event: event,
                              onTap: widget.isInteractive ? () {
                                if (widget.onEventTap != null) {
                                  widget.onEventTap!(event.toCalendarEvent());
                                }
                                
                                // Enregistrer l'événement analytics
                                _analyticsService.logEvent(
                                  name: 'event_interaction',
                                  parameters: {
                                    'action_type': 'select',
                                    'event_id': event.id,
                                  },
                                );
                              } : null,
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class EventTile extends StatelessWidget {
  final EventData event;
  final VoidCallback? onTap;
  
  const EventTile({
    Key? key,
    required this.event,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat.Hm();
    final isAllDay = event.isAllDay;
    
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: ListTile(
        onTap: onTap,
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAllDay
                ? 'Toute la journée'
                : '${timeFormat.format(event.startDate)} - ${timeFormat.format(event.endDate)}',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (event.location != null && event.location!.isNotEmpty)
              Text('📍 ${event.location}'),
            if (event.description != null && event.description!.isNotEmpty)
              Text(
                event.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12.0,
                ),
              ),
          ],
        ),
        trailing: Icon(
          isAllDay ? Icons.event : Icons.access_time,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
} 