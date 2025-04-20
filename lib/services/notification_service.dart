import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as firebase_msg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart' as app_badger;
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// Pour recevoir les messages en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(firebase_msg.RemoteMessage message) async {
  // Initialiser Firebase si ce n'est pas déjà fait
  await Firebase.initializeApp();
  print('Notification en arrière-plan: ${message.notification?.title}');
  
  // Sauvegarder la notification pour qu'elle puisse être traitée quand l'app est ouverte
  final prefs = await SharedPreferences.getInstance();
  final List<String> pendingNotifications = 
      prefs.getStringList('pendingNotifications') ?? [];
  
  pendingNotifications.add(json.encode({
    'title': message.notification?.title,
    'body': message.notification?.body,
    'data': message.data,
    'timestamp': DateTime.now().toIso8601String(),
  }));
  
  await prefs.setStringList('pendingNotifications', pendingNotifications);
  
  // Mettre à jour le badge de l'application
  try {
    // Utiliser directement updateBadgeCount sans vérifier isAppBadgeSupported
    app_badger.FlutterAppBadger.updateBadgeCount(pendingNotifications.length);
  } catch (e) {
    print('Erreur de mise à jour du badge: $e');
  }
}

/// Service de notification pour l'application
class NotificationService {
  /// Callback déclenché pour les notifications d'appel (push/in-app)
  void Function(Map<String, dynamic>)? onCallNotification;
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  final firebase_msg.FirebaseMessaging _firebaseMessaging = firebase_msg.FirebaseMessaging.instance;
  
  final PublishSubject<ReceivedNotification> _didReceiveLocalNotificationSubject = 
      PublishSubject<ReceivedNotification>();
  final PublishSubject<String> _selectNotificationSubject = PublishSubject<String>();
  
  // Ajouter cette propriété pour le flux des clics sur les notifications
  final PublishSubject<ReceivedNotification> _onNotificationClick = PublishSubject<ReceivedNotification>();
  
  // Liste des notifications reçues
  List<ReceivedNotification> _notifications = [];
  
  // Constructeur privé
  NotificationService._internal() {
    // Initialiser les timezones lors de la création
    tz_data.initializeTimeZones();
  }
  
  // Initialiser le service
  Future<void> initialize() async {
    await init();
    print('NotificationService initialisé');
  }
  
  // Initialiser le service
  Future<void> init() async {
    // Initialiser les paramètres pour Android
    // Utiliser la syntaxe qui correspond à la version du plugin que vous utilisez
    final androidSettings = AndroidInitializationSettings();
    
    // Initialiser les paramètres pour iOS
    // Utiliser la syntaxe qui correspond à la version du plugin que vous utilisez
    final iosSettings = DarwinInitializationSettings();
    
    // Paramètres d'initialisation pour toutes les plateformes
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // Initialiser les notifications
    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
    );
    
    // Charger les notifications persistantes
    await _loadNotifications();
  }

  // Méthode pour charger les notifications
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('notifications') ?? [];
      
      _notifications = notificationsJson
          .map((json) => ReceivedNotification.fromJson(jsonDecode(json)))
          .toList();
      
      print('${_notifications.length} notifications chargées');
    } catch (e) {
      print('Erreur lors du chargement des notifications: $e');
    }
  }
  
  // Méthode pour sauvegarder les notifications
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = _notifications
          .map((notification) => jsonEncode(notification.toJson()))
          .toList();
      
      await prefs.setStringList('notifications', notificationsJson);
    } catch (e) {
      print('Erreur lors de la sauvegarde des notifications: $e');
    }
  }
  
  // Demander les permissions pour iOS
  Future<bool?> requestIOSPermissions() async {
    try {
      if (Platform.isIOS) {
        // Méthode simplifiée pour demander les permissions
        return await _flutterLocalNotificationsPlugin.initialize(
          InitializationSettings(iOS: DarwinInitializationSettings()),
        );
      }
      return null;
    } catch (e) {
      print('Erreur lors de la demande de permissions iOS: $e');
      return false;
    }
  }
  
  // Afficher une notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Adapter cette partie en fonction de votre version du plugin
      final androidDetails = AndroidNotificationDetails(
        'channel_id',
        'channel_name',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      // Sauvegarder la notification dans notre liste
      final notification = ReceivedNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
        timestamp: DateTime.now(),
      );
      
      _notifications.add(notification);
      await _saveNotifications();
    } catch (e) {
      print('Erreur lors de l\'affichage de la notification: $e');
    }
  }
  
  // Méthode pour effacer le badge de l'application
  Future<void> clearBadge() async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        // Effacer le badge sur l'icône de l'application
        await app_badger.FlutterAppBadger.removeBadge();
        
        // Supprimer également les notifications en attente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('pendingNotifications', []);
        
        print('✅ Badge de l\'application effacé avec succès');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'effacement du badge: $e');
    }
  }
  
  // Obtenir le flux des notifications reçues en iOS
  Stream<ReceivedNotification> get onDidReceiveLocalNotification {
    return _didReceiveLocalNotificationSubject.stream;
  }
  
  // Obtenir le flux des notifications sélectionnées
  Stream<String> get onSelectNotification {
    return _selectNotificationSubject.stream;
  }
  
  // Obtenir le flux des clics sur les notifications
  Stream<ReceivedNotification> get onNotificationClick {
    return _onNotificationClick.stream;
  }
  
  // Obtenir la liste des notifications
  List<ReceivedNotification> get notifications => _notifications;

  // Handler centralisé pour toutes les notifications
  void _handleIncomingMessage(firebase_msg.RemoteMessage message, {bool fromBackground = false}) {
    final data = message.data;
    if (data != null && data['type'] == 'call') {
      // Notification d'appel entrant
      if (this.onCallNotification != null) {
        this.onCallNotification!({
          'callId': data['callId'],
          'from': data['from'],
          'fromName': data['fromName'],
          'isVideo': data['isVideo'] == 'true' || data['isVideo'] == true,
          'fromBackground': fromBackground,
        });
      }
      // Gestion des appels manqués : si l'utilisateur ne répond pas, afficher une notif locale
      _scheduleMissedCallNotification(data['fromName'] ?? 'Inconnu');
    }
    // ... gérer les autres types de notifications ici ...
  }

  // Affiche une notification locale pour appel manqué et incrémente le badge
  Future<void> _scheduleMissedCallNotification(String fromName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Appel manqué',
      body: 'Appel manqué de $fromName',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pendingNotifications') ?? [];
      app_badger.FlutterAppBadger.updateBadgeCount(pending.length + 1);
    } catch (_) {}
  }
}

/// Classe pour les notifications reçues
class ReceivedNotification {
  final int id;
  final String? title;
  final String? body;
  final String? payload;
  final DateTime? timestamp;
  final bool isRead;
  final String? imageUrl;
  final String? type;
  final Map<String, dynamic>? data;

  ReceivedNotification({
    required this.id,
    this.title,
    this.body,
    this.payload,
    this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.type,
    this.data,
  });

  // Convertir depuis JSON
  factory ReceivedNotification.fromJson(Map<String, dynamic> json) {
    return ReceivedNotification(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      payload: json['payload'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      imageUrl: json['imageUrl'],
      type: json['type'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }

  // Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
      'timestamp': timestamp?.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'type': type,
      'data': data,
    };
  }

  // Créer une copie avec des modifications
  ReceivedNotification copyWith({
    int? id,
    String? title,
    String? body,
    String? payload,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    String? type,
    Map<String, dynamic>? data,
  }) {
    return ReceivedNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      data: data ?? this.data,
    );
  }
}