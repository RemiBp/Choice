import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/constants.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();
  
  final String _pendingActionsKey = 'pendingActions';
  
  // Ajouter une action en attente
  Future<void> addPendingAction({
    required String type, // 'create', 'update', 'delete'
    required String entity, // 'contact', 'event', 'message', etc.
    required Map<String, dynamic> data,
    required String endpoint,
    String method = 'POST', // 'POST', 'PUT', 'DELETE'
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingActions = prefs.getStringList(_pendingActionsKey) ?? [];
    
    // Créer l'action
    final action = {
      'type': type,
      'entity': entity,
      'data': data,
      'endpoint': endpoint,
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Ajouter l'action à la liste
    pendingActions.add(json.encode(action));
    
    // Sauvegarder la liste mise à jour
    await prefs.setStringList(_pendingActionsKey, pendingActions);
  }
  
  // Récupérer toutes les actions en attente
  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingActions = prefs.getStringList(_pendingActionsKey) ?? [];
    
    // Convertir les chaînes JSON en objets
    return pendingActions
        .map((actionStr) => json.decode(actionStr) as Map<String, dynamic>)
        .toList();
  }
  
  // Supprimer une action en attente par index
  Future<void> removePendingAction(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingActions = prefs.getStringList(_pendingActionsKey) ?? [];
    
    if (index >= 0 && index < pendingActions.length) {
      pendingActions.removeAt(index);
      await prefs.setStringList(_pendingActionsKey, pendingActions);
    }
  }
  
  // Effacer toutes les actions en attente
  Future<void> clearPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingActionsKey, []);
  }
  
  // Synchroniser toutes les actions en attente
  Future<void> syncPendingActions() async {
    // Vérifier la connectivité avant de tenter la synchronisation
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw Exception('Pas de connexion internet');
    }
    
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingActions = prefs.getStringList(_pendingActionsKey) ?? [];
    
    if (pendingActions.isEmpty) {
      return; // Rien à synchroniser
    }
    
    // Récupérer le token d'authentification
    final token = prefs.getString('userToken');
    
    // Liste des actions qui ont échoué
    List<String> failedActions = [];
    
    // Traiter chaque action
    for (int i = 0; i < pendingActions.length; i++) {
      try {
        final action = json.decode(pendingActions[i]) as Map<String, dynamic>;
        final baseUrl = getBaseUrl();
        final endpoint = action['endpoint'];
        final method = action['method'];
        final data = action['data'];
        
        // Construire l'URI
        final uri = Uri.parse('$baseUrl$endpoint');
        
        // Préparer les en-têtes
        final headers = {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        };
        
        http.Response response;
        
        // Exécuter la requête selon la méthode
        switch (method) {
          case 'POST':
            response = await http.post(
              uri,
              headers: headers,
              body: json.encode(data),
            );
            break;
          case 'PUT':
            response = await http.put(
              uri,
              headers: headers,
              body: json.encode(data),
            );
            break;
          case 'DELETE':
            response = await http.delete(
              uri,
              headers: headers,
            );
            break;
          default:
            throw Exception('Méthode HTTP non supportée: $method');
        }
        
        // Vérifier si la requête a réussi
        if (response.statusCode < 200 || response.statusCode >= 300) {
          failedActions.add(pendingActions[i]);
          debugPrint('Échec de la synchronisation pour l\'action ${i+1}/${pendingActions.length}: ${response.statusCode}');
        } else {
          debugPrint('Action ${i+1}/${pendingActions.length} synchronisée avec succès');
        }
      } catch (e) {
        // En cas d'erreur, conserver l'action pour une future tentative
        failedActions.add(pendingActions[i]);
        debugPrint('Erreur lors de la synchronisation de l\'action ${i+1}/${pendingActions.length}: $e');
      }
    }
    
    // Mettre à jour la liste des actions en attente avec celles qui ont échoué
    await prefs.setStringList(_pendingActionsKey, failedActions);
  }
  
  // Vérifier s'il y a des actions en attente
  Future<bool> hasPendingActions() async {
    final actions = await getPendingActions();
    return actions.isNotEmpty;
  }
  
  // Enregistrer une action de création
  Future<void> queueCreateAction({
    required String entity,
    required Map<String, dynamic> data,
    required String endpoint,
  }) async {
    await addPendingAction(
      type: 'create',
      entity: entity,
      data: data,
      endpoint: endpoint,
      method: 'POST',
    );
  }
  
  // Enregistrer une action de mise à jour
  Future<void> queueUpdateAction({
    required String entity,
    required Map<String, dynamic> data,
    required String endpoint,
  }) async {
    await addPendingAction(
      type: 'update',
      entity: entity,
      data: data,
      endpoint: endpoint,
      method: 'PUT',
    );
  }
  
  // Enregistrer une action de suppression
  Future<void> queueDeleteAction({
    required String entity,
    required String endpoint,
  }) async {
    await addPendingAction(
      type: 'delete',
      entity: entity,
      data: {},
      endpoint: endpoint,
      method: 'DELETE',
    );
  }
  
  // Exécuter une action avec gestion du mode hors ligne
  Future<Map<String, dynamic>> executeWithOfflineSupport({
    required String entity,
    required String endpoint,
    required String method,
    required Map<String, dynamic> data,
    required Future<http.Response> Function() onlineAction,
  }) async {
    // Vérifier la connectivité
    var connectivityResult = await Connectivity().checkConnectivity();
    
    // Si en ligne, tenter l'action directement
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final response = await onlineAction();
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Action réussie en ligne
          try {
            return json.decode(response.body);
          } catch (e) {
            return {'success': true};
          }
        } else {
          // Erreur serveur, mettre en file d'attente pour réessayer plus tard
          await addPendingAction(
            type: method == 'POST' ? 'create' : method == 'PUT' ? 'update' : 'delete',
            entity: entity,
            data: data,
            endpoint: endpoint,
            method: method,
          );
          
          return {
            'success': false,
            'offlineQueued': true,
            'message': 'Erreur serveur, l\'action sera synchronisée ultérieurement'
          };
        }
      } catch (e) {
        // Erreur de connectivité ou autre, mettre en file d'attente
        await addPendingAction(
          type: method == 'POST' ? 'create' : method == 'PUT' ? 'update' : 'delete',
          entity: entity,
          data: data,
          endpoint: endpoint,
          method: method,
        );
        
        return {
          'success': false,
          'offlineQueued': true,
          'message': 'Erreur de connexion, l\'action sera synchronisée ultérieurement'
        };
      }
    } else {
      // Mode hors ligne, mettre en file d'attente
      await addPendingAction(
        type: method == 'POST' ? 'create' : method == 'PUT' ? 'update' : 'delete',
        entity: entity,
        data: data,
        endpoint: endpoint,
        method: method,
      );
      
      return {
        'success': false,
        'offlineQueued': true,
        'message': 'Mode hors ligne, l\'action sera synchronisée ultérieurement'
      };
    }
  }
} 