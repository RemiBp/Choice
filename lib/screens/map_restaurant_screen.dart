import 'package:flutter/material.dart' hide FilterChip;
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:location/location.dart' hide PermissionStatus;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/src/enums/location_accuracy.dart' as geo_accuracy;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart' as ui;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import '../utils/constants.dart';
import '../models/place.dart';
import '../constants/colors.dart';
import '../utils/location_helper.dart';
import '../widgets/loading_indicator.dart';
import '../utils/map_colors.dart' as mapcolors;
import '../widgets/filters/filter_chip.dart' as custom_filter;
import '../widgets/maps/adaptive_map_widget.dart';
import '../widgets/map_selector.dart' as widget_selector;
import '../services/map_service.dart';
import 'map_leisure_screen.dart' as leisure_map;
import 'map_wellness_screen.dart' as wellness_map;
import 'map_friends_screen.dart' as friends_map;
import 'producer_screen.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';

class MapRestaurantScreen extends StatefulWidget {
  final gmaps.LatLng? initialPosition;
  final double? initialZoom;

  const MapRestaurantScreen({Key? key, this.initialPosition, this.initialZoom}) : super(key: key);

  @override
  State<MapRestaurantScreen> createState() => MapRestaurantScreenState();
}

class MapRestaurantScreenState extends State<MapRestaurantScreen> with AutomaticKeepAliveClientMixin {
  // Contrôleur de carte
  gmaps.GoogleMapController? _mapController;
  
  // Helper function to create a blue dot BitmapDescriptor (Moved inside)
  Future<gmaps.BitmapDescriptor> _createBlueDotMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.blue;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final double radius = 15.0; // Main dot radius
    final double outerRadius = 20.0; // Outer semi-transparent radius (optional for pulse effect)

    // Draw outer semi-transparent circle (optional)
    // final Paint outerPaint = Paint()..color = Colors.blue.withOpacity(0.3);
    // canvas.drawCircle(Offset(outerRadius, outerRadius), outerRadius, outerPaint);

    // Draw white border
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
    // Draw blue dot
    canvas.drawCircle(Offset(radius, radius), radius - 1, paint); // Subtract 1 for border visibility

    final img = await pictureRecorder.endRecording().toImage(
          (radius * 2).toInt(),
          (radius * 2).toInt(),
        );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
  
  // Service pour les appels API
  late MapService _mapService;
  
  // Position initiale (Paris par défaut)
  gmaps.LatLng _initialPosition = const gmaps.LatLng(48.856614, 2.3522219);
  
  // Timer pour mise à jour de position
  Timer? _locationUpdateTimer;
  
  // Timer pour debounce des requêtes de filtrage
  Timer? _debounceTimer;
  
  // Marqueurs à afficher sur la carte
  Set<gmaps.Marker> _markers = {};
  
  // État de chargement et message d'erreur
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Stocke l'ID du dernier marqueur cliqué pour détecter double-tap
  String? _lastTappedMarkerId;
  
  // Position actuelle de l'utilisateur
  LocationData? _currentPosition;
  
  // Propriété pour les icônes de marqueurs
  Map<String, gmaps.BitmapDescriptor> _markerIcons = {};
  
  // Variables pour les critères de filtre
  List<String> _selectedCategories = [];
  double? _minRating;
  double _minPrice = 0;
  double _maxPrice = 1000;
  String? _searchKeyword;
  double _selectedRadius = 5000;
  bool _openNow = false;
  
  // Nouveaux filtres détaillés (Items)
  double? _minCalories;
  double? _maxCalories;
  double? _maxCarbonFootprint;
  List<String> _selectedNutriScores = [];
  
  // Nouveaux filtres détaillés (Restaurants)
  double? _minServiceRating;
  double? _minLocationRating;
  double? _minPortionRating;
  double? _minAmbianceRating;
  String? _openingHours;
  TimeOfDay? _selectedTime;
  List<String> _selectedDishTypes = [];
  String? _choice;
  int? _minFavorites;
  double? _minItemRating;
  String? _itemKeywords;
  
  // Paramètres d'affichage
  bool _showItemsOnly = false;
  bool _showRestaurantsOnly = false;
  
  // Indique si l'utilisateur utilise sa position en temps réel
  bool _isUsingLiveLocation = false;
  
  // Indique si la carte est prête
  bool _isMapReady = false;
  
  // Indique si un conseil sur les filtres a été affiché
  bool _hasShownFilterHint = false;
  
  // Onglets pour les filtres avancés
  int _selectedFilterTab = 0;
  List<String> _filterTabs = ['Restaurant', 'Items'];
  
  // Flags pour indiquer si des filtres sont actifs dans chaque catégorie
  bool get _hasActiveRestaurantFilters => 
      _selectedCategories.isNotEmpty || 
      _minRating != null || 
      _minPrice > 0 || 
      _maxPrice < 1000 || 
      _searchKeyword != null || 
      _openNow || 
      _minServiceRating != null ||
      _minLocationRating != null ||
      _minPortionRating != null ||
      _minAmbianceRating != null ||
      _minFavorites != null;
  
  bool get _hasActiveItemsFilters =>
      _minCalories != null ||
      _maxCalories != null ||
      _maxCarbonFootprint != null ||
      _selectedNutriScores.isNotEmpty ||
      _minItemRating != null ||
      _itemKeywords != null;
  
  // Flag pour indiquer si on recherche des items directement
  bool _searchingItems = false;
  
  // Nouvelles propriétés pour les icônes de marqueurs
  gmaps.BitmapDescriptor? _defaultMarkerIcon;
  gmaps.BitmapDescriptor? _selectedMarkerIcon;
  gmaps.BitmapDescriptor? _userLocationIcon;
  Map<String, gmaps.BitmapDescriptor> _categoryIcons = {};
  
  // Au début de la classe _MapRestaurantScreenState, après les autres propriétés
  bool _isLoadingLocation = false;
  String? _locationError;
  gmaps.LatLng? _currentLocation;
  gmaps.CameraPosition? _cameraPosition;
  Map<String, dynamic>? _selectedRestaurant;
  
  // Ajouter un nouvel état pour contrôler l'affichage du panneau de filtres
  bool _showFilterPanel = false;
  
  // Ajouter une liste pour les plats correspondants
  List<Map<String, dynamic>> _matchingDishes = [];
  
  // Liste des termes de recherche pour le calcul de score
  List<String> _searchQueries = [];
  
  // Définir la variable pour le rayon de recherche calculé
  double _searchRadius = 5.0; // Rayon en km
  
  // Définir la liste pour les résultats des restaurants (si elle n'existe pas)
  List<Map<String, dynamic>> _restaurantResults = [];
  
  // Déclaration de la variable manquante pour le mode recherche par zone
  bool _isSearchInAreaMode = false;
  
