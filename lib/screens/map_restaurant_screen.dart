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
  
  // Liste des termes de recherche pour le calcul de score
  List<String> _searchQueries = [];
  
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
      });
      
      try {
        // Continuer le chargement dans un microtask pour ne pas bloquer l'UI
        Future.microtask(() async {
          try {
            final double latitude = _currentPosition?.latitude ?? _initialPosition.latitude;
            final double longitude = _currentPosition?.longitude ?? _initialPosition.longitude;
            
            // Utiliser la route avancée pour les restaurants
            final String baseUrl = getBaseUrl();
            final Uri url = Uri.parse('${baseUrl}/api/producers/advanced-search');
            
            // Construire les paramètres de requête
            final Map<String, String> queryParams = {
              'page': '1',
              'limit': '50', // Limiter explicitement le nombre de résultats
            };
            
            // Ajouter les coordonnées si nous avons une position valide
            if (_currentLocation != null) {
              queryParams['lat'] = _currentLocation!.latitude.toString();
              queryParams['lng'] = _currentLocation!.longitude.toString();
              queryParams['radius'] = _selectedRadius.toString();
            }

            // Filtres de base
            if (_searchKeyword != null && _searchKeyword!.isNotEmpty) {
              queryParams['searchKeyword'] = _searchKeyword!;
            }
            
            // Filtres de l'onglet Général
            if (_selectedCategories.isNotEmpty) {
              queryParams['cuisine_type'] = _selectedCategories.join(',');
            }
            
            if (_minRating != null) {
              queryParams['min_rating'] = _minRating.toString();
            }
            
            if (_minPrice > 0) {
              queryParams['minPrice'] = _minPrice.toString();
            }
            
            if (_maxPrice < 1000) {
              queryParams['maxPrice'] = _maxPrice.toString();
            }
            
            if (_openNow) {
              queryParams['business_status'] = 'OPERATIONAL';
            }
            
            // Filtres pour restaurants
            if (_minServiceRating != null) {
              queryParams['min_service_rating'] = _minServiceRating.toString();
            }
            
            if (_minLocationRating != null) {
              queryParams['min_location_rating'] = _minLocationRating.toString();
            }
            
            if (_minPortionRating != null) {
              queryParams['min_portion_rating'] = _minPortionRating.toString();
            }
            
            if (_minAmbianceRating != null) {
              queryParams['min_ambiance_rating'] = _minAmbianceRating.toString();
            }
            
            if (_minFavorites != null) {
              queryParams['min_followers'] = _minFavorites.toString();
            }
            
            // Filtres pour items
            if (_itemKeywords != null && _itemKeywords!.isNotEmpty) {
              queryParams['itemKeywords'] = _itemKeywords!;
            }
            
            if (_minCalories != null) {
              queryParams['min_calories'] = _minCalories.toString();
            }
            
            if (_maxCalories != null) {
              queryParams['max_calories'] = _maxCalories.toString();
            }
            
            if (_maxCarbonFootprint != null) {
              queryParams['max_carbon_footprint'] = _maxCarbonFootprint.toString();
            }
            
            if (_minItemRating != null) {
              queryParams['min_item_rating'] = _minItemRating.toString();
            }
            
            if (_selectedNutriScores.isNotEmpty) {
              queryParams['nutri_scores'] = _selectedNutriScores.join(',');
            }
            
            print('🔍 Requête avancée avec paramètres: ${queryParams.toString()}');
            
            // Utiliser le bon schéma en fonction de l'URL de base
            final response = baseUrl.startsWith('https') 
                ? await http.get(Uri.https(url.authority, url.path, queryParams))
                : await http.get(Uri.http(url.authority, url.path, queryParams));
            
            if (!mounted) return; // Vérifier si le widget est toujours monté
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              print('✅ Réponse reçue: ${response.body.substring(0, math.min(200, response.body.length))}...');
              print('✅ Type de données: ${data.runtimeType}, Structure: ${data.keys}');
              
              List<dynamic> restaurants = [];
              if (data['success'] == true && data['results'] is List) {
                restaurants = data['results'];
                print('📊 Nombre de restaurants trouvés: ${restaurants.length}');
              } else if (data is List) {
                // Fallback si le format est différent
                restaurants = data;
                print('📊 Nombre de restaurants trouvés (format liste): ${restaurants.length}');
              } else if (data['producers'] is List) {
                // Autre format possible
                restaurants = data['producers'];
                print('📊 Nombre de restaurants trouvés (format producers): ${restaurants.length}');
              } else {
                print('❌ Format de réponse non reconnu: ${response.body}');
              }
                
              // Traiter les résultats
              if (restaurants.isNotEmpty) {
                _addRestaurantMarkers(restaurants);
                
                // Ajuster la caméra pour voir tous les résultats
                if (_mapController != null && mounted) {
                  _fitMapToMarkers();
                }
                
                // Vérifier mounted avant de modifier l'état
                if (!mounted) return;
                
                setState(() {
                  _isLoading = false;
                });
              } else if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Aucun restaurant trouvé avec ces critères.';
                });
              }
            } else if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Erreur: ${e.toString()}';
              });
            }
          }
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erreur: ${e.toString()}';
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
  
  /// Afficher une vue rapide du restaurant
  void _showRestaurantDetails(Map<String, dynamic> restaurant) {
              setState(() {
      _selectedRestaurant = restaurant;
    });
  }
  
  // Naviguer vers la page détaillée du restaurant
  void _navigateToRestaurantDetail() {
    if (_selectedRestaurant != null) {
      final String id = _selectedRestaurant!['_id']?.toString() ?? 
                         _selectedRestaurant!['id']?.toString() ?? '';
      
      if (id.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: id,
              userId: null, // Vous pouvez passer l'ID utilisateur si disponible
            ),
          ),
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
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Photo du restaurant
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _selectedRestaurant?['photo'] != null
                              ? Image.network(
                                  _selectedRestaurant!['photo'],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[300],
                                    child: Icon(Icons.restaurant, color: Colors.grey[600]),
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.restaurant, color: Colors.grey[600]),
                                ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedRestaurant?['name'] ?? 'Restaurant',
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
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _selectedRestaurant = null;
                            });
                          },
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start, // Align icons to the start
                                children: [
                                  if (_selectedRestaurant?['rating'] != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min, // Prevent row from expanding
                                      children: [
                                        Icon(Icons.star, color: Colors.amber, size: 18), // Slightly larger icon
                                        SizedBox(width: 4),
                                        Text(
                                          '${_selectedRestaurant!['rating']}',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Bolder text
                                        ),
                                        SizedBox(width: 12), // Increased spacing
                                      ],
                                    ),
                                  // Display follower count (using 'abonnés' or 'followers')
                                  _buildFollowerCountWidget(_selectedRestaurant),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _navigateToRestaurantDetail,
                            icon: Icon(Icons.info_outline),
                            label: Text('Voir détails'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mapcolors.MapColors.restaurantPrimary,
                        foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                      ),
                            ),
                          ),
                        ),
                      ],
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
        ],
      ),
      // Ajouter le FloatingActionButton pour les filtres
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showFilterPanel = true;
          });
        },
        backgroundColor: mapcolors.MapColors.restaurantPrimary,
        child: Icon(Icons.filter_list, color: Colors.white),
        tooltip: 'Filtres',
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
  
  /*
  // Méthode future pour convertir un SVG en BitmapDescriptor
  Future<gmaps.BitmapDescriptor> _svgToBitmapDescriptor(String assetName, {
    Color color = Colors.red,
    Size size = const Size(120, 120),
  }) async {
    // Dessiner le SVG sur un Canvas
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final svgString = await rootBundle.loadString(assetName);
    final svgDrawable = await svg.fromSvgString(svgString, assetName);
    
    // Appliquer la couleur et dessiner
    final colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    canvas.save();
    svgDrawable.draw(canvas, size: size, colorFilter: colorFilter);
    canvas.restore();
    
    // Convertir en image
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    
    // Créer le BitmapDescriptor
    return gmaps.BitmapDescriptor.fromBytes(buffer);
  }
  */

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
  void _navigateToMapScreen(String mapType) {
    if (mapType == 'restaurant') return; // Déjà sur cette carte
    
    // Utiliser l'extension NavigationHelper définie dans main.dart
    context.changeMapType(mapType);
  }

  /// Ajouter des marqueurs pour les restaurants trouvés
  void _addRestaurantMarkers(List<dynamic> restaurants) {
    if (!mounted) return;
    
    // Préparer les termes de recherche à partir du mot-clé
    if (_searchKeyword != null && _searchKeyword!.isNotEmpty) {
      _searchQueries = _searchKeyword!.toLowerCase().split(' ')
          .where((term) => term.length > 2)
          .toList();
    } else {
      _searchQueries = [];
    }
    
    // Ajouter les termes de recherche provenant des catégories sélectionnées
    if (_selectedCategories.isNotEmpty) {
      _searchQueries.addAll(_selectedCategories.map((cat) => cat.toLowerCase()));
    }
    
    // Au lieu de créer des marqueurs directement, utiliser le système de ranking
    _rankRestaurantsAndSetMarkers(restaurants);
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
    // Vérifier que les données nécessaires sont présentes et extraire les coordonnées
    double? restaurantLat, restaurantLng;
    
    // Vérifier les différentes structures de données possibles pour les coordonnées
    if (restaurant['gps_coordinates'] != null && 
        restaurant['gps_coordinates']['coordinates'] != null && 
        restaurant['gps_coordinates']['coordinates'] is List && 
        restaurant['gps_coordinates']['coordinates'].length >= 2) {
      // Format GeoJSON [longitude, latitude]
      restaurantLng = (restaurant['gps_coordinates']['coordinates'][0] as num).toDouble();
      restaurantLat = (restaurant['gps_coordinates']['coordinates'][1] as num).toDouble();
    } else if (restaurant['geometry'] != null && 
               restaurant['geometry']['location'] != null) {
      // Format Google Maps API
      if (restaurant['geometry']['location']['lat'] is double) {
        restaurantLat = restaurant['geometry']['location']['lat'] as double;
        restaurantLng = restaurant['geometry']['location']['lng'] as double;
      } else {
        // Certaines API renvoient les coordonnées comme des chaînes
        restaurantLat = double.tryParse(restaurant['geometry']['location']['lat'].toString()) ?? 0.0;
        restaurantLng = double.tryParse(restaurant['geometry']['location']['lng'].toString()) ?? 0.0;
      }
    } else if (restaurant['latitude'] != null && restaurant['longitude'] != null) {
      // Format simple avec latitude/longitude
      restaurantLat = (restaurant['latitude'] is num) ? (restaurant['latitude'] as num).toDouble() 
                                                      : double.tryParse(restaurant['latitude'].toString()) ?? 0.0;
      restaurantLng = (restaurant['longitude'] is num) ? (restaurant['longitude'] as num).toDouble() 
                                                       : double.tryParse(restaurant['longitude'].toString()) ?? 0.0;
    } else {
      // Si on ne peut pas obtenir de coordonnées, ne pas ajouter de marqueur
      print('❌ Coordonnées manquantes pour: ${restaurant['name']}');
      return;
    }
    
    final restaurantPosition = gmaps.LatLng(restaurantLat, restaurantLng);
    
    // Récupérer l'identifiant du restaurant
    final restaurantId = restaurant['place_id']?.toString() ?? 
                        restaurant['_id']?.toString() ?? 
                        restaurant['id']?.toString() ?? 
                        'restaurant_${restaurant['name']}_${DateTime.now().millisecondsSinceEpoch}';
    
    // Déterminer la couleur en fonction du score (rouge à vert)
    // Score max ~= 100, min ~= 0
    gmaps.BitmapDescriptor markerIcon;
    
    // Prioriser l'icône de catégorie si elle existe
    String categoryKey = (restaurant['category'] as List<dynamic>?)?.isNotEmpty == true
        ? (restaurant['category'] as List<dynamic>).first.toString().toLowerCase()
        : (restaurant['cuisine_type'] as String?)?.toLowerCase() ?? 'default'; // Fallback category

    if (_categoryIcons.containsKey(categoryKey)) {
      markerIcon = _categoryIcons[categoryKey]!;
    } else if (score >= 80) {
      markerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen); // Vert (excellent)
    } else if (score >= 60) {
      markerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(90.0); // Vert clair (très pertinent)
    } else if (score >= 40) {
      markerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueYellow); // Jaune (pertinent)
    } else if (score >= 20) {
      markerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange); // Orange (moyennement pertinent)
    } else {
      markerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed); // Rouge (peu pertinent)
    }
    
    // Créer le snippet avec des informations pertinentes
    final String snippet = 'Score: ${score.toStringAsFixed(1)} · ${_buildSnippet(restaurant)}';
    
    // Créer le marqueur
    final marker = gmaps.Marker(
      markerId: gmaps.MarkerId(restaurantId),
      position: restaurantPosition,
      icon: markerIcon,
      infoWindow: gmaps.InfoWindow(
        title: restaurant['name'] as String? ?? 'Restaurant',
        snippet: snippet,
      ),
      onTap: () {
        setState(() {
          _selectedRestaurant = restaurant;
        });
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
    // Réduire le nombre d'opérations dans cette méthode
    _mapController = controller;
    
    // Utiliser Future.delayed pour ne pas bloquer le thread principal
    Future.delayed(Duration.zero, () {
      // Si un zoom initial est fourni, l'utiliser
      if (widget.initialZoom != null && mounted) {
        // Animer la caméra vers la position initiale avec le zoom fourni
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            _initialPosition,
            widget.initialZoom!
          )
        );
      }
      
      // Charger les restaurants
      if (mounted) {
        _fetchRestaurants();
      }
    });
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
  void _addUserLocationMarker() {
    if (_currentLocation != null && mounted) {
      setState(() {
        // Supprimer l'ancien marqueur utilisateur s'il existe
        _markers.removeWhere((m) => m.markerId.value == 'user_location');

        // Créer le nouveau marqueur utilisateur
        final userMarker = gmaps.Marker(
          markerId: const gmaps.MarkerId('user_location'),
          position: _currentLocation!,
          icon: _userLocationIcon ?? gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue), // Use blue if custom icon not loaded
          infoWindow: const gmaps.InfoWindow(title: 'Votre Position'),
          zIndex: 1, // Assurer qu'il est au-dessus des autres marqueurs si nécessaire
        );
        _markers.add(userMarker);
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
      return Row(
        mainAxisSize: MainAxisSize.min, // Prevent row from expanding
        children: [
          Icon(Icons.favorite, color: Colors.redAccent, size: 18), // Slightly larger icon
          SizedBox(width: 4),
          Text(
            '$followerCount',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Bolder text
          ),
        ],
      );
    } else {
      return SizedBox.shrink(); // Ne rien afficher si pas d'abonnés
    }
  }
} 
