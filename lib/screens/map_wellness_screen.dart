import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:location/location.dart';
import '../models/map_selector.dart';
import '../widgets/map_selector.dart' as widget_selector;
import '../services/map_service.dart';
import 'map_restaurant_screen.dart' as restaurant_map;
import 'map_leisure_screen.dart' as leisure_map;
import 'map_friends_screen.dart' as friends_map;
import '../utils/map_colors.dart';
import '../main.dart';
import 'package:http/http.dart' as http;

// Utiliser des couleurs directement pour éviter le conflit
final wellnessPrimaryColor = Color(0xFF5C6BC0);

// Modèle pour les catégories de bien-être
class WellnessCategoryModel {
  final String name;
  final List<String> subCategories;
  final List<String> evaluationCriteria;
  final bool hasAvailability;
  
  WellnessCategoryModel({
    required this.name,
    required this.subCategories,
    required this.evaluationCriteria,
    this.hasAvailability = false,
  });
  
  factory WellnessCategoryModel.fromJson(Map<String, dynamic> json) {
    return WellnessCategoryModel(
      name: json['name'] ?? '',
      subCategories: List<String>.from(json['sous_categories'] ?? []),
      evaluationCriteria: List<String>.from(json['criteres_evaluation'] ?? []),
      hasAvailability: json['horaires_disponibilite'] ?? false,
    );
  }
}

// Modèle pour les critères d'évaluation
class CriteriaRating {
  final String criteriaName;
  double value;
  
  CriteriaRating({
    required this.criteriaName,
    this.value = 0.0,
  });
}

class MapWellnessScreen extends StatefulWidget {
  final gmaps.LatLng? initialPosition;
  final double? initialZoom;

  const MapWellnessScreen({Key? key, this.initialPosition, this.initialZoom}) : super(key: key);

  @override
  _MapWellnessScreenState createState() => _MapWellnessScreenState();
}

class _MapWellnessScreenState extends State<MapWellnessScreen> with AutomaticKeepAliveClientMixin {
  final MapService _mapService = MapService();
  gmaps.GoogleMapController? _mapController;
  Set<gmaps.Marker> _markers = {};
  bool _isLoading = true;
  bool _isMapReady = false;
  LocationData? _currentPosition;
  bool _isUsingLiveLocation = false;
  Timer? _locationUpdateTimer;
  String? _error;
  late final gmaps.LatLng _initialPosition;
  final Location _location = Location();
  
  // Nouvel état pour contrôler l'affichage du panneau de filtres
  bool _showFilterPanel = false;

  // Filtres basiques
  String? _searchQuery;
  List<String> _selectedSpecialties = [];
  double _minRating = 0.0;
  double _selectedRadius = 5000; // 5km par défaut
  
