import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/constants.dart' as constants;
import '../utils/utils.dart';
import '../models/producer.dart';
// Utiliser l'alias calendar pour éviter les conflits
import 'calendar_service.dart' as calendar;
import 'package:table_calendar/table_calendar.dart';
// Utilisation d'un alias pour éviter les conflits
import '../models/event_data.dart' hide CalendarEvent;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';
import '../services/api_service.dart'; // Import manquant
import 'package:intl/intl.dart'; // Import pour DateFormat

// Définir la classe Event qui était manquante
class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final DateTime? endDate;
  final String? location;
  final bool isPrivate;
  final String? category;
  final String producerId;
  
  Event({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.endDate,
    this.location,
    this.isPrivate = false,
    this.category,
    required this.producerId,
  });
  
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      eventDate: json['eventDate'] != null 
          ? DateTime.parse(json['eventDate']) 
          : (json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now()),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      location: json['location'],
      isPrivate: json['isPrivate'] ?? false,
      category: json['category'],
      producerId: json['producerId'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'eventDate': eventDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'location': location,
      'isPrivate': isPrivate,
      'category': category,
      'producerId': producerId,
    };
  }
}

class EventSource {
  Map<DateTime, List<dynamic>> _events = {};
  
  // Accesseur aux événements
  Map<DateTime, List<dynamic>> get events => _events;
  
  // Ajouter un événement
  void addEvent(DateTime date, dynamic event) {
    final day = DateTime.utc(date.year, date.month, date.day);
    if (_events[day] != null) {
      _events[day]!.add(event);
    } else {
      _events[day] = [event];
    }
  }
  
  // Supprimer un événement
  void removeEvent(DateTime date, dynamic event) {
    final day = DateTime.utc(date.year, date.month, date.day);
    if (_events[day] != null) {
      _events[day]!.removeWhere((e) => e.id == event.id);
      if (_events[day]!.isEmpty) {
        _events.remove(day);
      }
    }
  }
  
  // Obtenir les événements pour une date
  List<dynamic> getEventsForDay(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return _events[day] ?? [];
  }
  
  // Vider tous les événements
  void clear() {
    _events.clear();
  }
}

/// Service pour gérer les événements du calendrier
class EventCalendarService with ChangeNotifier {
  static final EventCalendarService _instance = EventCalendarService._internal();
  
  final String _baseUrl = getBaseUrl();
  List<EventData> _events = [];
  bool _initialized = false;
  final ApiService _apiService = ApiService();
  // Map pour stocker les événements par date
  final Map<String, List<dynamic>> _eventCache = {};
  
  // Constructeur pour l'implémentation du singleton
  factory EventCalendarService() => _instance;
  EventCalendarService._internal();
  
  // Initialiser le service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadEvents();
    
