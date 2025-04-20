import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_tag.dart';
import '../utils/constants.dart';
import 'package:http/http.dart' as http;

class TagService {
  // Singleton
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;
  TagService._internal();

  // Clés pour le stockage local
  final String _tagsKey = 'contact_tags';
  final String _associationsKey = 'contact_tag_associations';

  // Cache des tags et associations
  List<ContactTag> _tags = [];
  List<ContactTagAssociation> _associations = [];
  
  // Getters
  List<ContactTag> get tags => _tags;
  List<ContactTagAssociation> get associations => _associations;

  // Initialiser le service
  Future<void> initialize() async {
    await _loadFromLocal();
    await _syncWithServer();
  }

  // Charger les données depuis le stockage local
  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Charger les tags
    final tagsJson = prefs.getString(_tagsKey);
    if (tagsJson != null) {
      final List<dynamic> tagsData = json.decode(tagsJson);
      _tags = tagsData.map((tagData) => ContactTag.fromMap(tagData)).toList();
    } else {
      // Tags par défaut si aucun n'existe
      _tags = _getDefaultTags();
      await _saveToLocal();
    }
    
    // Charger les associations
    final associationsJson = prefs.getString(_associationsKey);
    if (associationsJson != null) {
      final List<dynamic> associationsData = json.decode(associationsJson);
      _associations = associationsData
          .map((data) => ContactTagAssociation.fromMap(data))
          .toList();
    }
  }
  
  // Sauvegarder les données en local
  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Sauvegarder les tags
    final tagsData = _tags.map((tag) => tag.toMap()).toList();
    await prefs.setString(_tagsKey, json.encode(tagsData));
    
    // Sauvegarder les associations
    final associationsData = _associations.map((assoc) => assoc.toMap()).toList();
    await prefs.setString(_associationsKey, json.encode(associationsData));
  }
  
  // Synchroniser avec le serveur
  Future<void> _syncWithServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) return;
      
      // Récupérer les tags depuis le serveur
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/contact-tags'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['tags'] != null) {
          final List<dynamic> tagsData = data['tags'];
          final serverTags = tagsData.map((tagData) => ContactTag.fromMap(tagData)).toList();
          
          // Merger les tags locaux et serveur (préférer les tags serveur)
          _mergeTags(serverTags);
        }
        
        if (data['associations'] != null) {
          final List<dynamic> associationsData = data['associations'];
          final serverAssociations = associationsData
              .map((data) => ContactTagAssociation.fromMap(data))
              .toList();
          
          // Merger les associations locales et serveur
          _mergeAssociations(serverAssociations);
        }
        
        // Sauvegarder les données fusionnées en local
        await _saveToLocal();
      }
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation des tags: $e');
    }
  }
  
  // Fusionner les tags locaux et serveur
  void _mergeTags(List<ContactTag> serverTags) {
    // Créer une map des tags locaux pour un accès rapide
    final Map<String, ContactTag> localTagsMap = {
      for (var tag in _tags) tag.id: tag
    };
    
    // Créer une liste pour les tags fusionnés
    final List<ContactTag> mergedTags = [];
    
    // Ajouter tous les tags du serveur
    mergedTags.addAll(serverTags);
    
    // Ajouter les tags locaux qui n'existent pas sur le serveur
    for (final localTag in _tags) {
      final exists = serverTags.any((serverTag) => serverTag.id == localTag.id);
      if (!exists) {
        mergedTags.add(localTag);
      }
    }
    
    _tags = mergedTags;
  }
  
  // Fusionner les associations locales et serveur
  void _mergeAssociations(List<ContactTagAssociation> serverAssociations) {
    // Créer un ensemble pour un accès rapide
    final Set<String> uniqueKeys = {};
    final List<ContactTagAssociation> mergedAssociations = [];
    
    // Ajouter toutes les associations du serveur
    for (final assoc in serverAssociations) {
      final key = '${assoc.contactId}:${assoc.tagId}';
      uniqueKeys.add(key);
      mergedAssociations.add(assoc);
    }
    
    // Ajouter les associations locales qui n'existent pas sur le serveur
    for (final localAssoc in _associations) {
      final key = '${localAssoc.contactId}:${localAssoc.tagId}';
      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        mergedAssociations.add(localAssoc);
      }
    }
    
    _associations = mergedAssociations;
  }
  
  // Créer un nouveau tag
  Future<ContactTag> createTag({
    required String name,
    required Color color,
    required IconData icon,
    String? description,
  }) async {
    // Générer un ID unique
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Créer le tag
    final tag = ContactTag(
      id: id,
      name: name,
      color: color,
      icon: icon,
      description: description,
    );
    
    // Ajouter à la liste locale
    _tags.add(tag);
    
    // Sauvegarder en local
    await _saveToLocal();
    
    // Synchroniser avec le serveur
    await _syncTagWithServer(tag);
    
    return tag;
  }
  
  // Mettre à jour un tag existant
  Future<ContactTag> updateTag({
    required String id,
    String? name,
    Color? color,
    IconData? icon,
    String? description,
  }) async {
    // Trouver le tag
    final index = _tags.indexWhere((tag) => tag.id == id);
    if (index == -1) {
      throw Exception('Tag non trouvé');
    }
    
    // Mettre à jour le tag
    final updatedTag = _tags[index].copyWith(
      name: name,
      color: color,
      icon: icon,
      description: description,
      updatedAt: DateTime.now(),
    );
    
    // Remplacer dans la liste
    _tags[index] = updatedTag;
    
    // Sauvegarder en local
    await _saveToLocal();
    
    // Synchroniser avec le serveur
    await _syncTagWithServer(updatedTag);
    
    return updatedTag;
  }
  
  // Supprimer un tag
  Future<void> deleteTag(String id) async {
    // Supprimer le tag
    _tags.removeWhere((tag) => tag.id == id);
    
    // Supprimer toutes les associations avec ce tag
    _associations.removeWhere((assoc) => assoc.tagId == id);
    
    // Sauvegarder en local
    await _saveToLocal();
    
    // Synchroniser avec le serveur
    await _deleteTagFromServer(id);
  }
  
  // Associer un tag à un contact
  Future<void> addTagToContact(String contactId, String tagId) async {
    // Vérifier si l'association existe déjà
    final exists = _associations.any(
      (assoc) => assoc.contactId == contactId && assoc.tagId == tagId
    );
    
    if (!exists) {
      // Créer l'association
      final association = ContactTagAssociation(
        contactId: contactId,
        tagId: tagId,
      );
      
      // Ajouter à la liste
      _associations.add(association);
      
      // Sauvegarder en local
      await _saveToLocal();
      
      // Synchroniser avec le serveur
      await _syncAssociationWithServer(association);
    }
  }
  
  // Retirer un tag d'un contact
  Future<void> removeTagFromContact(String contactId, String tagId) async {
    // Supprimer l'association
    _associations.removeWhere(
      (assoc) => assoc.contactId == contactId && assoc.tagId == tagId
    );
    
    // Sauvegarder en local
    await _saveToLocal();
    
    // Synchroniser avec le serveur
    await _deleteAssociationFromServer(contactId, tagId);
  }
  
  // Obtenir tous les tags pour un contact
  List<ContactTag> getTagsForContact(String contactId) {
    // Trouver toutes les associations pour ce contact
    final contactAssociations = _associations
        .where((assoc) => assoc.contactId == contactId)
        .toList();
    
    // Obtenir les IDs des tags
    final tagIds = contactAssociations.map((assoc) => assoc.tagId).toSet();
    
    // Filtrer les tags correspondants
    return _tags.where((tag) => tagIds.contains(tag.id)).toList();
  }
  
  // Obtenir tous les contacts pour un tag
  List<String> getContactsForTag(String tagId) {
    // Trouver toutes les associations pour ce tag
    final tagAssociations = _associations
        .where((assoc) => assoc.tagId == tagId)
        .toList();
    
    // Obtenir les IDs des contacts
    return tagAssociations.map((assoc) => assoc.contactId).toList();
  }
  
  // Rechercher des tags par nom
  List<ContactTag> searchTags(String query) {
    if (query.isEmpty) return _tags;
    
    final lowerQuery = query.toLowerCase();
    return _tags.where((tag) => 
      tag.name.toLowerCase().contains(lowerQuery) ||
      (tag.description != null && tag.description!.toLowerCase().contains(lowerQuery))
    ).toList();
  }
  
  // Synchroniser un tag avec le serveur
  Future<void> _syncTagWithServer(ContactTag tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) return;
      
      await http.post(
        Uri.parse('${getBaseUrl()}/api/contact-tags/sync'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tag': tag.toMap(),
        }),
      );
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation du tag: $e');
    }
  }
  
  // Supprimer un tag du serveur
  Future<void> _deleteTagFromServer(String tagId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) return;
      
      await http.delete(
        Uri.parse('${getBaseUrl()}/api/contact-tags/$tagId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint('Erreur lors de la suppression du tag: $e');
    }
  }
  
  // Synchroniser une association avec le serveur
  Future<void> _syncAssociationWithServer(ContactTagAssociation association) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) return;
      
      await http.post(
        Uri.parse('${getBaseUrl()}/api/contact-tags/association'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contactId': association.contactId,
          'tagId': association.tagId,
        }),
      );
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation de l\'association: $e');
    }
  }
  
  // Supprimer une association du serveur
  Future<void> _deleteAssociationFromServer(String contactId, String tagId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) return;
      
      await http.delete(
        Uri.parse('${getBaseUrl()}/api/contact-tags/association'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contactId': contactId,
          'tagId': tagId,
        }),
      );
    } catch (e) {
      debugPrint('Erreur lors de la suppression de l\'association: $e');
    }
  }
  
  // Obtenir les tags par défaut
  List<ContactTag> _getDefaultTags() {
    return [
      ContactTag(
        id: 'family',
        name: 'Famille',
        color: Colors.red,
        icon: Icons.family_restroom,
        description: 'Contacts familiaux',
      ),
      ContactTag(
        id: 'work',
        name: 'Travail',
        color: Colors.blue,
        icon: Icons.work,
        description: 'Collègues et contacts professionnels',
      ),
      ContactTag(
        id: 'friends',
        name: 'Amis',
        color: Colors.green,
        icon: Icons.people,
        description: 'Contacts amicaux',
      ),
      ContactTag(
        id: 'important',
        name: 'Important',
        color: Colors.orange,
        icon: Icons.star,
        description: 'Contacts importants',
      ),
      ContactTag(
        id: 'favorites',
        name: 'Favoris',
        color: Colors.pink,
        icon: Icons.favorite,
        description: 'Contacts favoris',
      ),
    ];
  }
} 