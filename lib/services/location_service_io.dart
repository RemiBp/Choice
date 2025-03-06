import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'location_service.dart' as location_service;

/// Implémentation pour les plateformes mobiles utilisant method channels
class LocationService implements location_service.LocationService {
  static const _methodChannel = MethodChannel('fr.choiceapp.app/location');
  static const _eventChannel = EventChannel('fr.choiceapp.app/location_updates');
  
  // Cache pour l'état de la permission
  location_service.LocationPermission? _lastPermission;
  
  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      // Utiliser Paris comme position de secours si erreur
      final result = await _methodChannel.invokeMethod<bool>('isLocationServiceEnabled');
      return result ?? false;
    } catch (e) {
      print('❌ Erreur lors de la vérification des services de localisation: $e');
      return false;
    }
  }

  @override
  Future<location_service.LocationPermission> requestPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('requestPermission');
      _lastPermission = _parsePermissionString(result);
      return _lastPermission!;
    } catch (e) {
      print('❌ Erreur lors de la demande de permissions: $e');
      return location_service.LocationPermission.denied;
    }
  }

  @override
  Future<location_service.LocationPermission> checkPermission() async {
    // Si nous avons déjà vérifié la permission, retourner la valeur en cache
    if (_lastPermission != null) {
      return _lastPermission!;
    }
    
    try {
      final result = await _methodChannel.invokeMethod<String>('checkPermission');
      _lastPermission = _parsePermissionString(result);
      return _lastPermission!;
    } catch (e) {
      print('❌ Erreur lors de la vérification des permissions: $e');
      return location_service.LocationPermission.denied;
    }
  }

  @override
  Future<location_service.LocationPosition> getCurrentPosition() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<String, dynamic>>('getCurrentPosition');
      
      if (result != null) {
        return location_service.LocationPosition(
          latitude: result['latitude'] as double? ?? 48.8566, // Paris par défaut
          longitude: result['longitude'] as double? ?? 2.3522,
          accuracy: result['accuracy'] as double?,
          altitude: result['altitude'] as double?,
          heading: result['heading'] as double?,
          speed: result['speed'] as double?,
          timestamp: result['timestamp'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(result['timestamp'] as int) 
              : DateTime.now(),
        );
      } else {
        // Retourner Paris par défaut
        return location_service.LocationPosition(
          latitude: 48.8566,
          longitude: 2.3522,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la position: $e');
      // Retourner Paris par défaut
      return location_service.LocationPosition(
        latitude: 48.8566,
        longitude: 2.3522,
        timestamp: DateTime.now(),
      );
    }
  }
  
  // Convertit les chaînes de permission en enum
  location_service.LocationPermission _parsePermissionString(String? permission) {
    switch (permission) {
      case 'denied':
        return location_service.LocationPermission.denied;
      case 'deniedForever':
        return location_service.LocationPermission.deniedForever;
      case 'whileInUse':
        return location_service.LocationPermission.whileInUse;
      case 'always':
        return location_service.LocationPermission.always;
      default:
        return location_service.LocationPermission.denied;
    }
  }
}