import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart' as constants;
import '../models/producer.dart';
import '../models/post.dart';
import '../widgets/profile_post_card.dart';
import 'post_detail_screen.dart';
import 'messaging_screen.dart';
import '../utils/utils.dart';
import '../services/app_data_sender_service.dart'; // Import the sender service
import '../utils/location_utils.dart'; // Import location utils
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() {
    return message;
  }
}

class ProducerScreen extends StatefulWidget {
  final String producerId;
  final Producer? producer;
  final String? userId;
  final bool isWellness;
  final bool isBeauty;

  const ProducerScreen({
    Key? key, 
    required this.producerId, 
    this.producer,
    this.userId,
    this.isWellness = false,
    this.isBeauty = false,
  }) : super(key: key);

  @override
  State<ProducerScreen> createState() => _ProducerScreenState();
}

class _ProducerScreenState extends State<ProducerScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _producerFuture;
  late TabController _tabController;
  bool _isFollowing = false;
  int _followersCount = 0;
  bool _isSendingMessage = false;
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> _posts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingMenus = false;
  List<dynamic> _menus = [];
  List<dynamic> _menuItems = [];
  
  @override
  void initState() {
    super.initState();
    print('🔍 Initialisation du ProductScreen avec ID: ${widget.producerId}');
    _producerFuture = _fetchProducerDetails(widget.producerId);
    _tabController = TabController(length: 4, vsync: this);
    
    // Charger les données initiales
    _producerFuture.then((producer) {
      // Check for error state before proceeding
      if (producer.containsKey('error') && producer['error'] == true) {
         print("🔥 Producer details fetch failed, skipping further initializations.");
         return; // Don't proceed if fetch failed
      }

      // Initialiser les données de suivi
      setState(() {
        // Safely access followers count
        _followersCount = (producer['followers'] as List?)?.length ?? 
                         (producer['relations']?['followers'] as List?)?.length ?? 0;
                         
        // Check following status if user is logged in
        if (widget.userId != null && widget.userId!.isNotEmpty) {
           final followersList = (producer['followers'] as List?) ?? 
                                (producer['relations']?['followers'] as List?);
           _isFollowing = followersList?.contains(widget.userId) ?? false;
        }
      });
      
      // Charger les posts
      _loadPosts();
      
      // Charger les menus
      _loadMenus(producer);

      // Log producer view activity
      _logProducerViewActivity(widget.producerId, producer['type'] ?? 'restaurant'); // Use detected type or default
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Fonction pour charger les posts
  Future<void> _loadPosts() async {
    if (_isLoadingPosts) return;
    
    setState(() {
      _isLoadingPosts = true;
    });
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/posts');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final postsData = json.decode(response.body);
        setState(() {
          _posts = postsData['posts'] ?? [];
        });
      } else {
        print('❌ Erreur lors du chargement des posts: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception lors du chargement des posts: $e');
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }
  
  // Fonction pour charger les menus et items
  Future<void> _loadMenus(Map<String, dynamic> producer) async {
    if (_isLoadingMenus) return;
    
    setState(() {
      _isLoadingMenus = true;
    });
    
    try {
      // Extraire les menus et items des données du producteur
      if (producer['structured_data'] != null) {
        final structuredData = producer['structured_data'];
        setState(() {
          _menus = structuredData['Menus Globaux'] ?? [];
          
          // Extraire les items indépendants
          _menuItems = [];
          final categoriesData = structuredData['Items Indépendants'] ?? [];
          for (var category in categoriesData) {
            if (category['items'] != null && category['items'] is List) {
              for (var item in category['items']) {
                item['category'] = category['catégorie'] ?? 'Non catégorisé';
                _menuItems.add(item);
              }
            }
          }
        });
      }
    } catch (e) {
      print('❌ Exception lors du chargement des menus: $e');
    } finally {
      setState(() {
        _isLoadingMenus = false;
      });
    }
  }

  void _testApi() async {
    final producerId = widget.producerId;
    print('🔍 Test API avec producerId: $producerId');
    
    // Validate MongoDB ObjectID format
    final bool isValidObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(producerId);
    if (!isValidObjectId) {
      print('⚠️ ID potentiellement invalide: $producerId - ne semble pas être un ObjectId MongoDB');
    }

    // Try multiple possible endpoints
    List<String> endpointsToTest = [
      '/api/producers/$producerId',
      '/api/producers/$producerId/relations',
      '/api/unified/$producerId',
      '/api/leisureProducers/$producerId',
    ];
    
    final baseUrl = await constants.getBaseUrl();
    print('🔄 URL de base utilisée: $baseUrl');
    
    for (String endpoint in endpointsToTest) {
      try {
        print('🔍 Test : appel à $endpoint');
        Uri url = Uri.parse('$baseUrl$endpoint');
        
        print('🌐 URL complète: $url');
        
        final response = await http.get(url).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Délai d'attente dépassé"),
        );
        
        print('Réponse pour $endpoint : ${response.statusCode}');
        if (response.statusCode == 200) {
          print('✅ Requête $endpoint réussie');
          print('Body (aperçu): ${response.body.substring(0, min(150, response.body.length))}...');
          break; // Sortir de la boucle si une requête réussit
        } else {
          print('❌ Échec de la requête $endpoint: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Erreur réseau pour $endpoint : $e');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchProducerDetails(String producerId) async {
    // Validation MongoDB ObjectID
    final bool isValidObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(producerId);
    if (!isValidObjectId) {
      print('⚠️ Warning: ID potentiellement invalide: $producerId');
    }
    
    final baseUrl = await constants.getBaseUrl();
    print('🌐 URL de base pour les requêtes API: $baseUrl');
    
    // Liste d'endpoints à essayer
    final List<Map<String, String>> endpointsToTry = [
      {'type': 'producer', 'main': '/api/producers/$producerId', 'relations': '/api/producers/$producerId/relations'},
      {'type': 'restaurant_places', 'main': '/api/restaurant_places/$producerId', 'relations': '/api/restaurant_places/$producerId/relations'},
      {'type': 'place', 'main': '/api/places/$producerId', 'relations': '/api/places/$producerId/relations'},
      {'type': 'unified', 'main': '/api/unified/$producerId', 'relations': '/api/unified/$producerId/relations'},
      {'type': 'leisure', 'main': '/api/leisureProducers/$producerId', 'relations': '/api/leisureProducers/$producerId/relations'},
    ];
    
    List<String> failedEndpoints = [];
    List<String> errorMessages = [];
    Map<String, dynamic> producerData = {};
    Map<String, dynamic> relationsData = {};
    bool producerDataFound = false;
    
    // Essayer chaque combinaison d'endpoints jusqu'à ce qu'une fonctionne
    for (final endpointSet in endpointsToTry) {
      if (producerDataFound) break; // Arrêter dès qu'on a trouvé les données
      
      try {
        print('🔍 Tentative avec ${endpointSet['type']} endpoints');
        
        Uri mainUrl = Uri.parse('$baseUrl${endpointSet['main']}');
        Uri relationsUrl = Uri.parse('$baseUrl${endpointSet['relations']}');

        print('🌐 URL complète: $mainUrl');
        
        // Tentative avec timeout
        try {
          final producerResponse = await http.get(mainUrl).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('⏱️ Timeout pour ${endpointSet['type']} main endpoint');
              throw TimeoutException('Délai expiré pour l\'endpoint ${endpointSet['main']}');
            },
          );
          
          if (producerResponse.statusCode == 200) {
            print('✅ Succès pour ${endpointSet['type']} avec status ${producerResponse.statusCode}');
            producerData = json.decode(producerResponse.body);
                
            // Normalisation des données
            _normalizeProducerData(producerData, endpointSet['type']!);
            
            producerDataFound = true;
            
            // Essayer de récupérer les relations
            try {
              final relationsResponse = await http.get(relationsUrl).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  print('⏱️ Timeout pour l\'endpoint relations, mais les données principales sont disponibles');
                  throw TimeoutException('Délai expiré pour l\'endpoint des relations');
                },
              );
              
              if (relationsResponse.statusCode == 200) {
                relationsData = json.decode(relationsResponse.body);
              }
            } catch (e) {
              print('⚠️ Erreur lors de la récupération des relations: $e');
            }
            
            break; // Sortir de la boucle
          } else {
            failedEndpoints.add('${endpointSet['type']} - ${producerResponse.statusCode}');
          }
        } catch (e) {
          if (e is TimeoutException) {
            failedEndpoints.add('${endpointSet['type']} - Timeout');
          } else {
            failedEndpoints.add('${endpointSet['type']} - Erreur: $e');
          }
          errorMessages.add(e.toString());
        }
      } catch (e) {
        failedEndpoints.add('${endpointSet['type']} - Erreur générale');
        errorMessages.add(e.toString());
      }
    }
    
    // Après avoir essayé tous les endpoints, vérifier si nous avons trouvé des données
    if (producerDataFound) {
      // Combinaison des données producteur et relations
      final result = {...producerData};
      if (relationsData.isNotEmpty) {
        result['relations'] = relationsData;
      } else {
        result['relations'] = {'followers': [], 'following': []};
      }
      
      // Ajouter une metadata
      result['_dataSource'] = 'API récupération réussie';
      
      return result;
    } else {
      // Si le producteur existe déjà en tant que widget.producer, l'utiliser comme fallback
      if (widget.producer != null) {
        print('🔄 Utilisation des données du producteur fournies par le widget');
        return {
          '_id': widget.producer!.id,
          'place_id': widget.producer!.id,
          'name': widget.producer!.name,
          'description': widget.producer!.description,
          'address': widget.producer!.address,
          'primary_category': widget.producer!.category,
          'category': widget.producer!.category,
          'structured_data': {},
          'relations': {'followers': [], 'following': []},
          '_dataSource': 'widget.producer fallback',
        };
      }
      
      // Si aucune donnée n'est disponible, retourner un objet d'erreur
      final String errorDetail = errorMessages.isEmpty 
          ? 'Tous les endpoints ont échoué' 
          : 'Dernière erreur: ${errorMessages.last}';
      
      print('❌ Échec de la récupération des données du producteur: $errorDetail');
      print('❌ Endpoints tentés: ${failedEndpoints.join(", ")}');
      
      return {
        'error': true,
        'error_message': 'Impossible de récupérer les données du producteur',
        'failed_endpoints': failedEndpoints,
        'last_error': errorMessages.isEmpty ? null : errorMessages.last,
      };
    }
  }
  
  // Fonction pour normaliser les données du producteur selon leur source
  void _normalizeProducerData(Map<String, dynamic> data, String sourceType) {
    // Vérifier et corriger les champs obligatoires
    if (data['_id'] == null && data['id'] != null) {
      data['_id'] = data['id'];
    }
    
    if (data['_id'] == null && data['place_id'] != null) {
      data['_id'] = data['place_id'];
    }
    
    if (data['place_id'] == null && data['_id'] != null) {
      data['place_id'] = data['_id'];
    }
    
    // Normaliser le champ photo
    _normalizePhotoField(data);
    
    // Vérifier la structure des données
    if (data['structured_data'] == null) {
      data['structured_data'] = {};
    }
    
    // S'assurer que structured_data contient les sous-objets nécessaires
    if (!data['structured_data'].containsKey('Menus Globaux')) {
      data['structured_data']['Menus Globaux'] = [];
    }
    
    if (!data['structured_data'].containsKey('Items Indépendants')) {
      data['structured_data']['Items Indépendants'] = [];
    }
    
    // Correction pour le type de données de Restaurant_GooglePlaces_Results
    if (sourceType == 'restaurant_places' || sourceType == 'place') {
      // Remapper les champs du format GooglePlaces vers le format producers si nécessaire
      if (data['primary_category'] == null && data['types'] != null) {
        // Extraire la catégorie principale des types
        final types = data['types'];
        if (types is List && types.isNotEmpty) {
          data['primary_category'] = types[0];
          // Ensure category is always an array
          if (data['category'] == null) {
            data['category'] = [types[0]];
          } else if (data['category'] is String) {
            // Convert string to list if it's a string
            data['category'] = [data['category']];
          }
        }
      }
      
      // S'assurer que les menus sont accessibles
      if (data['structured_data']['Menus Globaux'] == null) {
        // Vérifier si les menus sont stockés sous un autre format
        if (data['menus'] != null) {
          data['structured_data']['Menus Globaux'] = data['menus'];
        } else {
          data['structured_data']['Menus Globaux'] = [];
        }
      }
      
      // Harmoniser les coordonnées GPS
      if (data['gps_coordinates'] == null && data['geometry'] != null && data['geometry']['location'] != null) {
        final location = data['geometry']['location'];
        data['gps_coordinates'] = {
          'type': 'Point',
          'coordinates': [location['lng'], location['lat']]
        };
      }
    }
    
    // Vérifier les champs obligatoires et fournir des valeurs par défaut si nécessaires
    if (data['name'] == null) data['name'] = 'Sans nom';
    if (data['description'] == null) data['description'] = '';
    if (data['address'] == null) data['address'] = 'Adresse non disponible';
    
    // Ensure category is always an array
    if (data['category'] == null) {
      data['category'] = ['Non catégorisé'];
    } else if (data['category'] is String) {
      data['category'] = [data['category']];
    }
    
    // Set primary_category based on the first category
    if (data['primary_category'] == null && data['category'] != null) {
      if (data['category'] is List && (data['category'] as List).isNotEmpty) {
        data['primary_category'] = (data['category'] as List)[0];
      } else if (data['category'] is String) {
        data['primary_category'] = data['category'];
      } else {
        data['primary_category'] = 'Non catégorisé';
      }
    } else if (data['primary_category'] == null) {
      data['primary_category'] = 'Non catégorisé';
    }
    
    // Log pour le débogage
    print('🔄 Données normalisées depuis la source: $sourceType');
  }
  
  // Fonction pour normaliser le champ photo et traiter correctement les références photos Google Maps
  void _normalizePhotoField(Map<String, dynamic> data) {
    print('🔍 Normalizing photo field for data: ${data['name']} with photo type: ${data['photo']?.runtimeType}');
    
    // Si photo est une liste, prendre le premier élément
    if (data['photo'] is List) {
      if ((data['photo'] as List).isNotEmpty) {
        // Extraction de l'URL ou de la référence photo
        var photoItem = (data['photo'] as List)[0];
        if (photoItem is Map<String, dynamic> && photoItem.containsKey('photo_reference')) {
          // Cas d'une référence photo Google Maps
          String photoReference = photoItem['photo_reference'];
          print('📸 Found Google Maps photo reference: $photoReference');
          data['photo'] = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400'
              '&photoreference=$photoReference'
              '&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE';
          print('🔗 Created Google Maps photo URL: ${data['photo']}');
        } else if (photoItem is String) {
          data['photo'] = photoItem;
          print('🖼️ Found photo as string: ${data['photo']}');
        } else {
          // Valeur par défaut si le format n'est pas reconnu
          print('⚠️ Unrecognized photo format: ${photoItem.runtimeType}');
          data['photo'] = 'https://via.placeholder.com/400x200?text=Pas+d%27image';
        }
      } else {
        print('⚠️ Empty photo list');
        data['photo'] = 'https://via.placeholder.com/400x200?text=Pas+d%27image';
      }
    }
    
    // Vérifier les références photos Google Maps
    if (data['photo'] == null || (data['photo'] is String && data['photo'].toString().isEmpty)) {
      print('🔍 No photo found, checking photos field');
      // Rechercher une photo dans d'autres champs
      if (data['photos'] != null) {
        print('📸 Photos field exists with type: ${data['photos'].runtimeType}');
        if (data['photos'] is List && (data['photos'] as List).isNotEmpty) {
          var photoItem = (data['photos'] as List)[0];
          print('📸 First photo item type: ${photoItem.runtimeType}');
          
          if (photoItem is Map<String, dynamic> && photoItem.containsKey('photo_reference')) {
            // Cas d'une référence photo Google Maps
            String photoReference = photoItem['photo_reference'];
            print('📸 Found Google Maps photo reference in photos: $photoReference');
            data['photo'] = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400'
                '&photoreference=$photoReference'
                '&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE';
            print('🔗 Created Google Maps photo URL from photos: ${data['photo']}');
          } else if (photoItem is String) {
            data['photo'] = photoItem;
            print('🖼️ Found photo string in photos: ${data['photo']}');
          }
        }
      }
    }
    
    // Si toujours pas de photo, vérifier le champ maps_url pour construire une URL statique Maps
    if (data['photo'] == null || (data['photo'] is String && data['photo'].toString().isEmpty)) {
      if (data['maps_url'] != null && data['maps_url'].toString().isNotEmpty) {
        print('🗺️ No photo found, using maps_url for static map image');
        // Extract place_id or coordinates from maps_url if available
        if (data['gps_coordinates'] != null) {
          try {
            var lat = data['gps_coordinates']['lat'] ?? data['gps_coordinates']['latitude'];
            var lng = data['gps_coordinates']['lng'] ?? data['gps_coordinates']['longitude'];
            // Generate a static Maps image as fallback
            data['photo'] = 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=16&size=600x300&markers=color:red%7C$lat,$lng&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE';
            print('🗺️ Created static map image URL: ${data['photo']}');
          } catch (e) {
            print('❌ Error creating static map image: $e');
          }
        }
      }
    }
    
    // Si toujours pas de photo, utiliser une image par défaut
    if (data['photo'] == null || (data['photo'] is String && data['photo'].toString().isEmpty)) {
      print('⚠️ No usable photo found, using default placeholder');
      data['photo'] = 'https://via.placeholder.com/400x200?text=Pas+d%27image';
    }
  }
  
  // Fonction pour suivre ou ne plus suivre un producteur
  Future<void> _toggleFollow(String producerId) async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour suivre un producteur')),
      );
      return;
    }
    
    // --- ADDED: Log follow/unfollow action --- 
    final actionType = _isFollowing ? 'unfollow_producer' : 'follow_producer';
    _logGenericProducerAction(actionType);
    // --- End Log --- 
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId/follow');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': widget.userId}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFollowing = data['isFollowing'] ?? !_isFollowing;
          _followersCount = _isFollowing ? _followersCount + 1 : _followersCount - 1;
          if (_followersCount < 0) _followersCount = 0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing 
              ? 'Vous suivez maintenant ce producteur' 
              : 'Vous ne suivez plus ce producteur'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        print('❌ Erreur lors du suivi: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour du suivi')),
        );
      }
    } catch (e) {
      print('❌ Exception lors du suivi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau lors de la mise à jour du suivi')),
      );
    }
  }
  
  // Fonction pour envoyer un message au producteur
  Future<void> _sendMessage(String producerId, String message) async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour envoyer un message')),
      );
      return;
    }
    
    if (message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un message')),
      );
      return;
    }
    
    // --- ADDED: Log send message action --- 
    _logGenericProducerAction('send_message_producer');
    // --- End Log --- 
    
    setState(() {
      _isSendingMessage = true;
    });
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/conversations/new-message');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': widget.userId,
          'recipientIds': [producerId],
          'content': message,
        }),
      );
      
      if (response.statusCode == 201) {
        _messageController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message envoyé avec succès')),
        );
        
        // Naviguer vers l'écran de messagerie
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MessagingScreen(
                userId: widget.userId!,
              ),
            ),
          );
        }
      } else {
        print('❌ Erreur lors de l\'envoi du message: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du message')),
        );
      }
    } catch (e) {
      print('❌ Exception lors de l\'envoi du message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau lors de l\'envoi du message')),
      );
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }
  
  // Fonction pour partager le profil du producteur
  void _shareProducerProfile(Map<String, dynamic> producer) {
    final String name = producer['name'] ?? 'Producteur';
    final String description = producer['description'] ?? '';
    final String shareText = 'Découvrez $name sur Choice App.\n$description';
    
    // --- ADDED: Log share action --- 
    _logGenericProducerAction('share_producer');
    // --- End Log --- 
    
    _shareViaSystem(shareText);
  }
  
  // Méthode alternative pour partager
  Future<void> _shareViaSystem(String text) async {
    // Utilisation de url_launcher avec scheme particulier pour partager
    // ou simplement afficher un message
    try {
      // Sur les plateformes où c'est supporté
      final Uri uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Message de repli
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partage non disponible sur cet appareil')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de partager: $e')),
      );
    }
  }
  
  // Fonction pour ouvrir Google Maps avec l'adresse du producteur
  Future<void> _openMaps(Map<String, dynamic> producer) async {
    String? address = producer['address'];
    if (address == null || address.isEmpty) {
      address = producer['formatted_address'] ?? producer['vicinity'];
    }
    
    if (address == null || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse non disponible')),
      );
      return;
    }
    
    // Coordonnées GPS si disponibles
    double? lat;
    double? lng;
    
    if (producer['gps_coordinates'] != null && 
        producer['gps_coordinates']['coordinates'] != null &&
        producer['gps_coordinates']['coordinates'] is List &&
        producer['gps_coordinates']['coordinates'].length >= 2) {
      lng = producer['gps_coordinates']['coordinates'][0];
      lat = producer['gps_coordinates']['coordinates'][1];
    } else if (producer['geometry'] != null && 
               producer['geometry']['location'] != null) {
      lat = producer['geometry']['location']['lat'];
      lng = producer['geometry']['location']['lng'];
    }
    
    String mapsUrl;
    if (lat != null && lng != null) {
      mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else {
      mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    }
    
    final Uri url = Uri.parse(mapsUrl);
    // --- ADDED: Log open maps action --- 
    _logGenericProducerAction('open_maps');
    // --- End Log --- 
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Google Maps')),
      );
    }
  }
  
  // Fonction pour appeler le producteur
  Future<void> _callProducer(Map<String, dynamic> producer) async {
    String? phone = producer['phone_number'] ?? producer['formatted_phone_number'] ?? producer['international_phone_number'];
    
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone non disponible')),
      );
      return;
    }
    
    // Nettoyer le numéro de téléphone
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    
    final Uri url = Uri.parse('tel:$phone');
    // --- ADDED: Log call action --- 
    _logGenericProducerAction('call_producer');
    // --- End Log --- 
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'effectuer l\'appel')),
      );
    }
  }
  
  // Fonction pour ouvrir le site web du producteur
  Future<void> _openWebsite(Map<String, dynamic> producer) async {
    String? website = producer['website'] ?? producer['url'];
    
    if (website == null || website.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Site web non disponible')),
      );
      return;
    }
    
    final Uri url = Uri.parse(website);
    // --- ADDED: Log open website action --- 
    _logGenericProducerAction('open_website');
    // --- End Log --- 
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le site web')),
      );
    }
  }
  
  // Fonction pour afficher la boîte de dialogue de message
  void _showMessageDialog(BuildContext context, String producerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Envoyer un message',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Votre message...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSendingMessage
                        ? null
                        : () {
                            _sendMessage(producerId, _messageController.text);
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Envoyer'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _producerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _producerFuture = _fetchProducerDetails(widget.producerId);
                      });
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Aucune donnée disponible'),
            );
          } else {
            final producer = snapshot.data!;
            
            if (producer['error'] == true) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Erreur de chargement',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(producer['error_message'] ?? 'Erreur inconnue'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _producerFuture = _fetchProducerDetails(widget.producerId);
                        });
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            
            return _buildProducerProfile(producer);
          }
        },
      ),
    );
  }
  
  Widget _buildProducerProfile(Map<String, dynamic> producer) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(producer),
          _buildHeader(producer),
          _buildTabBar(),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(producer),
          _buildMenuTab(producer),
          _buildPostsTab(producer),
          _buildReviewsTab(producer),
        ],
      ),
    );
  }

  Widget _buildAppBar(Map<String, dynamic> producer) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.teal,
      flexibleSpace: FlexibleSpaceBar(
        background: CachedNetworkImage(
          imageUrl: producer['photo'] ?? 'https://via.placeholder.com/500x300?text=No+Image',
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.restaurant, size: 50, color: Colors.white),
          ),
        ),
        title: Text(
          producer['name'] ?? 'Sans nom',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3.0,
                color: Color.fromARGB(150, 0, 0, 0),
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        collapseMode: CollapseMode.parallax,
      ),
      actions: [
        IconButton(
          icon: Icon(_isFollowing ? Icons.favorite : Icons.favorite_border),
          color: Colors.white,
          onPressed: () => _toggleFollow(producer['_id']),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          color: Colors.white,
          onPressed: () => _shareProducerProfile(producer),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          color: Colors.white,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => _buildMoreOptions(context, producer),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> producer) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producer['name'] ?? 'Sans nom',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${producer['rating'] ?? '0'} · ${_followersCount} abonnés',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        producer['address'] ?? 'Adresse non disponible',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (producer['price_level'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getPriceLevel(producer['price_level']),
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        producer['primary_category'] ?? 'Non catégorisé',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.map,
                  label: 'Itinéraire',
                  onPressed: () => _openMaps(producer),
                ),
                _buildActionButton(
                  icon: Icons.phone,
                  label: 'Appeler',
                  onPressed: () => _callProducer(producer),
                ),
                _buildActionButton(
                  icon: Icons.message,
                  label: 'Message',
                  onPressed: () => _showMessageDialog(context, producer['_id']),
                ),
                _buildActionButton(
                  icon: Icons.web,
                  label: 'Site web',
                  onPressed: () => _openWebsite(producer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Info'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
            Tab(icon: Icon(Icons.photo_library), text: 'Posts'),
            Tab(icon: Icon(Icons.star_border), text: 'Avis'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> producer) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Description du producteur
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'À propos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    producer['description'] ?? 'Aucune description disponible',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ),
                
                // Tags ou spécialités (si disponibles)
                if (producer['specialties'] != null && producer['specialties'] is List) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Spécialités',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (producer['specialties'] as List).map<Widget>((specialty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          specialty,
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                
                // Cuisine ou type de restaurant (si disponible)
                if (producer['cuisine_type'] != null && producer['cuisine_type'] is List) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Type de cuisine',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (producer['cuisine_type'] as List).map<Widget>((cuisine) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          cuisine,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Horaires d'ouverture
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Horaires d\'ouverture',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildOpeningHours(producer),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Informations de contact
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.contact_phone, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Contact',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildContactInfo(producer),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Photos (si disponibles)
        if (producer['photos'] != null && producer['photos'] is List && (producer['photos'] as List).isNotEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.pink.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_library, color: Colors.pink),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Photos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPhotosGrid(producer['photos']),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOpeningHours(Map<String, dynamic> producer) {
    final openingHours = producer['opening_hours'];
    
    if (openingHours == null || 
        !(openingHours is List) || 
        (openingHours as List).isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Horaires non disponibles',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    
    final List<String> daysOfWeek = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    
    return Column(
      children: List.generate(
        min(openingHours.length, daysOfWeek.length),
        (index) {
          final String dayLabel = daysOfWeek[index];
          final String hourText = openingHours[index];
          
          // Déterminer si c'est le jour actuel
          bool isToday = DateTime.now().weekday - 1 == index;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isToday)
                      const Icon(Icons.today, size: 16, color: Colors.blue),
                    SizedBox(width: isToday ? 8 : 0),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? Colors.blue : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  hourText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactInfo(Map<String, dynamic> producer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (producer['phone_number'] != null || producer['formatted_phone_number'] != null) ...[
          GestureDetector(
            onTap: () => _callProducer(producer),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Téléphone',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          producer['phone_number'] ?? producer['formatted_phone_number'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        if (producer['website'] != null) ...[
          GestureDetector(
            onTap: () => _openWebsite(producer),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Site web',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          producer['website'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        GestureDetector(
          onTap: () => _openMaps(producer),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adresse',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        producer['address'] ?? 'Adresse non disponible',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.teal,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getPriceLevel(dynamic priceLevel) {
    if (priceLevel == null) return '';
    
    int level;
    if (priceLevel is int) {
      level = priceLevel;
    } else if (priceLevel is String) {
      level = int.tryParse(priceLevel) ?? 0;
    } else {
      return '';
    }
    
    switch (level) {
      case 0:
        return 'Gratuit';
      case 1:
        return '€';
      case 2:
        return '€€';
      case 3:
        return '€€€';
      case 4:
        return '€€€€';
      default:
        return '€';
    }
  }

  Widget _buildPostsTab(Map<String, dynamic> producer) {
    if (_isLoadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun post disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return GestureDetector(
          onTap: () {
            // Navigation vers le détail du post
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  postId: post['_id'] ?? post['id'] ?? '',
                  userId: widget.userId ?? '',
                ),
              ),
            );
          },
          child: ProfilePostCard(
            post: post,
            userId: widget.userId ?? '',
            onRefresh: _loadPosts,
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(Map<String, dynamic> producer) {
    final reviews = producer['reviews'] ?? [];
    
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.star_border,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun avis disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    // Calculer la note moyenne
    double averageRating = 0;
    int totalRatings = 0;
    
    for (var review in reviews) {
      if (review['rating'] != null) {
        averageRating += review['rating'];
        totalRatings++;
      }
    }
    
    if (totalRatings > 0) {
      averageRating = averageRating / totalRatings;
    }
    
    // Compter les avis par note (5★, 4★, etc.)
    Map<int, int> ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    
    for (var review in reviews) {
      if (review['rating'] != null) {
        int rating = review['rating'];
        if (ratingDistribution.containsKey(rating)) {
          ratingDistribution[rating] = ratingDistribution[rating]! + 1;
        }
      }
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Résumé des avis
        _buildReviewSummary(averageRating, totalRatings, ratingDistribution),
        
        const SizedBox(height: 24),
        
        // En-tête de la section des avis
        Row(
          children: [
            const Icon(Icons.comment, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              'Avis des clients (${reviews.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Liste des avis
        ...List.generate(reviews.length, (index) => _buildReviewCard(reviews[index])),
      ],
    );
  }
  
  // Widget pour afficher le résumé des avis
  Widget _buildReviewSummary(double averageRating, int totalRatings, Map<int, int> ratingDistribution) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Note moyenne en grand
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < averageRating.round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalRatings avis',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Séparateur vertical
                Container(
                  height: 100,
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                
                // Distribution des notes (barres)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: List.generate(
                      5,
                      (index) {
                        final ratingValue = 5 - index;
                        final count = ratingDistribution[ratingValue] ?? 0;
                        final percentage = totalRatings > 0 
                            ? count / totalRatings 
                            : 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '$ratingValue',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getRatingColor(ratingValue),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Fonction pour obtenir la couleur en fonction de la note
  Color _getRatingColor(int rating) {
    switch (rating) {
      case 5: return Colors.green;
      case 4: return Colors.lightGreen;
      case 3: return Colors.amber;
      case 2: return Colors.orange;
      case 1: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final String name = review['author_name'] ?? 'Utilisateur anonyme';
    final String text = review['text'] ?? '';
    final int rating = review['rating'] ?? 0;
    final String timeStr = review['relative_time_description'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar de l'utilisateur avec bordure
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    backgroundImage: review['profile_photo_url'] != null
                        ? NetworkImage(review['profile_photo_url'])
                        : null,
                    child: review['profile_photo_url'] == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Stars with custom color
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: index < rating ? Colors.amber : Colors.grey[400],
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (timeStr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),
            ],
            
            // Boutons d'action (optionnels)
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // Fonctionnalité à implémenter
                  },
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: const Text('Utile'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Fonctionnalité à implémenter
                  },
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Signaler'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptions(BuildContext context, Map<String, dynamic> producer) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(bottom: 20),
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Signaler'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implémenter la fonctionnalité de signalement
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité de signalement à venir')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Voir le site web'),
            onTap: () {
              Navigator.pop(context);
              _openWebsite(producer);
            },
          ),
          if (producer['phone_number'] != null || producer['formatted_phone_number'] != null)
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Appeler'),
              onTap: () {
                Navigator.pop(context);
                _callProducer(producer);
              },
            ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Partager'),
            onTap: () {
              Navigator.pop(context);
              _shareProducerProfile(producer);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosGrid(List<dynamic> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length > 9 ? 9 : photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        String photoUrl;
        
        if (photo is String) {
          photoUrl = photo;
        } else if (photo is Map && photo['photo_reference'] != null) {
          photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400'
              '&photoreference=${photo['photo_reference']}'
              '&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE';
        } else {
          photoUrl = 'https://via.placeholder.com/150';
        }
        
        return GestureDetector(
          onTap: () {
            // TODO: Implémenter la visualisation plein écran des photos
          },
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTab(Map<String, dynamic> producer) {
    if (_isLoadingMenus) {
      return const Center(child: CircularProgressIndicator());
    }

    // Vérifier s'il existe des menus ou des items indépendants
    if (_menus.isEmpty && _menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun menu disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section des menus globaux
        if (_menus.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book, color: Colors.amber),
              ),
              const SizedBox(width: 12),
              const Text(
                'Menus',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._menus.map((menu) => _buildMenuCard(menu)).toList(),
          const SizedBox(height: 24),
        ],
        
        // Section des items indépendants
        if (_menuItems.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fastfood, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              const Text(
                'Articles à la carte',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Regrouper les items par catégorie
          ..._buildItemsByCategory(),
        ],
      ],
    );
  }
  
  // Méthode pour construire la carte d'un menu
  Widget _buildMenuCard(Map<String, dynamic> menu) {
    final String title = menu['name'] ?? menu['title'] ?? 'Menu';
    final String description = menu['description'] ?? '';
    final dynamic price = menu['price'];
    final String formattedPrice = price != null ? '${price.toString()} €' : '';
    final List<dynamic> items = menu['items'] ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (formattedPrice.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              ...items.map((item) => _buildMenuItemRow(item)).toList(),
            ],
          ],
        ),
      ),
    );
  }
  
  // Méthode pour construire une rangée d'item de menu
  Widget _buildMenuItemRow(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Item';
    final String description = item['description'] ?? '';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Méthode pour regrouper et construire les items par catégorie
  List<Widget> _buildItemsByCategory() {
    // Regrouper les items par catégorie
    final Map<String, List<Map<String, dynamic>>> itemsByCategory = {};
    
    for (var item in _menuItems) {
      final category = item['category'] ?? 'Non catégorisé';
      if (!itemsByCategory.containsKey(category)) {
        itemsByCategory[category] = [];
      }
      itemsByCategory[category]!.add(item);
    }
    
    // Construire les sections pour chaque catégorie
    List<Widget> categoryWidgets = [];
    
    itemsByCategory.forEach((category, items) {
      categoryWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
      
      // Ajouter les items de cette catégorie
      for (var item in items) {
        categoryWidgets.add(_buildItemCard(item));
      }
    });
    
    return categoryWidgets;
  }

  // Widget pour afficher une carte d'item de menu
  Widget _buildItemCard(Map<String, dynamic> item) {
    final String name = item['name'] ?? item['nom'] ?? 'Item sans nom';
    final String description = item['description'] ?? '';
    final dynamic price = item['price'] ?? item['prix'];
    final String formattedPrice = price != null ? '${price.toString()} €' : '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          // Action optionnelle lors du tap
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (formattedPrice.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formattedPrice,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Logs the producer profile view activity.
  Future<void> _logProducerViewActivity(String producerId, String producerType) async {
    // Use the userId passed to the widget, assuming it's the logged-in user
    final String? currentUserId = widget.userId; 
    if (currentUserId == null || currentUserId.isEmpty) {
      print('📊 Cannot log producer view: Current user ID not available.');
      return; // Don't log if no user is logged in
    }

    // Get current location (handle null)
    final LatLng? currentLocation = await LocationUtils.getCurrentLocation();
    final LatLng locationToSend = currentLocation ?? LocationUtils.defaultLocation();

    print('📊 Logging producer view: User: $currentUserId, Viewed Producer ID: $producerId, Type: $producerType, Location: $locationToSend');

    // Use the correct producerType based on fetched data or widget param
    String finalProducerType = 'restaurant'; // Default
    if (widget.isWellness) {
      finalProducerType = 'wellness';
    } else if (widget.isBeauty) {
       finalProducerType = 'beauty'; // Assuming a type for beauty
    } else if (producerType.toLowerCase().contains('leisure')) {
       finalProducerType = 'leisure';
    }
    // Add more logic if needed based on producer data fields

    AppDataSenderService.sendActivityLog(
      userId: currentUserId,
      action: 'view_producer', // Specific action type
      location: locationToSend,
      producerId: producerId,
      producerType: finalProducerType, // Use determined type
    );
  }

  /// Generic helper to log producer interaction actions.
  Future<void> _logGenericProducerAction(String action) async {
    final String? currentUserId = widget.userId;
    if (currentUserId == null || currentUserId.isEmpty) {
      // FIXED: Use correct string interpolation
      print('📊 Cannot log action \'$action\': Current user ID not available.');
      return;
    }

    // Get current location
    final LatLng? currentLocation = await LocationUtils.getCurrentLocation();
    final LatLng locationToSend = currentLocation ?? LocationUtils.defaultLocation();

    // Determine producer type more robustly
    String finalProducerType = 'restaurant'; // Default
    if (widget.isWellness) {
      finalProducerType = 'wellness';
    } else if (widget.isBeauty) {
       finalProducerType = 'beauty';
    } else {
        // Try to infer from future data if available
        try {
          final producer = await _producerFuture;
           String? fetchedType = producer['type']?.toString().toLowerCase();
           if (fetchedType != null) {
               if (fetchedType.contains('leisure')) finalProducerType = 'leisure';
               // Add other type checks if needed
           }
        } catch (_) { /* Ignore error if future hasn't completed */ }
    }

    print('📊 Logging Action: User: $currentUserId, Action: $action, Producer: ${widget.producerId}, Type: $finalProducerType, Location: $locationToSend');

    AppDataSenderService.sendActivityLog(
      userId: currentUserId,
      action: action,
      location: locationToSend,
      producerId: widget.producerId, 
      producerType: finalProducerType,
      // Add more metadata if needed (e.g., button clicked)
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context, 
    double shrinkOffset, 
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
} 