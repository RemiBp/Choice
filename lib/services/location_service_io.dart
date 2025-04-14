import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:location/location.dart' as location_package hide LocationAccuracy;
import 'dart:math' as math;
import 'location_service.dart' as location_service;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifs;
import '../utils/constants.dart' as constants;
import 'package:latlong2/latlong.dart';
import 'notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

/// Implémentation native (Android/iOS) du service de localisation
class LocationService implements location_service.LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  final location_package.Location _location = location_package.Location();
  Position? _currentPosition;
  String? _currentAddress;
  bool _isTrackingLocation = false;
  bool _permissionGranted = false;
  bool _proximityAlertsEnabled = false;
  double _proximityThreshold = 500; // en mètres
  Timer? _backgroundLocationTimer;
  final NotificationService _notificationService = NotificationService();
  final notifs.FlutterLocalNotificationsPlugin _localNotifications = notifs.FlutterLocalNotificationsPlugin();
  String? _errorMessage;
  
  // Pour le support de ChangeNotifier
  final Set<VoidCallback> _listeners = <VoidCallback>{};
  
  // Contacts suivis
  final Map<String, location_service.ContactLocation> _trackedContacts = {};
  
  // Points d'intérêt
  final Map<String, location_service.PointOfInterest> _pointsOfInterest = {};
  
  // Rayon de proximité en mètres
  int _proximityRadius = 500; // Par défaut: 500m
  
  // Implementation de ChangeNotifier
  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    for (final VoidCallback listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;
  
  // Getters
  @override
  Position? get currentPosition => _currentPosition;
  
  @override
  String? get currentAddress => _currentAddress;
  
  @override
  bool get isTrackingLocation => _isTrackingLocation;
  
  @override
  bool get permissionGranted => _permissionGranted;
  
  @override
  bool get proximityAlertsEnabled => _proximityAlertsEnabled;
  
  @override
  double get proximityThreshold => _proximityThreshold;
  
  @override
  Map<String, location_service.ContactLocation> get trackedContacts => _trackedContacts;
  
  @override
  Map<String, location_service.PointOfInterest> get pointsOfInterest => _pointsOfInterest;
  
  @override
  int get proximityRadius => _proximityRadius;
  
  @override
  set proximityRadius(int value) {
    if (value > 0) {
      _proximityRadius = value;
      _savePreferences();
      notifyListeners();
    }
  }

  @override
  Future<void> initialize() async {
    await _loadPreferences();
    await checkLocationPermission();
    await _notificationService.initialize();
  }

  @override
  Future<bool> checkLocationPermission() async {
    try {
      // Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Les services de localisation ne sont pas activés, demander à l'utilisateur de les activer
        final result = await Geolocator.openLocationSettings();
        if (!result) {
          // L'utilisateur n'a pas activé les services de localisation
          _permissionGranted = false;
          return false;
        }
      }
      
      // Vérifier l'état des permissions de localisation
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Demander la permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // L'utilisateur a refusé les permissions
          _permissionGranted = false;
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        // L'utilisateur a définitivement refusé les permissions
        _permissionGranted = false;
        return false;
      }
      
      // L'utilisateur a accordé les permissions
      _permissionGranted = true;
      return true;
    } catch (e) {
      print('Erreur lors de la vérification des permissions de localisation: $e');
      _permissionGranted = false;
      return false;
    }
  }

  @override
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      print('Erreur lors de l\'obtention de la position: $e');
        return null;
      }
  }

  @override
  Future<void> startLocationTracking() async {
    if (!_permissionGranted) {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return;
    }
    
    // Si déjà en cours de suivi, ne rien faire
    if (_isTrackingLocation) return;
    
    try {
      // Obtenir la position initiale
      await getCurrentPosition();
      
      _isTrackingLocation = true;
      notifyListeners();
      
      // Configurer un timer pour mettre à jour la position régulièrement
      _backgroundLocationTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
        await _updatePosition();
      });
      
      // Si les alertes de proximité sont activées, démarrer la vérification
      if (_proximityAlertsEnabled) {
        _startProximityChecks();
      }
    } catch (e) {
      debugPrint('Erreur lors du démarrage du suivi de la localisation: $e');
    }
  }
  
  @override
  void stopLocationTracking() {
    if (!_isTrackingLocation) return;
    
    try {
      _backgroundLocationTimer?.cancel();
      _isTrackingLocation = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de l\'arrêt du suivi de la localisation: $e');
    }
  }

  // Démarrer le suivi de la position
  @override
  Future<void> startTracking() async {
    await startLocationTracking();
  }

  // Arrêter le suivi de la position
  @override
  void stopTracking() {
    stopLocationTracking();
  }

  // Métier à jour la position actuelle
  Future<void> _updatePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _currentPosition = position;
      
      // Vérifier la proximité avec les contacts suivis
      if (_currentPosition != null) {
        _checkContactsProximity();
        _checkPointsOfInterestProximity();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de la position: $e');
    }
  }

  // Calculer la distance entre deux points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    final meter = distance(LatLng(lat1, lon1), LatLng(lat2, lon2));
    return meter;
  }

  @override
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final url = '${getBaseUrl()}/api/geocode?lat=$latitude&lng=$longitude';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['address'];
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors de l\'obtention de l\'adresse: $e');
      return null;
    }
  }

  @override
  Future<void> addTrackedContact({
    required String contactId,
    required String contactName,
    required double latitude,
    required double longitude,
    String? photoUrl,
  }) async {
    _trackedContacts[contactId] = location_service.ContactLocation(
      id: contactId,
      name: contactName,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl,
      lastUpdated: DateTime.now(),
    );
    
    await _savePreferences();
    notifyListeners();
  }

  @override
  Future<void> removeTrackedContact(String contactId) async {
    if (_trackedContacts.containsKey(contactId)) {
      _trackedContacts.remove(contactId);
      await _savePreferences();
      notifyListeners();
    }
  }

  @override
  Future<void> updateContactLocation({
    required String contactId,
    required double latitude,
    required double longitude,
  }) async {
    if (_trackedContacts.containsKey(contactId)) {
      final contact = _trackedContacts[contactId]!;
      _trackedContacts[contactId] = location_service.ContactLocation(
        id: contact.id,
        name: contact.name,
        latitude: latitude,
        longitude: longitude,
        photoUrl: contact.photoUrl,
        lastUpdated: DateTime.now(),
      );
      
      await _savePreferences();
      
      // Vérifier la proximité si nous avons notre position actuelle
      if (_currentPosition != null) {
        _checkContactProximity(contactId);
      }
      
      notifyListeners();
    }
  }

  @override
  Future<void> addPointOfInterest({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required String type,
    String? description,
    String? imageUrl,
  }) async {
    _pointsOfInterest[id] = location_service.PointOfInterest(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      type: type,
      description: description,
      imageUrl: imageUrl,
    );
    
    await _savePreferences();
    notifyListeners();
  }

  @override
  Future<void> removePointOfInterest(String id) async {
    if (_pointsOfInterest.containsKey(id)) {
      _pointsOfInterest.remove(id);
      await _savePreferences();
      notifyListeners();
    }
  }

  @override
  List<location_service.ContactLocation> getNearbyContacts() {
    if (_currentPosition == null) return [];
    
    final List<location_service.ContactLocation> nearbyContacts = [];
    
    for (final contact in _trackedContacts.values) {
      final distance = calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        contact.latitude,
        contact.longitude,
      );
      
      if (distance <= _proximityRadius) {
        nearbyContacts.add(contact);
      }
    }
    
    return nearbyContacts;
  }

  @override
  List<location_service.PointOfInterest> getNearbyPointsOfInterest() {
    if (_currentPosition == null) return [];
    
    final List<location_service.PointOfInterest> nearbyPois = [];
    
    for (final poi in _pointsOfInterest.values) {
      final distance = calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        poi.latitude,
        poi.longitude,
      );
      
      if (distance <= _proximityRadius) {
        nearbyPois.add(poi);
      }
    }
    
    return nearbyPois;
  }

  @override
  Future<void> createAlertZone({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
    String? description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alertZones = json.decode(prefs.getString('alertZones') ?? '{}') as Map<String, dynamic>;
    
    alertZones[id] = {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'type': type,
      'description': description,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString('alertZones', json.encode(alertZones));
    
    // Si le suivi est actif, vérifier immédiatement
    if (_isTrackingLocation && _currentPosition != null) {
      _checkAlertZones();
    }
  }

  @override
  Future<void> toggleProximityAlerts(bool enabled) async {
    _proximityAlertsEnabled = enabled;
    await _savePreferences();
    
    if (enabled && _isTrackingLocation) {
      _startProximityChecks();
    } else {
      _backgroundLocationTimer?.cancel();
    }
    
    notifyListeners();
  }

  @override
  Future<void> setProximityThreshold(double threshold) async {
    _proximityThreshold = threshold;
    await _savePreferences();
    notifyListeners();
  }

  @override
  void dispose() {
    stopLocationTracking();
    _backgroundLocationTimer?.cancel();
    // Ne pas appeler super.dispose() car nous implémentons l'interface
  }

  // Méthodes privées
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _proximityAlertsEnabled = prefs.getBool('proximityAlertsEnabled') ?? false;
    _proximityThreshold = prefs.getDouble('proximityThreshold') ?? 500;
    
    // Charger les contacts suivis
    final trackedContactsJson = prefs.getString('trackedContacts');
    if (trackedContactsJson != null) {
      final Map<String, dynamic> data = json.decode(trackedContactsJson);
      data.forEach((id, contactJson) {
        _trackedContacts[id] = location_service.ContactLocation.fromJson(contactJson);
      });
    }
    
    // Charger les points d'intérêt
    final poisJson = prefs.getString('pointsOfInterest');
    if (poisJson != null) {
      final Map<String, dynamic> data = json.decode(poisJson);
      data.forEach((id, poiJson) {
        _pointsOfInterest[id] = location_service.PointOfInterest.fromJson(poiJson);
      });
    }
  }
  
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('proximityAlertsEnabled', _proximityAlertsEnabled);
    await prefs.setDouble('proximityThreshold', _proximityThreshold);
    
    // Sauvegarder les contacts suivis
    final Map<String, dynamic> contactsMap = {};
    _trackedContacts.forEach((id, contact) {
      contactsMap[id] = contact.toJson();
    });
    await prefs.setString('trackedContacts', json.encode(contactsMap));
    
    // Sauvegarder les points d'intérêt
    final Map<String, dynamic> poisMap = {};
    _pointsOfInterest.forEach((id, poi) {
      poisMap[id] = poi.toJson();
    });
    await prefs.setString('pointsOfInterest', json.encode(poisMap));
  }
  
  void _startProximityChecks() {
    // Annuler le timer existant si nécessaire
    _backgroundLocationTimer?.cancel();
    
    // Créer un nouveau timer qui vérifie la proximité toutes les 5 minutes
    _backgroundLocationTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkContactsProximity(),
    );
    
    // Exécuter immédiatement une première vérification
    _checkContactsProximity();
  }
  
  void _checkContactsProximity() {
    if (_currentPosition == null || _trackedContacts.isEmpty) return;
    
    for (final contactId in _trackedContacts.keys) {
      _checkContactProximity(contactId);
    }
  }
  
  void _checkContactProximity(String contactId) {
    if (_currentPosition == null) return;
    
    final contact = _trackedContacts[contactId];
    if (contact == null) return;
    
    // Calculer la distance
    final distance = calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      contact.latitude,
      contact.longitude,
    );
    
    // Si la distance est inférieure au rayon de proximité
    if (distance <= _proximityRadius) {
      // Éviter les notifications répétées en vérifiant le dernier temps de notification
      final now = DateTime.now();
      if (contact.lastNotified == null || 
          now.difference(contact.lastNotified!).inHours >= 1) {
        
        // Mettre à jour la date de dernière notification
        _trackedContacts[contactId] = location_service.ContactLocation(
          id: contact.id,
          name: contact.name,
          latitude: contact.latitude,
          longitude: contact.longitude,
          photoUrl: contact.photoUrl,
          lastUpdated: contact.lastUpdated,
          lastNotified: now,
        );
        
        // Envoyer une notification
        _notificationService.showNotification(
          id: int.parse(contactId.hashCode.toString().substring(0, 8)),
          title: 'Contact à proximité',
          body: '${contact.name} se trouve à ${distance.toInt()} mètres de vous.',
          payload: json.encode({
            'type': 'contact',
            'id': contactId,
          }),
        );
      }
    }
  }
  
  void _checkPointsOfInterestProximity() {
    if (_currentPosition == null || _pointsOfInterest.isEmpty) return;
    
    for (final poi in _pointsOfInterest.values) {
      // Calculer la distance
      final distance = calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        poi.latitude,
        poi.longitude,
      );
      
      // Si la distance est inférieure au rayon de proximité
      if (distance <= _proximityRadius) {
        // Éviter les notifications répétées en vérifiant le dernier temps de notification
        final now = DateTime.now();
        if (poi.lastNotified == null || 
            now.difference(poi.lastNotified!).inHours >= 3) {
          
          // Mettre à jour la date de dernière notification
          _pointsOfInterest[poi.id] = location_service.PointOfInterest(
            id: poi.id,
            name: poi.name,
            latitude: poi.latitude,
            longitude: poi.longitude,
            type: poi.type,
            description: poi.description,
            imageUrl: poi.imageUrl,
            lastNotified: now,
          );
          
          // Envoyer une notification
          _notificationService.showNotification(
            id: int.parse(poi.id.hashCode.toString().substring(0, 8)),
            title: 'Point d\'intérêt à proximité',
            body: '${poi.name} se trouve à ${distance.toInt()} mètres de vous.',
            payload: json.encode({
              'type': 'poi',
              'id': poi.id,
            }),
          );
        }
      }
    }
  }
  
  Future<void> _checkAlertZones() async {
    if (_currentPosition == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final alertZones = json.decode(prefs.getString('alertZones') ?? '{}') as Map<String, dynamic>;
    
    for (final entry in alertZones.entries) {
      final id = entry.key;
      final zone = entry.value as Map<String, dynamic>;
      
      final double zoneLatitude = zone['latitude'];
      final double zoneLongitude = zone['longitude'];
      final int zoneRadius = zone['radius'];
      
      // Calculer la distance
      final distance = calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        zoneLatitude,
        zoneLongitude,
      );
      
      // Si la distance est inférieure au rayon de la zone
      if (distance <= zoneRadius) {
        // Vérifier si une notification a déjà été envoyée récemment
        final lastNotified = zone['lastNotified'] != null 
            ? DateTime.parse(zone['lastNotified']) 
            : null;
        
        final now = DateTime.now();
        if (lastNotified == null || now.difference(lastNotified).inHours >= 3) {
          // Mettre à jour la date de dernière notification
          zone['lastNotified'] = now.toIso8601String();
          alertZones[id] = zone;
          await prefs.setString('alertZones', json.encode(alertZones));
          
          // Envoyer une notification
          _notificationService.showNotification(
            id: int.parse(id.hashCode.toString().substring(0, 8)),
            title: 'Zone d\'alerte',
            body: 'Vous êtes entré dans la zone "${zone['name']}".',
            payload: json.encode({
              'type': 'alertZone',
              'id': id,
            }),
          );
        }
      }
    }
  }

  // Méthode pour obtenir l'URL de base de l'API
  String getBaseUrl() {
    return constants.apiBaseUrl;
  }
}