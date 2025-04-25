import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/map_service.dart';
import '../models/place.dart';
import '../providers/user_provider.dart';
import '../widgets/filter_chips.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../utils/location_helper.dart';
import '../widgets/place_info_card.dart';
import '../utils/map_colors.dart' as mapcolors;
import 'package:permission_handler/permission_handler.dart';
import '../models/map_selector.dart' as map_selector;
import '../widgets/map_selector.dart' as widget_selector;
import 'dart:ui' as ui;
import '../models/map_filter.dart' as filter_models;
import '../widgets/maps/adaptive_map_widget.dart';
import 'map_restaurant_screen.dart' as restaurant_map;
import 'map_wellness_screen.dart' as wellness_map;
import 'map_friends_screen.dart' as friends_map;
import 'package:location/location.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/constants.dart' as constants;
import '../main.dart';
import '../widgets/filter_toggle_card.dart';
import '../widgets/leisure_bookmark_widget.dart';
import 'followings_interests_list.dart' as interests_list;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'eventLeisure_screen.dart'; // Nouvelle importation pour EventLeisureScreen
import '../utils.dart'; // Add import for getImageProvider function
import '../widgets/choiceInterestUsers_popup.dart'; // CORRECTION: Chemin vers le widget

class MapLeisureScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final double? initialZoom;

  const MapLeisureScreen({Key? key, this.initialPosition, this.initialZoom}) : super(key: key);

  @override
  State<MapLeisureScreen> createState() => _MapLeisureScreenState();
}

