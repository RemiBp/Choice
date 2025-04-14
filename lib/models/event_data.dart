import 'package:flutter/material.dart';
import '../services/calendar_service.dart' hide CalendarEvent;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

/// Classe représentant un événement dans le calendrier
class EventData {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String imageUrl;
  final String producerId;
  final String producerName;
  final bool isPrivate;
  final Map<String, dynamic>? additionalData;
  final String? organizerId;
  final String? organizerName;
  final String? organizerAvatar;
  final List<String> attendees;
  final bool isAllDay;
  final Color color;
  final String? category;

  EventData({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    this.imageUrl = '',
    required this.producerId,
    required this.producerName,
    this.isPrivate = false,
    this.additionalData,
    this.organizerId,
    this.organizerName,
    this.organizerAvatar,
    this.attendees = const [],
    this.isAllDay = false,
    this.color = Colors.blue,
    this.category,
  });

  /// Convertir à partir de JSON
  factory EventData.fromJson(Map<String, dynamic> json) {
    // Parse dates from string or timestamp
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return DateTime.now();
        }
      }
      if (dateValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      }
      return DateTime.now();
    }

    return EventData(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? json['intitulé'] ?? 'Événement sans titre',
      description: json['description'] ?? json['details'] ?? '',
      startDate: parseDate(json['startDate'] ?? json['date_debut']),
      endDate: parseDate(json['endDate'] ?? json['date_fin'] ?? json['startDate'] ?? json['date_debut']),
      location: json['location'] ?? json['lieu'] ?? 'Lieu non spécifié',
      imageUrl: json['imageUrl'] ?? json['image'] ?? '',
      producerId: json['producerId'] ?? json['organizerId'] ?? '',
      producerName: json['producerName'] ?? json['organizerName'] ?? '',
      isPrivate: json['isPrivate'] ?? json['private'] ?? false,
      additionalData: json['additionalData'] ?? json['metaData'],
      organizerId: json['organizerId'] ?? json['organizer_id'],
      organizerName: json['organizerName'] ?? json['organizer_name'],
      organizerAvatar: json['organizerAvatar'] ?? json['organizer_avatar'],
      attendees: json['attendees'] != null 
          ? List<String>.from(json['attendees']) 
          : [],
      isAllDay: json['isAllDay'] ?? false,
      color: _parseColor(json['color']),
      category: json['category'],
    );
  }

  /// Convertir depuis un CalendarEvent
  factory EventData.fromCalendarEvent(dynamic calendarEvent) {
    if (calendarEvent is Map<String, dynamic>) {
      return EventData.fromJson(calendarEvent);
    }
    
    return EventData(
      id: calendarEvent.id ?? '',
      title: calendarEvent.title ?? 'Événement',
      description: calendarEvent.description ?? '',
      startDate: calendarEvent.start ?? DateTime.now(),
      endDate: calendarEvent.end ?? (calendarEvent.start?.add(Duration(hours: 1)) ?? DateTime.now()),
      location: calendarEvent.location ?? '',
      producerId: calendarEvent.producerId ?? '',
      producerName: calendarEvent.producerName ?? '',
      isPrivate: false,
      additionalData: null,
      organizerId: calendarEvent.producerId,
      organizerName: calendarEvent.producerName,
    );
  }

  /// Convertir en équivalent CalendarEvent pour les services
  dynamic toCalendarEvent() {
    // Créer un objet de structure similaire au CalendarEvent du service
    return {
      'id': id,
      'title': title,
      'description': description,
      'start': startDate,
      'end': endDate,
      'location': location,
      'isAllDay': isAllDay,
      'color': color,
      'category': category,
      'producerId': producerId,
      'producerName': producerName,
    };
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

  /// Convertir vers JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'location': location,
      'imageUrl': imageUrl,
      'producerId': producerId,
      'producerName': producerName,
      'isPrivate': isPrivate,
      'additionalData': additionalData,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'organizerAvatar': organizerAvatar,
      'attendees': attendees,
      'isAllDay': isAllDay,
      'color': '#${color.value.toRadixString(16).substring(2)}',
      'category': category,
    };
  }

  /// Créer une copie avec des modifications
  EventData copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? imageUrl,
    String? producerId,
    String? producerName,
    bool? isPrivate,
    Map<String, dynamic>? additionalData,
    String? organizerId,
    String? organizerName,
    String? organizerAvatar,
    List<String>? attendees,
    bool? isAllDay,
    Color? color,
    String? category,
  }) {
    return EventData(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      producerId: producerId ?? this.producerId,
      producerName: producerName ?? this.producerName,
      isPrivate: isPrivate ?? this.isPrivate,
      additionalData: additionalData ?? this.additionalData,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerAvatar: organizerAvatar ?? this.organizerAvatar,
      attendees: attendees ?? this.attendees,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      category: category ?? this.category,
    );
  }

  /// Obtenir la date de l'événement
  DateTime get eventDate => startDate;

  String getFormattedDate() {
    final DateFormat formatter = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    return formatter.format(startDate);
  }

  String getFormattedTime() {
    final DateFormat formatter = DateFormat('HH:mm', 'fr_FR');
    return formatter.format(startDate);
  }

  bool isUpcoming() {
    return startDate.isAfter(DateTime.now());
  }

  bool isOngoing() {
    final now = DateTime.now();
    return startDate.isBefore(now) && endDate.isAfter(now);
  }

  bool isPast() {
    return endDate.isBefore(DateTime.now());
  }
}

/// Définit un alias Event pour compatibilité
typedef Event = EventData;

/// Définit un alias CalendarEvent pour compatibilité
typedef CalendarEvent = EventData; 