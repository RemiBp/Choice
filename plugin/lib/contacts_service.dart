import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' show debugPrint;

// Interface principale pour le plugin contacts_service
class ContactsService {
  static const MethodChannel _channel = MethodChannel('contacts_service');
  
  // Récupérer tous les contacts
  static Future<List<Contact>> getContacts({
    String? query,
    bool withThumbnails = true,
    bool photoHighResolution = true,
    bool orderByGivenName = true,
    bool iOSLocalizedLabels = true,
    bool androidLocalizedLabels = true,
  }) async {
    // Simuler des données de contact pour le développement
    if (kDebugMode) {
      return _mockContacts;
    }
    
    try {
      final Map<String, dynamic> params = <String, dynamic>{
        'query': query,
        'withThumbnails': withThumbnails,
        'photoHighResolution': photoHighResolution,
        'orderByGivenName': orderByGivenName,
        'iOSLocalizedLabels': iOSLocalizedLabels,
        'androidLocalizedLabels': androidLocalizedLabels,
      };
      
      final List<dynamic> result = await _channel.invokeMethod('getContacts', params);
      return result.map((dynamic m) => Contact.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des contacts: $e');
      return _mockContacts;
    }
  }
  
  // Récupérer un contact par son identifiant
  static Future<Contact> getContact({
    required String identifier,
    bool withThumbnails = true,
    bool photoHighResolution = true,
    bool iOSLocalizedLabels = true,
    bool androidLocalizedLabels = true,
  }) async {
    // Simuler un contact pour le développement
    if (kDebugMode) {
      return _mockContacts.firstWhere(
        (contact) => contact.identifier == identifier,
        orElse: () => _mockContacts.first,
      );
    }
    
    try {
      final Map<String, dynamic> params = <String, dynamic>{
        'identifier': identifier,
        'withThumbnails': withThumbnails,
        'photoHighResolution': photoHighResolution,
        'iOSLocalizedLabels': iOSLocalizedLabels,
        'androidLocalizedLabels': androidLocalizedLabels,
      };
      
      final dynamic result = await _channel.invokeMethod('getContact', params);
      return Contact.fromMap(result);
    } catch (e) {
      debugPrint('Erreur lors de la récupération du contact: $e');
      return _mockContacts.first;
    }
  }
  
  // Autres méthodes du plugin que vous pourriez avoir besoin
  static Future<void> addContact(Contact contact) async {
    // En mode debug, simuler l'ajout d'un contact
    if (kDebugMode) {
      debugPrint('Contact simulé ajouté: ${contact.displayName}');
      return;
    }
    
    await _channel.invokeMethod('addContact', contact.toMap());
  }
  
  static Future<void> updateContact(Contact contact) async {
    // En mode debug, simuler la mise à jour d'un contact
    if (kDebugMode) {
      debugPrint('Contact simulé mis à jour: ${contact.displayName}');
      return;
    }
    
    await _channel.invokeMethod('updateContact', contact.toMap());
  }
  
  static Future<void> deleteContact(Contact contact) async {
    // En mode debug, simuler la suppression d'un contact
    if (kDebugMode) {
      debugPrint('Contact simulé supprimé: ${contact.displayName}');
      return;
    }
    
    await _channel.invokeMethod('deleteContact', contact.toMap());
  }
  
  // Rechercher parmi les contacts ceux qui sont déjà présents sur l'application
  static Future<List<Contact>> findContactsOnApp({
    required String apiUrl,
    required String authToken,
  }) async {
    // En mode debug, simuler des résultats
    if (kDebugMode) {
      // Simuler que 2 sur 3 des contacts sont sur l'app
      return [_mockContacts[0], _mockContacts[2]];
    }
    
    try {
      // 1. Récupérer tous les contacts avec leurs numéros de téléphone
      final contacts = await getContacts();
      
      // 2. Extraire uniquement les numéros de téléphone (pour respecter la vie privée)
      final Map<String, String> phoneToContactId = {};
      for (final contact in contacts) {
        if (contact.phones != null) {
          for (final phone in contact.phones!) {
            if (phone.value != null && phone.value!.isNotEmpty) {
              // Normaliser le numéro (retirer espaces, tirets, etc.)
              String normalizedPhone = phone.value!.replaceAll(RegExp(r'[^\d+]'), '');
              phoneToContactId[normalizedPhone] = contact.identifier!;
            }
          }
        }
      }
      
      // 3. Envoyer les numéros au serveur pour vérifier lesquels sont sur l'app
      final http = HttpClient();
      final request = await http.postUrl(Uri.parse('$apiUrl/contacts/check'));
      request.headers.set('Authorization', 'Bearer $authToken');
      request.headers.contentType = ContentType.json;
      
      final phoneList = phoneToContactId.keys.toList();
      request.write(json.encode({'phoneNumbers': phoneList}));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody);
      
      // 4. Récupérer les contacts qui correspondent aux numéros retournés
      final List<String> matchedPhones = (data['matches'] as List).cast<String>();
      final Set<String> matchedContactIds = {};
      
      for (final phone in matchedPhones) {
        final contactId = phoneToContactId[phone];
        if (contactId != null) {
          matchedContactIds.add(contactId);
        }
      }
      
      // 5. Filtrer les contacts qui sont sur l'application
      return contacts.where((contact) => 
        matchedContactIds.contains(contact.identifier)
      ).toList();
    } catch (e) {
      debugPrint('Erreur lors de la recherche de contacts sur l\'app: $e');
      // En cas d'erreur, retourner une liste vide
      return [];
    }
  }
  