  // Filtres dynamiques basés sur les catégories de wellness.py
  List<WellnessCategoryModel> _categories = [];
  WellnessCategoryModel? _selectedCategory;
  String? _selectedSubCategory;
  List<CriteriaRating> _selectedCriteria = [];
  int _currentFilterTab = 0; // 0: catégories, 1: critères, 2: disponibilité
  bool _isLoadingCategories = false;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];
  
  // Variables manquantes pour la compatibilité avec MapScreen
  Map<String, dynamic>? _selectedPlace;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initialPosition = widget.initialPosition ?? const gmaps.LatLng(48.856614, 2.3522219);
    _checkLocationPermission();
    _loadCategories(); // Chargement des catégories au démarrage
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _showSnackBar("Service de localisation désactivé. Utilisation de Paris par défaut.");
          return;
        }
      }
      
      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          _showSnackBar("Permissions de localisation refusées. Utilisation de Paris par défaut.");
          return;
        }
      }
      
      _getCurrentLocation();
    } catch (e) {
      print("❌ Erreur lors de la vérification des permissions: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _location.changeSettings(accuracy: LocationAccuracy.high);
      LocationData position = await _location.getLocation();
      
      if (position.latitude == null || position.longitude == null) {
        _showSnackBar("Impossible d'obtenir des coordonnées valides. Utilisant la position par défaut.");
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _currentPosition = position;
        _initialPosition = gmaps.LatLng(position.latitude!, position.longitude!);
        _isUsingLiveLocation = true;
        _isLoading = false;
      });
      
      if (_mapController != null && _isMapReady) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(_initialPosition, 14),
        );
      }
      
      _fetchWellnessPlaces();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Erreur de localisation: $e");
    }
  }

  Future<void> _fetchWellnessPlaces() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Préparer les filtres pour l'API
      Map<String, dynamic> filters = {};
      
      // Filtres basiques
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        filters['search'] = _searchQuery;
      }
      
      if (_selectedSpecialties.isNotEmpty) {
        filters['specialties'] = _selectedSpecialties;
      }
      
      if (_minRating > 0) {
        filters['min_rating'] = _minRating;
      }
      
      // Filtres de catégorie
      if (_selectedCategory != null) {
        filters['category'] = _selectedCategory!.name;
        
        if (_selectedSubCategory != null) {
          filters['sous_categorie'] = _selectedSubCategory;
        }
      }
      
      // Filtres de critères d'évaluation
      if (_selectedCriteria.isNotEmpty) {
        Map<String, double> criteriaFilters = {};
        
        for (var criteria in _selectedCriteria) {
          if (criteria.value > 0) {
            // Convertir en format attendu par l'API
            final key = 'min_${criteria.criteriaName.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_')}';
            criteriaFilters[key] = criteria.value;
          }
        }
        
        if (criteriaFilters.isNotEmpty) {
          filters['criteria'] = criteriaFilters;
        }
      }
      
      // Filtres de disponibilité
      if (_selectedCategory?.hasAvailability == true && _selectedTimeSlot != null) {
        filters['date'] = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
        filters['time_slot'] = _selectedTimeSlot;
      }
      
      // Récupérer les établissements de bien-être
      final places = await _mapService.getNearbyPlaces(
        latitude: _initialPosition.latitude,
        longitude: _initialPosition.longitude,
        placeType: 'wellness',
        radius: _selectedRadius,
        filters: filters,
      );
      
      if (!mounted) return;
        
      if (places.isEmpty) {
        setState(() {
          _isLoading = false;
          _markers = {};
          _error = "Aucun établissement trouvé. Essayez d'élargir votre zone de recherche ou de modifier vos filtres.";
        });
        return;
      }
      
      // Mettre à jour les marqueurs sur la carte
      _updateMapMarkers(places);
            
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Erreur lors de la recherche: $e";
        });
      }
    }
  }

  /// Met à jour les marqueurs sur la carte
  void _updateMapMarkers(List<Map<String, dynamic>> places) {
    if (!mounted || places.isEmpty) return;
    
    // Créer un nouvel ensemble de marqueurs
    Set<gmaps.Marker> newMarkers = {};
    
    for (var place in places) {
      // Extraire les coordonnées GPS
      final coordinates = place['location']?['coordinates'];
      if (coordinates == null || coordinates.length < 2) {
        continue;
      }
      
      // Récupérer longitude et latitude (GeoJSON format: [lng, lat])
      final double lng = coordinates[0] is double ? coordinates[0] : coordinates[0].toDouble();
      final double lat = coordinates[1] is double ? coordinates[1] : coordinates[1].toDouble();
      
      // Générer un ID unique pour le marqueur
      final String markerId = place['_id'] ?? 'wellness_${place['name']}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Déterminer la couleur du marqueur en fonction de la note
      double hue = gmaps.BitmapDescriptor.hueViolet;
      if (place['rating'] != null) {
        final rating = place['rating'] is double ? place['rating'] : place['rating'].toDouble();
        if (rating >= 4.5) {
          hue = gmaps.BitmapDescriptor.hueGreen;
        } else if (rating >= 3.5) {
          hue = gmaps.BitmapDescriptor.hueAzure;
        } else {
          hue = gmaps.BitmapDescriptor.hueRose;
        }
      }
      
      // Créer le marqueur
      final marker = gmaps.Marker(
        markerId: gmaps.MarkerId(markerId),
        position: gmaps.LatLng(lat, lng),
        infoWindow: gmaps.InfoWindow(
          title: place['name'] ?? 'Établissement de bien-être',
          snippet: place['address'] ?? 'Adresse non disponible',
        ),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () {
          _showPlaceDetails(place);
        },
      );
      
      newMarkers.add(marker);
    }
    
    // Mettre à jour les marqueurs
    setState(() {
      _markers = newMarkers;
    });
    
    // Ajuster la vue de la carte si nécessaire et si des marqueurs existent
    if (newMarkers.isNotEmpty && _mapController != null && _isMapReady) {
      _fitMarkersOnMap();
    }
  }
  
  /// Ajuster la vue de la carte pour montrer tous les marqueurs
  void _fitMarkersOnMap() {
    if (_markers.isEmpty || _mapController == null) return;
    
    // Si un seul marqueur, centrer dessus avec un zoom prédéfini
    if (_markers.length == 1) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          _markers.first.position,
          14.0,
        ),
      );
      return;
    }
    
    // Calculer les limites pour englober tous les marqueurs
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (var marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }
    
    // Créer les limites et ajouter un peu de marge
    gmaps.LatLngBounds bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
    
    // Animer la caméra pour montrer tous les marqueurs
    _mapController!.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }

  /// Afficher les détails d'un établissement
  void _showPlaceDetails(dynamic place) {
    setState(() {
      _selectedPlace = place;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Méthode pour appliquer les filtres depuis MapScreen
  void applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _selectedRadius = filters['radius'] ?? _selectedRadius;
      _minRating = filters['minRating'] ?? _minRating;
      _searchQuery = filters['keyword'];
      
      if (filters['specialties'] != null && filters['specialties'] is List) {
        _selectedSpecialties = List<String>.from(filters['specialties']);
      }
    });
    
    // Rafraîchir les données sur la carte
    _fetchWellnessPlaces();
  }
  
  // Méthode pour activer la localisation en direct
  void enableLiveLocation() {
    setState(() {
      _isUsingLiveLocation = true;
    });
    
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLng(
          gmaps.LatLng(_currentPosition!.latitude!, _currentPosition!.longitude!)
        ),
      );
    }
  }

  // Méthode pour naviguer vers différentes cartes
  void _navigateToMapScreen(String mapType) {
    if (mapType == 'wellness') return; // Déjà sur cette carte
    
    // Utiliser l'extension NavigationHelper définie dans main.dart
    context.changeMapType(mapType);
  }

  // Événement lors de la création de la carte
  void _onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    _isMapReady = true;
    
    // Si un zoom initial est fourni, l'utiliser
    if (widget.initialZoom != null) {
      controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          _initialPosition, 
          widget.initialZoom!
        )
      );
    }
    
    // Charger les établissements de bien-être
    _fetchWellnessPlaces();
  }

  // Chargement des catégories depuis l'API
  Future<void> _loadCategories() async {
    if (_isLoadingCategories) return;
    
    setState(() {
      _isLoadingCategories = true;
    });
    
    try {
      // Essayer de charger depuis l'API
      final response = await http.get(Uri.parse('http://localhost:3000/api/beauty_places/criteria'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<WellnessCategoryModel> categories = [];
        
        data.forEach((key, value) {
          categories.add(WellnessCategoryModel(
            name: key,
            subCategories: List<String>.from(value['sous_categories'] ?? []),
            evaluationCriteria: List<String>.from(value['criteres_evaluation'] ?? []),
            hasAvailability: value['horaires_disponibilite'] ?? false,
          ));
        });
        
        setState(() {
          _categories = categories;
          if (categories.isNotEmpty) {
            _selectedCategory = categories.first;
          }
          _isLoadingCategories = false;
        });
      } else {
        // Fallback si l'API échoue
        _setDefaultCategories();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des catégories: $e');
      _setDefaultCategories();
    }
  }
  
  // Définir des catégories par défaut si l'API échoue
  void _setDefaultCategories() {
    setState(() {
      _categories = [
        WellnessCategoryModel(
          name: 'Soins esthétiques et bien-être',
          subCategories: ['Institut de beauté', 'Spa', 'Salon de massage', 'Centre d\'épilation'],
          evaluationCriteria: ['Qualité des soins', 'Propreté', 'Accueil', 'Rapport qualité/prix', 'Ambiance', 'Expertise du personnel'],
          hasAvailability: true,
        ),
        WellnessCategoryModel(
          name: 'Coiffure et soins capillaires',
          subCategories: ['Salon de coiffure', 'Barbier'],
          evaluationCriteria: ['Qualité de la coupe', 'Respect des attentes', 'Conseil', 'Produits utilisés', 'Tarifs', 'Ponctualité'],
          hasAvailability: true,
        ),
        WellnessCategoryModel(
          name: 'Onglerie et modifications corporelles',
          subCategories: ['Salon de manucure', 'Salon de tatouage', 'Salon de piercing'],
          evaluationCriteria: ['Précision', 'Hygiène', 'Créativité', 'Durabilité', 'Conseil', 'Douleur ressentie'],
          hasAvailability: false,
        ),
      ];
      
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
      
      _isLoadingCategories = false;
    });
  }
  
  // Mettre à jour les critères lorsque la catégorie change
  void _updateCriteria() {
    if (_selectedCategory == null) return;
    
    setState(() {
      _selectedCriteria = _selectedCategory!.evaluationCriteria
          .map((criteria) => CriteriaRating(criteriaName: criteria))
          .toList();
    });
  }
  
  // Charger les créneaux horaires disponibles
  Future<void> _loadAvailableTimeSlots() async {
    if (_selectedPlace == null) return;
    
    try {
      final String placeId = _selectedPlace!['place_id'] ?? _selectedPlace!['_id'];
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/beauty_places/available-hours?placeId=$placeId&date=$dateStr')
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _availableTimeSlots = List<String>.from(data['available_hours'] ?? []);
          _selectedTimeSlot = _availableTimeSlots.isNotEmpty ? _availableTimeSlots.first : null;
        });
      } else {
        setState(() {
          _availableTimeSlots = [];
          _selectedTimeSlot = null;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des créneaux horaires: $e');
      setState(() {
        _availableTimeSlots = [];
        _selectedTimeSlot = null;
      });
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
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: _initialPosition,
              zoom: widget.initialZoom ?? 14,
            ),
            markers: _markers,
            myLocationEnabled: _isUsingLiveLocation,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: _onMapCreated,
          ),
            
          // Sélecteur de carte
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: widget_selector.MapSelector(
              currentIndex: 2, // Index 2 pour la carte bien-être
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
          if (_error != null && _error!.isNotEmpty)
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
                      _error!,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchWellnessPlaces,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: wellnessPrimaryColor,
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
            
          // Affichage du lieu de bien-être sélectionné
          if (_selectedPlace != null)
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
                            _selectedPlace!['name'] ?? 'Établissement de bien-être',
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
                              _selectedPlace = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedPlace!['address'] ?? 'Adresse non disponible',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Naviguer vers la page détaillée du lieu de bien-être
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: wellnessPrimaryColor,
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
                              color: wellnessPrimaryColor,
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
                      _buildFilterTabs(),
                      SizedBox(height: 15),
                      
                      // Contenu de l'onglet actif
                      Expanded(
                        child: SingleChildScrollView(
                          child: _currentFilterTab == 0
                              ? _buildCategoryFilters()
                              : _currentFilterTab == 1
                                  ? _buildCriteriaFilters()
                                  : _buildAvailabilityFilters(),
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Boutons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton(
                            onPressed: _resetFilters,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: wellnessPrimaryColor,
                            ),
                            child: Text('Réinitialiser'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showFilterPanel = false;
                              });
                              _fetchWellnessPlaces();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: wellnessPrimaryColor,
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
        backgroundColor: wellnessPrimaryColor,
        child: Icon(Icons.filter_list, color: Colors.white),
        tooltip: 'Filtres',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  
  // Méthode helper pour construire les cases à cocher des spécialités
  Widget _buildSpecialtyCheckbox(String label, String value) {
    return CheckboxListTile(
      title: Text(label),
      value: _selectedSpecialties.contains(value),
      onChanged: (bool? selected) {
        setState(() {
          if (selected == true) {
            if (!_selectedSpecialties.contains(value)) {
              _selectedSpecialties.add(value);
            }
          } else {
            _selectedSpecialties.removeWhere((specialty) => specialty == value);
          }
        });
      },
      activeColor: wellnessPrimaryColor,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
  
  // Réinitialiser tous les filtres
  void _resetFilters() {
    setState(() {
      _searchQuery = null;
      _selectedRadius = 5000;
      _minRating = 0.0;
      _selectedSpecialties = [];
      
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      } else {
        _selectedCategory = null;
      }
      
      _selectedSubCategory = null;
      _selectedCriteria = [];
      _selectedDate = DateTime.now();
      _selectedTimeSlot = null;
    });
    
    // Mettre à jour les critères si une catégorie est sélectionnée
    if (_selectedCategory != null) {
      _updateCriteria();
    }
  }
  
  // Construire les onglets de filtres
  Widget _buildFilterTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentFilterTab = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _currentFilterTab == 0 ? wellnessPrimaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Catégories',
                  style: TextStyle(
                    color: _currentFilterTab == 0 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentFilterTab = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: _currentFilterTab == 1 ? wellnessPrimaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Critères',
                  style: TextStyle(
                    color: _currentFilterTab == 1 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentFilterTab = 2),
              child: Container(
                decoration: BoxDecoration(
                  color: _currentFilterTab == 2 ? wellnessPrimaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Disponibilité',
                  style: TextStyle(
                    color: _currentFilterTab == 2 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Construire les filtres de catégorie
  Widget _buildCategoryFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recherche par mot-clé
        TextField(
          decoration: InputDecoration(
            labelText: 'Rechercher par nom',
            hintText: 'Ex: Yoga, Spa, Massage...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().isEmpty ? null : value.trim();
            });
          },
          controller: TextEditingController(text: _searchQuery ?? ''),
        ),
        SizedBox(height: 20),
        
        // Rayon de recherche (Slider)
        Text('Rayon de recherche: ${(_selectedRadius/1000).toStringAsFixed(1)} km',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: _selectedRadius,
          min: 1000, // 1km
          max: 50000, // 50km
          divisions: 49,
          label: '${(_selectedRadius/1000).toStringAsFixed(1)} km',
          onChanged: (value) {
            setState(() {
              _selectedRadius = value;
            });
          },
          activeColor: wellnessPrimaryColor,
        ),
        SizedBox(height: 15),
        
        // Note minimale
        Text('Note minimale: ${_minRating.toStringAsFixed(1)}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: _minRating,
          min: 0,
          max: 5,
          divisions: 10,
          label: _minRating.toStringAsFixed(1),
          onChanged: (value) {
            setState(() {
              _minRating = value;
            });
          },
          activeColor: wellnessPrimaryColor,
        ),
        SizedBox(height: 20),
        
        // Catégories principales
        Text(
          'Catégories principales:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        _isLoadingCategories 
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: _categories.map((category) {
                return RadioListTile<WellnessCategoryModel>(
                  title: Text(category.name),
                  value: category,
                  groupValue: _selectedCategory,
                  onChanged: (WellnessCategoryModel? value) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedSubCategory = null;
                      _updateCriteria();
                    });
                  },
                  activeColor: wellnessPrimaryColor,
                  dense: true,
                );
              }).toList(),
            ),
        SizedBox(height: 15),
        
        // Sous-catégories
        if (_selectedCategory != null && _selectedCategory!.subCategories.isNotEmpty) ...[
          Text(
            'Sous-catégories:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _selectedCategory!.subCategories.map((subCategory) {
              final isSelected = subCategory == _selectedSubCategory;
              return FilterChip(
                label: Text(subCategory),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    _selectedSubCategory = selected ? subCategory : null;
                  });
                },
                selectedColor: wellnessPrimaryColor.withOpacity(0.3),
                checkmarkColor: wellnessPrimaryColor,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
  
  // Construire les filtres de critères
  Widget _buildCriteriaFilters() {
    if (_selectedCategory == null) {
      return Center(
        child: Text(
          'Veuillez d\'abord sélectionner une catégorie',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    if (_selectedCriteria.isEmpty) {
      _updateCriteria();
      
      if (_selectedCriteria.isEmpty) {
        return Center(
          child: Text(
            'Aucun critère disponible pour cette catégorie',
            style: TextStyle(fontSize: 16),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Critères pour ${_selectedSubCategory ?? _selectedCategory!.name}:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Définissez l\'importance de chaque critère (0 = non important, 10 = très important)',
          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
        SizedBox(height: 20),
        ..._selectedCriteria.map((criteria) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${criteria.criteriaName}: ${criteria.value.toInt()}',
                style: TextStyle(fontSize: 15),
              ),
              Slider(
                value: criteria.value,
                min: 0,
                max: 10,
                divisions: 10,
                label: criteria.value.toInt().toString(),
                onChanged: (value) {
                  setState(() {
                    criteria.value = value;
                  });
                },
                activeColor: wellnessPrimaryColor,
              ),
              SizedBox(height: 10),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  // Construire les filtres de disponibilité
  Widget _buildAvailabilityFilters() {
    if (_selectedCategory == null) {
      return Center(
        child: Text(
          'Veuillez d\'abord sélectionner une catégorie',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    if (_selectedCategory!.hasAvailability == false) {
      return Center(
        child: Text(
          'La réservation n\'est pas disponible pour cette catégorie',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Disponibilité:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 15),
        Text('Choisir une date:', style: TextStyle(fontSize: 15)),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 30)),
                  );
                  
                  if (pickedDate != null) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                    
                    // Charger les créneaux horaires pour cette date
                    if (_selectedPlace != null) {
                      _loadAvailableTimeSlots();
                    }
                  }
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        
        if (_selectedPlace != null) ...[
          Text('Créneaux disponibles:', style: TextStyle(fontSize: 15)),
          SizedBox(height: 10),
          _availableTimeSlots.isEmpty
              ? Center(
                  child: Text(
                    'Aucun créneau disponible pour cette date',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTimeSlots.map((timeSlot) {
                    final isSelected = timeSlot == _selectedTimeSlot;
                    return ChoiceChip(
                      label: Text(timeSlot),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedTimeSlot = selected ? timeSlot : null;
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: wellnessPrimaryColor.withOpacity(0.3),
                    );
                  }).toList(),
                ),
        ] else ...[
          Center(
            child: Text(
              'Sélectionnez d\'abord un établissement sur la carte pour voir les disponibilités',
              style: TextStyle(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
} 
