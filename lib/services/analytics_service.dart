import 'dart:async';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import '../utils/utils.dart';
import 'package:flutter/material.dart';

/// Service pour suivre les analyses utilisateur
class AnalyticsService extends ChangeNotifier {
  static final AnalyticsService _instance = AnalyticsService._internal();
  final List<Map<String, dynamic>> _eventQueue = [];
  bool _isProcessingQueue = false;
  final int _maxQueueSize = 100;
  final int _batchSize = 20;
  Timer? _queueProcessingTimer;
  bool _isEnabled = true;
  final String _baseUrl = getBaseUrl();

  // Singleton pattern
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Getter pour vérifier si le service est activé
  bool get isEnabled => _isEnabled;

  // Activer/désactiver le suivi analytique
  set isEnabled(bool value) {
    _isEnabled = value;
    _persistSettings();
  }

  // Initialiser le service
  Future<void> initialize() async {
    await _loadSettings();
    _startQueueProcessingTimer();
  }

  // Charger les paramètres
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('analytics_enabled') ?? true;
    } catch (e) {
      print('Erreur lors du chargement des paramètres analytiques: $e');
    }
  }

  // Sauvegarder les paramètres
  Future<void> _persistSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('analytics_enabled', _isEnabled);
    } catch (e) {
      print('Erreur lors de la sauvegarde des paramètres analytiques: $e');
    }
  }

  // Démarrer le timer pour traiter la file d'attente
  void _startQueueProcessingTimer() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _processEventQueue(),
    );
  }

  // Arrêter le timer
  void _stopQueueProcessingTimer() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = null;
  }

  // Méthode principale pour enregistrer un événement
  Future<void> trackEvent(String name, Map<String, dynamic> parameters) async {
    if (!_isEnabled) return;

    final event = {
      'name': name,
      'parameters': parameters,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _addToQueue(event);
  }

  // Ajouter un événement à la file d'attente
  void _addToQueue(Map<String, dynamic> event) {
    _eventQueue.add(event);

    // Si la file d'attente dépasse la taille maximale, traiter immédiatement
    if (_eventQueue.length >= _maxQueueSize) {
      _processEventQueue();
    }
  }

  // Traiter la file d'attente d'événements
  Future<void> _processEventQueue() async {
    if (_isProcessingQueue || _eventQueue.isEmpty) return;

    _isProcessingQueue = true;

    try {
      while (_eventQueue.isNotEmpty) {
        // Prendre un lot d'événements à traiter
        final batch = _eventQueue.length > _batchSize
            ? _eventQueue.sublist(0, _batchSize)
            : List<Map<String, dynamic>>.from(_eventQueue);

        // Essayer d'envoyer le lot
        final success = await _sendEvents(batch);

        // Si l'envoi a réussi, supprimer les événements traités de la file d'attente
        if (success) {
          _eventQueue.removeRange(0, batch.length);
        } else {
          // Si l'envoi a échoué, arrêter le traitement et réessayer plus tard
          break;
        }

        // Petite pause entre les lots pour éviter de surcharger le serveur
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('Erreur lors du traitement de la file d\'attente d\'événements: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  // Envoyer un lot d'événements au serveur
  Future<bool> _sendEvents(List<Map<String, dynamic>> events) async {
    try {
      final url = Uri.parse('${_baseUrl}/api/analytics/events');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'events': events}),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Erreur lors de l\'envoi des événements analytiques: $e');
      return false;
    }
  }

  // Enregistrer un événement de page vue
  Future<void> trackPageView(String screenName, {Map<String, dynamic>? additionalParams}) async {
    final params = {
      'page_name': screenName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (additionalParams != null) {
      // Convertir additionalParams en Map<String, String>
      Map<String, String> stringParams = {};
      additionalParams.forEach((key, value) {
        stringParams[key] = value.toString();
      });
      params.addAll(stringParams);
    }

    await trackEvent('page_view', params);
  }

  // Enregistrer un événement d'interaction utilisateur
  Future<void> trackUserInteraction(String actionType, String elementId, {Map<String, dynamic>? additionalParams}) async {
    final params = {
      'action_type': actionType,
      'element_id': elementId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (additionalParams != null) {
      // Convertir additionalParams en Map<String, String>
      Map<String, String> stringParams = {};
      additionalParams.forEach((key, value) {
        stringParams[key] = value.toString();
      });
      params.addAll(stringParams);
    }

    await trackEvent('user_interaction', params);
  }

  // Loguer un événement (méthode alternative à trackEvent mais avec même fonctionnalité)
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    Map<String, dynamic> eventParams = parameters ?? {};
    await trackEvent(name, eventParams);
  }

  // Enregistrer une interaction avec du contenu (vue, clic, etc.)
  Future<void> logContentInteraction({
    required String contentType,
    required String actionType,
    String? itemId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Données de l'événement
      final eventData = {
        'contentType': contentType,
        'actionType': actionType,
        'itemId': itemId,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };
      
      // Enregistrer localement
      _saveLocalEvent('content_interaction', eventData);
      
      // Envoyer au serveur si possible
      _sendEventToServer('content_interaction', eventData);
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'enregistrement de l\'interaction: $e');
    }
  }

  // Enregistrer un événement localement
  Future<void> _saveLocalEvent(String eventType, Map<String, dynamic> eventData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Récupérer les événements existants
      final eventsJson = prefs.getString('analytics_events') ?? '[]';
      final List<dynamic> events = json.decode(eventsJson);
      
      // Ajouter le nouvel événement
      events.add({
        'type': eventType,
        'data': eventData,
        'synced': false,
      });
      
      // Limiter le nombre d'événements stockés (garder les 1000 plus récents)
      final limitedEvents = events.length > 1000 ? events.sublist(events.length - 1000) : events;
      
      // Sauvegarder les événements
      await prefs.setString('analytics_events', json.encode(limitedEvents));
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde locale de l\'événement: $e');
    }
  }
  
  // Envoyer un événement au serveur
  Future<void> _sendEventToServer(String eventType, Map<String, dynamic> eventData) async {
    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}/api/analytics/events'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'type': eventType,
          'data': eventData,
        }),
      );
      
      if (response.statusCode != 200) {
        debugPrint('❌ Erreur lors de l\'envoi de l\'événement au serveur: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi de l\'événement au serveur: $e');
    }
  }

  // Libérer les ressources
  void dispose() {
    _stopQueueProcessingTimer();
    _processEventQueue();
  }

  // Obtenir un observateur pour les routes
  NavigatorObserver getNavigatorObserver() {
    return NavigatorObserver();
  }
  
  // Enregistrer une navigation
  void logNavigation(String routeName, {Map<String, dynamic>? parameters}) {
    logEvent(name: 'page_view', parameters: {
      'route_name': routeName,
      ...?parameters,
    });
  }

  // Méthode pour suivre une action utilisateur spécifique
  void trackUserAction(String action, Map<String, dynamic> parameters) {
    // Utiliser logEvent sous-jacent
    logEvent(name: 'user_action_$action', parameters: parameters);
  }
  
  // Enregistrer une vue de profil
  Future<void> logProfileView({
    required String profileId,
    required String username,
    bool isProducer = false,
    String? producerType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final Map<String, dynamic> eventData = {
        'profile_id': profileId,
        'username': username,
        'is_producer': isProducer,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      if (isProducer && producerType != null) {
        eventData['producer_type'] = producerType;
      }
      
      if (additionalData != null) {
        eventData.addAll(additionalData);
      }
      
      await logEvent(name: 'profile_view', parameters: eventData);
      
      // Enregistrer localement et envoyer au serveur
      _saveLocalEvent('profile_view', eventData);
      _sendEventToServer('profile_view', eventData);
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'enregistrement de la vue de profil: $e');
    }
  }
  
  // Enregistrer un événement de like de contenu
  Future<void> logLikeContent({
    required String contentId,
    required String contentType,
    String? producerId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Données de l'événement
      final eventData = {
        'contentId': contentId,
        'contentType': contentType,
        'producerId': producerId,
        'action': 'like',
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };
      
      // Enregistrer localement
      _saveLocalEvent('content_like', eventData);
      
      // Envoyer au serveur si possible
      _sendEventToServer('content_like', eventData);
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'enregistrement du like: $e');
    }
  }
  
  // Enregistrer un événement d'intérêt pour un contenu
  Future<void> logInterestContent({
    required String contentId,
    required String contentType,
    String? producerId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Données de l'événement
      final eventData = {
        'contentId': contentId,
        'contentType': contentType,
        'producerId': producerId,
        'action': 'interest',
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };
      
      // Enregistrer localement
      _saveLocalEvent('content_interest', eventData);
      
      // Envoyer au serveur si possible
      _sendEventToServer('content_interest', eventData);
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'enregistrement de l\'intérêt: $e');
    }
  }

  // Enregistrer un événement lorsqu'un utilisateur en suit un autre
  Future<void> logFollowUser({
    required String targetUserId,
    required String targetUsername,
    Map<String, dynamic>? additionalParams,
  }) async {
    final params = <String, Object>{
      'target_user_id': targetUserId,
      'target_username': targetUsername,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (additionalParams != null) {
      // Convertir Map<String, dynamic> en Map<String, Object>
      final objectParams = <String, Object>{};
      additionalParams.forEach((key, value) {
        if (value != null) {
          objectParams[key] = value as Object;
        }
      });
      params.addAll(objectParams);
    }

    await trackEvent('follow_user', params as Map<String, dynamic>);
  }

  // Enregistrer un événement lorsqu'un utilisateur arrête de suivre un autre
  Future<void> logUnfollowUser({
    required String targetUserId,
    required String targetUsername,
    Map<String, dynamic>? additionalParams,
  }) async {
    final params = <String, Object>{
      'target_user_id': targetUserId,
      'target_username': targetUsername,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (additionalParams != null) {
      // Convertir Map<String, dynamic> en Map<String, Object>
      final objectParams = <String, Object>{};
      additionalParams.forEach((key, value) {
        if (value != null) {
          objectParams[key] = value as Object;
        }
      });
      params.addAll(objectParams);
    }

    await trackEvent('unfollow_user', params as Map<String, dynamic>);
  }
} 