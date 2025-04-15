import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/map_service.dart';
import '../models/map_producer.dart';
import 'dart:convert';
import 'dart:math'; // Pour la fonction min()
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'utils.dart';
import '../services/auth_service.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'profile_screen.dart'; // Pour les utilisateurs
import 'wellness_producer_screen.dart'; // Pour les producteurs de bien-être
import 'dart:io' show SocketException;
import '../utils/constants.dart' as constants;
import '../services/app_data_sender_service.dart'; // Import the sender service
import '../utils/location_utils.dart'; // Import location utils
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng

class ProducerSearchPage extends StatefulWidget {
  final String userId;

  const ProducerSearchPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProducerSearchPageState createState() => _ProducerSearchPageState();
}

class _ProducerSearchPageState extends State<ProducerSearchPage> with SingleTickerProviderStateMixin {
  // Résultats de recherche et états de chargement
  List<dynamic> _searchResults = [];
  String _query = "";
  bool _isLoading = false;
  String _errorMessage = "";
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _searchAnimationController;

  // États de chargement pour chaque section
  bool _isLoadingTrending = true;
  bool _isLoadingNearby = true;
  bool _isLoadingFriends = true;
  bool _isLoadingInnovative = true;
  bool _isLoadingSurprise = true;
  
  // Messages d'erreur pour chaque section
  String _trendingError = "";
  String _nearbyError = "";
  String _friendsError = "";
  String _innovativeError = "";
  String _surpriseError = "";
  
  // Données pour chaque section - remplies dynamiquement via API
  List<dynamic> _trendingNow = [];
  List<dynamic> _popularNearby = [];
  List<dynamic> _bestFriendsExperiences = [];
  List<dynamic> _innovative = [];
  List<dynamic> _surprise = [];
  
  String getBaseUrl() {
    return constants.getBaseUrl();
  }
  
  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Charger les données de toutes les sections
    _fetchTrendingItems();
    _fetchNearbyItems();
    
