import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import '../models/map_selector.dart';
import '../widgets/map_selector.dart' as widget_selector;
import '../services/map_service.dart';
import 'map_restaurant_screen.dart' as restaurant_map;
import 'map_leisure_screen.dart' as leisure_map;
import 'map_friends_screen.dart' as friends_map;
import '../utils/map_colors.dart';
import '../main.dart';
import '../utils/constants.dart';

// Utiliser des couleurs directement pour éviter le conflit
final wellnessPrimaryColor = Color(0xFF5C6BC0);

// Fonction pour obtenir l'URL de base de l'API
String getBaseUrl() {
  // En production, utilisez le domaine réel
  // En développement, utilisez l'IP du serveur local
  const bool isProduction = false;
  if (isProduction) {
    return 'https://api.choice-app.com';  // URL de production
  } else {
    // URL de développement
    // 10.0.2.2 pour l'émulateur Android (correspond à localhost sur la machine hôte)
    // localhost ou 127.0.0.1 pour iOS et tests sur appareil
    return 'http://10.0.2.2:3000';
  }
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

  // Filtres
  String? _searchQuery;
  List<String> _selectedSpecialties = [];
  double _minRating = 0.0;
  double _selectedRadius = 5000; // 5km par défaut
  
  // Variables manquantes pour la compatibilité avec MapScreen
  Map<String, dynamic>? _selectedPlace;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initialPosition = widget.initialPosition ?? const gmaps.LatLng(48.856614, 2.3522219);
    _checkLocationPermission();
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
      
      // Paramètres de base pour la requête API
      final double latitude = _currentPosition?.latitude ?? _initialPosition.latitude;
      final double longitude = _currentPosition?.longitude ?? _initialPosition.longitude;
      
      // Utiliser l'API beauty_places au lieu de producers/advanced-search
      final uri = Uri.parse('${getBaseUrl()}/api/beauty_places/nearby');
      
      // Construire les paramètres de requête
      final Map<String, String> queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': _selectedRadius.toString(),
        'limit': '50', // Limiter le nombre de résultats
      };
      
      // Ajouter les filtres
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        queryParams['q'] = _searchQuery!;
      }
      
      if (_selectedSpecialties.isNotEmpty) {
        queryParams['specialties'] = _selectedSpecialties.join(',');
      }
      
      if (_minRating > 0) {
        queryParams['min_rating'] = _minRating.toString();
      }
      
      // Faire la requête HTTP
      print('🔍 Requête API: ${uri.toString()} avec params ${queryParams.toString()}');
      
      final response = await http.get(
        Uri.parse('${uri.toString()}').replace(queryParameters: queryParams),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode != 200) {
        throw Exception('Erreur API: ${response.statusCode} - ${response.body}');
      }
      
      // Décoder les résultats
      final data = json.decode(response.body);
      List<Map<String, dynamic>> places = [];
      
      // Vérifier le format de la réponse
      if (data is List) {
        // Format liste simple
        places = List<Map<String, dynamic>>.from(data);
      } else if (data['results'] is List) {
        // Format avec wrapper "results"
        places = List<Map<String, dynamic>>.from(data['results']);
      } else if (data['beautyPlaces'] is List) {
        // Format avec wrapper "beautyPlaces"
        places = List<Map<String, dynamic>>.from(data['beautyPlaces']);
      } else {
        throw Exception('Format de réponse non reconnu');
      }
      
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
          mapType = 'wellness';
      }
    } else {
      mapType = value.toString();
    }
    if (mapType == 'wellness') return;
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
                      Text(
                        'Filtres à venir prochainement',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
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
} 
