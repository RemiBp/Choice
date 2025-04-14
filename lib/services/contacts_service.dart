import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact.dart';
import '../utils/constants.dart';

class Item {
  String? label;
  String? value;

  Item({this.label, this.value});

  Item.fromMap(Map<dynamic, dynamic> m)
    : label = m['label'],
      value = m['value'];
      
  Map<String, dynamic> toMap() => {
    'label': label,
    'value': value,
  };
}

class PostalAddress {
  String? label;
  String? street;
  String? city;
  String? postcode;
  String? region;
  String? country;

  PostalAddress({
    this.label,
    this.street,
    this.city,
    this.postcode,
    this.region,
    this.country,
  });

  PostalAddress.fromMap(Map<dynamic, dynamic> m)
    : label = m['label'],
      street = m['street'],
      city = m['city'],
      postcode = m['postcode'],
      region = m['region'],
      country = m['country'];
      
  Map<String, dynamic> toMap() => {
    'label': label,
    'street': street,
    'city': city,
    'postcode': postcode,
    'region': region,
    'country': country,
  };
}

class ContactsService {
  // Singleton
  static final ContactsService _instance = ContactsService._internal();
  factory ContactsService() => _instance;
  ContactsService._internal();
  
  // Cache des contacts
  List<Contact> _contacts = [];
  bool _initialized = false;
  
  // Getter pour les contacts
  List<Contact> get contacts => _contacts;
  
  // Initialiser le service
  Future<void> initialize() async {
    if (!_initialized) {
      await getContactsFromServer();
      _initialized = true;
    }
  }
  
  // Récupérer les contacts depuis le serveur
  Future<List<Contact>> getContactsFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) {
        return [];
      }
      
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/contacts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> contactsData = data['contacts'] ?? [];
        
        _contacts = contactsData.map((contactData) => Contact.fromMap(contactData)).toList();
        
        // Trier par nom
        _contacts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        
        return _contacts;
      } else {
        debugPrint('Erreur lors de la récupération des contacts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception lors de la récupération des contacts: $e');
      return [];
    }
  }
  
  // Récupérer les contacts par tag
  Future<List<Contact>> getContactsByTag(String tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) {
        return [];
      }
      
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/contacts/tag/$tag'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> contactsData = data['contacts'] ?? [];
        
        final taggedContacts = contactsData.map((contactData) => Contact.fromMap(contactData)).toList();
        
        // Trier par nom
        taggedContacts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        
        return taggedContacts;
      } else {
        debugPrint('Erreur lors de la récupération des contacts par tag: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception lors de la récupération des contacts par tag: $e');
      return [];
    }
  }
  
  // Créer un nouveau contact
  Future<Contact?> createContact({
    required String name,
    String? email,
    String? phone,
    String? avatar,
    List<String>? tags,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) {
        return null;
      }
      
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/api/contacts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'phone': phone,
          'avatar': avatar,
          'tags': tags,
          'notes': notes,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final contactData = data['contact'];
        
        final newContact = Contact.fromMap(contactData);
        
        // Ajouter au cache
        _contacts.add(newContact);
        
        // Trier par nom
        _contacts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        
        return newContact;
      } else {
        debugPrint('Erreur lors de la création du contact: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception lors de la création du contact: $e');
      return null;
    }
  }
  
  // Mettre à jour un contact
  Future<Contact?> updateContact({
    required String id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    List<String>? tags,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) {
        return null;
      }
      
      final response = await http.put(
        Uri.parse('${getBaseUrl()}/api/contacts/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'phone': phone,
          'avatar': avatar,
          'tags': tags,
          'notes': notes,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contactData = data['contact'];
        
        final updatedContact = Contact.fromMap(contactData);
        
        // Mettre à jour le cache
        final index = _contacts.indexWhere((contact) => contact.id == id);
        if (index != -1) {
          _contacts[index] = updatedContact;
        }
        
        // Trier par nom
        _contacts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        
        return updatedContact;
      } else {
        debugPrint('Erreur lors de la mise à jour du contact: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception lors de la mise à jour du contact: $e');
      return null;
    }
  }
  
  // Supprimer un contact
  Future<bool> deleteContact(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) {
        return false;
      }
      
      final response = await http.delete(
        Uri.parse('${getBaseUrl()}/api/contacts/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        // Mettre à jour le cache
        _contacts.removeWhere((contact) => contact.id == id);
        return true;
      } else {
        debugPrint('Erreur lors de la suppression du contact: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception lors de la suppression du contact: $e');
      return false;
    }
  }
  
  // Rechercher des contacts
  Future<List<Contact>> searchContacts(String query) async {
    try {
      if (query.isEmpty) {
        return _contacts;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) {
        return [];
      }
      
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/contacts/search/$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> contactsData = data['contacts'] ?? [];
        
        final searchResults = contactsData.map((contactData) => Contact.fromMap(contactData)).toList();
        
        // Trier par nom
        searchResults.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        
        return searchResults;
      } else {
        debugPrint('Erreur lors de la recherche de contacts: ${response.statusCode}');
        
        // Recherche locale si le serveur échoue
        final lowercaseQuery = query.toLowerCase();
        return _contacts.where((contact) => 
          (contact.name?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          (contact.email?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          (contact.phone?.toLowerCase().contains(lowercaseQuery) ?? false)
        ).toList();
      }
    } catch (e) {
      debugPrint('Exception lors de la recherche de contacts: $e');
      
      // Recherche locale en cas d'erreur
      final lowercaseQuery = query.toLowerCase();
      return _contacts.where((contact) => 
        (contact.name?.toLowerCase().contains(lowercaseQuery) ?? false) ||
        (contact.email?.toLowerCase().contains(lowercaseQuery) ?? false) ||
        (contact.phone?.toLowerCase().contains(lowercaseQuery) ?? false)
      ).toList();
    }
  }
  
  // Obtenir les détails d'un contact
  Future<Contact?> getContactById(String id) async {
    try {
      // Vérifier d'abord dans le cache
      final cachedContact = _contacts.firstWhere(
        (contact) => contact.id == id,
        orElse: () => Contact(id: ''),
      );
      
      if (cachedContact.id!.isNotEmpty) {
        return cachedContact;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      
      if (token == null) {
        return null;
      }
      
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/contacts/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contactData = data['contact'];
        
        final contact = Contact.fromMap(contactData);
        
        return contact;
      } else {
        debugPrint('Erreur lors de la récupération du contact: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception lors de la récupération du contact: $e');
      return null;
    }
  }
} 