    _initialized = true;
  }
  
  // Charger les événements
  Future<void> _loadEvents() async {
    // Implémentation à remplir
    _events = [];
    notifyListeners();
  }
  
  // Obtenir les événements pour une date spécifique
  List<EventData> getEventsForDay(DateTime day) {
    final events = <EventData>[];
    
    // Normaliser la date (ignorer l'heure)
    final normalizedDay = DateTime(day.year, day.month, day.day);
    
    for (final event in _events) {
      // Normaliser les dates de début et de fin
      final normalizedStart = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
      );
      final normalizedEnd = DateTime(
        event.endDate.year,
        event.endDate.month,
        event.endDate.day,
      );
      
      // Vérifier si le jour est entre le début et la fin de l'événement
      if (normalizedDay.isAtSameMomentAs(normalizedStart) ||
          normalizedDay.isAtSameMomentAs(normalizedEnd) ||
          (normalizedDay.isAfter(normalizedStart) && normalizedDay.isBefore(normalizedEnd))) {
        events.add(event);
      }
    }
    
    return events;
  }
  
  // Obtenir les événements à venir pour un producteur
  Future<List<EventData>> getUpcomingEvents(String producerId, {int limit = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}/api/producers/$producerId/events?limit=$limit'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((eventJson) => EventData.fromJson(eventJson)).toList();
      } else {
        print('Erreur lors de la récupération des événements : ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception lors de la récupération des événements : $e');
      return [];
    }
  }
  
  // Obtenir les événements à venir (pour les X prochains jours)
  List<EventData> getUpcomingEventsForDays({int days = 7}) {
    final DateTime now = DateTime.now();
    final DateTime endDate = now.add(Duration(days: days));
    
    return _events.where((event) {
      return event.startDate.isAfter(now) && event.startDate.isBefore(endDate);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }
  
  // Obtenir tous les événements
  List<EventData> getAllEvents() {
    return _events;
  }
  
  // Obtenir les événements filtrés par critères
  List<EventData> getFilteredEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? organizerId,
    String? searchTerm,
    bool includePrivate = false,
  }) {
    return _events.where((event) {
      // Filtre par date de début
      if (startDate != null && event.startDate.isBefore(startDate)) {
        return false;
      }
      
      // Filtre par date de fin
      if (endDate != null && event.endDate.isAfter(endDate)) {
        return false;
      }
      
      // Filtre par organisateur
      if (organizerId != null && event.organizerId != organizerId) {
        return false;
      }
      
      // Filtre par termes de recherche
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final termLower = searchTerm.toLowerCase();
        final titleLower = event.title.toLowerCase();
        final descriptionLower = event.description.toLowerCase();
        
        if (!titleLower.contains(termLower) && !descriptionLower.contains(termLower)) {
          return false;
        }
      }
      
      // Filtre par évènements privés (ajouter une propriété isPrivate à EventData ou utiliser un autre critère)
      // on suppose que les événements privés sont ceux marqués avec la catégorie "private"
      if (!includePrivate && event.category == 'private') {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  // Ajouter un événement au calendrier
  Future<void> addEvent(EventData event) async {
    // Ajouter l'événement à la liste
    _events.add(event);
    
    // Notifier les auditeurs
    notifyListeners();
    
    // Stocker les événements dans le cache
    _storeEventsToCache();
  }
  
  // Ajouter plusieurs événements
  Future<void> addEvents(List<EventData> events) async {
    _events.addAll(events);
    await _storeEventsToCache();
    notifyListeners();
  }
  
  // Stocker les événements dans le cache
  Future<void> _storeEventsToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = _events.map((e) => e.toJson()).toList();
    await prefs.setString('cached_events', json.encode(eventsJson));
  }
  
  // Obtenir les événements d'un producteur
  Future<List<EventData>> getProducerEvents(String producerId) async {
    try {
      final response = await _apiService.fetchProducerEvents(producerId);
      
      if (response != null && response is List) {
        final events = response
            .map((json) => EventData.fromJson(json))
            .toList();
        
        // Ajouter les événements au cache
        _addEventsToCache(events);
        
        return events;
      }
      
      return [];
    } catch (e) {
      print('Erreur lors de la récupération des événements du producteur : $e');
      return [];
    }
  }
  
  // Obtenir les événements populaires
  Future<List<EventData>> getPopularEvents({int limit = 10}) async {
    try {
      final response = await _apiService.fetchPopularEvents(limit: limit);
      
      if (response != null && response is List) {
        final events = response
            .map((json) => EventData.fromJson(json))
            .toList();
        
        // Ajouter les événements au cache
        _addEventsToCache(events);
        
        return events;
      }
      
      return [];
    } catch (e) {
      print('Erreur lors de la récupération des événements populaires : $e');
      return [];
    }
  }
  
  // Ajouter des événements extérieurs
  Future<void> addExternalEvents(List<EventData> events) async {
    _addEventsToCache(events);
  }
  
  // Ajouter des événements au cache
  void _addEventsToCache(List<dynamic> events) {
    for (var event in events) {
      try {
        if (event is Map<String, dynamic>) {
          // Construire une clé de date pour cet événement
          final DateTime startDate = event['startDate'] != null
              ? DateTime.parse(event['startDate'])
              : DateTime.now();
              
          final String dateKey = DateFormat('yyyy-MM-dd').format(startDate);
          
          // Initialiser la liste si elle n'existe pas encore
          _eventCache.putIfAbsent(dateKey, () => []);
          
          // Ajouter l'événement au cache pour cette date
          _eventCache[dateKey]!.add(event);
        }
      } catch (e) {
        print('❌ Erreur lors de l\'ajout au cache: $e');
      }
    }
  }
  
  // Ajouter des événements au service (version dynamique)
  void addDynamicEvents(List<dynamic> events) {
    _addEventsToCache(events);
    notifyListeners();
  }
} 