    // Only fetch friends experiences if we have a valid userId
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.hasValidUserId()) {
      _fetchFriendsExperiences();
    } else {
      setState(() {
        _isLoadingFriends = false;
        _friendsError = "Connexion requise pour voir les expériences de vos amis";
      });
    }
    
    _fetchInnovativeItems();
    _fetchSurpriseItems();
  }
  
  /// Récupère les tendances actuelles
  Future<void> _fetchTrendingItems() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingTrending = true;
      _trendingError = "";
    });
    
    try {
      final baseUrl = await constants.getBaseUrl(); // Use await and constants.getBaseUrl()
      Uri url = Uri.parse('$baseUrl/api/unified/trending-public');
      
      // Ajout des paramètres de pagination
      final params = {
        'limit': '6',
        'page': '1'
      };
      
      url = url.replace(queryParameters: params);
      
      print('🔍 Chargement des tendances: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu: ${decoded.runtimeType}');
        }
        
        if (!mounted) return;
        
        setState(() {
          _trendingNow = _transformApiData(resultList);
          _isLoadingTrending = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des tendances: $e');
      
      if (!mounted) return;
      
      setState(() {
        _trendingError = "Impossible de charger les tendances";
        _isLoadingTrending = false;
        
        // Données de secours si l'API échoue
        _trendingNow = [
          {
            'id': '1',
            'type': 'restaurant',
            'name': 'Le Petit Bistrot',
            'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&q=80',
            'rating': 4.8,
            'category': 'Cuisine française'
          },
          {
            'id': '2',
            'type': 'event',
            'name': 'Festival Jazz des Puces',
            'image': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
            'rating': 4.5,
            'category': 'Concert'
          },
        ];
      });
    }
  }
  
  /// Récupère les lieux populaires à proximité
  Future<void> _fetchNearbyItems() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingNearby = true;
      _nearbyError = "";
    });
    
    try {
      final baseUrl = await constants.getBaseUrl(); // Use await and constants.getBaseUrl()
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/unified/nearby-public');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/unified/nearby-public');
      } else {
        url = Uri.parse('$baseUrl/api/unified/nearby-public');
      }
      
      // Paramètres optionnels pour la localisation
      // Idéalement on utiliserait la position réelle de l'utilisateur
      final params = {
        'lat': '48.8566',  // Paris par défaut
        'lng': '2.3522',
        'radius': '5000',  // 5km
      };
      
      url = url.replace(queryParameters: params);
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu: ${decoded.runtimeType}');
        }
        
        if (!mounted) return;
        
        setState(() {
          _popularNearby = _transformApiData(resultList);
          _isLoadingNearby = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des lieux à proximité: $e');
      
      if (!mounted) return;
      
      setState(() {
        _nearbyError = "Impossible de charger les lieux à proximité";
        _isLoadingNearby = false;
        
        // Données de secours
        _popularNearby = [
          {
            'id': '4',
            'type': 'restaurant',
            'name': 'Sushi Fusion',
            'image': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=500&q=80',
            'rating': 4.6,
            'category': 'Japonais'
          },
          {
            'id': '5',
            'type': 'leisureProducer',
            'name': 'Cinéma Le Palace',
            'image': 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80',
            'rating': 4.3,
            'category': 'Cinéma'
          },
        ];
      });
    }
  }
  
  /// Récupère les expériences des amis de l'utilisateur
  Future<void> _fetchFriendsExperiences() async {
    if (!mounted) return;
    
    // On ne charge pas cette section si l'utilisateur n'est pas connecté
    setState(() {
      _isLoadingFriends = false;
      _friendsError = "";
    });
    
    // Données de secours - expériences populaires pour tous
    if (!mounted) return;
    
    setState(() {
      _bestFriendsExperiences = [
        {
          'id': '7',
          'type': 'restaurant',
          'name': 'La Trattoria',
          'image': 'https://images.unsplash.com/photo-1481833761820-0509d3217039?w=500&q=80',
          'rating': 4.7,
          'category': 'Italien'
        },
        {
          'id': '8',
          'type': 'event',
          'name': 'Concert Live Band',
          'image': 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=500&q=80',
          'rating': 4.4,
          'category': 'Musique'
        },
        {
          'id': '9',
          'type': 'leisureProducer',
          'name': 'Musée d\'Art Moderne',
          'image': 'https://images.unsplash.com/photo-1626126525134-fbbc0db37b8a?w=500&q=80',
          'rating': 4.6,
          'category': 'Musée'
        },
      ];
    });
  }
  
  /// Récupère les expériences innovantes
  Future<void> _fetchInnovativeItems() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingInnovative = true;
      _innovativeError = "";
    });
    
    try {
      final baseUrl = await constants.getBaseUrl(); // Use await and constants.getBaseUrl()
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/unified/innovative-public');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/unified/innovative-public');
      } else {
        url = Uri.parse('$baseUrl/api/unified/innovative-public');
      }
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu pour innovative: ${decoded.runtimeType}');
        }
        
        if (!mounted) return;
        
        setState(() {
          _innovative = _transformApiData(resultList);
          _isLoadingInnovative = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des expériences innovantes: $e');
      
      if (!mounted) return;
      
      setState(() {
        _innovativeError = "Impossible de charger les expériences innovantes";
        _isLoadingInnovative = false;
        
        // Données de secours
        _innovative = [
          {
            'id': '9',
            'type': 'leisureProducer',
            'name': 'VR Experience Center',
            'image': 'https://images.unsplash.com/photo-1478416272538-5f7e51dc5400?w=500&q=80',
            'rating': 4.8,
            'category': 'Réalité Virtuelle'
          },
          {
            'id': '10',
            'type': 'restaurant',
            'name': 'Dark Dinner',
            'image': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=500&q=80',
            'rating': 4.5,
            'category': 'Expérience culinaire'
          },
        ];
      });
    }
  }
  
  /// Récupère les expériences surprises
  Future<void> _fetchSurpriseItems() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingSurprise = true;
      _surpriseError = "";
    });
    
    try {
      final baseUrl = await constants.getBaseUrl(); // Use await and constants.getBaseUrl()
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/unified/surprise-public');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/unified/surprise-public');
      } else {
        url = Uri.parse('$baseUrl/api/unified/surprise-public');
      }
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu pour surprise: ${decoded.runtimeType}');
        }
        
        if (!mounted) return;
        
        setState(() {
          _surprise = _transformApiData(resultList);
          _isLoadingSurprise = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des surprises: $e');
      
      if (!mounted) return;
      
      setState(() {
        _surpriseError = "Impossible de charger les surprises";
        _isLoadingSurprise = false;
        
        // Données de secours
        _surprise = [
          {
            'id': '11',
            'type': 'event',
            'name': 'Théâtre d\'improvisation',
            'image': 'https://images.unsplash.com/photo-1503095396549-807759245b35?w=500&q=80',
            'rating': 4.6,
            'category': 'Théâtre'
          },
          {
            'id': '12',
            'type': 'leisureProducer',
            'name': 'Laser Game Nature',
            'image': 'https://images.unsplash.com/photo-1551892374-ecf8754cf8b0?w=500&q=80',
            'rating': 4.4,
            'category': 'Activité plein air'
          },
        ];
      });
    }
  }
  
  /// Transforme les données de l'API en format utilisable pour l'UI
  List<Map<String, dynamic>> _transformApiData(List<dynamic> apiData) {
    return apiData.map((item) {
      // Déterminer le type avec gestion améliorée
      String type = 'unknown';
      if (item['type'] != null) {
        type = item['type'].toString();
      } else if (item['category'] != null && item['category'].toString().toLowerCase().contains('restaurant')) {
        type = 'restaurant';
      } else if (item['catégorie'] != null && item['catégorie'].toString().toLowerCase().contains('restaurant')) {
        type = 'restaurant';
      } else if (item['sector'] != null) {
        final sector = item['sector'].toString().toLowerCase();
        if (sector.contains('loisir') || sector.contains('culture')) {
          type = 'leisureProducer';
        } else if (sector.contains('restaurant') || sector.contains('gastro')) {
          type = 'restaurant';
        } else if (sector.contains('bien') && sector.contains('être') || 
                  sector.contains('beauté') || sector.contains('spa')) {
          type = 'wellnessProducer';
        }
      }
      
      // Débogage pour les restaurants
      if (type == 'restaurant') {
        _debugRestaurantData(item);
      }
      
      // Extraire l'ID avec meilleure gestion
      String id = '';
      if (item['_id'] != null && item['_id'].toString().trim().isNotEmpty) {
        id = item['_id'].toString();
      } else if (item['id'] != null && item['id'].toString().trim().isNotEmpty) {
        id = item['id'].toString();
      } else if (item['place_id'] != null && item['place_id'].toString().trim().isNotEmpty) {
        id = item['place_id'].toString();
      }
      
      // Extraire le nom selon le type avec méthode améliorée
      String name = '';
      final possibleNameFields = [
        'name', 'nom', 'lieu', 'établissement', 'intitulé', 'titre', 
        'business_name', 'place_name', 'lieu_nom'
      ];
      
      for (final field in possibleNameFields) {
        if (item[field] != null && item[field].toString().trim().isNotEmpty) {
          name = item[field].toString();
          break;
        }
      }
      
      if (name.isEmpty) {
        name = 'Sans nom';
      }
      
      // Extraction d'image améliorée
      String image = '';
      
      // Traitement spécial pour les restaurants
      if (type == 'restaurant') {
        image = _getRestaurantImage(item);
      }
      
      // Si aucune image n'a été trouvée avec le traitement spécial, utiliser la méthode standard
      if (image.isEmpty) {
        image = _getStandardImage(item, type, id);
      }
      
      // Extraction de note avec gestion améliorée
      double rating = 0.0; // Commencer à zéro plutôt qu'une note arbitraire
      final ratingFields = ['note', 'rating', 'note_google', 'stars', 'score', 'avis'];
      
      for (final field in ratingFields) {
        if (item[field] != null) {
          try {
            if (item[field] is double) {
              rating = item[field];
              break;
            } else if (item[field] is int) {
              rating = (item[field] as int).toDouble();
              break;
            } else if (item[field] is String && (item[field] as String).isNotEmpty) {
              rating = double.parse(item[field].toString());
              break;
            } else if (item[field] is List && (item[field] as List).isNotEmpty) {
              var firstItem = (item[field] as List).first;
              if (firstItem is num) {
            rating = firstItem.toDouble();
                break;
          } else {
              rating = double.parse(firstItem.toString());
                break;
              }
            }
          } catch (e) {
            print('Erreur de conversion de note: ${item[field]} - $e');
          }
        }
      }
      
      // Si aucune note trouvée, attribuer une note par défaut selon le type
      if (rating == 0.0) {
        switch (type) {
          case 'restaurant':
            rating = 4.0;
            break;
          case 'leisureProducer':
            rating = 4.2;
            break;
          case 'event':
            rating = 4.5;
            break;
          case 'wellnessProducer':
            rating = 4.3;
            break;
          default:
            rating = 4.0;
        }
      }
      
      // Limiter la note entre 0 et 5
      if (rating < 0) rating = 0;
      if (rating > 5) rating = 5;
      
      // Extraction de catégorie améliorée
      String category = 'Non catégorisé';
      final categoryFields = [
        'catégorie', 'category', 'type_cuisine', 'sub_category', 
        'genres', 'style', 'ambiance', 'thématique'
      ];
      
      for (final field in categoryFields) {
        if (item[field] != null) {
          if (item[field] is String && item[field].toString().trim().isNotEmpty) {
            category = item[field].toString().trim();
            break;
          } else if (item[field] is List && (item[field] as List).isNotEmpty) {
            var list = item[field] as List;
            // Prendre les 2 premières catégories
            if (list.length > 1) {
              category = '${list[0].toString().trim()}, ${list[1].toString().trim()}';
            } else {
              category = list[0].toString().trim();
            }
            break;
          }
        }
      }
      
      // Adresse avec détection améliorée
      String address = '';
      final addressFields = ['address', 'adresse', 'lieu', 'location', 'place'];
      
      for (final field in addressFields) {
        if (item[field] != null) {
          if (item[field] is String && item[field].toString().trim().isNotEmpty) {
            address = item[field].toString().trim();
            break;
          } else if (item[field] is Map && 
                    item[field]['formatted_address'] != null &&
                    item[field]['formatted_address'].toString().trim().isNotEmpty) {
            address = item[field]['formatted_address'].toString().trim();
            break;
          }
        }
      }
      
      // Si l'adresse est trop longue, la tronquer
      if (address.length > 100) {
        address = address.substring(0, 97) + '...';
      }
      
      // Description avec extraction améliorée
      String description = '';
      final descriptionFields = [
        'description', 'détail', 'about', 'content', 'texte', 
        'présentation', 'summary', 'overview'
      ];
      
      for (final field in descriptionFields) {
        if (item[field] != null && item[field] is String && item[field].toString().trim().isNotEmpty) {
          description = item[field].toString().trim();
          break;
        }
      }
      
      // Limiter la longueur de la description
      if (description.length > 300) {
        description = description.substring(0, 297) + '...';
      }
      
      // Extraire les coordonnées géographiques
      double? latitude;
      double? longitude;
      
      if (item['coordinates'] is List && (item['coordinates'] as List).length >= 2) {
        try {
          longitude = double.parse(item['coordinates'][0].toString());
          latitude = double.parse(item['coordinates'][1].toString());
        } catch (e) {
          print('Erreur de conversion des coordonnées: ${item['coordinates']}');
        }
      } else if (item['gps_coordinates'] is Map) {
        try {
          latitude = double.parse(item['gps_coordinates']['lat'].toString());
          longitude = double.parse(item['gps_coordinates']['lng'].toString());
        } catch (e) {
          print('Erreur de conversion des coordonnées GPS: ${item['gps_coordinates']}');
        }
      } else if (item['location'] is Map && item['location']['coordinates'] is List) {
        try {
          longitude = double.parse(item['location']['coordinates'][0].toString());
          latitude = double.parse(item['location']['coordinates'][1].toString());
        } catch (e) {
          print('Erreur de conversion des coordonnées de localisation: ${item['location']['coordinates']}');
        }
      }
      
      return {
        'id': id,
        'type': type,
        'name': name,
        'image': image,
        'rating': rating,
        'category': category,
        'address': address,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'raw_data': item, // Conserver les données brutes pour référence future
      };
    }).toList();
  }

  /// Fonction de débogage pour analyser les données des restaurants
  void _debugRestaurantData(dynamic item) {
    print('🔍 DEBUG RESTAURANT: ${item['name'] ?? 'Sans nom'}');
    
    // Vérifier les champs de photos
    if (item['photos'] != null) {
      if (item['photos'] is List) {
        print('📸 PHOTOS (liste): ${(item['photos'] as List).length} photos');
        if ((item['photos'] as List).isNotEmpty) {
          print('   - Première photo: ${(item['photos'] as List)[0]}');
        }
      } else {
        print('📸 PHOTOS (non-liste): ${item['photos']}');
      }
    } else {
      print('📸 PHOTOS: Absent');
    }
    
    if (item['photo'] != null) {
      print('🖼️ PHOTO: ${item['photo']}');
    } else {
      print('🖼️ PHOTO: Absent');
    }
    
    // Vérifier les autres champs d'image
    final imageFields = ['image', 'images', 'photo_url', 'image_url', 'thumbnail', 'cover'];
    for (final field in imageFields) {
      if (item[field] != null) {
        print('📷 $field: ${item[field]}');
      }
    }
    
    print('-----------------------------------');
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  /// Rafraîchit toutes les sections
  Future<void> _refreshAllSections() async {
    List<Future<void>> futures = [
      _fetchTrendingItems(),
      _fetchNearbyItems(),
      _fetchInnovativeItems(),
      _fetchSurpriseItems(),
    ];
    
    // Pour les amis, on actualise juste les données de secours
    _fetchFriendsExperiences();
    
    await Future.wait(futures);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données actualisées'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Méthode pour déclencher la recherche de producteurs
  void _performSearch(String query) async {
    if (query.length < 3) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    // Log the search action
    _logSearchActivity(query);

    try {
      final baseUrl = await constants.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/unified/search').replace(
        queryParameters: {
          'query': query,
          'limit': '20' // Limiter les résultats de la recherche principale
        }
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception("Search timed out"),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        setState(() {
          _searchResults = _transformApiData(results);
          _isLoading = false;
        });
      } else {
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur de recherche: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = "Erreur lors de la recherche. Veuillez réessayer.";
        _isLoading = false;
      });
    }
  }

  /// Logs the search activity using AppDataSenderService.
  Future<void> _logSearchActivity(String query) async {
    final String userId = widget.userId; // Assuming userId is available in the widget
    // Get current location (handle null)
    final LatLng? currentLocation = await LocationUtils.getCurrentLocation();
    
    // If location is unavailable, use a default or skip logging location
    final LatLng locationToSend = currentLocation ?? LocationUtils.defaultLocation();

    print('📊 Logging search activity: User: $userId, Query: $query, Location: $locationToSend');

    // Call the service without awaiting (fire and forget)
    AppDataSenderService.sendActivityLog(
      userId: userId,
      action: 'search', // Standardized action type
      location: locationToSend,
      query: query,
      // producerId and producerType are not applicable for a general search
    );
  }

  Future<void> _navigateToDetails(String id, String type) async {
    print('🔍 Navigation vers les détails');
    print('📝 ID: $id');
    print('📝 Type: $type');
    
    // Store a reference to the context at the start of the method
    final BuildContext currentContext = context;
    
    // Check if ID is valid before attempting to navigate
    if (id.isEmpty) {
      print('❌ ID invalide');
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'accéder aux détails: ID invalide"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      // Obtenir l'ID d'utilisateur ou utiliser un ID invité
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.hasValidUserId() ? authService.userId ?? 'guest-user' : 'guest-user';
      print('👤 Utilisation de l\'ID utilisateur: $userId');
      
      switch (type) {
        case 'restaurant':
          print('🍽️ Navigation vers le restaurant');
          // Afficher un indicateur de chargement
          BuildContext? dialogContext;
          if (mounted) {
            showDialog(
              context: currentContext,
              barrierDismissible: false,
              builder: (BuildContext context) {
                dialogContext = context;
                return const Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Chargement du restaurant..."),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          try {
            // Vérifier si le restaurant existe avant de naviguer
            final url = Uri.parse('${getBaseUrl()}/api/producers/$id');
            print('🌐 URL de l\'API: $url');
            
            final response = await http.get(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception("Délai d'attente dépassé"),
            );
            
            // Fermer le dialogue de chargement
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            if (response.statusCode == 200) {
          if (mounted) {
            Navigator.push(
              currentContext,
              MaterialPageRoute(
                builder: (context) => ProducerScreen(
                  producerId: id,
                      userId: userId,
                ),
              ),
            );
              }
            } else {
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            print('❌ Erreur lors du chargement du restaurant: $e');
            // Fermer le dialogue si toujours ouvert
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            if (mounted) {
              // Essayer de naviguer quand même en cas d'erreur réseau
              Navigator.push(
                currentContext,
                MaterialPageRoute(
                  builder: (context) => ProducerScreen(
                    producerId: id,
                    userId: userId,
                  ),
                ),
              );
            }
          }
          break;
        
        case 'leisureProducer':
          print('🎮 Navigation vers le producteur de loisirs');
          BuildContext? dialogContext;
          
          // Only show dialog if the widget is still mounted
          if (mounted) {
            showDialog(
              context: currentContext,
              barrierDismissible: false,
              builder: (BuildContext context) {
                dialogContext = context;
                return const Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Chargement des informations..."),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          try {
            // Make the API request
            final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
            print('🌐 URL de l\'API: $url');
            print('📤 Envoi de la requête GET');
            
            final response = await http.get(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception("Délai d'attente dépassé"),
            );
            
            print('📥 Réponse reçue: ${response.statusCode}');
            print('📦 Corps de la réponse: ${response.body.substring(0, min(100, response.body.length))}...');
            
            // Always close dialog if it's open, regardless of mounted state
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only proceed with navigation if the request was successful and widget still mounted
            if (response.statusCode == 200 && mounted) {
              print('✅ Navigation vers ProducerLeisureScreen');
              final dynamic data = json.decode(response.body);
              
              // Vérifier le type des données reçues
              if (data is List && data.isNotEmpty) {
                // Si c'est une liste, prendre le premier élément
                print('⚠️ L\'API a renvoyé une liste. Utilisation du premier élément.');
                final Map<String, dynamic> producerData = data[0];
                Navigator.push(
                  currentContext,
                  MaterialPageRoute(
                    builder: (context) => ProducerLeisureScreen(producerData: producerData),
                  ),
                );
              } else if (data is Map<String, dynamic>) {
                // Si c'est un Map, utiliser directement
                Navigator.push(
                  currentContext,
                  MaterialPageRoute(
                    builder: (context) => ProducerLeisureScreen(producerData: data),
                  ),
                );
              } else {
                // Type inconnu, afficher une erreur
                throw Exception("Format de données inattendu: ${data.runtimeType}");
              }
            } else if (response.statusCode != 200 && mounted) {
              print('❌ Erreur serveur: ${response.statusCode}');
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            print('❌ Erreur lors du chargement: $e');
            // Safely close the loading dialog if still open
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only show error if widget is still mounted
            if (mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(
                  content: Text("Erreur lors du chargement: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        
        case 'event':
          print('🎪 Navigation vers l\'événement');
          BuildContext? dialogContext;
          
          // Only show dialog if the widget is still mounted
          if (mounted) {
            showDialog(
              context: currentContext,
              barrierDismissible: false,
              builder: (BuildContext context) {
                dialogContext = context;
                return const Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Chargement de l'événement..."),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          try {
            // Make the API request
            final url = Uri.parse('${getBaseUrl()}/api/events/$id');
            print('🌐 URL de l\'API: $url');
            print('📤 Envoi de la requête GET');
            
            final response = await http.get(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception("Délai d'attente dépassé"),
            );
            
            print('📥 Réponse reçue: ${response.statusCode}');
            print('📦 Corps de la réponse: ${response.body.substring(0, min(100, response.body.length))}...');
            
            // Always close dialog if it's open, regardless of mounted state
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only proceed with navigation if the request was successful and widget still mounted
            if (response.statusCode == 200 && mounted) {
              print('✅ Navigation vers EventLeisureScreen');
              final dynamic data = json.decode(response.body);
              
              // Vérifier le type des données reçues
              if (data is List && data.isNotEmpty) {
                // Si c'est une liste, prendre le premier élément
                print('⚠️ L\'API a renvoyé une liste. Utilisation du premier élément.');
                final Map<String, dynamic> eventData = data[0];
                Navigator.push(
                  currentContext,
                  MaterialPageRoute(
                    builder: (context) => EventLeisureScreen(eventData: eventData),
                  ),
                );
              } else if (data is Map<String, dynamic>) {
                // Si c'est un Map, utiliser directement
                Navigator.push(
                  currentContext,
                  MaterialPageRoute(
                    builder: (context) => EventLeisureScreen(eventData: data),
                  ),
                );
              } else {
                // Type inconnu, afficher une erreur
                throw Exception("Format de données inattendu: ${data.runtimeType}");
              }
            } else if (response.statusCode != 200 && mounted) {
              print('❌ Erreur serveur: ${response.statusCode}');
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            print('❌ Erreur lors du chargement: $e');
            // Safely close the loading dialog if still open
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only show error if widget is still mounted
            if (mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(
                  content: Text("Erreur lors du chargement: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        
        case 'wellnessProducer':
          print('💆 Navigation vers le producteur bien-être');
          BuildContext? dialogContext;
          
          if (mounted) {
            showDialog(
              context: currentContext,
              barrierDismissible: false,
              builder: (BuildContext context) {
                dialogContext = context;
                return const Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.green),
                        SizedBox(width: 20),
                        Text("Chargement de l'établissement de bien-être..."),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          try {
            final url = Uri.parse('${getBaseUrl()}/api/wellness/$id');
            print('🌐 URL de l\'API wellness: $url');
            
            final response = await http.get(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception("Délai d'attente dépassé"),
            );
            
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            if (response.statusCode == 200 && mounted) {
              final dynamic data = json.decode(response.body);
              
              // Adapter au format attendu par la page de détail
              final Map<String, dynamic> wellnessData;
              if (data is List && data.isNotEmpty) {
                wellnessData = data[0];
              } else if (data is Map<String, dynamic>) {
                wellnessData = data;
              } else {
                throw Exception("Format de données invalide");
              }
              
              // Rediriger vers un écran spécifique pour les lieux bien-être
              // Pour l'instant, on utilise le même écran que les lieux de loisir
              Navigator.push(
                currentContext,
                MaterialPageRoute(
                  builder: (context) => WellnessProducerScreen(producerId: id),
                ),
              );
            } else {
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            print('❌ Erreur lors du chargement du lieu bien-être: $e');
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            if (mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(
                  content: Text("Erreur: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        
        case 'user':
          print('👤 Navigation vers le profil utilisateur');
          // Only navigate if the widget is still mounted
          if (mounted) {
            Navigator.push(
              currentContext,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: id, viewMode: 'public'),
              ),
            );
          }
          break;
        
        default:
          print('⚠️ Type non reconnu: $type');
          if (mounted) {
            // Essayer de résoudre par l'API unifiée
            BuildContext? dialogContext;
            
            showDialog(
              context: currentContext,
              barrierDismissible: false,
              builder: (BuildContext context) {
                dialogContext = context;
                return const Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Chargement des informations..."),
                      ],
                    ),
                  ),
                );
              },
            );
            
            try {
              final url = Uri.parse('${getBaseUrl()}/api/unified/$id');
              final response = await http.get(url).timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception("Délai d'attente dépassé"),
              );
              
              if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                Navigator.of(dialogContext!).pop();
              }
              
              if (response.statusCode == 200 && mounted) {
                final dynamic data = json.decode(response.body);
                String detectedType = data['type'] ?? 'unknown';
                
                // Appel récursif avec le type détecté
                if (detectedType != 'unknown') {
                  _navigateToDetails(id, detectedType);
                  return;
                }
              }
              
              // Si on arrive ici, c'est qu'on n'a pas pu détecter le type
              throw Exception("Type non reconnu et impossible à détecter");
            } catch (e) {
              if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                Navigator.of(dialogContext!).pop();
              }
              
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(
                content: Text("Type non reconnu: $type"),
                backgroundColor: Colors.orange,
              ),
            );
            }
          }
      }
    } catch (e) {
      print('❌ Erreur de navigation: $e');
      // Only show error if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text("Erreur de navigation: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pull to refresh
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Barre de recherche stylisée
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (text) {
                          setState(() {
                            _query = text;
                          });
                          // Optionnel: Déclencher la recherche automatiquement après un délai
                          // _debounceSearch(text);
                        },
                        onSubmitted: (text) {
                          _performSearch(text);
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher restaurants, activités...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _searchAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_searchAnimationController.value * 0.1),
                          child: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = "";
                                _searchResults = [];
                                _errorMessage = "";
                              });
                            },
                          ),
                        );
                      }
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple, Colors.purple.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        // Call _performSearch with the current text from the controller
                        onPressed: () => _performSearch(_searchController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenu principal avec résultats de recherche ou sections tendances
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isNotEmpty
                  ? _buildSearchResults()
                  : _errorMessage.isNotEmpty && _query.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshAllSections,
                        child: _buildTrendingSections(),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final String type = item['type'] ?? 'unknown';
        return _buildResultCard(
          id: item['id'] ?? '',
          type: type,
          title: item['name'] ?? 'Nom non spécifié',
          subtitle: item['address'] ?? item['lieu'] ?? 'Adresse non spécifiée',
          imageUrl: item['image'] ?? '',
          rating: item['rating'] ?? 0.0,
          category: item['category'] ?? 'Non catégorisé',
        );
      },
    );
  }

  Widget _buildTrendingSections() {
    // Liste des sections à construire avec leurs données respectives
    final sections = [
      {
        'title': 'Tendances du moment',
        'data': _trendingNow,
        'isLoading': _isLoadingTrending,
        'error': _trendingError,
        'color': Colors.purple.shade800,
        'icon': Icons.trending_up,
      },
      {
        'title': 'Le plus populaire autour de vous',
        'data': _popularNearby,
        'isLoading': _isLoadingNearby,
        'error': _nearbyError,
        'color': Colors.blue.shade700,
        'icon': Icons.place,
      },
      {
        'title': 'Les meilleures expériences de vos proches',
        'data': _bestFriendsExperiences,
        'isLoading': _isLoadingFriends,
        'error': _friendsError,
        'color': Colors.teal.shade700,
        'icon': Icons.people,
      },
      {
        'title': 'Tenter quelque chose d\'improbable, novateur',
        'data': _innovative,
        'isLoading': _isLoadingInnovative,
        'error': _innovativeError,
        'color': Colors.amber.shade800,
        'icon': Icons.lightbulb,
      },
      {
        'title': 'Laissez-vous surprendre',
        'data': _surprise,
        'isLoading': _isLoadingSurprise,
        'error': _surpriseError,
        'color': Colors.pink.shade700,
        'icon': Icons.auto_awesome,
      },
    ];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Construire dynamiquement toutes les sections
          ...sections.map((section) {
            final title = section['title'] as String;
            final data = section['data'] as List;
            final isLoading = section['isLoading'] as bool;
            final error = section['error'] as String;
            final color = section['color'] as Color;
            final icon = section['icon'] as IconData;
            
            return _buildTrendingSection(
              title, 
              data, 
              color,
              icon,
              isLoading: isLoading,
              errorMessage: error,
            );
          }).toList(),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(
    String title, 
    List<dynamic> items, 
    Color accentColor, 
    IconData icon, {
    bool isLoading = false,
    String errorMessage = "",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        
        // En-tête de section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                _showSectionDetails(title, items, accentColor, icon);
              },
              child: Text(
                'Voir plus',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Contenu de la section (charge, erreur ou données)
        SizedBox(
          height: 190,
          child: isLoading
              ? _buildSectionLoading(accentColor)
              : errorMessage.isNotEmpty
                  ? _buildSectionError(errorMessage, accentColor)
                  : items.isEmpty
                      ? _buildEmptySection(accentColor)
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildItemCard(
                              id: item['id'] ?? '',
                              type: item['type'] ?? 'unknown',
                              name: item['name'] ?? 'Sans nom',
                              imageUrl: item['image'] ?? '',
                              rating: item['rating'] is double ? item['rating'] : 0.0,
                              category: item['category'] ?? 'Non catégorisé',
                              accentColor: accentColor,
                            );
                          },
                        ),
        ),
      ],
    );
  }
  // Widget pour afficher un loader pendant le chargement des sections
  Widget _buildSectionLoading(Color accentColor) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3, // Nombre de skeletons à afficher
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image skeleton avec effet de pulse
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor.withOpacity(value * 0.8)),
                      strokeWidth: 2,
                    ),
                        ),
                      );
                    },
                    onEnd: () {
                      // Redémarrer l'animation
                      setState(() {});
                    },
                  ),
                ),
              ),
              
              // Texte skeleton avec effet de pulse
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.3, end: 0.8),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, double value, child) {
                        return Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                            color: Colors.grey[300]!.withOpacity(value),
                        borderRadius: BorderRadius.circular(4),
                      ),
                        );
                      },
                      onEnd: () {
                        // Redémarrer l'animation
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.3, end: 0.8),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, double value, child) {
                        return Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                            color: Colors.grey[300]!.withOpacity(value),
                        borderRadius: BorderRadius.circular(4),
                      ),
                        );
                      },
                      onEnd: () {
                        // Redémarrer l'animation avec un léger décalage
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) setState(() {});
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.3, end: 0.8),
                          duration: const Duration(milliseconds: 800),
                          builder: (context, double value, child) {
                            return Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                                color: Colors.grey[300]!.withOpacity(value),
                            borderRadius: BorderRadius.circular(4),
                          ),
                            );
                          },
                          onEnd: () {
                            // Redémarrer l'animation avec un léger décalage
                            Future.delayed(const Duration(milliseconds: 200), () {
                              if (mounted) setState(() {});
                            });
                          },
                        ),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.3, end: 0.8),
                          duration: const Duration(milliseconds: 800),
                          builder: (context, double value, child) {
                            return Container(
                          height: 12,
                          width: 40,
                          decoration: BoxDecoration(
                                color: Colors.grey[300]!.withOpacity(value),
                            borderRadius: BorderRadius.circular(4),
                          ),
                            );
                          },
                          onEnd: () {
                            // Redémarrer l'animation avec un léger décalage
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted) setState(() {});
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Widget pour afficher un message d'erreur
  Widget _buildSectionError(String errorMessage, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: accentColor, size: 40),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(color: accentColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _refreshAllSections,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget pour afficher un message quand il n'y a pas de données
  Widget _buildEmptySection(Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: accentColor.withOpacity(0.5), size: 40),
            const SizedBox(height: 8),
            Text(
              'Aucun résultat trouvé',
              style: TextStyle(color: accentColor.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // Méthode pour afficher les détails d'une section en plein écran
  void _showSectionDetails(String title, List<dynamic> items, Color accentColor, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Barre de titre avec l'icône
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: accentColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Liste d'éléments
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun élément trouvé',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _buildDetailedItemCard(
                                id: item['id'] ?? '',
                                type: item['type'] ?? 'unknown',
                                name: item['name'] ?? 'Sans nom',
                                imageUrl: item['image'] ?? '',
                                rating: item['rating'] is double ? item['rating'] : 0.0,
                                category: item['category'] ?? 'Non catégorisé',
                                accentColor: accentColor,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Widget de carte d'élément détaillé pour la vue modale
  Widget _buildDetailedItemCard({
    required String id,
    required String type,
    required String name,
    required String imageUrl,
    required double rating,
    required String category,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _navigateToDetails(id, type);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec badge du type
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      height: 120,
                      child: Center(
                        child: Icon(
                          _getIconForType(type),
                          color: accentColor.withOpacity(0.6),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Badge de type
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getColorForType(type).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getTypeLabel(type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Informations
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildItemCard({
    required String id,
    required String type,
    required String name,
    required String imageUrl,
    required double rating,
    required String category,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDetails(id, type),
      child: Hero(
        tag: 'item_$id',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 180,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image avec badge du type et overlay pour contraste
              Stack(
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                      height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        _getIconForType(type),
                        color: accentColor.withOpacity(0.5),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              
                  // Overlay gradient pour assurer la lisibilité du texte
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                            stops: const [0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Badge de type dans le coin supérieur droit
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getColorForType(type).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconForType(type),
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getTypeLabel(type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Badge de rating dans le coin inférieur droit
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Contenu avec animation au survol
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom avec taille adaptative
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Catégorie avec icône
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                      category,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Note avec étoiles graphiques
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          if (index < rating.floor()) {
                            // Étoile complète
                            return Icon(Icons.star, color: Colors.amber, size: 14);
                          } else if (index < rating.ceil() && rating.floor() != rating.ceil()) {
                            // Demi-étoile
                            return Icon(Icons.star_half, color: Colors.amber, size: 14);
                          } else {
                            // Étoile vide
                            return Icon(Icons.star_border, color: Colors.amber, size: 14);
                          }
                        }),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Bouton voir plus
                        Container(
                      width: double.infinity,
                      height: 24,
                          decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                          ),
                      child: Center(
                          child: Text(
                          'Découvrir',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            fontSize: 11,
                            ),
                          ),
                        ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String id,
    required String type,
    required String title,
    required String subtitle,
    required String imageUrl,
    dynamic rating,
    dynamic category,
    String? description,
  }) {
    Color accentColor = _getColorForType(type);
    
    // Ensure rating is a double or null
    double? ratingValue;
    if (rating != null) {
      if (rating is double) {
        ratingValue = rating;
      } else if (rating is String && (rating as String).isNotEmpty) {
        try {
          ratingValue = double.parse(rating);
        } catch (e) {
          print('Erreur de conversion de rating: $rating');
        }
      } else if (rating is int) {
        ratingValue = rating.toDouble();
      }
    }
    
    // Ensure category is a string
    String categoryText = 'Non catégorisé';
    if (category != null) {
      if (category is String) {
        categoryText = category;
      } else {
        try {
          categoryText = category.toString();
        } catch (e) {
          print('Erreur de conversion de category: $category');
        }
      }
    }
    
    return GestureDetector(
      onTap: () => _navigateToDetails(id, type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec badge de type
            Stack(
          children: [
            // Image
                Hero(
                  tag: 'result_$id',
                  child: ClipRRect(
              borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl.isNotEmpty 
                  ? imageUrl 
                  : 'https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80',
                      width: 120,
                      height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                        width: 120,
                        height: 120,
                        child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                        width: 120,
                        height: 120,
                  child: Center(
                    child: Icon(
                      _getIconForType(type),
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
                ),
                
                // Badge de type dans le coin supérieur gauche
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getIconForType(type),
                          color: Colors.white,
                          size: 12,
                        ),
                          const SizedBox(width: 4),
                          Text(
                          _getTypeLabel(type),
                            style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Badge de rating dans le coin inférieur droit
                if (ratingValue != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            ratingValue.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
            
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    // Titre avec badge de vérifié si pertinent
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Expanded(
                      child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ratingValue != null && ratingValue >= 4.5)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 16,
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Adresse avec icône
                    Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Catégorie avec icône
                    if (categoryText.isNotEmpty && categoryText != 'Non catégorisé')
                      Row(
                                      children: [
                          Icon(
                            Icons.category,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              categoryText,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                                        ),
                                        
                                        const SizedBox(height: 4),
                                        
                    // Description si disponible
                    if (description != null && description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: Text(
                          description,
                                          style: TextStyle(
                            color: Colors.grey[700],
                                            fontSize: 12,
                                          ),
                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                        ),
                                        ),
                                        
                    // Note avec étoiles
                    if (ratingValue != null)
                                        Row(
                                          children: [
                          ...List.generate(5, (index) {
                            if (index < ratingValue!.floor()) {
                              // Étoile complète
                              return Icon(Icons.star, color: Colors.amber, size: 14);
                            } else if (index < ratingValue!.ceil() && ratingValue!.floor() != ratingValue!.ceil()) {
                              // Demi-étoile
                              return Icon(Icons.star_half, color: Colors.amber, size: 14);
                            } else {
                              // Étoile vide
                              return Icon(Icons.star_border, color: Colors.amber, size: 14);
                            }
                          }),
                          const SizedBox(width: 4),
                                                Text(
                            ratingValue!.toStringAsFixed(1),
                                                  style: const TextStyle(
                              fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                              color: Colors.amber,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                    // Bouton d'action
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                                              decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _navigateToDetails(id, type),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Voir détails',
                                                style: TextStyle(
                                      fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                      color: accentColor,
                                                ),
                                              ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 10,
                                    color: accentColor,
                                            ),
                                          ],
                                        ),
                                    ),
                                  ),
                              ),
                            ),
                          ),
                  ],
                ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'leisureProducer':
        return Icons.local_activity;
      case 'event':
        return Icons.event;
      case 'user':
        return Icons.person;
      case 'wellnessProducer':
        return Icons.spa;
      default:
        return Icons.place;
    }
  }
  
  Color _getColorForType(String type) {
    switch (type) {
      case 'restaurant':
        return Color(0xFFFF7043); // Orange profond
      case 'leisureProducer':
        return Color(0xFF7E57C2); // Violet
      case 'event':
        return Color(0xFF26A69A); // Vert teal
      case 'user':
        return Color(0xFF42A5F5); // Bleu
      case 'wellnessProducer':
        return Color(0xFFEC407A); // Rose
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'restaurant':
        return 'Restaurant';
      case 'leisureProducer':
        return 'Loisir';
      case 'event':
        return 'Événement';
      case 'user':
        return 'Utilisateur';
      case 'wellnessProducer':
        return 'Bien-être';
      default:
        return type;
    }
  }

  /// Extrait l'image d'un restaurant en priorisant le tableau photos
  String _getRestaurantImage(dynamic item) {
    String image = '';
    
    // Priorité 1: Tableau photos - prendre la première photo
    if (item['photos'] != null && item['photos'] is List && (item['photos'] as List).isNotEmpty) {
      var firstPhoto = (item['photos'] as List)[0];
      if (firstPhoto != null && firstPhoto.toString().trim().isNotEmpty) {
        String photoUrl = firstPhoto.toString().trim();
        if (photoUrl != "N/A" && photoUrl != "null" && photoUrl != "undefined" && photoUrl != "none") {
          image = _formatImageUrl(photoUrl);
          print('🍽️ Image de restaurant trouvée (photos[0]): $image');
          return image;
        }
      }
    }
    
    // Priorité 2: Champ photo unique
    if (item['photo'] != null && item['photo'].toString().trim().isNotEmpty) {
      String photoUrl = item['photo'].toString().trim();
      if (photoUrl != "N/A" && photoUrl != "null" && photoUrl != "undefined" && photoUrl != "none") {
        image = _formatImageUrl(photoUrl);
        print('🍽️ Image de restaurant trouvée (photo): $image');
        return image;
      }
    }
    
    // Priorité 3: Autres champs d'image
    final imageFields = ['image', 'photo_url', 'image_url', 'thumbnail', 'cover'];
    for (final field in imageFields) {
      if (item[field] != null && item[field].toString().trim().isNotEmpty) {
        String photoUrl = item[field].toString().trim();
        if (photoUrl != "N/A" && photoUrl != "null" && photoUrl != "undefined" && photoUrl != "none") {
          image = _formatImageUrl(photoUrl);
          print('🍽️ Image de restaurant trouvée ($field): $image');
          return image;
        }
      }
    }
    
    print('⚠️ Aucune image trouvée pour le restaurant: ${item['name'] ?? 'Sans nom'}');
    return '';
  }
  
  /// Obtient l'image standard pour tous les types de producteurs
  String _getStandardImage(dynamic item, String type, String id) {
    List<String> possibleImages = [];
    final imageFields = [
      'photo', 'photos', 'image', 'images', 'photo_url', 'image_url', 
      'thumbnail', 'cover', 'pictures', 'media'
    ];
    
    // Collecter toutes les images possibles
    for (final field in imageFields) {
      if (item[field] != null) {
        if (item[field] is String && item[field].toString().trim().isNotEmpty) {
          possibleImages.add(item[field].toString().trim());
        } else if (item[field] is List && (item[field] as List).isNotEmpty) {
          for (var img in item[field]) {
            if (img != null && img.toString().trim().isNotEmpty) {
              possibleImages.add(img.toString().trim());
            }
          }
        } else if (item[field] is Map && item[field]['url'] != null) {
          possibleImages.add(item[field]['url'].toString().trim());
        }
      }
    }
    
    // Trouver la première image valide
    for (String img in possibleImages) {
      if (img.isEmpty) continue;
      if (img == "N/A" || img == "null" || img == "undefined" || img == "none") continue;
      
      return _formatImageUrl(img);
    }
    
    // Images par défaut si aucune image trouvée
    switch (type) {
      case 'restaurant':
        final restaurantImages = [
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=500&q=80',
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80',
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=500&q=80',
        ];
        return restaurantImages[id.isEmpty ? 0 : id.hashCode % restaurantImages.length];
      case 'leisureProducer':
        final leisureImages = [
          'https://images.unsplash.com/photo-1503095396549-807759245b35?w=500&q=80',
          'https://images.unsplash.com/photo-1551632811-561732d1e306?w=500&q=80',
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
        ];
        return leisureImages[id.isEmpty ? 0 : id.hashCode % leisureImages.length];
      case 'event':
        final eventImages = [
          'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=500&q=80',
          'https://images.unsplash.com/photo-1472653431158-6364773b2fba?w=500&q=80',
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80',
        ];
        return eventImages[id.isEmpty ? 0 : id.hashCode % eventImages.length];
      case 'wellnessProducer':
        final wellnessImages = [
          'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=500&q=80',
          'https://images.unsplash.com/photo-1519823551278-64ac92734fb1?w=500&q=80',
          'https://images.unsplash.com/photo-1596178060671-7a58b8f962be?w=500&q=80',
        ];
        return wellnessImages[id.isEmpty ? 0 : id.hashCode % wellnessImages.length];
      default:
        return 'https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80';
    }
  }
  
  /// Format correctement une URL d'image selon son format
  String _formatImageUrl(String img) {
    if (img.startsWith('http')) {
      // URL complète
      return img;
    } else if (img.startsWith('/')) {
      // URL relative avec slash
      return '${getBaseUrl()}$img';
    } else if (img.startsWith('uploads/') || img.startsWith('images/')) {
      // Chemin relatif sans slash initial
      return '${getBaseUrl()}/$img';
    } else if (!img.contains('/') && !img.contains('\\')) {
      // Juste un nom de fichier
      return '${getBaseUrl()}/uploads/$img';
    }
    return img; // Retourner tel quel en dernier recours
  }
}