import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart';

class Date {
  final int year;
  final int month;
  final int day;

  Date({required this.year, required this.month, required this.day});

  static Date fromDateTime(DateTime dateTime) {
    return Date(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
    );
  }

  String toIso8601String() {
    return "${year.toString().padLeft(4, '0')}-"
        "${month.toString().padLeft(2, '0')}-"
        "${day.toString().padLeft(2, '0')}";
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? location;
  final bool isAllDay;
  final List<String> attendees;
  final String? calendarId;
  final String source;
  final Color? color;
  final String? category;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.location,
    this.isAllDay = false,
    this.attendees = const [],
    this.calendarId,
    this.source = 'local',
    this.color,
    this.category,
  });

  factory CalendarEvent.fromGoogleEvent(calendar.Event event) {
    final isAllDay = event.start?.date != null;
    DateTime startDateTime;
    DateTime endDateTime;

    if (isAllDay) {
      final startDate = event.start?.date?.toIso8601String().split('T')[0];
      final endDate = event.end?.date?.toIso8601String().split('T')[0];
      
      startDateTime = startDate != null ? DateTime.parse(startDate) : DateTime.now();
      endDateTime = endDate != null ? DateTime.parse(endDate) : startDateTime.add(const Duration(days: 1));
    } else {
      startDateTime = event.start?.dateTime ?? DateTime.now();
      endDateTime = event.end?.dateTime ?? startDateTime.add(const Duration(hours: 1));
    }

    return CalendarEvent(
      id: event.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: event.summary ?? 'Sans titre',
      description: event.description,
      start: startDateTime,
      end: endDateTime,
      location: event.location,
      isAllDay: isAllDay,
      attendees: event.attendees
          ?.map((attendee) => attendee.email ?? '')
          .where((email) => email.isNotEmpty)
          .toList() ?? [],
      source: 'google',
      color: null,
      category: null,
    );
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      location: json['location'],
      attendees: List<String>.from(json['attendees'] ?? []),
      isAllDay: json['isAllDay'] ?? false,
      calendarId: json['calendarId'],
      source: json['source'],
      color: json['color'] != null ? _parseColor(json['color']) : null,
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'location': location,
      'attendees': attendees,
      'isAllDay': isAllDay,
      'calendarId': calendarId,
      'source': source,
      'color': color != null ? '#${color!.value.toRadixString(16).substring(2)}' : null,
      'category': category,
    };
  }

  calendar.Event toGoogleEvent() {
    final event = calendar.Event()
      ..summary = title
      ..description = description;
      
    if (isAllDay) {
      event.start = calendar.EventDateTime();
      final dateString = start.toIso8601String().split('T')[0];
      event.start!.date = null;
      
      event.end = calendar.EventDateTime();
      final endDateString = end.toIso8601String().split('T')[0];
      event.end!.date = null;
    } else {
      event.start = calendar.EventDateTime();
      event.start!.dateTime = start;
      event.end = calendar.EventDateTime();
      event.end!.dateTime = end;
    }
    
    event.location = location;
    event.attendees = attendees
        .map((email) => calendar.EventAttendee(email: email))
        .toList();
    
    return event;
  }
  
  String _dateToApiDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  static Color _parseColor(dynamic colorValue) {
    if (colorValue == null) return Colors.blue;
    
    if (colorValue is String) {
      try {
        if (colorValue.startsWith('#')) {
          return Color(int.parse('0xFF${colorValue.substring(1)}'));
        } else if (colorValue.startsWith('0x')) {
          return Color(int.parse(colorValue));
        }
      } catch (e) {
        return Colors.blue;
      }
    }
    
    return Colors.blue;
  }
}

class CalendarService with ChangeNotifier {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  calendar.CalendarApi? _calendarApi;
  List<calendar.CalendarListEntry> _calendars = [];
  List<CalendarEvent> _events = [];
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;

  // Getters
  List<calendar.CalendarListEntry> get calendars => _calendars;
  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _isConnected;