  // Inviter un contact à rejoindre l'application
  static Future<bool> inviteContact(Contact contact, {String? message}) async {
    if (kDebugMode) {
      debugPrint('Invitation simulée envoyée à ${contact.displayName}');
      return true;
    }
    
    try {
      // Vérifier qu'il y a au moins un numéro de téléphone
      if (contact.phones == null || contact.phones!.isEmpty || contact.phones!.first.value == null) {
        return false;
      }
      
      final phoneNumber = contact.phones!.first.value!;
      final Map<String, dynamic> args = {
        'phoneNumber': phoneNumber,
        'message': message ?? 'Rejoins-moi sur notre application!',
      };
      
      await _channel.invokeMethod('inviteContact', args);
      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'invitation: $e');
      return false;
    }
  }
}

// Classe représentant un contact
class Contact {
  Contact({
    this.identifier,
    this.displayName,
    this.givenName,
    this.middleName,
    this.familyName,
    this.prefix,
    this.suffix,
    this.company,
    this.jobTitle,
    this.emails,
    this.phones,
    this.postalAddresses,
    this.avatar,
    this.birthday,
    this.androidAccountTypeRaw,
    this.androidAccountName,
  });
  
  String? identifier;
  String? displayName;
  String? givenName;
  String? middleName;
  String? familyName;
  String? prefix;
  String? suffix;
  String? company;
  String? jobTitle;
  List<Item>? emails;
  List<Item>? phones;
  List<PostalAddress>? postalAddresses;
  Uint8List? avatar;
  DateTime? birthday;
  String? androidAccountTypeRaw;
  String? androidAccountName;
  
  String? get androidAccountType => androidAccountTypeRaw;
  