class _MapLeisureScreenState extends State<MapLeisureScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Google Map controller
  final Completer<GoogleMapController> _controller = Completer();
  
  // Location properties
  LatLng _initialPosition = const LatLng(48.856614, 2.3522219); // Position par défaut (Paris)
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  bool _isLoading = false;
  Place? _selectedPlace;
  
  // Filter properties
  String _searchKeyword = '';
  bool _showFilterPanel = false;
  int _selectedFilterIndex = 1; // 0: Lieux, 1: Événements // DEFAULT TO EVENTS
  int _selectedTabIndex = 0; // 0: Général, 1: Détails
  
  // General filters
  double _selectedRadius = 1000;
  double _minRating = 0;
  List<String> _selectedCategories = [];
  List<String> _selectedEmotions = [];
  RangeValues _priceRange = const RangeValues(0, 500);
  
  // Place-specific filters
  List<String> _selectedAccessibility = [];
  double _minMiseEnScene = 0;
  double _minJeuActeurs = 0;
  double _minScenario = 0;
  String? _selectedProducerType;
  
  // Event-specific filters
  DateTime? _dateStart;
  DateTime? _dateEnd;
  String? _timeStart;
  String? _timeEnd;
  double _minAmbiance = 0;
  double _minOrganisation = 0;
  double _minProgrammation = 0;
  String? _selectedEventType;
  bool _familyFriendly = false;
  List<String> _selectedLineup = [];
  List<int> _selectedDays = [];
  String _sortBy = 'date'; // 'date', 'popularity', 'rating'
  
  // Additional data
  List<String> _availableLineup = [];
  List<String> _availableEventTypes = [];
  List<String> _availableProducerTypes = [];
  bool _isLoadingCategories = false;
  bool _isLoadingEmotions = false;
  
  // Tab controller for filter section
  late TabController _tabController;
  
  // Lists for filter options
  final List<String> _availableCategories = [
    'Théâtre', 'Musée', 'Galerie', 'Cinéma', 'Salle de concert', 
    'Exposition', 'Festival', 'Spectacle'
  ];
  
  final List<String> _availableEmotions = [
    'Joie', 'Surprise', 'Nostalgie', 'Fascination', 'Inspiration',
    'Amusement', 'Détente', 'Excitation'
  ];
  
  final List<String> _availableAccessibility = [
    'Accès handicapé', 'Parking à proximité', 'Transports en commun',
    'Audioguide', 'Visites guidées', 'Espaces familiaux'
  ];
  
  final List<String> _producerTypes = [
    'Tous', 'Théâtre', 'Musée', 'Galerie d\'art', 'Cinéma', 'Salle de spectacle'
  ];
  
  final List<String> _eventTypes = [
    'Tous', 'Exposition temporaire', 'Concert', 'Pièce de théâtre', 
    'Festival', 'Atelier', 'Visite guidée'
  ];
  
  final List<String> _daysOfWeek = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  
  final List<String> _sortOptions = [
    'Date', 'Popularité', 'Note'
  ];
  
  final MapService _mapService = MapService();
  List<Map<String, dynamic>> _placesData = [];
  
  // Variables manquantes pour la compatibilité avec MapScreen
  bool _isUsingLiveLocation = false;
  String? _errorMessage;
  
  // Ajout des variables manquantes
  bool _isLoadingDetails = false;
  String? _loadError;
  
  // Critères dynamiques d'évaluation
  Map<String, dynamic> _currentCriteria = {};
  Map<String, double> _selectedCriteriaValues = {};
  bool _isLoadingCriteria = false;
  
  // Icônes pour les marqueurs
  late BitmapDescriptor _defaultIcon;
  late BitmapDescriptor _musicIcon;
  late BitmapDescriptor _theaterIcon;
  late BitmapDescriptor _museumIcon;
  late BitmapDescriptor _cinemaIcon;
  
  // Nouvelles variables pour les signets et les followings intéressés
  List<Map<String, dynamic>> _bookmarkedVenues = [];
  bool _isLoadingBookmarks = false;
  Set<String> _bookmarkedVenueIds = {};
  
  // État pour afficher les détails de followings intéressés
  bool _showFollowingsPanel = false;
  Map<String, dynamic> _selectedVenueFollowingsData = {
    'interests': [],
    'choices': [],
    'followings': [],
  };
  
  // Ajouter un flag pour indiquer si on affiche les lieux ou les signets
  bool _showBookmarksView = false;
  
  // Keep alive override
  @override
  bool get wantKeepAlive => true;
  
  // Configurations des cartes disponibles
  final List<map_selector.MapConfig> mapConfigs = [
    map_selector.MapConfig(
      icon: 'restaurant',  // Paramètre obligatoire
      label: 'Restaurant',
      color: mapcolors.MapColors.restaurantPrimary,
      mapType: map_selector.MapType.restaurant,
      route: '/map/restaurant',
      imageIcon: 'assets/icons/restaurant_map.png',
    ),
    map_selector.MapConfig(
      icon: 'leisure',  // Paramètre obligatoire
      label: 'Loisir',
      color: mapcolors.MapColors.leisurePrimary,
      mapType: map_selector.MapType.leisure,
      route: '/map/leisure',
      imageIcon: 'assets/icons/leisure_map.png',
    ),
    map_selector.MapConfig(
      icon: 'wellness',  // Paramètre obligatoire
      label: 'Bien-être',
      color: mapcolors.MapColors.wellnessPrimary,
      mapType: map_selector.MapType.wellness,
      route: '/map/wellness',
      imageIcon: 'assets/icons/wellness_map.png',
    ),
    map_selector.MapConfig(
      icon: 'friends',  // Paramètre obligatoire
      label: 'Amis',
      color: mapcolors.MapColors.friendsPrimary,
      mapType: map_selector.MapType.friends,
      route: '/map/friends',
      imageIcon: 'assets/icons/friends_map.png',
    ),
  ];
  
  // New variable for filter sections
  List<filter_models.FilterSection> _filterSections = [];
  
  // Constantes pour les options de filtre rapide de date
  final List<String> _quickDateOptions = [
    'Aujourd\'hui',
    'Demain',
    'Ce week-end',
    'Cette semaine',
    'Ce mois-ci',
    'Personnalisé'
  ];
  
  // Option actuellement sélectionnée dans les filtres rapides de date
  String _selectedQuickDateOption = 'Personnalisé';
  
  @override
  void initState() {
    super.initState();
    // Utiliser la position initiale si fournie
    if (widget.initialPosition != null) {
      _initialPosition = widget.initialPosition!;
    }
    
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentLocation();
    
    // Charger les données des filtres
    _loadCategoriesAndEmotions();
    
    // Initialiser les sections de filtres
    _initializeFilterSections();
    
    // Initialiser les icônes (sans utiliser .then car ce ne sont pas des Futures)
    _defaultIcon = BitmapDescriptor.defaultMarker;
    _musicIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    _theaterIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    _museumIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    _cinemaIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    
    // Charger les signets
    _loadUserBookmarks();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _getCurrentLocation() async {
    if (!mounted) return; // Vérifier si le widget est toujours monté avant de continuer
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Position position = await LocationHelper.getCurrentLocation();
      if (!mounted) return; // Vérifier à nouveau après l'opération asynchrone
      
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      
      _fetchLeisurePlaces();
    } catch (error) {
      print('Erreur lors de la récupération de la position: $error');
      if (!mounted) return; // Vérifier à nouveau avant le setState final
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _loadCategoriesAndEmotions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingCategories = true;
      _isLoadingEmotions = true;
    });
    
    try {
      // Charger les catégories disponibles
      final categoriesResponse = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/leisure/categories'),
      );
      
      if (!mounted) return;
      
      if (categoriesResponse.statusCode == 200) {
        final List<dynamic> categoriesData = json.decode(categoriesResponse.body);
        if (categoriesData.isNotEmpty) {
          setState(() {
            _availableCategories.clear();
            _availableCategories.addAll(categoriesData.map((cat) => cat.toString()));
          });
        }
      }
      
      // Charger les émotions disponibles
      final emotionsResponse = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/leisure/emotions'),
      );
      
      if (!mounted) return;
      
      if (emotionsResponse.statusCode == 200) {
        final List<dynamic> emotionsData = json.decode(emotionsResponse.body);
        if (emotionsData.isNotEmpty) {
          setState(() {
            _availableEmotions.clear();
            _availableEmotions.addAll(emotionsData.map((emotion) => emotion.toString()));
          });
        }
      }
      
      // Charger d'autres données disponibles (types d'événements, lineup, etc.)
      _loadEventTypes();
      
    } catch (error) {
      print('Erreur lors du chargement des catégories et émotions: $error');
    } finally {
      if (!mounted) return;
      
      setState(() {
        _isLoadingCategories = false;
        _isLoadingEmotions = false;
      });
    }
  }
  
  void _loadEventTypes() async {
    if (!mounted) return;
    
    try {
      // Exemples de types d'événements 
      setState(() {
        _availableEventTypes = [
          'Concert', 'Festival', 'Exposition', 'Théâtre', 'Cinéma', 
          'Atelier', 'Visite guidée', 'Conférence', 'Spectacle'
        ];
        
        _availableProducerTypes = [
          'Salle de concert', 'Galerie d\'art', 'Théâtre', 'Musée', 
          'Cinéma', 'Centre culturel', 'Espace d\'exposition'
        ];
        
        // Exemple d'artistes/lineup
        _availableLineup = [
          'DJ Snake', 'Angèle', 'Stromae', 'Orelsan', 'Clara Luciani',
          'Grand Corps Malade', 'Pomme', 'Phoenix', 'Justice', 'Air'
        ];
      });
    } catch (error) {
      print('Erreur lors du chargement des types d\'événements: $error');
    }
  }
  
  Future<void> _fetchLeisurePlaces() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Construire les paramètres de la requête
      final Map<String, dynamic> params = {
        'latitude': _currentLocation?.latitude ?? _initialPosition.latitude,
        'longitude': _currentLocation?.longitude ?? _initialPosition.longitude,
        'radius': _selectedRadius,
      };
      
      // --- Common Filters ---
      if (_searchKeyword.isNotEmpty) {
        params['keyword'] = _searchKeyword;
      }
      
      if (_minRating > 0) {
        params['minRating'] = _minRating.toString();
      }
      
      if (_selectedCategories.isNotEmpty) {
        params['categories'] = _selectedCategories.join(',');
      }
      
      // Price filter (common to both, applied differently in backend)
      if (_priceRange.start > 0 || _priceRange.end < 500) {
        if (_priceRange.start > 0) params['minPrice'] = _priceRange.start.toInt().toString();
        if (_priceRange.end < 500) params['maxPrice'] = _priceRange.end.toInt().toString();
      }
      
      // --- Endpoint specific logic ---
      List<dynamic> placesData = [];
      String endpointPath = '';
      
      if (_selectedFilterIndex == 1) { // ==== Fetching EVENTS ==== 
        endpointPath = '/api/leisure/events'; // Use the main events endpoint
        print('🔍 Fetching EVENTS...');
        
        // Event-specific filters
        if (_selectedEmotions.isNotEmpty) {
          params['emotions'] = _selectedEmotions.join(',');
        }
        
        // *** Appel API pour les événements ***
        // Utilisation directe de http.get car MapService.getLeisureVenues n'est pas adapté
        final uri = Uri.parse('${constants.getBaseUrl()}$endpointPath').replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())));
        print('📞 Calling Event API: ${uri.toString()}');
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final decodedData = json.decode(response.body);
          // La réponse peut être une liste directe ou un objet avec une clé 'events' (si debug)
          if (decodedData is List) {
            placesData = decodedData;
          } else if (decodedData is Map && decodedData.containsKey('events')) {
            placesData = decodedData['events'] as List;
            print('🐞 Debug info received: ${decodedData['debug']}');
          }
        } else {
          throw Exception('Failed to load events: ${response.statusCode} ${response.body}');
        }
      } else { // ==== Fetching VENUES ==== 
        endpointPath = '/api/leisure/venues';
        print('🏢 Fetching VENUES...');
        
        // Venue-specific filters (supported by backend /venues)
        if (_selectedProducerType != null && _selectedProducerType != 'Tous') {
          params['producerType'] = _selectedProducerType;
        }
        if (_selectedAccessibility.isNotEmpty) {
          params['accessibility'] = _selectedAccessibility.join(',');
        }
        // Note: sortBy for venues might differ, backend defaults to note
        
        // *** Appel API pour les lieux via MapService ***
        print('📞 Calling Venue API via MapService with params: ${params.toString()}');
        // Assumes getLeisureVenues targets the /venues endpoint correctly
        placesData = await _mapService.getLeisureVenues(params);
      }
      
      if (placesData is List && placesData.isNotEmpty) {
        // Vérifier si les données contiennent bien des coordonnées
        int validLocationCount = placesData.where((place) {
          // Vérifier les différentes possibilités de coordonnées
          return _hasValidCoordinates(place);
        }).length;
        
        print('✓ ${placesData.length} lieux/événements trouvés, dont $validLocationCount avec des coordonnées valides');
        
        // Mettre à jour la liste des lieux
        setState(() {
          _placesData = List<Map<String, dynamic>>.from(placesData);
          _isLoading = false;
        });
        
        // Ajouter les marqueurs sur la carte
        _addLeisureMarkers(_placesData);
        
        // Afficher un message s'il y a des lieux sans coordonnées
        if (validLocationCount == 0 && placesData.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aucun lieu avec des coordonnées valides trouvé'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (validLocationCount < placesData.length) {
          int missingCount = placesData.length - validLocationCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$missingCount lieux sans coordonnées ont été ignorés'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Aucun résultat
        setState(() {
          _placesData = [];
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucun lieu trouvé avec ces critères'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (error) {
      print('❌ Erreur lors de la récupération des lieux: $error');
      setState(() {
        _errorMessage = 'Erreur lors de la récupération des données: $error';
        _isLoading = false;
      });
    }
  }
  
  // Méthode pour vérifier si un lieu/événement a des coordonnées valides
  bool _hasValidCoordinates(dynamic place) {
    if (place == null) return false;
    
    // Format direct latitude/longitude
    if (place['latitude'] != null && place['longitude'] != null) {
      double? lat = double.tryParse(place['latitude'].toString());
      double? lng = double.tryParse(place['longitude'].toString());
      if (lat != null && lng != null && lat != 0 && lng != 0) return true;
    }
    
    // Format location
    if (place['location'] != null) {
      var location = place['location'];
      if (location is Map) {
        if (location['lat'] != null && location['lng'] != null) return true;
        if (location['latitude'] != null && location['longitude'] != null) return true;
      }
    }
    
    // Format coordinates
    if (place['coordinates'] != null) {
      var coordinates = place['coordinates'];
      if (coordinates is List && coordinates.length == 2) return true;
    }
    
    // Format GeoJSON
    if (place['gps_coordinates'] != null && 
        place['gps_coordinates'] is Map && 
        place['gps_coordinates']['coordinates'] is List && 
        place['gps_coordinates']['coordinates'].length >= 2) {
      return true;
    }
    
    // Format Google Maps API
    if (place['geometry'] != null && 
        place['geometry'] is Map && 
        place['geometry']['location'] is Map) {
      var location = place['geometry']['location'];
      if (location['lat'] != null && location['lng'] != null) return true;
    }
    
    // Vérifier le lieu associé
    if (place['lieu'] != null && place['lieu'] is Map) {
      var venue = place['lieu'];
      if (venue['latitude'] != null && venue['longitude'] != null) return true;
      if (venue['gps_coordinates'] != null && 
          venue['gps_coordinates'] is Map && 
          venue['gps_coordinates']['coordinates'] is List) {
        return true;
      }
    }
    
    return false;
  }
  
  void _addLeisureMarkers(List<dynamic> places) {
    if (places.isEmpty) {
      print('⚠️ Aucun lieu à afficher sur la carte');
      return;
    }

    print('📍 Ajout de ${places.length} marqueurs sur la carte');
    _markers.clear();
    
    // Compteur pour les marqueurs valides
    int validMarkers = 0;

    for (var place in places) {
      // Extraction des coordonnées géographiques avec gestion des différents formats
      double? lat, lng;
      
      // Vérifier si les coordonnées sont disponibles dans le format attendu
      if (place['latitude'] != null && place['longitude'] != null) {
        lat = double.tryParse(place['latitude'].toString());
        lng = double.tryParse(place['longitude'].toString());
      } 
      // Vérifier s'il existe une propriété location avec lat/lng
      else if (place['location'] != null) {
        var location = place['location'];
        if (location is Map) {
          if (location['lat'] != null && location['lng'] != null) {
            lat = double.tryParse(location['lat'].toString());
            lng = double.tryParse(location['lng'].toString());
          } else if (location['latitude'] != null && location['longitude'] != null) {
            lat = double.tryParse(location['latitude'].toString());
            lng = double.tryParse(location['longitude'].toString());
          }
        } else if (location is String && location.contains(',')) {
          var parts = location.split(',');
          if (parts.length == 2) {
            lat = double.tryParse(parts[0].trim());
            lng = double.tryParse(parts[1].trim());
          }
        }
      }
      // Vérifier s'il existe une propriété coordinates
      else if (place['coordinates'] != null) {
        var coordinates = place['coordinates'];
        if (coordinates is List && coordinates.length == 2) {
          lng = double.tryParse(coordinates[0].toString());
          lat = double.tryParse(coordinates[1].toString());
        } else if (coordinates is String && coordinates.contains(',')) {
          var parts = coordinates.split(',');
          if (parts.length == 2) {
            lat = double.tryParse(parts[0].trim());
            lng = double.tryParse(parts[1].trim());
          }
        }
      }
      // Vérifier s'il existe une propriété gps_coordinates au format GeoJSON
      else if (place['gps_coordinates'] != null && 
              place['gps_coordinates'] is Map && 
              place['gps_coordinates']['coordinates'] is List && 
              place['gps_coordinates']['coordinates'].length >= 2) {
        try {
          lng = double.tryParse(place['gps_coordinates']['coordinates'][0].toString());
          lat = double.tryParse(place['gps_coordinates']['coordinates'][1].toString());
        } catch (e) {
          print('❌ Erreur lors de l\'extraction des coordonnées GeoJSON: $e');
        }
      }
      // Vérifier s'il existe une propriété geometry comme dans l'API Google Maps
      else if (place['geometry'] != null && 
              place['geometry'] is Map && 
              place['geometry']['location'] is Map) {
        try {
          var location = place['geometry']['location'];
          lat = double.tryParse(location['lat'].toString());
          lng = double.tryParse(location['lng'].toString());
        } catch (e) {
          print('❌ Erreur lors de l\'extraction des coordonnées geometry: $e');
        }
      }
      // Vérifier s'il existe un lieu (place) associé à l'événement
      else if (place['lieu'] != null && place['lieu'] is Map) {
        try {
          var venue = place['lieu'];
          if (venue['latitude'] != null && venue['longitude'] != null) {
            lat = double.tryParse(venue['latitude'].toString());
            lng = double.tryParse(venue['longitude'].toString());
          } else if (venue['gps_coordinates'] != null && 
                    venue['gps_coordinates'] is Map && 
                    venue['gps_coordinates']['coordinates'] is List) {
            lng = double.tryParse(venue['gps_coordinates']['coordinates'][0].toString());
            lat = double.tryParse(venue['gps_coordinates']['coordinates'][1].toString());
          }
        } catch (e) {
          print('❌ Erreur lors de l\'extraction des coordonnées du lieu: $e');
        }
      }
      
      // Si on n'a pas trouvé de coordonnées valides, passer à l'élément suivant
      if (lat == null || lng == null || lat == 0 || lng == 0) {
        String itemName = place['name'] ?? place['title'] ?? place['nom'] ?? place['intitulé'] ?? 'null';
        print('⚠️ Coordonnées manquantes pour un lieu: $itemName');
        continue;
      }
      
      // Extraction du titre/nom avec gestion des différents formats
      String title = '';
      if (place['title'] != null && place['title'].toString().isNotEmpty) {
        title = place['title'].toString();
      } else if (place['intitulé'] != null && place['intitulé'].toString().isNotEmpty) {
        title = place['intitulé'].toString();
      } else if (place['nom'] != null && place['nom'].toString().isNotEmpty) {
        title = place['nom'].toString();
      } else if (place['name'] != null && place['name'].toString().isNotEmpty) {
        title = place['name'].toString();
      } else {
        title = 'Lieu culturel';  // Titre par défaut
      }
      
      // Extraction de l'adresse
      String address = '';
      if (place['adresse'] != null && place['adresse'].toString().isNotEmpty) {
        address = place['adresse'].toString();
      } else if (place['address'] != null && place['address'].toString().isNotEmpty) {
        address = place['address'].toString();
      } else if (place['lieu'] != null && place['lieu'] is Map) {
        if (place['lieu']['adresse'] != null) {
          address = place['lieu']['adresse'].toString();
        } else if (place['lieu']['address'] != null) {
          address = place['lieu']['address'].toString();
        }
      }
      
      // Extraction de la description
      String description = '';
      if (place['description'] != null && place['description'].toString().isNotEmpty) {
        description = place['description'].toString();
      }
      
      // Extraction de la catégorie
      String category = '';
      if (place['catégorie'] != null && place['catégorie'].toString().isNotEmpty) {
        category = place['catégorie'].toString();
      } else if (place['category'] != null && place['category'].toString().isNotEmpty) {
        category = place['category'].toString();
      } else {
        category = 'Loisir';  // Catégorie par défaut
      }
      
      // Extraction de l'URL de l'image
      String imageUrl = '';
      if (place['imageUrl'] != null && place['imageUrl'].toString().isNotEmpty) {
        imageUrl = place['imageUrl'].toString();
      } else if (place['image'] != null && place['image'].toString().isNotEmpty) {
        imageUrl = place['image'].toString();
      }
      
      // Extraction de la notation
      double rating = 0.0;
      if (place['rating'] != null) {
        rating = double.tryParse(place['rating'].toString()) ?? 0.0;
      }
      
      // Extraction des événements si disponibles
      List<dynamic>? events;
      if (place['events'] != null && place['events'] is List) {
        events = place['events'] as List<dynamic>;
      }
      
      // Création de l'objet Place
      final placeObject = Place(
        id: place['_id']?.toString() ?? place['id']?.toString() ?? '',
        name: title,
        description: description,
        address: address,
        latitude: lat,
        longitude: lng,
        category: category,
        image: imageUrl,
        rating: rating,
        rawData: Map<String, dynamic>.from(place),
        events: events?.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      
      // Vérifier si ce lieu est dans les signets
      final String venueId = placeObject.id;
      final bool isBookmarked = _bookmarkedVenueIds.contains(venueId);
      
      // Détermination de la couleur du marqueur en fonction de la catégorie et du signet
      BitmapDescriptor markerIcon = _defaultIcon;
      
      final categoryLower = category.toLowerCase();
      if (categoryLower.contains('concert') || categoryLower.contains('music') || categoryLower.contains('musique')) {
        markerIcon = _musicIcon;
      } else if (categoryLower.contains('théâtre') || categoryLower.contains('spectacle')) {
        markerIcon = _theaterIcon;
      } else if (categoryLower.contains('expo') || categoryLower.contains('musée')) {
        markerIcon = _museumIcon;
      } else if (categoryLower.contains('cinéma') || categoryLower.contains('film')) {
        markerIcon = _cinemaIcon;
      }
      
      // Création du marqueur
      final markerId = MarkerId('leisure_${placeObject.id}');
      
      // Infowindow avec badge signet si nécessaire
      final String snippet = isBookmarked 
          ? '📌 ${address.isNotEmpty ? address : category}' 
          : address.isNotEmpty ? address : category;

      print('📍 Ajout du marqueur ${title} (${lat}, ${lng}) - ${isBookmarked ? "Signet" : "Normal"}');
      
      final marker = Marker(
        markerId: markerId,
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: title,
          snippet: snippet,
        ),
        icon: markerIcon,
        onTap: () {
          setState(() {
            _selectedPlace = placeObject;
          });
        },
      );
      
      _markers.add(marker);
      validMarkers++;
    }
    
    setState(() {});
    print('📍 $validMarkers marqueurs ajoutés sur la carte');
  }
  
  // Obtenir la teinte pour BitmapDescriptor à partir d'une couleur
  double _getBitmapDescriptorHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }
  
  void _onLeisureMarkerTapped(Map<String, dynamic> place) {
    setState(() {
      _selectedPlace = Place.fromMap(place);
    });
  }
  
  void _resetFilters() {
    setState(() {
      _searchKeyword = '';
      _selectedRadius = 1000;
      _minRating = 0;
      _selectedCategories = [];
      _selectedEmotions = [];
      _priceRange = const RangeValues(0, 500);
      
      // Réinitialiser les filtres spécifiques aux lieux
      _selectedAccessibility = [];
      _minMiseEnScene = 0;
      _minJeuActeurs = 0;
      _minScenario = 0;
      _selectedProducerType = null;
      
      // Réinitialiser les filtres spécifiques aux événements
      _dateStart = null;
      _dateEnd = null;
      _timeStart = null;
      _timeEnd = null;
      _minAmbiance = 0;
      _minOrganisation = 0;
      _minProgrammation = 0;
      _selectedEventType = null;
      _familyFriendly = false;
      _selectedLineup = [];
      _selectedDays = [];
      _sortBy = 'date';
    });
    
    _fetchLeisurePlaces();
  }
  
  Widget _buildGeneralFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rayon de recherche: ${(_selectedRadius / 1000).toStringAsFixed(1)} km',
            style: AppStyles.filterTitle),
        Slider(
          value: _selectedRadius,
          min: 500,
          max: 10000,
          divisions: 19,
          onChanged: (value) {
            setState(() {
              _selectedRadius = value;
            });
          },
        ),
        
        Text('Note minimale: ${_minRating.toStringAsFixed(1)}',
            style: AppStyles.filterTitle),
        Slider(
          value: _minRating,
          min: 0,
          max: 5,
          divisions: 10,
          onChanged: (value) {
            setState(() {
              _minRating = value;
            });
          },
        ),
        
        Text('Fourchette de prix', style: AppStyles.filterTitle),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 500,
          divisions: 20,
          labels: RangeLabels(
            '${_priceRange.start.round()}€',
            '${_priceRange.end.round()}€',
          ),
          onChanged: (values) {
            setState(() {
              _priceRange = values;
            });
          },
        ),
        
        Text('Catégories', style: AppStyles.filterTitle),
        _isLoadingCategories 
          ? Center(child: CircularProgressIndicator()) 
          : FilterChips(
              options: _availableCategories,
              selectedOptions: _selectedCategories,
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedCategories = selected;
                  
                  // Charger les critères d'évaluation si une seule catégorie est sélectionnée
                  if (selected.length == 1) {
                    _loadRatingCriteria(selected.first);
                  } else if (selected.isEmpty) {
                    _loadRatingCriteria(null); // Charger les critères par défaut
                  }
                });
              },
            ),
        
        if (_selectedFilterIndex == 1) // Montrer les émotions uniquement pour les événements
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Émotions', style: AppStyles.filterTitle),
              _isLoadingEmotions 
                ? Center(child: CircularProgressIndicator()) 
                : FilterChips(
                    options: _availableEmotions,
                    selectedOptions: _selectedEmotions,
                    onSelectionChanged: (selected) {
                      setState(() {
                        _selectedEmotions = selected;
                      });
                    },
                  ),
                  
              Text('Trier par', style: AppStyles.filterTitle),
              DropdownButton<String>(
                isExpanded: true,
                value: _sortBy == 'date' ? 'Date' : (_sortBy == 'popularity' ? 'Popularité' : 'Note'),
                items: _sortOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value.toLowerCase() == 'date' ? 'date' : 
                               value.toLowerCase() == 'popularité' ? 'popularity' : 'rating';
                    });
                  }
                },
              ),
            ],
          ),
      ],
    );
  }
  
  Widget _buildPlaceFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accessibilité', style: AppStyles.filterTitle),
        FilterChips(
          options: _availableAccessibility,
          selectedOptions: _selectedAccessibility,
          onSelectionChanged: (selected) {
            setState(() {
              _selectedAccessibility = selected;
            });
          },
        ),
        
        Text('Type de lieu', style: AppStyles.filterTitle),
        DropdownButton<String>(
          isExpanded: true,
          hint: Text('Sélectionner un type'),
          value: _selectedProducerType,
          items: _availableProducerTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedProducerType = value;
              if (value != null && value != 'Tous') {
                _loadRatingCriteria(value);
              }
            });
          },
        ),
        
        SizedBox(height: 16),
        
        // Critères d'évaluation dynamiques
        if (_isLoadingCriteria)
          Center(child: CircularProgressIndicator())
        else
          ..._buildDynamicRatingCriteria(),
      ],
    );
  }
  
  // Méthode pour construire les sliders des critères dynamiques
  List<Widget> _buildDynamicRatingCriteria() {
    final widgets = <Widget>[];
    
    // Ajouter un titre pour indiquer la catégorie des critères
    if (_currentCriteria.isNotEmpty) {
      String categoryTitle = "Critères d'évaluation";
      
      // Déterminer la catégorie actuelle
      if (_selectedCategories.length == 1) {
        categoryTitle += " pour ${_selectedCategories.first}";
      } else if (_selectedProducerType != null && _selectedProducerType != 'Tous') {
        categoryTitle += " pour $_selectedProducerType";
      } else if (_selectedEventType != null && _selectedEventType != 'Tous') {
        categoryTitle += " pour $_selectedEventType";
      }
      
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(height: 24),
            Text(
              categoryTitle, 
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: mapcolors.MapColors.leisurePrimary
              )
            ),
            SizedBox(height: 16),
          ],
        )
      );
    }
    
    // Ajouter les sliders pour chaque critère
    _currentCriteria.forEach((key, label) {
      widgets.add(
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _selectedCriteriaValues[key]! > 0 
                ? mapcolors.MapColors.leisurePrimary.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Note $label: ', style: AppStyles.filterTitle),
                  Text(
                    '${_selectedCriteriaValues[key]?.toStringAsFixed(1) ?? "0.0"}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedCriteriaValues[key]! > 3.0 
                          ? Colors.green 
                          : (_selectedCriteriaValues[key]! > 0 ? Colors.orange : Colors.grey),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _selectedCriteriaValues[key] ?? 0.0,
                min: 0,
                max: 5,
                divisions: 10,
                activeColor: _selectedCriteriaValues[key]! > 3.0 
                    ? Colors.green 
                    : (_selectedCriteriaValues[key]! > 0 ? mapcolors.MapColors.leisurePrimary : Colors.grey),
                onChanged: (value) {
                  setState(() {
                    _selectedCriteriaValues[key] = value;
                  });
                },
              ),
            ],
          ),
        ),
      );
    });
    
    return widgets;
  }
  
  Widget _buildEventFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dates', style: AppStyles.filterTitle),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _dateStart ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateStart = picked;
                    });
                  }
                },
                child: Text(_dateStart == null 
                    ? 'Date de début' 
                    : DateFormat('dd/MM/yyyy').format(_dateStart!)),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _dateEnd ?? (_dateStart ?? DateTime.now()),
                    firstDate: _dateStart ?? DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateEnd = picked;
                    });
                  }
                },
                child: Text(_dateEnd == null 
                    ? 'Date de fin' 
                    : DateFormat('dd/MM/yyyy').format(_dateEnd!)),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        Text('Heures', style: AppStyles.filterTitle),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Heure début (HH:MM)',
                  border: OutlineInputBorder(),
                ),
                initialValue: _timeStart,
                onChanged: (value) {
                  setState(() {
                    _timeStart = value.isNotEmpty ? value : null;
                  });
                },
                keyboardType: TextInputType.datetime,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Heure fin (HH:MM)',
                  border: OutlineInputBorder(),
                ),
                initialValue: _timeEnd,
                onChanged: (value) {
                  setState(() {
                    _timeEnd = value.isNotEmpty ? value : null;
                  });
                },
                keyboardType: TextInputType.datetime,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        Text('Jours de la semaine', style: AppStyles.filterTitle),
        Wrap(
          spacing: 8,
          children: List.generate(_daysOfWeek.length, (index) {
            return FilterChip(
              label: Text(_daysOfWeek[index].substring(0, 3)),
              selected: _selectedDays.contains(index),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(index);
                  } else {
                    _selectedDays.remove(index);
                  }
                });
              },
            );
          }),
        ),
        
        SizedBox(height: 16),
        
        Text('Type d\'événement', style: AppStyles.filterTitle),
        DropdownButton<String>(
          isExpanded: true,
          hint: Text('Sélectionner un type'),
          value: _selectedEventType,
          items: _availableEventTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEventType = value;
              if (value != null && value != 'Tous') {
                _loadRatingCriteria(value);
              }
            });
          },
        ),
        
        SizedBox(height: 8),
        
        Text('Lineup / Artistes', style: AppStyles.filterTitle),
        FilterChips(
          options: _availableLineup,
          selectedOptions: _selectedLineup,
          onSelectionChanged: (selected) {
            setState(() {
              _selectedLineup = selected;
            });
          },
        ),
        
        Row(
          children: [
            Checkbox(
              value: _familyFriendly,
              onChanged: (value) {
                setState(() {
                  _familyFriendly = value ?? false;
                });
              },
            ),
            Text('Adapté aux familles'),
          ],
        ),
        
        Text('Note ambiance: ${_minAmbiance.toStringAsFixed(1)}',
            style: AppStyles.filterTitle),
        Slider(
          value: _minAmbiance,
          min: 0,
          max: 5,
          divisions: 10,
          onChanged: (value) {
            setState(() {
              _minAmbiance = value;
            });
          },
        ),
        
        Text('Note organisation: ${_minOrganisation.toStringAsFixed(1)}',
            style: AppStyles.filterTitle),
        Slider(
          value: _minOrganisation,
          min: 0,
          max: 5,
          divisions: 10,
          onChanged: (value) {
            setState(() {
              _minOrganisation = value;
            });
          },
        ),
        
        Text('Note programmation: ${_minProgrammation.toStringAsFixed(1)}',
            style: AppStyles.filterTitle),
        Slider(
          value: _minProgrammation,
          min: 0,
          max: 5,
          divisions: 10,
          onChanged: (value) {
            setState(() {
              _minProgrammation = value;
            });
          },
        ),
        
        // Critères d'évaluation dynamiques
        if (_isLoadingCriteria)
          Center(child: CircularProgressIndicator())
        else
          ..._buildDynamicRatingCriteria(),
      ],
    );
  }
  
  Widget _buildFilterPanel() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtrer les événements',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: mapcolors.MapColors.leisurePrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 28),
                    onPressed: () {
                      setState(() {
                        _showFilterPanel = false;
                      });
                    },
                  ),
                ],
              ),
              Divider(thickness: 1),
              
              // Contenu du filtre avec défilement
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Catégories d'événements
                      _buildFilterSection(
                        title: 'Catégories d\'événements',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _availableCategories.map((category) {
                            return FilterChip(
                              label: Text(category),
                              selected: _selectedCategories.contains(category),
                              checkmarkColor: Colors.white,
                              selectedColor: mapcolors.MapColors.leisurePrimary,
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _selectedCategories.contains(category) 
                                      ? mapcolors.MapColors.leisurePrimary 
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      
                      // Émotions
                      _buildFilterSection(
                        title: 'Émotions recherchées',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _availableEmotions.map((emotion) {
                            return FilterChip(
                              label: Text(emotion),
                              selected: _selectedEmotions.contains(emotion),
                              checkmarkColor: Colors.white,
                              selectedColor: mapcolors.MapColors.leisurePrimary,
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _selectedEmotions.contains(emotion) 
                                      ? mapcolors.MapColors.leisurePrimary 
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedEmotions.add(emotion);
                                  } else {
                                    _selectedEmotions.remove(emotion);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      
                      // Note minimale
                      _buildFilterSection(
                        title: 'Note minimale: ${_minRating > 0 ? "$_minRating★" : "Toutes"}',
                        child: Slider(
                          min: 0,
                          max: 5,
                          divisions: 10,
                          value: _minRating,
                          label: _minRating > 0 ? '$_minRating★' : 'Toutes',
                          activeColor: mapcolors.MapColors.leisurePrimary,
                          inactiveColor: mapcolors.MapColors.leisurePrimary.withOpacity(0.2),
                          onChanged: (value) {
                            setState(() {
                              _minRating = value;
                            });
                          },
                        ),
                      ),
                      
                      // Date et heure
                      _buildFilterSection(
                        title: 'Quand ?',
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildDateChip('Aujourd\'hui'),
                                _buildDateChip('Demain'),
                                _buildDateChip('Ce weekend'),
                                _buildDateChip('Cette semaine'),
                              ],
                            ),
                            SizedBox(height: 10),
                            // Bouton pour sélectionner une date précise
                            OutlinedButton.icon(
                              icon: Icon(Icons.calendar_today, color: mapcolors.MapColors.leisurePrimary),
                              label: Text('Date précise'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: mapcolors.MapColors.leisurePrimary,
                                side: BorderSide(color: mapcolors.MapColors.leisurePrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: mapcolors.MapColors.leisurePrimary,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    _dateStart = picked;
                                    _dateEnd = null;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Distance
                      _buildFilterSection(
                        title: 'Distance maximale: ${(_selectedRadius / 1000).toStringAsFixed(1)} km',
                        child: Slider(
                          min: 500,
                          max: 10000,
                          divisions: 19,
                          value: _selectedRadius,
                          activeColor: mapcolors.MapColors.leisurePrimary,
                          inactiveColor: mapcolors.MapColors.leisurePrimary.withOpacity(0.2),
                          onChanged: (value) {
                            setState(() {
                              _selectedRadius = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              Divider(thickness: 1),
              
              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text('Réinitialiser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _resetFilters();
                    },
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.check),
                    label: Text('Appliquer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mapcolors.MapColors.leisurePrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _fetchLeisurePlaces();
                      setState(() {
                        _showFilterPanel = false;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Méthode utilitaire pour créer une section de filtre
  Widget _buildFilterSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        child,
        SizedBox(height: 10),
      ],
    );
  }
  
  // Méthode utilitaire pour créer un chip de date
  Widget _buildDateChip(String label) {
    bool isSelected = false;
    
    // Logique pour déterminer si cette date est sélectionnée
    if (label == 'Aujourd\'hui' && _dateStart?.day == DateTime.now().day) {
      isSelected = true;
    } else if (label == 'Demain' && _dateStart?.day == DateTime.now().add(Duration(days: 1)).day) {
      isSelected = true;
    }
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      checkmarkColor: Colors.white,
      selectedColor: mapcolors.MapColors.leisurePrimary,
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? mapcolors.MapColors.leisurePrimary : Colors.grey.shade300,
        ),
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            if (label == 'Aujourd\'hui') {
              _dateStart = DateTime.now();
              _dateEnd = DateTime.now();
            } else if (label == 'Demain') {
              _dateStart = DateTime.now().add(Duration(days: 1));
              _dateEnd = DateTime.now().add(Duration(days: 1));
            } else if (label == 'Ce weekend') {
              // Calculer le prochain vendredi
              final now = DateTime.now();
              final daysUntilFriday = (DateTime.friday - now.weekday) % 7;
              _dateStart = DateTime(now.year, now.month, now.day + daysUntilFriday);
              _dateEnd = _dateStart!.add(Duration(days: 2)); // Vendredi à dimanche
            } else if (label == 'Cette semaine') {
              final now = DateTime.now();
              _dateStart = now;
              // Calculer le prochain dimanche
              final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
              _dateEnd = DateTime(now.year, now.month, now.day + daysUntilSunday);
            }
          } else {
            _dateStart = null;
            _dateEnd = null;
          }
        });
      },
    );
  }
  
  // Méthode pour appliquer les filtres depuis MapScreen
  void applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _selectedRadius = filters['radius'] ?? _selectedRadius;
      _minRating = filters['minRating'] ?? _minRating;
      _searchKeyword = filters['keyword'] ?? '';
      
      if (filters['categories'] != null && filters['categories'] is List) {
        _selectedCategories = List<String>.from(filters['categories']);
      }
    });
    
    // Rafraîchir les données sur la carte
    _fetchLeisurePlaces();
  }
  
  // Méthode pour activer la localisation en direct
  void enableLiveLocation() {
    setState(() {
      _isUsingLiveLocation = true;
    });
    
    if (_currentLocation != null && _controller.isCompleted) {
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newLatLng(_currentLocation!),
        );
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // Mode carte ou signets
          _showBookmarksView 
              ? _buildBookmarksView() 
              : _buildMapView(),
          
          // En-tête de la carte
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Sélecteur de carte
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: widget_selector.MapSelector(
                      currentIndex: 1, // Index 1 pour la carte loisirs
                      mapCount: 4, // Nombre total de cartes
                      onMapSelected: _navigateToMapScreen,
                    ),
                  ),
                  
                  // Barre de recherche
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(left: 8),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher des lieux, événements...',
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: mapcolors.MapColors.leisurePrimary),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchKeyword = value;
                          });
                        },
                        onSubmitted: (value) {
                          _fetchLeisurePlaces();
                        },
                      ),
                    ),
                  ),
                  
                  // Bouton de bascule entre carte et signets
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _showBookmarksView ? Icons.map : Icons.bookmark,
                        color: mapcolors.MapColors.leisurePrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showBookmarksView = !_showBookmarksView;
                        });
                      },
                      tooltip: _showBookmarksView ? 'Voir la carte' : 'Voir mes signets',
                      constraints: BoxConstraints(maxWidth: 40, maxHeight: 40),
                      padding: EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Widget de détail pour l'endroit sélectionné (uniquement en vue carte)
          if (!_showBookmarksView && _selectedPlace != null)
            _buildSelectedPlaceDetails(),
          
          // Panel overlay pour les filtres
          if (_showFilterPanel)
            _buildFilterPanel(),
            
          // Panel overlay pour les followings intéressés
          if (_showFollowingsPanel)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFollowingsPanel = false;
                });
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 64),
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: interests_list.FollowingsInterestsList(
                      followingsData: _selectedVenueFollowingsData,
                      onClose: () {
                        setState(() {
                          _showFollowingsPanel = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // Ajouter le bouton de filtres en bas à droite seulement si on est sur la carte
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton pour montrer le widget avec les signets favoris
          if (!_showBookmarksView && _bookmarkedVenues.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.small(
                heroTag: 'bookmarks_preview',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Vous avez ${_bookmarkedVenues.length} lieux en favoris'),
                      action: SnackBarAction(
                        label: 'VOIR',
                        onPressed: () {
                          setState(() {
                            _showBookmarksView = true;
                          });
                        },
                      ),
                    ),
                  );
                  
                  // Si nous avons des signets, centrer la carte sur le premier
                  if (_bookmarkedVenues.isNotEmpty && _controller.isCompleted) {
                    final venue = _bookmarkedVenues.first;
                    final double? lat = double.tryParse(venue['latitude']?.toString() ?? '');
                    final double? lng = double.tryParse(venue['longitude']?.toString() ?? '');
                    
                    if (lat != null && lng != null) {
                      _controller.future.then((controller) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(lat, lng),
                            15.0,
                          ),
                        );
                      });
                    }
                  }
                },
                backgroundColor: Colors.white,
                child: Stack(
                  children: [
                    Icon(
                      Icons.bookmark,
                      color: mapcolors.MapColors.leisurePrimary,
                    ),
                    if (_bookmarkedVenues.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${_bookmarkedVenues.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // Bouton de filtres
          if (!_showBookmarksView)
            FloatingActionButton(
              heroTag: 'filter_button',
              onPressed: () {
                setState(() {
                  _showFilterPanel = true;
                });
              },
              backgroundColor: mapcolors.MapColors.leisurePrimary,
              child: Icon(Icons.filter_list, color: Colors.white),
              tooltip: 'Filtres',
            ),
        ].where((widget) => widget != null).cast<Widget>().toList(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const SizedBox(height: 60), // Réservé pour la navigation principale
    );
  }

  // Méthode pour naviguer vers différentes cartes
  void _navigateToMapScreen(dynamic value) {
    String mapType;
    if (value is int) {
      switch (value) {
        case 0:
          mapType = 'restaurant';
          break;
        case 1:
          mapType = 'leisure';
          break;
        case 2:
          mapType = 'wellness';
          break;
        case 3:
          mapType = 'friends';
          break;
        default:
          mapType = 'leisure';
      }
    } else {
      mapType = value.toString();
    }
    if (mapType == 'leisure') return;
    context.changeMapType(mapType);
  }

  // Événement lors de la création de la carte
  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    
    // Si un zoom initial est fourni, l'utiliser
    if (widget.initialZoom != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          _initialPosition, 
          widget.initialZoom!
        )
      );
    }
    
    // Charger les lieux de loisirs
    _fetchLeisurePlaces();
  }

  // Charger les critères d'évaluation en fonction de la catégorie
  Future<void> _loadRatingCriteria(String? category) async {
    setState(() {
      _isLoadingCriteria = true;
    });
    
    try {
      final criteria = await _mapService.getRatingCriteria(category);
      
      setState(() {
        _currentCriteria = criteria;
        
        // Initialiser les valeurs des critères à 0
        _selectedCriteriaValues = {};
        criteria.forEach((key, value) {
          _selectedCriteriaValues[key] = 0.0;
        });
        
        _isLoadingCriteria = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des critères: $e');
      setState(() {
        _isLoadingCriteria = false;
      });
    }
  }

  // Méthode pour initialiser les sections de filtres
  void _initializeFilterSections() {
    // Simplification : garder uniquement les filtres d'événements
    _filterSections = [
      filter_models.FilterSection(
        title: 'Catégories d\'événements',
        icon: Icons.category,
        options: _availableCategories.map((cat) => 
          filter_models.FilterOption(
            id: cat,
            label: cat,
            isSelected: _selectedCategories.contains(cat),
          )
        ).toList(),
      ),
      filter_models.FilterSection(
        title: 'Émotions',
        icon: Icons.emoji_emotions,
        options: _availableEmotions.map((emotion) => 
          filter_models.FilterOption(
            id: emotion,
            label: emotion,
            isSelected: _selectedEmotions.contains(emotion),
          )
        ).toList(),
      ),
      filter_models.FilterSection(
        title: 'Note minimale',
        icon: Icons.star,
        options: [
          filter_models.FilterOption(
            id: '0',
            label: 'Toutes les notes',
            isSelected: _minRating == 0,
          ),
          filter_models.FilterOption(
            id: '3',
            label: '3★ et plus',
            isSelected: _minRating == 3,
          ),
          filter_models.FilterOption(
            id: '4',
            label: '4★ et plus',
            isSelected: _minRating == 4,
          ),
          filter_models.FilterOption(
            id: '4.5',
            label: '4.5★ et plus',
            isSelected: _minRating == 4.5,
          ),
        ],
      ),
      filter_models.FilterSection(
        title: 'Date et heure',
        icon: Icons.calendar_today,
        options: [
          filter_models.FilterOption(
            id: 'today',
            label: 'Aujourd\'hui',
            isSelected: false,
          ),
          filter_models.FilterOption(
            id: 'tomorrow',
            label: 'Demain',
            isSelected: false,
          ),
          filter_models.FilterOption(
            id: 'this_weekend',
            label: 'Ce weekend',
            isSelected: false,
          ),
          filter_models.FilterOption(
            id: 'this_week',
            label: 'Cette semaine',
            isSelected: false,
          ),
        ],
      ),
      filter_models.FilterSection(
        title: 'Type d\'événement',
        icon: Icons.event,
        options: _availableEventTypes.map((type) => 
          filter_models.FilterOption(
            id: type,
            label: type,
            isSelected: _selectedEventType == type,
          )
        ).toList(),
      ),
    ];
  }

  // Méthode pour construire le widget de détail pour le lieu sélectionné
  Widget _buildSelectedPlaceDetails() {
    if (_selectedPlace == null) {
      return const SizedBox(); // Si aucun lieu n'est sélectionné, ne rien afficher
    }

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: _buildUpdatedPlaceInfoCard(_selectedPlace!),
    );
  }

  
  // Obtenir l'icône correspondant à la catégorie
  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    
    if (categoryLower.contains('concert') || categoryLower.contains('music') || categoryLower.contains('musique')) {
      return Icons.music_note;
    } else if (categoryLower.contains('théâtre') || categoryLower.contains('theatre')) {
      return Icons.theater_comedy;
    } else if (categoryLower.contains('expo') || categoryLower.contains('art') || 
               categoryLower.contains('musée') || categoryLower.contains('musee')) {
      return Icons.museum;
    } else if (categoryLower.contains('cinéma') || categoryLower.contains('cinema')) {
      return Icons.local_movies;
    } else if (categoryLower.contains('danse') || categoryLower.contains('ballet')) {
      return Icons.directions_run;
    } else if (categoryLower.contains('festival')) {
      return Icons.festival;
    } else if (categoryLower.contains('comédie') || categoryLower.contains('comedie') || 
               categoryLower.contains('humour')) {
      return Icons.theater_comedy;
    } else {
      return Icons.event;
    }
  }
  
  // Obtenir la couleur correspondant à la catégorie
  Color _getCategoryColor(String category) {
    final categoryLower = category.toLowerCase();
    
    if (categoryLower.contains('concert') || categoryLower.contains('music') || categoryLower.contains('musique')) {
      return Colors.deepPurple;
    } else if (categoryLower.contains('théâtre') || categoryLower.contains('theatre')) {
      return Colors.deepOrange;
    } else if (categoryLower.contains('expo') || categoryLower.contains('art') || 
               categoryLower.contains('musée') || categoryLower.contains('musee')) {
      return Colors.indigo;
    } else if (categoryLower.contains('cinéma') || categoryLower.contains('cinema')) {
      return Colors.red;
    } else if (categoryLower.contains('danse') || categoryLower.contains('ballet')) {
      return Colors.pink;
    } else if (categoryLower.contains('festival')) {
      return Colors.amber;
    } else if (categoryLower.contains('comédie') || categoryLower.contains('comedie') || 
               categoryLower.contains('humour')) {
      return Colors.teal;
    } else {
      return mapcolors.MapColors.leisurePrimary;
    }
  }
  
  // Simplifier la catégorie pour l'affichage
  String _simplifyCategory(String category) {
    // Extraire juste la première partie de la catégorie (avant le premier »)
    if (category.contains('»')) {
      return category.split('»').first.trim();
    }
    
    // Extraire avant la première parenthèse s'il y en a une
    if (category.contains('(')) {
      return category.split('(').first.trim();
    }
    
    // Limiter la longueur si trop longue
    if (category.length > 20) {
      return category.substring(0, 18) + '...';
    }
    
    return category;
  }
  
  // Charger les signets de l'utilisateur
  Future<void> _loadUserBookmarks() async {
    setState(() {
      _isLoadingBookmarks = true;
    });
    
    try {
      final bookmarks = await _mapService.getUserLeisureBookmarks();
      
      setState(() {
        _bookmarkedVenues = bookmarks;
        _bookmarkedVenueIds = Set<String>.from(
          bookmarks.map((venue) => venue['id']?.toString() ?? venue['_id']?.toString() ?? '')
        );
        _isLoadingBookmarks = false;
      });
    } catch (e) {
      print('❌ Erreur lors du chargement des signets: $e');
      setState(() {
        _isLoadingBookmarks = false;
      });
    }
  }
  
  // Gérer l'ajout ou la suppression d'un signet
  void _handleBookmarkChange(String venueId, bool isBookmarked) {
    setState(() {
      if (isBookmarked) {
        _bookmarkedVenueIds.add(venueId);
        
        // Ajouter le lieu aux signets s'il existe dans _placesData
        final venue = _placesData.firstWhere(
          (place) => (place['id']?.toString() ?? place['_id']?.toString() ?? '') == venueId,
          orElse: () => <String, dynamic>{},
        );
        
        if (venue.isNotEmpty && !_bookmarkedVenues.any((v) => 
            (v['id']?.toString() ?? v['_id']?.toString() ?? '') == venueId)) {
          _bookmarkedVenues.add(venue);
        }
      } else {
        _bookmarkedVenueIds.remove(venueId);
        
        // Supprimer le lieu des signets
        _bookmarkedVenues.removeWhere((venue) => 
          (venue['id']?.toString() ?? venue['_id']?.toString() ?? '') == venueId);
      }
    });
  }
  
  // Charger les données des followings intéressés par un lieu
  Future<void> _loadFollowingsForVenue(String venueId) async {
    try {
      final data = await _mapService.getFollowingsInterestsForVenue(venueId);
      
      setState(() {
        _selectedVenueFollowingsData = {
          'interests': data,
          'choices': [],
          'followings': [],
        };
        _showFollowingsPanel = true;
      });
    } catch (e) {
      print('❌ Erreur lors du chargement des followings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des amis intéressés'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Widget pour afficher la liste des signets
  Widget _buildBookmarksView() {
    if (_isLoadingBookmarks) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(mapcolors.MapColors.leisurePrimary),
        ),
      );
    }
    
    if (_bookmarkedVenues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 72,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'Vous n\'avez pas encore de signets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Explorez la carte et ajoutez des lieux à vos signets pour les retrouver facilement',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.explore),
                label: Text('Explorer la carte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mapcolors.MapColors.leisurePrimary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _showBookmarksView = false;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _bookmarkedVenues.length,
      itemBuilder: (context, index) {
        final venue = _bookmarkedVenues[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: LeisureBookmarkWidget(
            venue: venue,
            isBookmarked: true,
            onTap: (venueId) {
              // Afficher les détails du lieu
              final selectedVenueData = _bookmarkedVenues.firstWhere(
                (v) => (v['id']?.toString() ?? v['_id']?.toString()) == venueId,
                orElse: () => <String, dynamic>{}, // Return empty map if not found
              );
              
              if (selectedVenueData.isNotEmpty) {
                // Ensure rawData is passed if available, otherwise use the venue map itself
                final rawDataForPlace = selectedVenueData['rawData'] ?? selectedVenueData;
                final placeToSelect = Place.fromMap(rawDataForPlace); // Create Place object
                
                setState(() {
                  _selectedPlace = placeToSelect; // Use the created Place object
                  _showBookmarksView = false;
                });
                
                // Si la carte est prête, centrer sur le lieu
                if (_controller.isCompleted) {
                  final double? lat = placeToSelect.latitude;
                  final double? lng = placeToSelect.longitude;
                  
                  if (lat != null && lng != null) {
                    _controller.future.then((controller) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(lat, lng),
                          15.0,
                        ),
                      );
                    });
                  }
                }
              }
            },
            onBookmarkChanged: _handleBookmarkChange,
          ),
        );
      },
    );
  }

  // Méthode pour créer la carte d'information avec les fonctionnalités améliorées
  Widget _buildUpdatedPlaceInfoCard(Place place) {
    // Identifier si c'est un événement unique vs un lieu avec événements
    // On peut se baser sur la présence de 'event' dans le type ou l'absence de liste 'events' dans l'objet Place
    // Ou mieux, si l'API renvoie un 'type' dans rawData
    final bool isSingleEvent = place.rawData['locationType'] == 'event' || place.events == null || place.events!.isEmpty;
    final int eventCount = place.events?.length ?? 0;
    
    // Vérifier si le lieu est dans les signets
    final venueId = place.id;
    final bool isBookmarked = _bookmarkedVenueIds.contains(venueId);

    // Récupérer les compteurs depuis rawData (avec fallback à 0)
    final int choiceCount = place.rawData['choice_count'] ?? place.rawData['choiceCount'] ?? 0;
    final int interestCount = place.rawData['interest_count'] ?? place.rawData['interestCount'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du lieu/événement
              if (place.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Builder(
                    builder: (context) {
                      final imageProvider = getImageProvider(place.imageUrl);
                      
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300], // Background placeholder
                        child: imageProvider != null 
                          ? Image(
                              image: imageProvider,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print("❌ Error loading venue image: $error");
                                return Center(child: Icon(Icons.image_not_supported, color: Colors.grey[600]));
                              },
                            )
                          : Center(child: Icon(isSingleEvent ? Icons.event : Icons.place, color: Colors.grey[600])), // Icon if no image
                      );
                    }
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(isSingleEvent ? Icons.event : Icons.place),
                ),
              const SizedBox(width: 12),
              
              // Informations sur le lieu/événement
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            place.name ?? (isSingleEvent ? 'Événement sans nom' : 'Lieu sans nom'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Bouton de signet
                        GestureDetector(
                          onTap: () {
                            _toggleBookmark(venueId);
                          },
                          child: Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: isBookmarked ? mapcolors.MapColors.leisurePrimary : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (place.category != null)
                      Text(
                        place.category!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Afficher l'adresse si ce n'est pas un événement unique (ou si l'événement a une adresse spécifique)
                    if (!isSingleEvent && place.address != null && place.address!.isNotEmpty)
                      Text(
                        place.address!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    // Afficher la date si c'est un événement unique
                    else if (isSingleEvent && place.rawData['start_date'] != null)
                      Text(
                        'Date: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(DateTime.parse(place.rawData['start_date']))}',
                         style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Affichage des compteurs Choice / Interest
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: GestureDetector( // Rendre la ligne cliquable pour ouvrir les détails
              onTap: () {
                print("TODO: Ouvrir le popup des détails des utilisateurs (choices/interests) pour ${place.id}");
                // Ici, appeler une fonction qui ouvre le nouveau popup
                _showChoiceInterestUsersPopup(context, place.id, isSingleEvent ? 'event' : 'venue'); 
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible( // Wrap with Flexible
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, color: mapcolors.MapColors.leisurePrimary, size: 18),
                        SizedBox(width: 4),
                        Flexible(child: Text('$choiceCount Choices')), // Also wrap Text just in case
                      ],
                    ),
                  ),
                  Flexible( // Wrap with Flexible
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border, color: Colors.redAccent, size: 18),
                        SizedBox(width: 4),
                        Flexible(child: Text('$interestCount Intérêts')), // Also wrap Text just in case
                      ],
                    ),
                  ),
                   // Ajouter une petite flèche pour indiquer qu'on peut cliquer
                   Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
          Divider(height: 16), // Séparateur visuel
          
          // Information sur les événements (si c'est un lieu qui a des événements)
          if (!isSingleEvent && eventCount > 0) // Utilisation de !isSingleEvent au lieu de isVenue
            Padding(
              padding: const EdgeInsets.only(top: 0), // Ajusté le padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eventCount > 1 
                        ? '$eventCount événements à venir' 
                        : '1 événement à venir',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Liste des événements (limitée à 2)
                  ...place.events!.take(2).map((event) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event['name'] ?? 'Événement sans nom',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Ajouter un bouton pour voir les détails de cet événement spécifique
                          TextButton(
                             onPressed: () {
                               final eventId = event['_id'] ?? event['id'];
                               if (eventId != null) {
                                 // Utiliser la route et le paramètre 'id'
                                 Navigator.pushNamed(context, '/leisure/event/$eventId');
                               } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                     const SnackBar(content: Text('ID de l\'événement introuvable')),
                                   );
                               }
                             },
                             child: Text('Détails >'),
                             style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(50, 30)),
                          )
                        ],
                      ),
                    )
                  ).toList(),
                  if (eventCount > 2)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Afficher tous les événements
                          _showAllEvents(place);
                        },
                        child: Text(
                          'Voir tous (${eventCount - 2} de plus)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // Section des followings intéressés (si c'est un lieu)
          if (!isSingleEvent) // Ne pas montrer pour un événement unique pour l'instant
            FutureBuilder<List<Map<String, dynamic>>>(
              future: MapService().getFollowingsInterestsForVenue(venueId),
              builder: (context, snapshot) {
                  // ... (le reste du code du FutureBuilder reste identique) ...
                  // ...
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink(); // Retourner un widget vide en cas d'erreur ou de données vides
                  }

                  final followingInterests = snapshot.data!;
                  
                  return Padding(
                     padding: const EdgeInsets.only(top: 12), // Ajout du padding manquant
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         // ... (le reste du code de Padding reste identique) ...
                         // ...
                       ],
                     ),
                  );
              },
            ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                 // Bouton Voir détails (si c'est un événement unique)
                 if (isSingleEvent)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Naviguer vers l'écran de détail de l'événement en utilisant la route et l'ID
                         Navigator.pushNamed(context, '/leisure/event/${place.id}');
                      },
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Voir détails'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                 // Bouton de navigation (si c'est un lieu)
                 else 
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Ouvrir la navigation vers le lieu
                        _navigateToPlace(place);
                      },
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('Y aller'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Bouton de partage
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Partager le lieu/événement
                      _sharePlace(place); // La fonction _sharePlace doit être adaptée si nécessaire
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Partager'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      foregroundColor: Theme.of(context).primaryColor,
                       side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Méthode pour afficher tous les événements d'un lieu
  void _showAllEvents(Place place) {
    if (place.events == null || place.events!.isEmpty) {
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Événements à ${place.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: place.events!.length,
                  itemBuilder: (context, index) {
                    final event = place.events![index];
                    return ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(event['name'] ?? 'Événement sans nom'),
                      subtitle: Text(event['date'] ?? 'Date non spécifiée'),
                      onTap: () {
                        // Action lors du clic sur un événement
                        Navigator.pop(context);
                        // Naviguer vers les détails de l'événement si nécessaire
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Méthode pour afficher tous les followings intéressés
  void _showAllFollowingInterests(List<Map<String, dynamic>> followingInterests) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Amis intéressés',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: followingInterests.length,
                  itemBuilder: (context, index) {
                    final following = followingInterests[index];
                    final hasInterest = following['interest'] == true;
                    final hasVisited = following['hasVisited'] == true;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hasVisited
                            ? Colors.green[100]
                            : hasInterest
                                ? Colors.blue[100]
                                : Colors.grey[300],
                        child: Text(
                          following['username']?.substring(0, 1).toUpperCase() ?? '?',
                          style: TextStyle(
                            color: hasVisited
                                ? Colors.green[800]
                                : hasInterest
                                    ? Colors.blue[800]
                                    : Colors.grey[800],
                          ),
                        ),
                      ),
                      title: Text(following['username'] ?? 'Utilisateur inconnu'),
                      subtitle: Text(
                        hasVisited
                            ? 'A visité ce lieu'
                            : hasInterest
                                ? 'Intéressé(e) par ce lieu'
                                : 'A ajouté ce lieu',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.message),
                        onPressed: () {
                          // Envoyer un message à ce following
                          Navigator.pop(context);
                          _sendMessageToUser(following['userId']);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Méthode pour naviguer vers un lieu
  void _navigateToPlace(Place place) {
    if (place.latitude == null || place.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de trouver les coordonnées du lieu')),
      );
      return;
    }
    
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}';
    launchUrl(Uri.parse(url));
  }
  
  // Méthode pour partager un lieu
  void _sharePlace(Place place) async {
    await Share.share(
      'Découvre ce lieu sur Choice: ${place.name}\nhttps://choiceapp.fr/venue/${place.id}',
      subject: place.name,
    );
  }
  
  // Méthode pour envoyer un message à un utilisateur
  void _sendMessageToUser(String userId) {
    // Naviguer vers la conversation avec cet utilisateur
    Navigator.pushNamed(
      context, 
      '/messages/conversation',
      arguments: {'userId': userId},
    );
  }

  // Construire la vue carte
  Widget _buildMapView() {
    return Stack(
      children: [
        // Carte Google Maps
        AdaptiveMapWidget(
          initialPosition: _currentLocation ?? _initialPosition,
          markers: _markers,
          onMapCreated: _onMapCreated,
        ),
        
        // Indicateur de chargement
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        
        // Message d'erreur
        if (_errorMessage != null && _errorMessage!.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchLeisurePlaces,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mapcolors.MapColors.leisurePrimary,
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        
        // Afficher un message si aucun lieu n'est trouvé mais pas d'erreur
        if (!_isLoading && _markers.isEmpty && _errorMessage == null)
          Positioned(
            bottom: 70,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: mapcolors.MapColors.leisurePrimary,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aucun lieu trouvé avec ces critères',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Essayez de modifier vos filtres ou d\'élargir votre zone de recherche',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showFilterPanel = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mapcolors.MapColors.leisurePrimary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Modifier les filtres'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Méthode pour basculer l'état d'un signet
  void _toggleBookmark(String venueId) {
    setState(() {
      if (_bookmarkedVenueIds.contains(venueId)) {
        _bookmarkedVenueIds.remove(venueId);
        _bookmarkedVenues.removeWhere((venue) => 
          (venue['id']?.toString() ?? venue['_id']?.toString() ?? '') == venueId);
      } else {
        _bookmarkedVenueIds.add(venueId);
        final venue = _placesData.firstWhere(
          (place) => (place['id']?.toString() ?? place['_id']?.toString() ?? '') == venueId,
          orElse: () => <String, dynamic>{},
        );
        if (venue.isNotEmpty && !_bookmarkedVenues.any((v) => 
            (v['id']?.toString() ?? v['_id']?.toString() ?? '') == venueId)) {
          _bookmarkedVenues.add(venue);
        }
      }
    });
  }

  // Ajouter cette méthode pour configurer les dates en fonction de l'option rapide
  void _updateDatesByQuickOption(String option) {
    final now = DateTime.now();
    switch (option) {
      case 'Aujourd\'hui':
        setState(() {
          _dateStart = now;
          _dateEnd = now;
          _selectedQuickDateOption = option;
        });
        break;
        
      case 'Demain':
        final tomorrow = now.add(Duration(days: 1));
        setState(() {
          _dateStart = tomorrow;
          _dateEnd = tomorrow;
          _selectedQuickDateOption = option;
        });
        break;
        
      case 'Ce week-end':
        // Calculer le prochain week-end (samedi et dimanche)
        final dayOfWeek = now.weekday; // 1 = lundi, 7 = dimanche
        final daysToSaturday = dayOfWeek == 6 || dayOfWeek == 7 
            ? (dayOfWeek == 7 ? 6 : 0) // Si dimanche (7), samedi prochain est dans 6 jours, si samedi (6), c'est aujourd'hui
            : 6 - dayOfWeek; // Sinon, calculer jours jusqu'à samedi
        
        final nextSaturday = now.add(Duration(days: daysToSaturday));
        final nextSunday = nextSaturday.add(Duration(days: 1));
        
        // Si on est déjà le week-end, utiliser la date actuelle
        final weekendStart = dayOfWeek == 6 || dayOfWeek == 7 ? now : nextSaturday;
        
        setState(() {
          _dateStart = DateTime(weekendStart.year, weekendStart.month, weekendStart.day);
          _dateEnd = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59);
          _selectedQuickDateOption = option;
        });
        break;
        
      case 'Cette semaine':
        // Calculer le début et la fin de la semaine en cours
        final dayOfWeek = now.weekday;
        final startOfWeek = now.subtract(Duration(days: dayOfWeek - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        
        setState(() {
          _dateStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          _dateEnd = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
          _selectedQuickDateOption = option;
        });
        break;
        
      case 'Ce mois-ci':
        // Calculer le début et la fin du mois en cours
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        
        setState(() {
          _dateStart = startOfMonth;
          _dateEnd = endOfMonth;
          _selectedQuickDateOption = option;
        });
        break;
        
      case 'Personnalisé':
        // Ne rien faire, l'utilisateur définira manuellement les dates
        setState(() {
          _selectedQuickDateOption = option;
        });
        break;
    }
  }
  
  // Modifier le widget existant qui affiche les boutons de date
  
  // Remplacer la section des dates avec une version améliorée qui inclut les filtres rapides
  Widget _buildDateFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Période', style: AppStyles.filterTitle),
        
        // Sélection rapide de période
        Wrap(
          spacing: 8,
          children: _quickDateOptions.map((option) {
            return ChoiceChip(
              label: Text(option),
              selected: _selectedQuickDateOption == option,
              onSelected: (selected) {
                if (selected) {
                  _updateDatesByQuickOption(option);
                }
              },
            );
          }).toList(),
        ),
        
        SizedBox(height: 16),
        
        // Champs de dates personnalisées (visibles seulement si 'Personnalisé' est sélectionné)
        if (_selectedQuickDateOption == 'Personnalisé')
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _dateStart ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(Duration(days: 30)), // Permettre dates passées pour les événements récurrents
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _dateStart = picked;
                        // Si la date de fin est avant la date de début, l'ajuster
                        if (_dateEnd != null && _dateEnd!.isBefore(_dateStart!)) {
                          _dateEnd = _dateStart;
                        }
                      });
                    }
                  },
                  child: Text(_dateStart == null 
                      ? 'Date de début' 
                      : DateFormat('dd/MM/yyyy').format(_dateStart!)),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _dateEnd ?? (_dateStart ?? DateTime.now()),
                      firstDate: _dateStart ?? DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _dateEnd = picked;
                      });
                    }
                  },
                  child: Text(_dateEnd == null 
                      ? 'Date de fin' 
                      : DateFormat('dd/MM/yyyy').format(_dateEnd!)),
                ),
              ),
            ],
          ),
        
        SizedBox(height: 16),
      ],
    );
  }

  // *** NOUVELLE MÉTHODE POUR AFFICHER LE POPUP ***
  void _showChoiceInterestUsersPopup(BuildContext context, String targetId, String targetType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          builder: (_, controller) {
            // Passer le controller au widget interne pour le scrolling
            return ChoiceInterestUsersPopup( 
              targetId: targetId, 
              targetType: targetType,
              scrollController: controller, // Passer le controller
            );
          },
        );
      },
    );
  }
}