  // Initialiser le service
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final isSignedIn = await _googleSignIn.isSignedIn();
      if (isSignedIn) {
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          await _authenticateWithGoogle(googleUser);
        }
      }
    } catch (e) {
      _setError('Erreur lors de l\'initialisation: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Connexion à Google Calendar
  Future<bool> connectToGoogleCalendar() async {
    _setLoading(true);
    _resetError();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setError('Connexion annulée');
        return false;
      }

      await _authenticateWithGoogle(googleUser);
      await _fetchCalendars();
      return true;
    } catch (e) {
      _setError('Erreur lors de la connexion à Google Calendar: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Déconnexion de Google Calendar
  Future<void> disconnectFromGoogleCalendar() async {
    _setLoading(true);
    try {
      await _googleSignIn.signOut();
      _calendarApi = null;
      _calendars = [];
      _events = [];
      _isConnected = false;
      notifyListeners();
    } catch (e) {
      _setError('Erreur lors de la déconnexion: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Récupérer les calendriers
  Future<List<calendar.CalendarListEntry>> fetchCalendars() async {
    _setLoading(true);
    _resetError();

    try {
      if (_calendarApi == null) {
        _setError('Non connecté à Google Calendar');
        return [];
      }

      final calendarList = await _calendarApi!.calendarList.list();
      _calendars = calendarList.items ?? [];
      notifyListeners();
      return _calendars;
    } catch (e) {
      _setError('Erreur lors de la récupération des calendriers: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Récupérer les événements d'un calendrier
  Future<List<CalendarEvent>> fetchEvents(String calendarId, {
    DateTime? timeMin,
    DateTime? timeMax,
  }) async {
    _setLoading(true);
    _resetError();

    try {
      if (_calendarApi == null) {
        _setError('Non connecté à Google Calendar');
        return [];
      }

      final now = DateTime.now();
      timeMin ??= DateTime(now.year, now.month, now.day);
      timeMax ??= timeMin.add(const Duration(days: 30));

      final events = await _calendarApi!.events.list(
        calendarId,
        timeMin: timeMin.toUtc(),
        timeMax: timeMax.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      _events = events.items
          ?.map((e) => CalendarEvent.fromGoogleEvent(e))
          .toList() ?? [];

      notifyListeners();
      return _events;
    } catch (e) {
      _setError('Erreur lors de la récupération des événements: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Créer un événement
  Future<CalendarEvent?> createEvent(String calendarId, CalendarEvent event) async {
    _setLoading(true);
    _resetError();

    try {
      if (_calendarApi == null) {
        _setError('Non connecté à Google Calendar');
        return null;
      }

      final googleEvent = event.toGoogleEvent();
      final createdEvent = await _calendarApi!.events.insert(googleEvent, calendarId);

      final newEvent = CalendarEvent.fromGoogleEvent(createdEvent);
      _events.add(newEvent);
      notifyListeners();

      return newEvent;
    } catch (e) {
      _setError('Erreur lors de la création de l\'événement: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Modifier un événement
  Future<CalendarEvent?> updateEvent(String calendarId, CalendarEvent event) async {
    _setLoading(true);
    _resetError();

    try {
      if (_calendarApi == null) {
        _setError('Non connecté à Google Calendar');
        return null;
      }

      final googleEvent = event.toGoogleEvent();
      final updatedEvent = await _calendarApi!.events.update(
        googleEvent,
        calendarId,
        event.id,
      );

      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = CalendarEvent.fromGoogleEvent(updatedEvent);
        notifyListeners();
      }

      return CalendarEvent.fromGoogleEvent(updatedEvent);
    } catch (e) {
      _setError('Erreur lors de la modification de l\'événement: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Supprimer un événement
  Future<bool> deleteEvent(String calendarId, String eventId) async {
    _setLoading(true);
    _resetError();

    try {
      if (_calendarApi == null) {
        _setError('Non connecté à Google Calendar');
        return false;
      }

      await _calendarApi!.events.delete(calendarId, eventId);

      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Erreur lors de la suppression de l\'événement: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Créer un rendez-vous avec un contact
  Future<CalendarEvent?> createAppointmentWithContact(
    String calendarId,
    String contactName,
    String? contactEmail,
    DateTime start,
    DateTime end,
    String title,
    String? description,
    String? location,
  ) async {
    if (contactEmail == null) {
      _setError('Email du contact manquant');
      return null;
    }

    final event = CalendarEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      start: start,
      end: end,
      location: location,
      attendees: [contactEmail],
      source: 'app',
    );

    return await createEvent(calendarId, event);
  }

  // Sauvegarder les événements localement
  Future<void> saveEventsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = _events.map((e) => e.toJson()).toList();
      await prefs.setString('calendar_events', json.encode(eventsJson));
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde des événements: $e');
    }
  }

  // Charger les événements sauvegardés localement
  Future<List<CalendarEvent>> loadLocalEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString('calendar_events');
      
      if (eventsJson != null) {
        final List<dynamic> decoded = json.decode(eventsJson);
        _events = decoded
            .map((e) => CalendarEvent.fromJson(e))
            .toList();
        notifyListeners();
      }
      
      return _events;
    } catch (e) {
      debugPrint('Erreur lors du chargement des événements: $e');
      return [];
    }
  }

  // Méthodes privées
  Future<void> _authenticateWithGoogle(GoogleSignInAccount googleUser) async {
    final googleAuth = await googleUser.authentication;
    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        googleAuth.accessToken!,
        DateTime.now().add(const Duration(hours: 1)),
      ),
      googleAuth.idToken,
      ['https://www.googleapis.com/auth/calendar', 'https://www.googleapis.com/auth/calendar.events'],
    );

    final client = http.Client();
    final authClient = authenticatedClient(client, credentials);
    
    _calendarApi = calendar.CalendarApi(authClient);
    _isConnected = true;
    notifyListeners();
  }

  Future<void> _fetchCalendars() async {
    try {
      await fetchCalendars();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des calendriers: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _resetError() {
    _error = null;
    notifyListeners();
  }
} 