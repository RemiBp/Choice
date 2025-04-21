import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import '../widgets/filter_chip.dart' as custom_chips;
import '../widgets/map_selector.dart' as custom_selector;
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../widgets/activity_detail_sheet.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_filter.dart' as filter_models;
import '../widgets/filter_section.dart' as filter_widgets;
import '../configs/map_configs.dart' as configs;
import '../models/map_selector.dart' as app_model;
import '../widgets/map_selector.dart' as map_selector_widget;
import '../services/map_service.dart';
import '../widgets/map_filter_panel.dart';
import '../widgets/map_place_card.dart';
import '../widgets/map_marker_generator.dart' as marker_gen;
import 'map_restaurant_screen.dart' as restaurant_map;
import 'map_leisure_screen.dart' as leisure_map;
import 'map_wellness_screen.dart' as wellness_map;
import '../utils/map_colors.dart' as mapcolors;
import '../configs/map_configs.dart';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../services/friends_service.dart';
import '../widgets/filter_panel.dart';
import '../widgets/maps/adaptive_map_widget.dart';
import '../utils/map_utils.dart';
import '../widgets/filter_chip.dart' as custom_chips;
import '../widgets/map_selector.dart' as custom_selector;
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../widgets/activity_detail_sheet.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_filter.dart';
import '../main.dart';
import '../utils.dart' show getImageProvider;

// Définir une classe MapConfig locale pour éviter les conflits
class MapConfig {
  final String label;
  final String icon;
  final Color color;
  final String mapType; // Utiliser String au lieu d'un enum pour éviter les conflits
  final String route;

  const MapConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.mapType,
    required this.route,
  });
}

class MapFriendsScreen extends StatefulWidget {
  final String? userId;
  final LatLng? initialPosition;
  final double? initialZoom;
  
  const MapFriendsScreen({
    Key? key, 
    this.userId,
    this.initialPosition,
    this.initialZoom,
  }) : super(key: key);

  @override
  _MapFriendsScreenState createState() => _MapFriendsScreenState();
}

class _MapFriendsScreenState extends State<MapFriendsScreen> {
  // Contrôleur de la carte
  final Completer<gmaps.GoogleMapController> _controller = Completer();
  
  // Service pour les appels API
  final MapService _mapService = MapService();
  
  // Paramètres de localisation
  final Location _location = Location();
  gmaps.LatLng _currentPosition = const gmaps.LatLng(48.856614, 2.3522219); // Paris par défaut
  bool _locationPermissionGranted = false;
  double _initialZoom = 14.0; // Ajout du zoom initial
  
  // État de la carte
  final Set<gmaps.Marker> _markers = {};
  bool _isLoading = true;
  String _errorMessage = '';
  
  // État des filtres
  late List<filter_models.FilterSection> _filterSections;
  bool _isFilterPanelVisible = false;
  
  // Données des amis et activités
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _activities = [];
  Map<String, dynamic>? _selectedActivity;
  
  // Préférences d'affichage
  bool _showChoices = true;
  bool _showInterests = true;
  List<String> _selectedFriendIds = [];
  List<String> _selectedCategories = [];
  
  // ID utilisateur (à remplacer par l'authentification réelle)
  final String _userId = 'user_${const Uuid().v4()}';

  // Configuration des maps disponibles
  final List<MapConfig> mapConfigs = [
    MapConfig(
      label: 'Restaurant',
      icon: 'assets/icons/restaurant_map.png',
      color: mapcolors.MapColors.restaurantPrimary,
      mapType: 'restaurant',
      route: '/map/restaurant',
    ),
    MapConfig(
      label: 'Loisir',
      icon: 'assets/icons/leisure_map.png', 
      color: mapcolors.MapColors.leisurePrimary,
      mapType: 'leisure',
      route: '/map/leisure',
    ),
    MapConfig(
      label: 'Bien-être',
      icon: 'assets/icons/wellness_map.png',
      color: mapcolors.MapColors.wellnessPrimary,
      mapType: 'wellness',
      route: '/map/wellness',
    ),
    MapConfig(
      label: 'Amis',
      icon: 'assets/icons/friends_map.png',
      color: mapcolors.MapColors.friendsPrimary,
      mapType: 'friends',
      route: '/map/friends',
    ),
  ];

