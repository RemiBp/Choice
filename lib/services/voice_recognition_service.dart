import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'analytics_service.dart';

/// Service pour la reconnaissance vocale
class VoiceRecognitionService with ChangeNotifier {
  static final VoiceRecognitionService _instance = VoiceRecognitionService._internal();

  final SpeechToText _speech = SpeechToText();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedText = '';
  String _currentLocale = 'fr_FR';
  List<SpeechRecognitionWords> _lastWords = [];
  List<dynamic> _locales = [];
  String? _initError;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get hasRecognizedText => _lastRecognizedText.isNotEmpty;
  String get lastRecognizedText => _lastRecognizedText;
  String get currentLocale => _currentLocale;
  List<SpeechRecognitionWords> get lastWords => _lastWords;
  List<dynamic> get locales => _locales;
  String get lastRecognizedWords => _lastRecognizedText;
  String get lastError => _initError ?? 'Erreur inconnue';
  
  // Constructeur factory pour singleton
  factory VoiceRecognitionService() {
    return _instance;
  }
  
  // Constructeur privé
  VoiceRecognitionService._internal();
  
  /// Initialiser le service de reconnaissance vocale
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Vérifier les permissions du microphone
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _analyticsService.logEvent(
          name: 'voice_recognition_permission_denied',
          parameters: {'status': status.toString()},
        );
        return false;
      }
      
      _analyticsService.logEvent(
        name: 'voice_recognition_permission_granted',
        parameters: {},
      );
      
      // Initialiser le service de reconnaissance vocale
      _isInitialized = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: kDebugMode,
      );
      
      _analyticsService.logEvent(
        name: 'voice_recognition_initialized',
        parameters: {'success': _isInitialized},
      );
      
      // Charger les locales disponibles si initialisé
      if (_isInitialized) {
        try {
          _locales = await _speech.locales();
        } catch (e) {
          print('Erreur lors du chargement des locales: $e');
        }
      }
      
      return _isInitialized;
    } catch (e) {
      print('Erreur lors de l\'initialisation de la reconnaissance vocale: $e');
      _analyticsService.logEvent(
        name: 'voice_recognition_error',
        parameters: {'error_type': 'initialization_failed', 'error_message': e.toString()},
      );
      return false;
    }
  }
  
  /// Démarrer l'écoute vocale
  Future<bool> startListening({
    Function(String)? onResult, 
    int listenDuration = 30,
    List<String>? hints,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }
    
    if (_isListening) {
      await cancelListening();
    }
    
    _lastRecognizedText = '';
    _lastWords = [];
    
    try {
      _isListening = await _speech.listen(
        onResult: (result) => _onSpeechResult(result, onResult),
        listenFor: Duration(seconds: listenDuration),
        pauseFor: const Duration(seconds: 3),
        localeId: _currentLocale,
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.confirmation,
        onDevice: true,
        sampleRate: 44100,
      );
      
      _analyticsService.logEvent(
        name: 'voice_recognition_started',
        parameters: {'language': _currentLocale, 'listening_duration': listenDuration},
      );
      
      notifyListeners();
      return _isListening;
    } catch (e) {
      print('Erreur lors du démarrage de la reconnaissance vocale: $e');
      _analyticsService.logEvent(
        name: 'voice_recognition_error',
        parameters: {'error_type': 'start_listening_failed', 'error_message': e.toString()},
      );
      return false;
    }
  }
  
  /// Arrêter l'écoute vocale
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      await _speech.stop();
      _isListening = false;
      
      _analyticsService.logEvent(
        name: 'voice_recognition_stopped',
        parameters: {'language': _currentLocale, 'manual_stop': true},
      );
      
      notifyListeners();
    } catch (e) {
      print('Erreur lors de l\'arrêt de la reconnaissance vocale: $e');
      _analyticsService.logEvent(
        name: 'voice_recognition_error',
        parameters: {'error_type': 'stop_listening_failed', 'error_message': e.toString()},
      );
    }
  }
  
  /// Annuler l'écoute vocale
  Future<void> cancelListening() async {
    if (!_isListening) return;
    
    try {
      await _speech.cancel();
      _isListening = false;
      
      _analyticsService.logEvent(
        name: 'voice_recognition_canceled',
        parameters: {'language': _currentLocale, 'reason': 'user_cancelled'},
      );
      
      notifyListeners();
    } catch (e) {
      print('Erreur lors de l\'annulation de la reconnaissance vocale: $e');
      _analyticsService.logEvent(
        name: 'voice_recognition_error',
        parameters: {'error_type': 'cancel_listening_failed', 'error_message': e.toString()},
      );
    }
  }
  
  /// Changer la locale utilisée pour la reconnaissance
  Future<void> changeLocale(String localeId) async {
    if (_currentLocale == localeId) return;
    
    _currentLocale = localeId;
    
    _analyticsService.logEvent(
      name: 'voice_recognition_locale_changed',
      parameters: {'old_locale': _currentLocale, 'new_locale': localeId},
    );
    
    notifyListeners();
  }
  
  /// Vérifier si la reconnaissance vocale est disponible
  Future<bool> checkAvailability() async {
    if (!_isInitialized) {
      final success = await initialize();
      return success;
    }
    return _isInitialized;
  }
  
  /// Gérer les résultats de la reconnaissance vocale
  void _onSpeechResult(SpeechRecognitionResult result, Function(String)? onResult) {
    _lastRecognizedText = result.recognizedWords;
    
    if (result.finalResult) {
      _analyticsService.logEvent(
        name: 'voice_recognition_text_detected',
        parameters: {
          'language': _currentLocale,
          'has_result': hasRecognizedText,
          'word_count': _lastRecognizedText.split(' ').length,
        },
      );
      
      // Si un callback est fourni, le déclencher
      if (onResult != null) {
        onResult(_lastRecognizedText);
      }
    }
    
    // Mettre à jour les derniers mots reconnus s'ils sont disponibles
    if (result.alternates.isNotEmpty) {
      _lastWords = result.alternates;
    }
    
    notifyListeners();
  }
  
  /// Gérer les erreurs de reconnaissance vocale
  void _onSpeechError(SpeechRecognitionError error) {
    _isListening = false;
    _initError = error.errorMsg;
    
    _analyticsService.logEvent(
      name: 'voice_recognition_error',
      parameters: {'error_type': 'realtime_error', 'error_message': error.errorMsg},
    );
    
    print('Erreur de reconnaissance vocale: ${error.errorMsg}');
    notifyListeners();
  }
  
  /// Gérer les changements de statut de la reconnaissance vocale
  void _onSpeechStatus(String status) {
    print('Statut de reconnaissance vocale: $status');
    
    if (status == 'done') {
      _isListening = false;
      notifyListeners();
    }
  }
} 