// Classe pour représenter un lieu ou un événement
class Place {
  final String id;
  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final String image;
  final double rating;
  final List<Map<String, dynamic>>? events;
  final Map<String, dynamic> rawData;

  Place({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.image,
    this.rating = 0,
    this.events,
    required this.rawData,
  });

  factory Place.fromMap(Map<String, dynamic> map) {
    // Extraire les événements si présents
    List<Map<String, dynamic>>? events;
    if (map['events'] != null && map['events'] is List) {
      events = List<Map<String, dynamic>>.from(
        map['events'].map((e) => e is Map<String, dynamic> ? e : {}));
    }
    
    return Place(
      id: map['_id'] ?? map['id'] ?? '',
      name: map['title'] ?? map['intitulé'] ?? map['nom'] ?? map['name'] ?? '',
      description: map['description'] ?? map['détail'] ?? '',
      address: map['address'] ?? map['adresse'] ?? '',
      latitude: _parseDouble(map['latitude']) ?? 
               (_parseDouble(map['location']?['coordinates']?[1]) ?? 0),
      longitude: _parseDouble(map['longitude']) ?? 
                (_parseDouble(map['location']?['coordinates']?[0]) ?? 0),
      category: map['category'] ?? map['catégorie'] ?? '',
      image: map['image'] ?? map['photo'] ?? map['photo_url'] ?? map['imageUrl'] ?? '',
      rating: _parseDouble(map['rating']) ?? _parseDouble(map['note']) ?? 0,
      events: events,
      rawData: Map<String, dynamic>.from(map),
    );
  }
  
  // Getter pour l'URL de l'image (pour faciliter l'accès)
  String get imageUrl => image;
  
  // Utilitaire pour analyser correctement une valeur double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