  // Variables manquantes pour la compatibilité avec MapScreen
  bool _isUsingLiveLocation = false;
  bool _isMapReady = false;
  String? _searchQuery;
  double _searchRadius = 5000;
  List<String> _selectedActivityTypes = [];
  Map<String, dynamic>? _dateRange;

  bool _isComputingMarkers = false;
  String? _lastTappedMarkerId;

  // Ajouter un état d'initialisation et une gestion d'erreur
  bool _isInitialized = false;
  String? _initErrorMessage;

  // Ajouter cette variable d'état avec les autres variables d'état en haut de la classe
  bool _showFilterPanel = false;

  @override
  void initState() {
    super.initState();
    
    // Utiliser la position initiale si fournie
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition!;
    }
    
    // Utiliser le zoom initial si fourni
    if (widget.initialZoom != null) {
      _initialZoom = widget.initialZoom!;
    }
    
    // Initialisation standard
    _initializeScreen();
  }

  // Méthode pour initialiser l'écran de manière sécurisée
  Future<void> _initializeScreen() async {
    try {
      _filterSections = filter_models.DefaultFilters.getFriendsFilters();
      await _initLocationService();
      await _loadFriends();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _initErrorMessage = 'Erreur lors de l\'initialisation: $e';
        _isInitialized = true; // Marquer comme initialisé même en cas d'erreur
      });
      print("❌ Erreur d'initialisation de la carte des amis: $e");
    }
  }
  
  // Initialise le service de localisation
  Future<void> _initLocationService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() {
            _errorMessage = 'Le service de localisation est désactivé';
            _isLoading = false;
          });
          return;
        }
      }
      
      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          setState(() {
            _errorMessage = 'L\'autorisation de localisation est refusée';
            _isLoading = false;
          });
          return;
        }
      }
      
      setState(() {
        _locationPermissionGranted = true;
      });
      
      // Obtenir la position actuelle
      final locationData = await _location.getLocation();
      setState(() {
        _currentPosition = gmaps.LatLng(
          locationData.latitude ?? 48.856614,
          locationData.longitude ?? 2.3522219,
        );
      });
      
      // Charger les activités des amis
      _loadFriendsActivities();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de localisation: $e';
        _isLoading = false;
      });
    }
  }
  
  // Charge la liste des amis
  Future<void> _loadFriends() async {
    try {
      final friends = await _mapService.getUserFriends(_userId);
      
      setState(() {
        _friends = friends;
        
        // Créer les options de filtre pour les amis
        final friendOptions = _friends.map((friend) => 
          filter_models.FilterOption(
            id: friend['id'],
            label: friend['name'],
            iconPath: friend['avatar'],
          )
        ).toList();
        
        // Mettre à jour la section des amis dans les filtres
        for (int i = 0; i < _filterSections.length; i++) {
          if (_filterSections[i].title == 'Amis') {
            _filterSections[i] = _filterSections[i].copyWith(options: friendOptions);
            break;
          }
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des amis: $e');
    }
  }
  
  // Charge les activités des amis depuis le service
  Future<void> _loadFriendsActivities() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      final userId = widget.userId ?? _userId;
      
      // Récupérer les données des activités des amis depuis l'API
      final result = await _mapService.getFriendsMapData(userId: userId);
      
      if (result == null || (result['choices'].isEmpty && result['interests'].isEmpty)) {
        setState(() {
          _isLoading = false;
          _activities = [];
          _markers.clear();
          _errorMessage = 'Aucune activité trouvée. Suivez des amis pour voir leurs choix et intérêts sur la carte.';
        });
        return;
      }
      
      // Transformer et filtrer les données
      final List<Map<String, dynamic>> processedActivities = _processActivities(result);
      
      setState(() {
        _activities = processedActivities;
        _isLoading = false;
        _errorMessage = '';
      });
      
      // Générer les marqueurs pour les activités
      _createMarkers();
    } catch (e) {
      print('❌ Erreur lors du chargement des activités des amis: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Impossible de charger les activités: $e';
      });
    }
  }

  // Traite et filtre les données des activités
  List<Map<String, dynamic>> _processActivities(Map<String, dynamic> result) {
    List<Map<String, dynamic>> allActivities = [];
    
    // Ajouter les choix si activés
    if (_showChoices && result['choices'] is List) {
      for (final choice in result['choices']) {
        if (choice is Map<String, dynamic> && 
            choice.containsKey('latitude') && 
            choice.containsKey('longitude')) {
          
          // Appliquer les filtres ici
          final String activityType = choice['type'] ?? '';
          final String userId = choice['userId'] ?? '';
          
          // Filtrer par amis si nécessaire
          if (_selectedFriendIds.isNotEmpty && !_selectedFriendIds.contains(userId)) {
            continue;
          }
          
          // Filtrer par catégories si nécessaire
          if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(activityType)) {
            continue;
          }
          
          // Calculer le score pour déterminer la taille et la proéminence du marqueur
          final double score = _calculateActivityScore(choice);
          
          // Ajouter l'activité à la liste si elle passe les filtres
          final Map<String, dynamic> activity = {
            ...choice,
            'score': score,
            'id': choice['_id'] ?? choice['id'] ?? '${choice['latitude']}_${choice['longitude']}',
            'isChoice': true,
            'isInterest': false,
          };
          
          allActivities.add(activity);
        }
      }
    }
    
    // Ajouter les intérêts si activés
    if (_showInterests && result['interests'] is List) {
      for (final interest in result['interests']) {
        if (interest is Map<String, dynamic> && 
            interest.containsKey('latitude') && 
            interest.containsKey('longitude')) {
          
          // Appliquer les filtres ici
          final String activityType = interest['type'] ?? '';
          final String userId = interest['userId'] ?? '';
          
          // Filtrer par amis si nécessaire
          if (_selectedFriendIds.isNotEmpty && !_selectedFriendIds.contains(userId)) {
            continue;
          }
          
          // Filtrer par catégories si nécessaire
          if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(activityType)) {
            continue;
          }
          
          // Calculer le score pour déterminer la taille et la proéminence du marqueur
          final double score = _calculateActivityScore(interest);
          
          // Ajouter l'activité à la liste si elle passe les filtres
          final Map<String, dynamic> activity = {
            ...interest,
            'score': score,
            'id': interest['_id'] ?? interest['id'] ?? '${interest['latitude']}_${interest['longitude']}',
            'isChoice': false,
            'isInterest': true,
          };
          
          allActivities.add(activity);
        }
      }
    }
    
    // Trier par score pour que les activités les plus pertinentes soient en avant-plan
    allActivities.sort((a, b) => (b['score'] ?? 0.0).compareTo(a['score'] ?? 0.0));
    
    return allActivities;
  }
  
  // Calculer un score pour une activité basé sur les filtres
  double _calculateActivityScore(Map<String, dynamic> activity) {
    double score = 0.5; // Score de base
    
    // Type d'activité (intérêt ou choix)
    final bool isChoice = activity['isChoice'] ?? false;
    final bool isInterest = activity['isInterest'] ?? false;
    
    // Vérifier que l'activité correspond au filtrage de base
    if (!((isChoice && _showChoices) || (isInterest && _showInterests))) {
      return 0.0; // Score minimal si l'activité ne correspond pas au filtre de base
    }
    
    // Bonus pour les choix (plus élevé que les intérêts)
    if (isChoice) {
      score += 0.2;
    } else if (isInterest) {
      score += 0.1;
    }
    
    // Si des amis spécifiques sont sélectionnés
    if (_selectedFriendIds.isNotEmpty && 
        activity['userId'] != null && 
        _selectedFriendIds.contains(activity['userId'])) {
      score += 0.25;
    }
    
    // Si des catégories spécifiques sont sélectionnées
    if (_selectedCategories.isNotEmpty && 
        activity['type'] != null && 
        _selectedCategories.contains(activity['type'])) {
      score += 0.25;
    }
    
    // Favoriser les activités récentes
    if (activity['date'] != null) {
      try {
        final DateTime createdAt = DateTime.parse(activity['date']);
        final int daysAgo = DateTime.now().difference(createdAt).inDays;
        
        if (daysAgo < 30) {
          // Plus l'activité est récente, plus le score est élevé
          score += 0.2 * (1 - (daysAgo / 30)); // Score maximum pour aujourd'hui, diminue avec le temps
        }
      } catch (e) {
        // Ignorer les erreurs de parsing de date
      }
    }
    
    // Bonus pour les lieux bien notés
    if (activity['rating'] != null) {
      final double rating = (activity['rating'] is num) 
          ? (activity['rating'] as num).toDouble() 
          : 0.0;
      
      if (rating > 0) {
        // Bonus proportionnel à la note
        score += (rating / 5.0) * 0.15;
      }
    }
    
    // Normaliser le score entre 0 et 1
    return min(1.0, max(0.0, score));
  }
  
  // Crée les marqueurs pour la carte
  Future<void> _createMarkers() async {
    final Set<gmaps.Marker> markers = {};
    
    for (final activity in _activities) {
      final String activityId = activity['id'] ?? '';
      final String name = activity['name'] ?? 'Sans nom';
      final String friendId = activity['friendId'] ?? '';
      final String friendName = activity['friendName'] ?? 'Ami';
      final String type = activity['type'] ?? '';
      final bool isChoice = activity['isChoice'] ?? false;
      final bool isInterest = activity['isInterest'] ?? false;
      final double score = activity['score'] ?? 0.5;
      
      // Récupérer l'ami
      final friend = _friends.firstWhere(
        (f) => f['id'] == friendId,
        orElse: () => {'name': friendName, 'avatar': null},
      );
      
      // Coordonnées
      final double lat = activity['latitude'] ?? 0;
      final double lng = activity['longitude'] ?? 0;
      
      if (lat != 0 && lng != 0) {
        final gmaps.LatLng position = gmaps.LatLng(lat, lng);
        
        // Déterminer la couleur du marqueur en fonction du type d'activité
        Color markerColor;
        if (isInterest) {
          markerColor = Colors.blue;
        } else if (isChoice) {
          markerColor = Colors.amber;
        } else {
          markerColor = _getActivityColor(type);
        }
        
        // Générer un marqueur personnalisé en fonction du score
        gmaps.BitmapDescriptor markerIcon;
        
        try {
          // Utiliser la méthode personnalisée pour créer un marqueur plus avancé
          markerIcon = await _createCustomMarkerBitmap(
            color: markerColor,
            score: score,
            rating: activity['rating']?.toDouble() ?? 0.0,
          );
        } catch (e) {
          // Fallback avec une méthode plus simple
          markerIcon = await marker_gen.MapMarkerGenerator.generateFriendMarker(
            friendName,
            markerColor,
          );
        }
        
        final marker = gmaps.Marker(
          markerId: gmaps.MarkerId(activityId),
          position: position,
          icon: markerIcon,
          onTap: () => _onMarkerTapped(activity),
          // Rendre le marqueur plus gros si c'est celui sélectionné
          zIndex: activityId == _lastTappedMarkerId ? 1.0 : 0.0,
        );
        
        markers.add(marker);
      }
    }
    
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
    
    // Ajuster la vue de la carte pour voir tous les marqueurs
    if (markers.isNotEmpty && _isMapReady) {
      _fitMarkersOnMap();
    }
  }
  
  // Créer un bitmap personnalisé pour les marqueurs
  Future<gmaps.BitmapDescriptor> _createCustomMarkerBitmap({
    required Color color,
    required double score,
    required double rating,
    double size = 120,
    bool isSelected = false,
  }) async {
    try {
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..color = color;
      final double radius = size / 2;
      
      // Dessiner le cercle principal
      canvas.drawCircle(Offset(radius, radius), radius, paint);
      
      // Dessiner le bord
      final Paint borderPaint = Paint()
        ..color = isSelected ? Colors.white : color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4 : 2;
      canvas.drawCircle(Offset(radius, radius), radius - 2, borderPaint);
      
      // Dessiner un indicateur de score (plus le score est élevé, plus la taille est grande)
      final double innerRadius = radius * 0.6 * math.max(0.5, score);
      final Paint innerPaint = Paint()..color = isSelected 
        ? Colors.white.withOpacity(0.9) 
        : color.withOpacity(0.6);
      canvas.drawCircle(Offset(radius, radius), innerRadius, innerPaint);
      
      // Dessiner les étoiles pour le rating
      if (rating > 0) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: '★ ${rating.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: isSelected ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.white,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        
        // Centrer le texte
        final double xCenter = (size - textPainter.width) / 2;
        final double yCenter = (size - textPainter.height) / 2;
        textPainter.paint(canvas, Offset(xCenter, yCenter));
      }
      
      // Convertir en image
      final ui.Image image = await pictureRecorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      
      // Convertir l'image en bytes
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (data == null) {
        // Fallback en cas d'erreur
        return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure);
      }
      
      // Convertir en BitmapDescriptor
      return gmaps.BitmapDescriptor.fromBytes(data.buffer.asUint8List());
    } catch (e) {
      print('Erreur lors de la création du marqueur personnalisé: $e');
      return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure);
    }
  }
  
  // Ajuste la vue pour voir tous les marqueurs
  void _fitMarkersOnMap() {
    if (!_controller.isCompleted || _markers.isEmpty) return;
    
    _controller.future.then((controller) {
      double minLat = 90.0;
      double maxLat = -90.0;
      double minLng = 180.0;
      double maxLng = -180.0;
      
      for (final marker in _markers) {
        final lat = marker.position.latitude;
        final lng = marker.position.longitude;
        
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        minLng = math.min(minLng, lng);
        maxLng = math.max(maxLng, lng);
      }
      
      // Ajouter un padding pour éviter que les marqueurs soient collés aux bords
      final double latPadding = (maxLat - minLat) * 0.2;
      final double lngPadding = (maxLng - minLng) * 0.2;
      
      final bounds = gmaps.LatLngBounds(
        southwest: gmaps.LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: gmaps.LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      
      controller.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 50));
    });
  }
  
  // Gère l'événement de tap sur un marqueur
  void _onMarkerTapped(Map<String, dynamic> activity) {
    setState(() {
      _selectedActivity = activity;
      _lastTappedMarkerId = activity['id'];
    });
    
    // Afficher les détails dans une bottom sheet
    _showActivityDetails(activity);
    
    // Recréer les marqueurs pour mettre à jour celui qui est sélectionné
    _createMarkers();
  }
  
  // Affiche les détails d'une activité dans une bottom sheet
  void _showActivityDetails(Map<String, dynamic> activity) {
    final String activityType = activity['type'] ?? '';
    final String activityName = activity['name'] ?? 'Activité sans nom';
    final String friendName = activity['friendName'] ?? 'Ami';
    final String address = activity['address'] ?? 'Adresse non disponible';
    final String imageUrl = activity['photo'] ?? 'https://via.placeholder.com/400x200?text=Activity';
    final double rating = activity['rating'] != null 
      ? (activity['rating'] is num ? (activity['rating'] as num).toDouble() : 0.0) 
      : 0.0;
    final bool isChoice = activity['isChoice'] ?? false;
    final bool isInterest = activity['isInterest'] ?? false;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 280,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec photo
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      image: DecorationImage(
                        image: getImageProvider(imageUrl) ?? AssetImage('assets/images/default_profile.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Afficher la note
                  if (rating > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Badge pour indiquer le type d'activité
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isInterest 
                          ? Colors.blue.withOpacity(0.8)
                          : Colors.amber.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isInterest 
                              ? Icons.star_border
                              : Icons.check_circle_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isInterest ? 'Intérêt' : 'Choix',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Informations
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: getImageProvider(activity['friendAvatar']) ?? const AssetImage('assets/images/default_avatar.png'),
                          backgroundColor: Colors.grey[200],
                          child: getImageProvider(activity['friendAvatar']) == null
                            ? Icon(Icons.person, color: Colors.grey[400])
                            : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isInterest
                                ? "$friendName est intéressé(e) par ce lieu"
                                : "$friendName a visité ce lieu",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activityName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Boutons d'action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline, color: Colors.amber),
                      label: const Text('Profil'),
                      onPressed: () {
                        Navigator.pop(context);
                        if (activity['friendId'] != null) {
                          _navigateToFriendProfile({'id': activity['friendId'], 'name': friendName});
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('Détails'),
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToActivityDetails(activity);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mapcolors.MapColors.friendsPrimary,
                        foregroundColor: Colors.white,
                      ),
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
  
  // Navigation vers les détails complets de l'activité
  void _navigateToActivityDetails(Map<String, dynamic> activity) {
    // TODO: Implémenter la navigation vers les détails complets
    _showSnackBar("Détails de l'activité non disponibles pour le moment");
  }
  
  // Met à jour les filtres et recharge les activités
  void _onFiltersChanged(List<filter_models.FilterSection> updatedSections) {
    // Extraire les options de filtre
    bool showChoices = true;
    bool showInterests = true;
    List<String> selectedFriendIds = [];
    List<String> selectedCategories = [];
    
    for (final section in updatedSections) {
      if (section.title == 'Afficher') {
        for (final option in section.options) {
          if (option.id == 'choices') {
            showChoices = option.isSelected;
          } else if (option.id == 'interests') {
            showInterests = option.isSelected;
          }
        }
      } else if (section.title == 'Amis') {
        selectedFriendIds = section.options
          .where((option) => option.isSelected)
          .map((option) => option.id)
          .toList();
      } else if (section.title == 'Catégories') {
        selectedCategories = section.options
          .where((option) => option.isSelected)
          .map((option) => option.id)
          .toList();
      }
    }
    
    setState(() {
      _filterSections = updatedSections;
      _showChoices = showChoices;
      _showInterests = showInterests;
      _selectedFriendIds = selectedFriendIds;
      _selectedCategories = selectedCategories;
    });
    
    // Recharger les activités
    _loadFriendsActivities();
  }
  
  // Événement lors de la création de la carte
  void _onMapCreated(gmaps.GoogleMapController controller) {
    _controller.complete(controller);
    setState(() {
      _isMapReady = true;
    });
    
    // Si un zoom initial est fourni, l'utiliser
    if (widget.initialZoom != null) {
      controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          _currentPosition, 
          widget.initialZoom!
        )
      );
    }
    
    // Charger les amis et leurs activités
    _loadFriendsActivities();
  }
  
  // Méthode pour appliquer les filtres depuis MapScreen
  void applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _searchRadius = filters['radius'] ?? _searchRadius;
      _searchQuery = filters['keyword'];
      
      // Filtres spécifiques aux amis si présents
      if (filters['selectedFriendIds'] != null && filters['selectedFriendIds'] is List) {
        _selectedFriendIds = List<String>.from(filters['selectedFriendIds']);
      }
      
      if (filters['selectedActivityTypes'] != null && filters['selectedActivityTypes'] is List) {
        _selectedActivityTypes = List<String>.from(filters['selectedActivityTypes']);
      }
      
      if (filters['dateRange'] != null) {
        _dateRange = Map<String, dynamic>.from(filters['dateRange']);
      }
    });
    
    // Rafraîchir les données sur la carte
    _loadFriendsActivities();
  }
  
  // Méthode pour activer la localisation en direct
  void enableLiveLocation() {
    setState(() {
      _isUsingLiveLocation = true;
    });
    
    if (_controller.isCompleted) {
      _controller.future.then((controller) {
        controller.animateCamera(
          gmaps.CameraUpdate.newLatLng(_currentPosition),
        );
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_initErrorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _initErrorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeScreen,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Carte Google Maps
          AdaptiveMapWidget(
            initialPosition: _currentPosition,
            markers: _markers,
            onMapCreated: _onMapCreated,
          ),

          // Sélecteur de carte en haut
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: map_selector_widget.MapSelector(
              currentIndex: 3, // Index 3 pour la carte amis
              mapCount: 4, // Nombre total de cartes
              onMapSelected: _navigateToMapScreen,
            ),
          ),

          // Indicateur de chargement
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Message d'erreur
          if (_errorMessage.isNotEmpty)
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
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadFriends,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mapcolors.MapColors.friendsPrimary,
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),

          // Détails de l'activité sélectionnée
          if (_selectedActivity != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedActivity!['name'] ?? 'Activité',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedActivity = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedActivity!['venue']?['address'] ?? 'Adresse non disponible',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Naviguer vers la page détaillée de l'activité
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mapcolors.MapColors.friendsPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Voir détails'),
                    ),
                  ],
                ),
              ),
            ),

          // Panneau de filtres (affiché quand _showFilterPanel est true)
          if (_showFilterPanel)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filtres',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: mapcolors.MapColors.friendsPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showFilterPanel = false;
                              });
                            },
                          ),
                        ],
                      ),
                      Divider(),
                      Text(
                        'Filtrer par amis, activités et dates',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showFilterPanel = false;
                            });
                            _loadFriendsActivities();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mapcolors.MapColors.friendsPrimary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      // Ajouter le FloatingActionButton pour les filtres
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showFilterPanel = true;
          });
        },
        backgroundColor: mapcolors.MapColors.friendsPrimary,
        child: Icon(Icons.filter_list, color: Colors.white),
        tooltip: 'Filtres',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMapTypeButton(String mapType, String label, Color color, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () => _navigateToMapScreen(mapType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _navigateToMapScreen(String mapType) {
    if (mapType == 'friends') return; // Déjà sur cette carte
    
    // Utiliser l'extension NavigationHelper définie dans main.dart
    context.changeMapType(mapType);
  }

  // Construire un widget pour afficher les statistiques d'intérêt
  Widget _buildInterestStat({
    required String label, 
    required int count, 
    required Color color
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Chip(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: color.withOpacity(0.2),
        label: Text(
          '$label: $count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Afficher les détails d'un ami dans une bottom sheet
  void _showFriendDetails(Map<String, dynamic> friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec avatar et statut
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar de l'ami
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: mapcolors.MapColors.friendsSecondary,
                      backgroundImage: getImageProvider(friend['avatar']) ?? const AssetImage('assets/images/default_avatar.png'),
                      child: getImageProvider(friend['avatar']) == null
                          ? Icon(Icons.person, color: Colors.grey[400])
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Nom et statut
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend['name'] ?? 'Ami',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: friend['online'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                friend['online'] == true ? 'En ligne' : 'Hors ligne',
                                style: TextStyle(
                                  color: friend['online'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                  fontSize: 14,
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
              
              // Activités récentes
              if (friend['activities'] != null && (friend['activities'] as List).isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activités récentes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        (friend['activities'] as List).length > 3
                            ? 3
                            : (friend['activities'] as List).length,
                        (index) {
                          final activity = (friend['activities'] as List)[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: mapcolors.MapColors.friendsSecondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: mapcolors.MapColors.friendsSecondary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getActivityIcon(activity['type']),
                                  color: _getActivityColor(activity['type']),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activity['name'] ?? 'Activité inconnue',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        activity['location'] ?? 'Lieu inconnu',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (activity['date'] != null)
                                  Text(
                                    _formatDate(activity['date']),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              
              // Boutons d'action
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSnackBar('Message envoyé à ${friend['name']}');
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mapcolors.MapColors.friendsPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToFriendProfile(friend);
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('Profil'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mapcolors.MapColors.friendsPrimary,
                          side: BorderSide(color: mapcolors.MapColors.friendsPrimary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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
  
  // Déterminer l'icône appropriée pour le type d'activité
  IconData _getActivityIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'leisure':
        return Icons.theater_comedy;
      case 'wellness':
        return Icons.spa;
      default:
        return Icons.place;
    }
  }
  
  // Obtenir une couleur en fonction du type d'activité
  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
      case 'café':
      case 'bar':
        return mapcolors.MapColors.restaurantPrimary;
      case 'musée':
      case 'théâtre':
      case 'cinéma':
      case 'concert':
        return mapcolors.MapColors.leisurePrimary;
      case 'spa':
      case 'yoga':
      case 'massage':
        return mapcolors.MapColors.wellnessPrimary;
      default:
        return Colors.teal; // Couleur par défaut
    }
  }
  
  // Formatter une date pour affichage
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'À l\'instant';
      }
    } catch (e) {
      return 'Date inconnue';
    }
  }
  
  // Naviguer vers le profil d'un ami
  void _navigateToFriendProfile(Map<String, dynamic> friend) {
    // TODO: Implémenter la navigation vers le profil de l'ami
    _showSnackBar('Navigation vers le profil de ${friend['name']}');
  }

  // Méthode pour afficher un snackbar avec un message
  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
} 