  Contact.fromMap(Map<dynamic, dynamic> m) {
    identifier = m['identifier'];
    displayName = m['displayName'];
    givenName = m['givenName'];
    middleName = m['middleName'];
    familyName = m['familyName'];
    prefix = m['prefix'];
    suffix = m['suffix'];
    company = m['company'];
    jobTitle = m['jobTitle'];
    
    // Initialiser explicitement les listes pour éviter les erreurs de null safety
    emails = (m['emails'] as List<dynamic>?)?.map((dynamic item) => Item.fromMap(item)).toList();
    phones = (m['phones'] as List<dynamic>?)?.map((dynamic item) => Item.fromMap(item)).toList();
    postalAddresses = (m['postalAddresses'] as List<dynamic>?)?.map((dynamic item) => PostalAddress.fromMap(item)).toList();
    
    final avatar = m['avatar'];
    if (avatar != null) {
      this.avatar = Uint8List.fromList(avatar.cast<int>());
    }
    
    final birthday = m['birthday'];
    if (birthday != null) {
      this.birthday = DateTime.parse(birthday);
    }
    
    androidAccountTypeRaw = m['androidAccountType'];
    androidAccountName = m['androidAccountName'];
  }
  
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> m = <String, dynamic>{};
    m['identifier'] = identifier;
    m['displayName'] = displayName;
    m['givenName'] = givenName;
    m['middleName'] = middleName;
    m['familyName'] = familyName;
    m['prefix'] = prefix;
    m['suffix'] = suffix;
    m['company'] = company;
    m['jobTitle'] = jobTitle;
    
    m['emails'] = emails?.map((Item item) => item.toMap()).toList();
    m['phones'] = phones?.map((Item item) => item.toMap()).toList();
    m['postalAddresses'] = postalAddresses?.map((PostalAddress address) => address.toMap()).toList();
    
    if (avatar != null) {
      m['avatar'] = avatar!.toList();
    }
    
    if (birthday != null) {
      m['birthday'] = birthday!.toIso8601String();
    }
    
    m['androidAccountType'] = androidAccountTypeRaw;
    m['androidAccountName'] = androidAccountName;
    return m;
  }
}

// Classe pour les éléments comme téléphone, email, etc.
class Item {
  Item({
    this.label,
    this.value,
  });
  
  String? label;
  String? value;
  
  Item.fromMap(Map<dynamic, dynamic> m) {
    label = m['label'];
    value = m['value'];
  }
  
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> m = <String, dynamic>{};
    m['label'] = label;
    m['value'] = value;
    return m;
  }
}

// Classe pour les adresses postales
class PostalAddress {
  PostalAddress({
    this.label,
    this.street,
    this.city,
    this.postcode,
    this.region,
    this.country,
  });
  
  String? label;
  String? street;
  String? city;
  String? postcode;
  String? region;
  String? country;
  
  PostalAddress.fromMap(Map<dynamic, dynamic> m) {
    label = m['label'];
    street = m['street'];
    city = m['city'];
    postcode = m['postcode'];
    region = m['region'];
    country = m['country'];
  }
  
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> m = <String, dynamic>{};
    m['label'] = label;
    m['street'] = street;
    m['city'] = city;
    m['postcode'] = postcode;
    m['region'] = region;
    m['country'] = country;
    return m;
  }
}

// Liste de contacts simulés pour le développement
final List<Contact> _mockContacts = [
  Contact(
    identifier: '1',
    displayName: 'John Doe',
    givenName: 'John',
    familyName: 'Doe',
    phones: [
      Item(label: 'mobile', value: '+33612345678'),
    ],
    emails: [
      Item(label: 'work', value: 'john.doe@example.com'),
    ],
  ),
  Contact(
    identifier: '2',
    displayName: 'Jane Smith',
    givenName: 'Jane',
    familyName: 'Smith',
    phones: [
      Item(label: 'mobile', value: '+33623456789'),
    ],
    emails: [
      Item(label: 'work', value: 'jane.smith@example.com'),
    ],
  ),
  Contact(
    identifier: '3',
    displayName: 'Alice Johnson',
    givenName: 'Alice',
    familyName: 'Johnson',
    phones: [
      Item(label: 'mobile', value: '+33634567890'),
      Item(label: 'home', value: '+33145678901'),
    ],
    emails: [
      Item(label: 'personal', value: 'alice.johnson@example.com'),
    ],
  ),
]; 