  // --- Helper function to get the correct ImageProvider (copied from recover_producer.dart) ---
  ImageProvider? _getImageProvider(dynamic source) {
    String? imageSource;
    
    // If it's a restaurant object, extract image source with fallbacks
    if (source is Map<String, dynamic>) {
      imageSource = source['photo'] ??
        (source['photos'] is List && source['photos'].isNotEmpty ? source['photos'][0] : null) ??
        source['image'] ??
        source['photo_url'] ??
        source['icon'] ??
        null;
      
      print('🔍 Restaurant image source extraction: $imageSource');
    } else if (source is String) {
      // If it's already a string (direct image source)
      imageSource = source;
      if (imageSource.isNotEmpty) {
        print('🔍 Direct string image source: ${imageSource.substring(0, math.min(30, imageSource.length))}...'); 
      }
    }

    if (imageSource == null || imageSource.isEmpty) {
      print('❌ No image source found');
      return null; // No image source
    }

    if (imageSource.startsWith('data:image')) {
      try {
        print('🔍 Processing Base64 image: ${imageSource.substring(0, math.min(30, imageSource.length))}...');
        final commaIndex = imageSource.indexOf(',');
        if (commaIndex != -1) {
          final base64String = imageSource.substring(commaIndex + 1);
          print('🔍 Base64 length: ${base64String.length} chars');
          
          try {
          final Uint8List bytes = base64Decode(base64String);
            print('✅ Base64 decoded successfully, image size: ${bytes.length} bytes');
          return MemoryImage(bytes);
          } catch (decodeError) {
            print('❌ Base64 decode error: $decodeError');
            return null;
          }
        } else {
          print('❌ Invalid Base64 Data URL format: no comma found');
          return null; // Invalid format
        }
      } catch (e) {
        print('❌ Error processing Base64 image: $e');
        return null; // Decoding error
      }
    } else if (imageSource.startsWith('http')) {
      // Assume it's a network URL
      print('🔍 Using network image: ${imageSource.substring(0, math.min(50, imageSource.length))}...');
        return NetworkImage(imageSource);
    } else {
      print('❓ Unknown image source format: ${imageSource.substring(0, math.min(20, imageSource.length))}...');
      
      // Try to handle it as a network URL anyway as a fallback
      if (imageSource.contains('.jpg') || imageSource.contains('.png') || imageSource.contains('.jpeg')) {
        print('🔄 Trying to load as network image anyway (contains image extension)');
        return NetworkImage(imageSource);
      }
      
      // Returning null for other cases
      return null;
    }
  }
  // --- End Helper ---
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    // Utiliser la position initiale si fournie
    if (widget.initialPosition != null) {
      _initialPosition = gmaps.LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude
      );
    }
    
    _mapService = MapService();
    _loadMarkerIcons();
    _loadUserLocationIcon();
    _getCurrentLocationAndFetch();
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    _locationUpdateTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  /// Vérifie les permissions de localisation
  Future<void> _checkLocationPermissionAndFetch() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });
      
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          _locationError = 'Les permissions de localisation sont refusées';
          _isLoadingLocation = false;
        });
        return;
      }
      
      Position position = await _getCurrentLocation();
        setState(() {
        _currentLocation = gmaps.LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
        _locationError = null;
      });
      
      // Charger les restaurants à proximité
      _fetchRestaurants();
    } catch (e) {
      setState(() {
        _locationError = 'Erreur: $e';
        _isLoadingLocation = false;
      });
    }
  }

  /// Vérifier les permissions de localisation
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }

  /// Obtenir la position actuelle
  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: geo_accuracy.LocationAccuracy.high
    );
  }
  
  /// Configurer les mises à jour de position
  void _setupLocationUpdates(Location location) {
    _locationUpdateTimer?.cancel();
    
    // Mettre à jour la position toutes les 30 secondes
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final currentPosition = await location.getLocation();
        
        if (mounted && _isUsingLiveLocation) {
          setState(() {
            _currentPosition = currentPosition;
            
            // Mettre à jour la position sur la carte si nous suivons l'utilisateur
            if (_isUsingLiveLocation && _mapController != null) {
              _mapController!.animateCamera(
                gmaps.CameraUpdate.newLatLng(
                  gmaps.LatLng(
                    currentPosition.latitude ?? 48.856614,
                    currentPosition.longitude ?? 2.3522219,
                  ),
                ),
              );
            }
          });
        }
      } catch (e) {
        print("❌ Erreur lors de la mise à jour de la position: $e");
      }
    });
  }
  
  /// Appliquer des filtres à la carte
  void applyFilters(Map<String, dynamic> filters) {
    setState(() {
      // Appliquer tous les filtres reçus
      _selectedRadius = filters['radius'] ?? _selectedRadius;
      _minRating = filters['minRating'];
      _minPrice = filters['minPrice'] ?? _minPrice;
      _maxPrice = filters['maxPrice'] ?? _maxPrice;
      
      if (filters['categories'] != null) {
        _selectedCategories = List<String>.from(filters['categories']);
      }
      
      _searchKeyword = filters['keyword'];
      
      // Filtres avancés si présents
      _openNow = filters['openNow'] ?? _openNow;
      _minServiceRating = filters['minServiceRating'];
      _minLocationRating = filters['minLocationRating'];
      _minPortionRating = filters['minPortionRating'];
      _minAmbianceRating = filters['minAmbianceRating'];
      _choice = filters['choice'];
      _minFavorites = filters['minFavorites'];
      
      // Filtres pour items
      _minCalories = filters['minCalories'];
      _maxCalories = filters['maxCalories'];
      _maxCarbonFootprint = filters['maxCarbonFootprint'];
      _minItemRating = filters['minItemRating'];
      
      if (filters['selectedNutriScores'] != null) {
        _selectedNutriScores = List<String>.from(filters['selectedNutriScores']);
      }
      
      if (filters['selectedDishTypes'] != null) {
        _selectedDishTypes = List<String>.from(filters['selectedDishTypes']);
      }
      
      _itemKeywords = filters['itemKeywords'];
    });
    
    // Lancer la recherche avec les nouveaux filtres
    _fetchRestaurants();
  }
  
  /// Active le mode de localisation en direct
  void enableLiveLocation() {
    setState(() {
      _isUsingLiveLocation = true;
    });
    
    // Déplacer la caméra vers la position actuelle
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLng(_currentLocation!),
      );
    } else {
      _getCurrentLocationAndFetch();
    }
  }
  
  /// Récupérer les restaurants autour de l'utilisateur
  Future<void> _fetchRestaurants() async {
    if (_isLoading || !mounted) return;
    
    // Annuler le debounce précédent si existant
    _debounceTimer?.cancel();
    
    // Attendre 500ms avant d'exécuter la requête pour éviter les appels multiples
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return; // Vérifier si toujours monté après le délai
      
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _selectedRestaurant = null;
        _matchingDishes = [];
      });
      
      try {
        final String? currentUserId = getCurrentUserId(context);
        final double latitude = _currentLocation?.latitude ?? _initialPosition.latitude;
        final double longitude = _currentLocation?.longitude ?? _initialPosition.longitude;
            final Map<String, String> queryParams = {
              'page': '1',
          'limit': '75',
          'lat': latitude.toString(),
          'lng': longitude.toString(),
          'radius': _selectedRadius.toString(),
        };
        if (currentUserId != null) {
          queryParams['userId'] = currentUserId;
        }
        if (_searchKeyword != null && _searchKeyword!.isNotEmpty) queryParams['searchKeyword'] = _searchKeyword!;
        if (_selectedCategories.isNotEmpty) queryParams['cuisine_type'] = _selectedCategories.join(',');
        if (_minRating != null) queryParams['min_rating'] = _minRating!.toStringAsFixed(1);
        if (_openNow) queryParams['business_status'] = 'OPERATIONAL';
        if (_minFavorites != null) queryParams['min_followers'] = _minFavorites!.toString();
        if (_minServiceRating != null) queryParams['minServiceRating'] = _minServiceRating!.toStringAsFixed(1);
        if (_minAmbianceRating != null) queryParams['minAmbianceRating'] = _minAmbianceRating!.toStringAsFixed(1);
        if (_minPortionRating != null) queryParams['minPortionRating'] = _minPortionRating!.toStringAsFixed(1);
        if (_itemKeywords != null && _itemKeywords!.isNotEmpty) queryParams['itemKeywords'] = _itemKeywords!;
        if (_minCalories != null) queryParams['min_calories'] = _minCalories!.toString();
        if (_maxCalories != null) queryParams['max_calories'] = _maxCalories!.toString();
        if (_maxCarbonFootprint != null) queryParams['max_carbon_footprint'] = _maxCarbonFootprint!.toString();
        if (_minItemRating != null) queryParams['min_item_rating'] = _minItemRating!.toStringAsFixed(1);
        if (_selectedNutriScores.isNotEmpty) queryParams['nutri_scores'] = _selectedNutriScores.join(',');
        if (_minPrice > 0) queryParams['minPrice'] = _minPrice.toStringAsFixed(0);
        if (_maxPrice < 1000) queryParams['maxPrice'] = _maxPrice.toStringAsFixed(0);
        print('📡 Calling /advanced-search with params: $queryParams');
        final responseData = await _mapService.fetchAdvancedRestaurants(queryParams);
        if (!mounted) return;
        if (responseData['success'] == true) {
          List<dynamic> restaurants = responseData['results'] ?? [];
          print('✅ Received [32m${restaurants.length}[0m restaurants from backend.');
              if (restaurants.isNotEmpty) {
                _addRestaurantMarkers(restaurants);
          } else {
            _markers.clear();
            _addUserLocationMarker();
                  _errorMessage = 'Aucun restaurant trouvé avec ces critères.';
              }
          setState(() { _isLoading = false; });
        } else {
          _markers.clear();
          _addUserLocationMarker();
              setState(() {
                _isLoading = false;
            _errorMessage = responseData['message'] ?? 'Erreur lors de la récupération des restaurants';
              });
            }
          } catch (e) {
        print('❌ Error fetching restaurants: $e');
        _markers.clear();
        _addUserLocationMarker();
            if (mounted) {
              setState(() {
                _isLoading = false;
            _errorMessage = 'Erreur de connexion: ${e.toString()}';
          });
        }
      }
    });
  }
  
  /// Retourne l'icône de marqueur appropriée en fonction du lieu
  gmaps.BitmapDescriptor _getMarkerIcon(Map<String, dynamic> place) {
    // Obtenir la note et déterminer la couleur
    double rating = 0.0;
    if (place['rating'] != null) {
      rating = place['rating'] is num ? (place['rating'] as num).toDouble() : 0.0;
    }
    
    // Si on a une icône personnalisée pour cette catégorie, l'utiliser
    if (place['category'] != null && _categoryIcons.containsKey(place['category'])) {
      return _categoryIcons[place['category']]!;
    }
    
    // Sinon, utiliser une icône standard avec teinte basée sur la note
    double hue = _getMarkerHue(rating / 5.0);
    return gmaps.BitmapDescriptor.defaultMarkerWithHue(hue);
  }
  
  /// Calcule la teinte du marqueur en fonction de la note (normalisée entre 0 et 1)
  double _getMarkerHue(double normalizedRating) {
    // Gradient de couleurs de rouge (0) à vert (120) en passant par jaune (60)
    if (normalizedRating <= 0.2) {
      return gmaps.BitmapDescriptor.hueRed; // Rouge pour les mauvaises notes
    } else if (normalizedRating <= 0.4) {
      return gmaps.BitmapDescriptor.hueOrange; // Orange pour les notes moyennes-basses
    } else if (normalizedRating <= 0.6) {
      return gmaps.BitmapDescriptor.hueYellow; // Jaune pour les notes moyennes
    } else if (normalizedRating <= 0.8) {
      return 90.0; // Vert clair pour les bonnes notes
    } else {
      return gmaps.BitmapDescriptor.hueGreen; // Vert foncé pour les excellentes notes
    }
  }
  
  /// Construire le texte de description pour le snippet du marqueur
  String _buildSnippet(Map<String, dynamic> restaurant) {
    final List<String> parts = [];
    
    // Ajouter la notation si disponible
    if (restaurant['rating'] != null) {
      parts.add('${restaurant['rating']}⭐');
    }
    
    // Ajouter la catégorie si disponible
    if (restaurant['category'] != null) {
      parts.add(restaurant['category'].toString());
    }
    
    // Ajouter une indication de prix si disponible
    if (restaurant['price_level'] != null) {
      final int priceLevel = restaurant['price_level'] is int 
          ? restaurant['price_level'] 
          : int.tryParse(restaurant['price_level'].toString()) ?? 0;
      
      parts.add('${'€' * priceLevel}');
    }
    
    return parts.join(' · ');
  }
  
  // Stylized restaurant detail card
  Widget _showRestaurantDetails(Map<String, dynamic> restaurant) {
    setState(() {
      _selectedRestaurant = restaurant;
    });

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Si nous avons des plats correspondants à la recherche, les afficher en premier
            if (_matchingDishes.isNotEmpty)
              Container(
                padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.search, size: 16, color: mapcolors.MapColors.restaurantPrimary),
                        const SizedBox(width: 4),
                        Text(
                          "Plats correspondants à \"${_itemKeywords ?? ''}\"",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: mapcolors.MapColors.restaurantPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _matchingDishes.length,
                        itemBuilder: (context, index) {
                          final dish = _matchingDishes[index];
                          final dishName = dish['name'] ?? dish['nom'] ?? 'Plat';
                          final dishPrice = dish['price'] ?? dish['prix'] ?? '€';
                          final dishDesc = dish['description'] ?? '';
                          final dishPhoto = dish['photo_url'] ?? dish['photo'] ?? dish['image'] ?? '';
                          
                          return GestureDetector(
                            onTap: () {
                              // Naviguer vers la page du producteur avec focus sur ce plat
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProducerScreen(
                                    producerId: restaurant['_id'].toString(),
                                    userId: getCurrentUserId(context),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Photo du plat
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                    child: SizedBox(
                                      height: 70,
                                      width: double.infinity,
                                      child: _getImageProvider(dishPhoto) != null
                                          ? Image(
                                              image: _getImageProvider(dishPhoto)!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[200],
                                                  child: Icon(
                                                    Icons.restaurant_menu,
                                                    size: 30,
                                                    color: mapcolors.MapColors.restaurantPrimary,
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              color: Colors.grey[200],
                                              child: Icon(
                                                Icons.restaurant_menu,
                                                size: 30,
                                                color: mapcolors.MapColors.restaurantPrimary,
                                              ),
                                            ),
                                    ),
                                  ),
                                  // Infos du plat
                                  Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dishName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          dishPrice is num ? '${dishPrice.toStringAsFixed(2)}€' : dishPrice.toString(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: mapcolors.MapColors.restaurantPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              ),
            
            // Restaurant Header with Image (le reste du code inchangé)
            // ... existing code ...
            
            // Restaurant Header with Image
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Restaurant image (with fallback)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _getImageProvider(restaurant) != null
                        ? Image(
                            image: _getImageProvider(restaurant)!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200], // Utiliser Colors.grey[200]
                                child: Icon(
                                  Icons.restaurant,
                                  size: 40,
                                  color: mapcolors.MapColors.restaurantPrimary,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200], // Utiliser Colors.grey[200]
                            child: Icon(
                              Icons.restaurant,
                              size: 40,
                              color: mapcolors.MapColors.restaurantPrimary,
                            ),
                          ),
                  ),
                ),
                
                // Restaurant info overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + Rating 
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                restaurant['name'] ?? 'Restaurant',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (restaurant['rating'] != null) ...[
                              Text(
                                (restaurant['rating'] as num).toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Restaurant Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Category chip
                      if (restaurant['category'] != null && restaurant['category'] is List && restaurant['category'].isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: mapcolors.MapColors.restaurantPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            restaurant['category'][0].toString(),
                            style: TextStyle(fontSize: 12, color: mapcolors.MapColors.restaurantPrimary),
                          ),
                        ),
                      
                      // Cuisine type chip
                      if (restaurant['cuisine_type'] != null && restaurant['cuisine_type'] is List && restaurant['cuisine_type'].isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: mapcolors.MapColors.restaurantPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            restaurant['cuisine_type'][0].toString(),
                            style: TextStyle(fontSize: 12, color: mapcolors.MapColors.restaurantPrimary),
                          ),
                        ),
                      
                      // Top Match badge if high relevance
                      if (_calculateRelevanceScore(restaurant) > 0.7)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.thumb_up, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                "TOP MATCH",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Address and distance
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          restaurant['address'] ?? restaurant['formatted_address'] ?? 'Adresse non spécifiée',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (restaurant['distance'] != null)
                        Text(
                          '${(restaurant['distance'] as num).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Social stats (interests and choices)
                  _buildSocialStatsRow(restaurant),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Directions button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _openInMaps(restaurant); // Appel correct
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Itinéraire'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mapcolors.MapColors.restaurantPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // View details button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _navigateToRestaurantDetail, // Appel sans argument
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Voir la fiche'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: mapcolors.MapColors.restaurantPrimary,
                            side: BorderSide(color: mapcolors.MapColors.restaurantPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }
  
  // Naviguer vers la page détaillée du restaurant (sans argument)
  void _navigateToRestaurantDetail() {
    if (_selectedRestaurant != null) {
      final String id = _selectedRestaurant!['_id']?.toString() ?? 
                         _selectedRestaurant!['id']?.toString() ?? '';
      
      if (id.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: id,
              userId: getCurrentUserId(context),
            ),
          ),
        );
      }
    }
  }
  
  // Fonction pour ouvrir l'itinéraire dans une app de cartographie
  Future<void> _openInMaps(Map<String, dynamic> restaurant) async {
    final coords = getProducerCoords(restaurant);
    if (coords == null) return;
    
    final lat = coords.latitude;
    final lng = coords.longitude;
    final String query = Uri.encodeComponent("${coords.latitude},${coords.longitude}");
    final String label = Uri.encodeComponent(restaurant['name'] ?? 'Destination');

    final googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    final appleMapsUrl = Uri.parse('maps://?q=$label&ll=$lat,$lng');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl);
    } else {
      print("Impossible d'ouvrir une application de cartographie pour l'itinéraire.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir une application de cartographie.")),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Afficher Google Maps
          AdaptiveMapWidget(
            initialPosition: _initialPosition,
            markers: _markers,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
          ),
          
          // Sélecteur de carte
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: widget_selector.MapSelector(
              currentIndex: 0, // Index 0 pour la carte restaurant
              mapCount: 4, // Nombre total de cartes
              onMapSelected: _navigateToMapScreen,
            ),
          ),
          
          // Bouton "Rechercher dans cette zone"
          if (_isMapReady && _cameraPosition != null && _cameraPosition!.zoom > 13 && !_isSearchInAreaMode)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher dans cette zone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mapcolors.MapColors.restaurantPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                  ),
                  onPressed: _searchInThisArea,
                ),
              ),
            ),
            
          // Bouton de réinitialisation de la recherche
          if (_isMapReady && _isSearchInAreaMode)
            Positioned(
              top: 80,
              right: 16,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.extended(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réinitialiser'),
                  backgroundColor: Colors.white,
                  foregroundColor: mapcolors.MapColors.restaurantPrimary,
                  elevation: 4,
                  onPressed: _resetSearch,
                ),
            ),
          ),
          
          // Indicateur de chargement
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
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
                      _errorMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchRestaurants,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mapcolors.MapColors.restaurantPrimary,
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          
          // Affichage des détails du restaurant sélectionné  
          if (_selectedRestaurant != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Builder( // Use Builder to get context for image provider
                              builder: (context) {
                                final imageSource = _selectedRestaurant?['photo'] as String?;
                                final imageProvider = _getImageProvider(imageSource);
                                
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
                                          print("❌ Error loading image in details card: $error");
                                          return Center(child: Icon(Icons.broken_image, color: Colors.grey[600])); 
                                        },
                                      )
                                    : Center(child: Icon(Icons.restaurant, color: Colors.grey[600])), // Icon if no image
                                );
                              }
                            )
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedRestaurant?['name'] ?? 'Restaurant',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 24, width: 24,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            _selectedRestaurant = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _selectedRestaurant?['address'] ?? 'Adresse non disponible',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                // Use Wrap for chips to prevent overflow
                                Wrap(
                                  spacing: 6.0, // Horizontal spacing
                                  runSpacing: 4.0, // Vertical spacing
                                  children: [
                                    // Rating
                                    if (_selectedRestaurant?['rating'] != null)
                                      _buildInfoChip(
                                        icon: Icons.star,
                                        text: '${_selectedRestaurant!['rating']}',
                                        color: Colors.amber,
                                      ),
                                    // Follower Count
                                    _buildFollowerCountWidget(_selectedRestaurant),
                                  ],
                                ),
                                SizedBox(height: 8),
                                _buildSocialStatsRow(_selectedRestaurant!),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _navigateToRestaurantDetail,
                          icon: Icon(Icons.info_outline, size: 20),
                          label: Text('Voir détails'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mapcolors.MapColors.restaurantPrimary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (_matchingDishes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.restaurant_menu, color: Colors.blue.shade400, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                        _matchingDishes[0]['name'] ?? _matchingDishes[0]['nom'] ?? '',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                                      ),
                                      if (_matchingDishes[0]['category'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Text(
                                            _matchingDishes[0]['category'].toString(),
                                            style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                                          ),
                                        ),
                                      Row(
                                            children: [
                                          if (_matchingDishes[0]['price'] != null || _matchingDishes[0]['prix'] != null)
                                            Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${_matchingDishes[0]['price'] ?? _matchingDishes[0]['prix']} €',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 13),
                                              ),
                                            ),
                                          if (_matchingDishes[0]['nutri_score'] != null)
                                                Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Nutri-score: ${_matchingDishes[0]['nutri_score']}',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 13),
                                              ),
                                            ),
                                          if (_matchingDishes[0]['calories'] != null)
                                            Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${_matchingDishes[0]['calories']} kcal',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800, fontSize: 13),
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
                              ),
                            ],
                          ),
                        ),
                    ],
                      ),
                    ],
                  ),
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
                              color: mapcolors.MapColors.restaurantPrimary,
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
                      // Onglets de filtres
                      Row(
                        children: List.generate(_filterTabs.length, (index) {
                          final bool hasActiveFilters = index == 0 
                              ? _hasActiveRestaurantFilters 
                              : _hasActiveItemsFilters;
                              
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilterTab = index;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedFilterTab == index
                                          ? mapcolors.MapColors.restaurantPrimary
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                  _filterTabs[index],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedFilterTab == index
                                        ? mapcolors.MapColors.restaurantPrimary
                                            : hasActiveFilters
                                                ? mapcolors.MapColors.restaurantPrimary.withOpacity(0.7)
                                        : Colors.grey,
                                        fontWeight: _selectedFilterTab == index || hasActiveFilters
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                    ),
                                    if (hasActiveFilters && _selectedFilterTab != index)
                                      Positioned(
                                        right: 40,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: mapcolors.MapColors.restaurantPrimary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 20),

                      // Container pour le contenu des filtres avec défilement
                      Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: SingleChildScrollView(
                          child: IndexedStack(
                            index: _selectedFilterTab,
                            children: [
                              // Filtres Restaurant (fusionnés avec Général)
                              _buildRestaurantFilters(),
                              
                              // Filtres Items
                              _buildItemFilters(),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton(
                            onPressed: _clearFilters,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: mapcolors.MapColors.restaurantPrimary),
                            ),
                            child: Text(
                              'Réinitialiser',
                              style: TextStyle(color: mapcolors.MapColors.restaurantPrimary),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showFilterPanel = false;
                              });
                              _fetchRestaurants();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mapcolors.MapColors.restaurantPrimary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Appliquer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Search in this area button
          if (_isMapReady && _cameraPosition != null && _cameraPosition!.zoom > 13 && !_isSearchInAreaMode)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher dans cette zone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mapcolors.MapColors.restaurantPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                  ),
                  onPressed: _searchInThisArea,
                ),
              ),
            ),
            
          // Reset search button (only when in area search mode)
          if (_isMapReady && _isSearchInAreaMode)
            Positioned(
              top: 70,
              right: 16,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.extended(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réinitialiser'),
                  backgroundColor: Colors.white,
                  foregroundColor: mapcolors.MapColors.restaurantPrimary,
                  elevation: 4,
                  onPressed: _resetSearch,
                ),
              ),
            ),
        ],
      ),
      // Ajouter le FloatingActionButton pour les filtres
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: FloatingActionButton(
          onPressed: () {
            setState(() {
              _showFilterPanel = true;
            });
          },
          backgroundColor: mapcolors.MapColors.restaurantPrimary,
          child: Icon(Icons.filter_list, color: Colors.white),
          tooltip: 'Filtres',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const SizedBox(height: 60),
    );
  }

  /// Récupère la position actuelle de l'utilisateur
  Future<void> _getCurrentLocationAndFetch() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });
      
      bool hasPermission = await _checkLocationPermission();
      if (!mounted) return; // Vérifier si toujours monté après l'opération asynchrone
      
      if (!hasPermission) {
        setState(() {
          _locationError = 'Les permissions de localisation sont refusées';
          _isLoadingLocation = false;
        });
        return;
      }
      
      Position position = await _getCurrentLocation();
      if (!mounted) return; // Vérifier si toujours monté après l'opération asynchrone
      
      setState(() {
        _currentLocation = gmaps.LatLng(position.latitude, position.longitude);
        _initialPosition = _currentLocation!;
        _isLoadingLocation = false;
        _locationError = null;
      });
      
      // Charger les restaurants à proximité
      _fetchRestaurants();

      // Ajouter le marqueur de la position utilisateur
      _addUserLocationMarker();
    } catch (e) {
      if (!mounted) return; // Vérifier si toujours monté avant setState final
      
      setState(() {
        _locationError = 'Erreur: $e';
        _isLoadingLocation = false;
      });
    }
  }
  
  /// Charge les icônes des marqueurs pour la carte
  Future<void> _loadMarkerIcons() async {
    try {
      // Utiliser des icônes par défaut en attendant de configurer SVG
      setState(() {
        _defaultMarkerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed);
        _selectedMarkerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue);
        _userLocationIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen);
        
        // Icônes par catégorie
        _categoryIcons = {
          'restaurant': gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
          'cafe': gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
          'bar': gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueViolet),
          'bakery': gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueYellow),
          'food': gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRose),
          'meal_takeaway': gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueCyan),
          'meal_delivery': gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
        };
      });
      
      // Note pour l'implémentation SVG future:
      // Pour utiliser des icônes SVG, nous aurons besoin d'une approche différente:
      // 1. Charger le SVG avec flutter_svg
      // 2. Convertir le SVG en Bitmap (ByteData)
      // 3. Créer un BitmapDescriptor à partir des bytes
      
      /* 
      // Exemple de code pour l'implémentation future avec SVG
      Future.microtask(() async {
        try {
          // Convertir les SVG en BitmapDescriptor
          _defaultMarkerIcon = await _svgToBitmapDescriptor('assets/images/custom_marker.svg', color: Colors.red, size: 120);
          _selectedMarkerIcon = await _svgToBitmapDescriptor('assets/images/custom_marker.svg', color: Colors.blue, size: 140);
          _userLocationIcon = await _svgToBitmapDescriptor('assets/images/custom_marker.svg', color: Colors.green, size: 50);
          
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          print('❌ Erreur lors du chargement des icônes SVG: $e');
        }
      });
      */
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du chargement des icônes: $e');
    }
  }
  
  /// Load custom blue dot icon
  Future<void> _loadUserLocationIcon() async {
    try {
      _userLocationIcon = await _createBlueDotMarker();
      if (mounted) {
        setState(() {
          // Potentially update the existing user marker if map is already created
          _addUserLocationMarker(); 
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement de l\'icône utilisateur: $e');
      // Fallback to default blue marker
      if (mounted) {
        setState(() {
          _userLocationIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure);
        });
      }
    }
  }

  /// Convertir des bytes d'une image asset en Uint8List
  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    Uint8List bytes = data.buffer.asUint8List();
    
    // Dans une vraie implémentation, nous redimensionnerions l'image
    // Mais pour simplifier et éviter les dépendances complexes,
    // nous retournons simplement les bytes bruts
    return bytes;
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
          mapType = 'restaurant';
      }
    } else {
      mapType = value.toString();
    }
    if (mapType == 'restaurant') return;
    context.changeMapType(mapType);
  }

  /// Ajouter des marqueurs pour les restaurants trouvés
  void _addRestaurantMarkers(List<dynamic> restaurants) {
    if (!mounted) return;
    final Set<gmaps.Marker> newMarkers = {};
    
    // Ajouter le marqueur de localisation de l'utilisateur si nécessaire
    if (_isUsingLiveLocation) {
    _addUserLocationMarker(targetSet: newMarkers);
    }
    
    // Rechercher des items spécifiques dans le menu
    for (final restaurantData in restaurants) {
      if (restaurantData is Map<String, dynamic>) {
        final double score = (restaurantData['relevanceScore'] as num?)?.toDouble() ?? 0.0;
        
        // Si on recherche un item spécifique, trouver les items correspondants
        List<Map<String, dynamic>> matchingItems = [];
        if (_itemKeywords != null && _itemKeywords!.isNotEmpty) {
          // Chercher dans les différentes structures de menu
          final menuPaths = [
            'structured_data.Menus Globaux.inclus.items',
            'Menus Globaux.inclus.items',
            'structured_data.Items Indépendants.items',
            'Items Indépendants.items',
            'menu'
          ];
          
          for (final path in menuPaths) {
            final parts = path.split('.');
            dynamic current = restaurantData;
            bool pathExists = true;
            
            // Naviguer dans l'objet selon le chemin
            for (final part in parts) {
              if (current == null || current is! Map<String, dynamic> || !current.containsKey(part)) {
                pathExists = false;
                break;
              }
              current = current[part];
            }
            
            // Si le chemin existe et que c'est une liste, chercher les items correspondants
            if (pathExists && current is List) {
              for (final item in current) {
                if (item is Map<String, dynamic>) {
                  final itemName = item['name'] ?? item['nom'] ?? '';
                  final itemDesc = item['description'] ?? '';
                  
                  if (itemName.toString().toLowerCase().contains(_itemKeywords!.toLowerCase()) ||
                      itemDesc.toString().toLowerCase().contains(_itemKeywords!.toLowerCase())) {
                    // Ajouter à la liste des items correspondants
                    matchingItems.add(item);
                  }
                }
              }
            }
          }
        }
        
        // Garder trace des items correspondants
        if (matchingItems.isNotEmpty) {
          restaurantData['matchingItems'] = matchingItems;
        }
        
        // Créer un snippet plus détaillé si des items correspondent
        String snippet = _buildSnippet(restaurantData);
        if (matchingItems.isNotEmpty) {
          final List<String> itemNames = matchingItems.map((item) => 
            "${item['name'] ?? item['nom'] ?? 'Item'} (${item['price'] ?? item['prix'] ?? '€'})").toList();
          
          snippet += "\n🍽️ Plats correspondants: ${itemNames.join(', ')}";
        }
        
        // Ajouter le marker avec le snippet amélioré
        final marker = gmaps.Marker(
          markerId: gmaps.MarkerId(restaurantData['_id'].toString()),
          position: _getRestaurantPosition(restaurantData),
          icon: _getMarkerIcon(restaurantData),
          infoWindow: gmaps.InfoWindow(
            title: restaurantData['name'],
            snippet: snippet,
          ),
          onTap: () {
            setState(() {
              _selectedRestaurant = restaurantData;
              if (matchingItems.isNotEmpty) {
                _matchingDishes = matchingItems;
              } else {
                _matchingDishes = [];
              }
            });
          },
        );
        
        newMarkers.add(marker);
      }
    }
    
    setState(() {
      _markers = newMarkers;
    });
  }
  
  /// Obtient la position géographique d'un restaurant en gérant les différents formats
  gmaps.LatLng _getRestaurantPosition(Map<String, dynamic> restaurant) {
    // Format GeoJSON (MongoDB)
    if (restaurant['gps_coordinates'] != null && 
        restaurant['gps_coordinates']['coordinates'] != null && 
        restaurant['gps_coordinates']['coordinates'] is List && 
        restaurant['gps_coordinates']['coordinates'].length >= 2) {
      final lng = (restaurant['gps_coordinates']['coordinates'][0] as num).toDouble();
      final lat = (restaurant['gps_coordinates']['coordinates'][1] as num).toDouble();
      return gmaps.LatLng(lat, lng);
    } 
    // Format Google Maps API
    else if (restaurant['geometry'] != null && restaurant['geometry']['location'] != null) {
      final lat = restaurant['geometry']['location']['lat'] is double ? 
        restaurant['geometry']['location']['lat'] as double : 
        double.tryParse(restaurant['geometry']['location']['lat'].toString()) ?? 0.0;
      final lng = restaurant['geometry']['location']['lng'] is double ? 
        restaurant['geometry']['location']['lng'] as double : 
        double.tryParse(restaurant['geometry']['location']['lng'].toString()) ?? 0.0;
      return gmaps.LatLng(lat, lng);
    } 
    // Format simple lat/lng
    else if (restaurant['latitude'] != null && restaurant['longitude'] != null) {
      final lat = (restaurant['latitude'] is num) ? 
        (restaurant['latitude'] as num).toDouble() : 
        double.tryParse(restaurant['latitude'].toString()) ?? 0.0;
      final lng = (restaurant['longitude'] is num) ? 
        (restaurant['longitude'] as num).toDouble() : 
        double.tryParse(restaurant['longitude'].toString()) ?? 0.0;
      return gmaps.LatLng(lat, lng);
    } 
    // Valeur par défaut
    return const gmaps.LatLng(0, 0);
  }
  
  /// Calcule un score de pertinence pour un restaurant basé sur plusieurs critères
  double _calculateRelevanceScore(Map<String, dynamic> restaurant) {
    double score = 0.0;
    
    // Vérifier si les données nécessaires sont présentes
    if (_currentLocation == null) {
      return 0.0;
    }
    
    // Récupérer les coordonnées du restaurant - Traiter les différents formats
    double? restaurantLat, restaurantLng;
    
    // Format GeoJSON (MongoDB)
    if (restaurant['gps_coordinates'] != null && 
        restaurant['gps_coordinates']['coordinates'] != null && 
        restaurant['gps_coordinates']['coordinates'] is List && 
        restaurant['gps_coordinates']['coordinates'].length >= 2) {
      restaurantLng = (restaurant['gps_coordinates']['coordinates'][0] as num).toDouble();
      restaurantLat = (restaurant['gps_coordinates']['coordinates'][1] as num).toDouble();
    } 
    // Format Google Maps API
    else if (restaurant['geometry'] != null && restaurant['geometry']['location'] != null) {
      if (restaurant['geometry']['location']['lat'] is double) {
        restaurantLat = restaurant['geometry']['location']['lat'] as double;
        restaurantLng = restaurant['geometry']['location']['lng'] as double;
      } else {
        restaurantLat = double.tryParse(restaurant['geometry']['location']['lat'].toString()) ?? 0.0;
        restaurantLng = double.tryParse(restaurant['geometry']['location']['lng'].toString()) ?? 0.0;
      }
    } 
    // Format simple avec latitude/longitude directes
    else if (restaurant['latitude'] != null && restaurant['longitude'] != null) {
      restaurantLat = (restaurant['latitude'] is num) ? (restaurant['latitude'] as num).toDouble() 
                                                      : double.tryParse(restaurant['latitude'].toString()) ?? 0.0;
      restaurantLng = (restaurant['longitude'] is num) ? (restaurant['longitude'] as num).toDouble() 
                                                       : double.tryParse(restaurant['longitude'].toString()) ?? 0.0;
    } else {
      // Si aucun format reconnu, retourner un score minimal
      return 0.0;
    }
    
    // Calcul de la distance (facteur le plus important)
    final double distance = _calculateDistance(
      _currentLocation!.latitude, 
      _currentLocation!.longitude, 
      restaurantLat, 
      restaurantLng
    );
    
    // La distance est inversement proportionnelle au score (plus c'est proche, plus le score est élevé)
    // Normaliser pour que 5km ou moins donne un bon score, et au-delà diminue rapidement
    double distanceScore = 0;
    if (distance <= 0.5) {
      distanceScore = 50; // Max 50 points pour très proche (<500m)
    } else if (distance <= 5) {
      distanceScore = 50 * (1 - (distance - 0.5) / 4.5); // Diminue progressivement jusqu'à 5km
    }
    score += distanceScore;
    
    // Vérifier si le restaurant correspond aux critères de recherche sélectionnés
    if (_searchQueries.isNotEmpty) {
      double matchScore = 0;
      
      // Récupérer les données à comparer
      final types = restaurant['types'] as List<dynamic>? ?? 
                   restaurant['categories'] as List<dynamic>? ?? 
                   restaurant['tags'] as List<dynamic>? ?? [];
      final name = restaurant['name'] as String? ?? '';
      final vicinity = restaurant['vicinity'] as String? ?? 
                      restaurant['address'] as String? ?? '';
      final cuisineType = restaurant['cuisine_type'] as String? ?? 
                         restaurant['category'] as String? ?? '';
      
      for (String query in _searchQueries) {
        // Vérifie si le type correspond (20 points par match)
        if (types.any((type) => type.toString().toLowerCase().contains(query.toLowerCase())) ||
            cuisineType.toLowerCase().contains(query.toLowerCase())) {
          matchScore += 20;
        }
        
        // Vérifie si le nom correspond (15 points par match)
        if (name.toLowerCase().contains(query.toLowerCase())) {
          matchScore += 15;
        }
        
        // Vérifie si l'adresse/quartier correspond (10 points par match)
        if (vicinity.toLowerCase().contains(query.toLowerCase())) {
          matchScore += 10;
        }
      }
      
      // Limiter le score de correspondance à 40 points maximum
      score += math.min(matchScore, 40);
    } else {
      // Si aucun critère n'est spécifié, donner un score de base aux restaurants
      score += 20;
    }
    
    // Ajouter des points pour le rating si disponible (jusqu'à 10 points)
    if (restaurant['rating'] != null) {
      final rating = restaurant['rating'] is double 
          ? restaurant['rating'] as double 
          : double.tryParse(restaurant['rating'].toString()) ?? 0.0;
      
      score += math.min(rating * 2, 10); // 5 étoiles = 10 points
    } else if (restaurant['notes_globales'] != null && restaurant['notes_globales']['moyenne'] != null) {
      // Format alternatif pour les notes
      final rating = restaurant['notes_globales']['moyenne'] is double
          ? restaurant['notes_globales']['moyenne'] as double
          : double.tryParse(restaurant['notes_globales']['moyenne'].toString()) ?? 0.0;
          
      score += math.min(rating * 2, 10);
    }
    
    // Points bonus pour les restaurants ouverts maintenant si ce filtre est actif
    if (_openNow && (restaurant['business_status'] == 'OPERATIONAL' || restaurant['open_now'] == true)) {
      score += 10;
    }
    
    // Points bonus pour les restaurants avec une bonne note de service si ce filtre est défini
    if (_minServiceRating != null && restaurant['service_rating'] != null) {
      final serviceRating = restaurant['service_rating'] is double 
          ? restaurant['service_rating'] as double 
          : double.tryParse(restaurant['service_rating'].toString()) ?? 0.0;
      
      if (serviceRating >= _minServiceRating!) {
        score += 5;
      }
    }
    
    return score;
  }
  
  /// Calcule la distance entre deux points GPS en kilomètres
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0; // Rayon moyen de la Terre en km
    
    // Conversion des degrés en radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    
    // Formule de Haversine
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
              math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c; // Distance en km
  }
  
  /// Convertit des degrés en radians
  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
  
  /// Classe les restaurants par score de pertinence et définit les marqueurs en conséquence
  void _rankRestaurantsAndSetMarkers(List<dynamic> restaurants) {
    if (!mounted || _currentLocation == null) return;
    
    // Calculer les scores pour tous les restaurants
    final scoredRestaurants = restaurants.map((restaurant) {
      final Map<String, dynamic> rest = restaurant as Map<String, dynamic>;
      final double score = _calculateRelevanceScore(rest);
      return {'restaurant': rest, 'score': score};
    }).toList();
    
    // Trier par score décroissant
    scoredRestaurants.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    // Créer un nouveau set de marqueurs
    final Set<gmaps.Marker> newMarkers = {};
    
    // Ajouter les marqueurs pour chaque restaurant avec leur couleur basée sur le score
    for (final item in scoredRestaurants) {
      final restaurant = item['restaurant'] as Map<String, dynamic>;
      final score = item['score'] as double;
      _addScoredMarker(newMarkers, restaurant, score);
    }
    
    // Ajouter un marqueur pour la position actuelle de l'utilisateur
    if (_currentLocation != null) {
      final marker = gmaps.Marker(
        markerId: const gmaps.MarkerId('user_location'),
        position: _currentLocation!,
        icon: _userLocationIcon ?? gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
        infoWindow: const gmaps.InfoWindow(
          title: 'Votre position',
        ),
      );
      newMarkers.add(marker);
    }
    
    // Mettre à jour l'état avec les nouveaux marqueurs
      setState(() {
      _markers = newMarkers;
    });
  }
  
  /// Ajoute un marqueur pour un restaurant avec une couleur basée sur son score de pertinence
  void _addScoredMarker(Set<gmaps.Marker> markers, Map<String, dynamic> restaurant, double score) {
    final coords = getProducerCoords(restaurant);
    if (coords == null) {
      print('❌ Coordonnées manquantes pour: ${restaurant['name']}');
      return;
    }
    final restaurantPosition = gmaps.LatLng(coords.latitude, coords.longitude);
    final restaurantId = restaurant['_id']?.toString() ??
                        restaurant['id']?.toString() ?? 
                         restaurant['place_id']?.toString() ??
                        'restaurant_${restaurant['name']}_${DateTime.now().millisecondsSinceEpoch}';
    final double hue = _getHueFromScore(score);
    final gmaps.BitmapDescriptor markerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(hue);
    final String snippet = _buildSnippet(restaurant);
    final marker = gmaps.Marker(
      markerId: gmaps.MarkerId(restaurantId),
      position: restaurantPosition,
      icon: markerIcon,
      infoWindow: gmaps.InfoWindow(
        title: restaurant['name'] as String? ?? 'Restaurant',
        snippet: snippet,
        onTap: () {},
      ),
      onTap: () {
        setState(() {
          _selectedRestaurant = restaurant;
          _matchingDishes = [];
          _showRestaurantDetails(restaurant);
        });
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLng(restaurantPosition),
        );
      },
    );
    markers.add(marker);
  }

  /// Ajuste la vue de la carte pour afficher tous les marqueurs
  void _fitMapToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;
    
    // Si on a un seul marqueur, centrer dessus avec un zoom standard
    if (_markers.length == 1) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          _markers.first.position,
          14.0
        )
      );
      return;
    }
    
    // Calculer les limites pour englober tous les marqueurs
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;
    
    for (gmaps.Marker marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    
    // Créer les limites avec une marge
    final gmaps.LatLngBounds bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat - 0.01, minLng - 0.01),
      northeast: gmaps.LatLng(maxLat + 0.01, maxLng + 0.01),
    );
    
    // Animer la caméra pour montrer tous les marqueurs
    _mapController!.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, 50)
    );
  }

  // Au moment de créer la carte, définir la position et le zoom
  void _onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    
    // Utiliser Future.microtask pour s'assurer que le widget est monté
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _isMapReady = true;
      });
      
      // Suivre la position de la caméra
      controller.getVisibleRegion().then((region) {
        final center = gmaps.LatLng(
          (region.northeast.latitude + region.southwest.latitude) / 2,
          (region.northeast.longitude + region.southwest.longitude) / 2,
        );
        
        controller.getZoomLevel().then((zoomLevel) {
          if (mounted) {
            // Utiliser setState pour mettre à jour _cameraPosition
            setState(() {
              _cameraPosition = gmaps.CameraPosition(
                target: center,
                zoom: zoomLevel,
              );
            });
          }
        });
      });
      
      // Si un zoom initial est fourni, l'utiliser
      if (widget.initialZoom != null) {
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            _initialPosition,
            widget.initialZoom!
          )
        );
      }
      
        _fetchRestaurants();
    });
  }
  
  // Ajouter la détection du mouvement de la caméra
  void _onCameraMove(gmaps.CameraPosition position) {
    // Utiliser setState pour mettre à jour _cameraPosition
    setState(() {
      _cameraPosition = position;
    });
  }
  
  // Fonction pour rechercher dans la zone visible
  void _searchInThisArea() {
    if (_cameraPosition != null) {
      setState(() {
        _currentLocation = _cameraPosition!.target;
        _isSearchInAreaMode = true;
        
        final zoom = _cameraPosition!.zoom;
        if (zoom > 14) {
          _searchRadius = 1.0; // 1km
        } else if (zoom > 12) {
          _searchRadius = 3.0; // 3km
        } else {
          _searchRadius = 5.0; // 5km par défaut
        }
        
        _selectedRadius = _searchRadius * 1000;
      });
      
      _clearResults(); // Appeler la fonction définie
      _fetchRestaurants();
    }
  }
  
  // Réinitialiser la recherche
  void _resetSearch() {
    setState(() {
      _isSearchInAreaMode = false;
      _searchRadius = 5.0; // Rayon par défaut
      _selectedRadius = 5000; // Rayon par défaut pour le slider
      
      // Revenir à la position de l'utilisateur si disponible (_currentLocation est la position GPS)
      // Pas besoin de réassigner _currentLocation s'il représente déjà la pos user
    });
    
    // Animer la caméra vers la position utilisateur
    if (_currentLocation != null && _mapController != null) { // Correction: _currentLocation et _mapController
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          _currentLocation!, // Correction: Utiliser _currentLocation
          14,
        ),
      );
    }
    
    _clearResults(); // Correction: Appeler la fonction définie
    _fetchRestaurants();
  }

  // Méthode pour réinitialiser tous les filtres
  void _clearFilters() {
    setState(() {
      _selectedCategories = [];
      _minRating = null;
      _minPrice = 0;
      _maxPrice = 1000;
      _searchKeyword = null;
      _openNow = false;
      
      // Filtres détaillés restaurants
      _minServiceRating = null;
      _minLocationRating = null;
      _minPortionRating = null;
      _minAmbianceRating = null;
      _minFavorites = null;
      
      // Filtres items
      _minCalories = null;
      _maxCalories = null;
      _maxCarbonFootprint = null;
      _selectedNutriScores = [];
      _minItemRating = null;
      _itemKeywords = null;
    });
  }
  
  // Construire les widgets pour les filtres restaurant (fusionnés avec Général)
  Widget _buildRestaurantFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION GÉNÉRAL
        Text(
          'Recherche générale',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: mapcolors.MapColors.restaurantPrimary),
        ),
        SizedBox(height: 16),
        
        // Recherche par mot-clé
        Text(
          'Recherche par mot-clé',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher un restaurant...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchKeyword = value.isEmpty ? null : value;
            });
          },
        ),
        SizedBox(height: 16),
        
        // Rayon de recherche
        Text(
          'Rayon de recherche: ${(_selectedRadius / 1000).toStringAsFixed(1)} km',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Slider(
          min: 500,
          max: 10000,
          divisions: 19,
          value: _selectedRadius,
          onChanged: (value) {
            setState(() {
              _selectedRadius = value;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        SizedBox(height: 16),
        
        // Note minimale
        Text(
          'Note minimale',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Slider(
          min: 0,
          max: 5,
          divisions: 10,
          value: _minRating ?? 0,
          onChanged: (value) {
            setState(() {
              _minRating = value > 0 ? value : null;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        Text(_minRating == null 
            ? 'Non filtré' 
            : '${_minRating!.toStringAsFixed(1)} minimum'),
        SizedBox(height: 16),
        
        // Catégories de cuisine
        Text(
          'Catégories',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Italien', 'Français', 'Japonais', 'Mexicain', 
            'Indien', 'Chinois', 'Végétarien', 'Fast-food'
          ].map((category) {
            final isSelected = _selectedCategories.contains(category);
            return custom_filter.FilterChip(
              selected: isSelected,
              label: Text(category),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              },
              selectedColor: mapcolors.MapColors.restaurantPrimary.withOpacity(0.2),
              checkmarkColor: mapcolors.MapColors.restaurantPrimary,
            );
          }).toList() as List<Widget>,
        ),
        SizedBox(height: 16),
        
        // Fourchette de prix
        Text(
          'Fourchette de prix',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        RangeSlider(
          min: 0,
          max: 100,
          divisions: 20,
          labels: RangeLabels(
            '${_minPrice.round()} €', 
            _maxPrice >= 100 ? '100+ €' : '${_maxPrice.round()} €'
          ),
          values: RangeValues(_minPrice, _maxPrice >= 100 ? 100 : _maxPrice),
          onChanged: (values) {
            setState(() {
              _minPrice = values.start;
              _maxPrice = values.end >= 100 ? 1000 : values.end;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        SizedBox(height: 16),
        
        // Ouvert maintenant
        Row(
          children: [
            Checkbox(
              value: _openNow,
              onChanged: (value) {
                setState(() {
                  _openNow = value ?? false;
                });
              },
              activeColor: mapcolors.MapColors.restaurantPrimary,
            ),
            Text(
              'Ouvert maintenant',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        Divider(height: 32),
        
        // SECTION RESTAURANT SPÉCIFIQUE
        Text(
          'Détails du restaurant',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: mapcolors.MapColors.restaurantPrimary),
        ),
        SizedBox(height: 16),
        
        // Notation service
        Text(
          'Note service minimum',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Slider(
          min: 0,
          max: 5,
          divisions: 10,
          value: _minServiceRating ?? 0,
          onChanged: (value) {
            setState(() {
              _minServiceRating = value > 0 ? value : null;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        Text(_minServiceRating == null 
            ? 'Non filtré' 
            : 'Service: ${_minServiceRating!.toStringAsFixed(1)}/5 minimum'),
        SizedBox(height: 16),
        
        // Notation lieu
        Text(
          'Note ambiance minimum',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Slider(
          min: 0,
          max: 5,
          divisions: 10,
          value: _minAmbianceRating ?? 0,
          onChanged: (value) {
            setState(() {
              _minAmbianceRating = value > 0 ? value : null;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        Text(_minAmbianceRating == null 
            ? 'Non filtré' 
            : 'Ambiance: ${_minAmbianceRating!.toStringAsFixed(1)}/5 minimum'),
        SizedBox(height: 16),
        
        // Notation portions
        Text(
          'Note portions minimum',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Slider(
          min: 0,
          max: 5,
          divisions: 10,
          value: _minPortionRating ?? 0,
          onChanged: (value) {
            setState(() {
              _minPortionRating = value > 0 ? value : null;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        Text(_minPortionRating == null 
            ? 'Non filtré' 
            : 'Portions: ${_minPortionRating!.toStringAsFixed(1)}/5 minimum'),
        SizedBox(height: 16),
        
        // Nombre d'abonnés minimum
        Text(
          'Popularité',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Slider(
          min: 0,
          max: 1000,
          divisions: 20,
          value: _minFavorites?.toDouble() ?? 0,
          onChanged: (value) {
            setState(() {
              _minFavorites = value > 0 ? value.toInt() : null;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        Text(_minFavorites == null 
            ? 'Non filtré' 
            : 'Au moins ${_minFavorites} abonnés'),
        SizedBox(height: 32),
      ],
    );
  }
  
  // Construire les widgets pour les filtres d'items
  Widget _buildItemFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recherche d'items
        Text(
          'Rechercher des plats',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Nom du plat...',
            prefixIcon: Icon(Icons.restaurant_menu),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _itemKeywords = value.isEmpty ? null : value;
            });
          },
        ),
        SizedBox(height: 16),
        
        // Fourchette de calories
        Text(
          'Calories',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Min',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _minCalories = value.isEmpty ? null : double.tryParse(value);
                  });
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Max',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _maxCalories = value.isEmpty ? null : double.tryParse(value);
                  });
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        
        // Bilan carbone maximum
        Text(
          'Bilan carbone maximum',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Empreinte carbone max',
            prefixIcon: Icon(Icons.eco),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              _maxCarbonFootprint = value.isEmpty ? null : double.tryParse(value);
            });
          },
        ),
        SizedBox(height: 16),
        
        // Nutri-score
        Text(
          'Nutri-score',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['A', 'B', 'C', 'D', 'E'].map((score) {
            final isSelected = _selectedNutriScores.contains(score);
            return custom_filter.FilterChip(
              selected: isSelected,
              label: Text(score),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedNutriScores.add(score);
                  } else {
                    _selectedNutriScores.remove(score);
                  }
                });
              },
              selectedColor: mapcolors.MapColors.restaurantPrimary.withOpacity(0.2),
              checkmarkColor: mapcolors.MapColors.restaurantPrimary,
            );
          }).toList() as List<Widget>,
        ),
        SizedBox(height: 16),
        
        // Note minimum pour les plats
        Text(
          'Note minimum des plats',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Slider(
          min: 0,
          max: 10,
          divisions: 20,
          value: _minItemRating ?? 0,
          onChanged: (value) {
            setState(() {
              _minItemRating = value > 0 ? value : null;
            });
          },
          activeColor: mapcolors.MapColors.restaurantPrimary,
        ),
        Text(_minItemRating == null 
            ? 'Non filtré' 
            : '${_minItemRating!.toStringAsFixed(1)}/10 minimum'),
      ],
    );
  }

  /// Ajoute ou met à jour le marqueur de la position de l'utilisateur
  void _addUserLocationMarker({Set<gmaps.Marker>? targetSet}) {
    // Si ce n'est pas la localisation en direct, ne pas afficher le marqueur bleu
    // pour éviter la confusion lors de "recherche dans cette zone"
    if (!_isUsingLiveLocation) {
      return;
    }
    
    if (_currentLocation != null && mounted) {
      // Use the loaded custom icon or a fallback
      final icon = _userLocationIcon ?? gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure);
      
      setState(() {
        // Supprimer l'ancien marqueur utilisateur s'il existe
        _markers.removeWhere((m) => m.markerId.value == 'user_location');

        // Créer le nouveau marqueur utilisateur
        final userMarker = gmaps.Marker(
          markerId: const gmaps.MarkerId('user_location'),
          position: _currentLocation!,
          icon: icon, // Use the loaded or fallback icon
          infoWindow: const gmaps.InfoWindow(title: 'Votre Position'),
          zIndex: 1, // Assurer qu'il est au-dessus des autres marqueurs si nécessaire
          anchor: const Offset(0.5, 0.5), // Center the dot on the location
        );
        if (targetSet != null) {
          targetSet.add(userMarker);
        } else {
        _markers.add(userMarker);
        }
      });
    }
  }

  // Widget pour afficher le nombre d'abonnés
  Widget _buildFollowerCountWidget(Map<String, dynamic>? restaurant) {
    if (restaurant == null) return SizedBox.shrink();

    int followerCount = 0;
    if (restaurant['abonnés'] is int) {
      followerCount = restaurant['abonnés'];
    } else if (restaurant['followers'] is List) {
      followerCount = (restaurant['followers'] as List).length;
    } else if (restaurant['abonnés'] is String) {
      followerCount = int.tryParse(restaurant['abonnés']) ?? 0;
    }

    if (followerCount > 0) {
      return _buildInfoChip(
        icon: Icons.favorite,
        text: '$followerCount',
        color: Colors.redAccent,
      );
    } else {
      return SizedBox.shrink(); // Ne rien afficher si pas d'abonnés
    }
  }

  // Helper widget to create consistent info chips
  Widget _buildInfoChip({required IconData icon, required String text, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0), // Add spacing between chips
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16), // Smaller icon
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500), // Slightly smaller, medium weight
          ),
        ],
      ),
    );
  }

  double _getHueFromScore(double score) {
    // Accentuer la différence pour les scores élevés
    final normalizedScore = score.clamp(0.0, 100.0) / 100.0;
    if (normalizedScore >= 0.95) return 150; // Vert très vif
    if (normalizedScore >= 0.85) return 120; // Vert
    if (normalizedScore >= 0.7) return 90; // Vert clair
    if (normalizedScore >= 0.5) return 60; // Jaune
    if (normalizedScore >= 0.3) return 30; // Orange
    return 0; // Rouge
  }

  // Widget stylisé pour les compteurs sociaux (intérêts, amis, choices)
  Widget _buildSocialStatsRow(Map<String, dynamic> restaurant) {
    final int totalInterests = restaurant['totalInterests'] ?? 0;
    final int followingInterests = restaurant['followingInterestsCount'] ?? 0;
    final int totalChoices = restaurant['totalChoices'] ?? 0;
    final int followingChoices = restaurant['followingChoicesCount'] ?? 0;
    final double relevanceScore = (restaurant['relevanceScore'] ?? 0).toDouble();
    final bool isTopMatch = relevanceScore >= 90;

    // Définir les listes locales pour les IDs
    final List<String> allInterestIds = (restaurant['interests'] as List<dynamic>?)?.cast<String>() ?? [];
    final List<String> friendInterestIds = (restaurant['friendsInterests'] as List<dynamic>?)?.cast<String>() ?? [];
    final List<String> allChoiceIds = (restaurant['choices'] as List<dynamic>?)?.cast<String>() ?? [];
    final List<String> friendChoiceIds = (restaurant['friendsChoices'] as List<dynamic>?)?.cast<String>() ?? [];

    Widget statCol({
      required String emoji,
      required int total,
      required int friends,
      required String label,
      Color? color,
      Color? friendColor,
      bool highlight = false,
      VoidCallback? onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: 28, shadows: highlight ? [Shadow(color: Colors.yellow, blurRadius: 8)] : []),
            ),
            SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black,
                    shadows: highlight ? [Shadow(color: Colors.yellow, blurRadius: 8)] : [],
                  ),
                ),
                if (friends > 0) ...[
                  SizedBox(width: 4),
                  Text(
                    '$friends',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: friendColor ?? Colors.blueAccent,
                    ),
                  ),
                ]
              ],
            ),
            SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color?.withOpacity(0.7) ?? Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    void _showDetailsDialog(String title, String type, List<String> allIds, List<String> friendsIds) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Aucun $type pour le moment',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Total: ${allIds.length}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  
                  if (friendsIds.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Amis: ${friendsIds.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: type == 'intérêts' ? Colors.pinkAccent : Colors.teal),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (type == 'intérêts' ? Colors.pinkAccent : Colors.teal).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: friendsIds.map((id) {
                          // Ici, idéalement, nous récupérerions le nom/avatar de l'ami
                          // Pour l'instant, affichons juste l'ID avec style
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (type == 'intérêts' ? Colors.pinkAccent : Colors.teal).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Ami ${id.substring(0, 4)}...',
                              style: TextStyle(
                                fontSize: 12,
                                color: type == 'intérêts' ? Colors.pinkAccent : Colors.teal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 16),
                  
                  if (allIds.length > friendsIds.length) ...[
                    Text(
                      'Autres personnes: ${allIds.length - friendsIds.length}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Les autres personnes qui ont montré leur ${type.substring(0, type.length - 1)} ne sont pas affichées.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        statCol(
          emoji: '⭐',
          total: totalInterests,
          friends: followingInterests,
          label: 'Intérêts',
          color: Colors.amber[800],
          friendColor: Colors.pinkAccent,
          highlight: totalInterests > 0,
          onTap: () => _showDetailsDialog(
            'Intérêts', 
            'intérêts',
            allInterestIds, // Utilise la variable locale
            friendInterestIds, // Utilise la variable locale
          ),
        ),
        statCol(
          emoji: '✅',
          total: totalChoices,
          friends: followingChoices,
          label: 'Choices',
          color: Colors.green,
          friendColor: Colors.teal,
          highlight: totalChoices > 0,
          onTap: () => _showDetailsDialog(
            'Choices', 
            'choices',
            allChoiceIds, // Utilise la variable locale
            friendChoiceIds, // Utilise la variable locale
          ),
        ),
        if (isTopMatch)
          Container(
            margin: EdgeInsets.only(left: 8),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                SizedBox(width: 4),
                Text('TOP MATCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  // Définition de la méthode manquante pour effacer les résultats
  void _clearResults() {
    setState(() {
      _markers.clear();
      _restaurantResults = [];
      
      // Si on n'est pas en mode recherche par zone, on remet le marqueur de position utilisateur
      if (!_isSearchInAreaMode && _currentLocation != null) {
        _markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('user_location'),
            position: _currentLocation!,
            icon: _userLocationIcon ?? gmaps.BitmapDescriptor.defaultMarker,
            zIndex: 2,
          ),
        );
      }
    });
  }
} 

// 1. Fonction pour obtenir le userId (dummy)
String? getCurrentUserId(BuildContext context) {
  // TODO: remplacer par la vraie logique d'auth
  return null; // ou un id de test
}

gmaps.LatLng? getProducerCoords(Map<String, dynamic> producer) {
  double? lat, lng;
  if (producer['geometry']?['location']?['lat'] != null && producer['geometry']?['location']?['lng'] != null) {
    lat = (producer['geometry']['location']['lat'] as num?)?.toDouble();
    lng = (producer['geometry']['location']['lng'] as num?)?.toDouble();
  } else if (producer['gps_coordinates']?['coordinates'] != null && producer['gps_coordinates']['coordinates'].length >= 2) {
    lng = (producer['gps_coordinates']['coordinates'][0] as num?)?.toDouble();
    lat = (producer['gps_coordinates']['coordinates'][1] as num?)?.toDouble();
  }
  if (lat != null && lng != null && !lat.isNaN && !lng.isNaN) {
    return gmaps.LatLng(lat, lng);
  }
  return null;
} 
