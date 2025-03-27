import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'utils.dart';
import '../widgets/maps/adaptive_map_widget.dart';
import 'map_screen.dart';
import 'producer_screen.dart';
import '../services/api_service.dart';
import '../widgets/filters/filter_panel.dart';
import '../widgets/filters/filter_section.dart';
import '../widgets/filters/filter_toggle_card.dart';
import '../widgets/filters/filter_chip_group.dart';
import '../widgets/filters/filter_chip.dart';
import '../widgets/filters/floating_filter_button.dart';
import '../widgets/filters/custom_filter_chip.dart' as custom;
import 'myprofile_screen.dart';

class MapFriendsScreen extends StatefulWidget {
  final String? userId;
  
  const MapFriendsScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<MapFriendsScreen> createState() => _MapFriendsScreenState();
}

class _MapFriendsScreenState extends State<MapFriendsScreen> {
  LatLng _initialPosition = const LatLng(48.866667, 2.333333); // Paris par défaut
  GoogleMapController? _mapController;
  LocationData? _currentPosition;
  bool _isUsingLiveLocation = false;
  Timer? _locationUpdateTimer;

  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isMapReady = false;
  bool _shouldShowMarkers = true;
  
  // Filter properties
  bool _showInterests = true; // Show friends' interests
  bool _showChoices = true; // Show friends' choices
  List<String> _selectedFriends = []; // Selected friends to filter
  List<String> _selectedCategories = []; // Selected categories to filter
  
  // UI control properties
  bool _isFilterPanelVisible = false;
  bool _isPanelAnimating = false;

  // List of friends (will be fetched from backend)
  List<Map<String, dynamic>> _friendsList = [];
  
  final ApiService _apiService = ApiService();
  
  @override
  void initState() {
    super.initState();
    
    // Check location permissions on startup
    _checkLocationPermission();
    
    // Load friends list and map data
    _loadFriendsList();
    
    // Load markers after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchFriendsActivity();
      }
    });
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  /// Check and request location permissions
  Future<void> _checkLocationPermission() async {
    try {
      final Location location = Location();
      
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showSnackBar("Service de localisation désactivé. Utilisation de Paris par défaut.");
          return;
        }
      }
      
      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
        if (permissionStatus == PermissionStatus.denied) {
          _showSnackBar("Permissions de localisation refusées. Utilisation de Paris par défaut.");
          return;
        }
      }
      
      if (permissionStatus == PermissionStatus.deniedForever) {
        _showSnackBar("Permissions de localisation définitivement refusées. Utilisez les paramètres pour les activer.");
        return;
      }
      
      _getCurrentLocation(location);
    } catch (e) {
      print("❌ Erreur lors de la vérification des permissions: $e");
    }
  }
  
  /// Get current location
  Future<void> _getCurrentLocation(Location location) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await location.changeSettings(accuracy: LocationAccuracy.high);
      
      LocationData position = await location.getLocation();
      
      if (position.latitude == null || position.longitude == null) {
        _showSnackBar("Impossible d'obtenir des coordonnées valides. Veuillez réessayer.");
        setState(() {
          _isLoading = false;
          _isUsingLiveLocation = false;
        });
        return;
      }
      
      setState(() {
        _currentPosition = position;
        _initialPosition = LatLng(position.latitude!, position.longitude!);
        _isUsingLiveLocation = true;
      });
      
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_initialPosition, 14.0),
        );
      }
      
      _fetchFriendsActivity();
      _showSnackBar("Position GPS obtenue. Recherche des activités à proximité.");
      
      _setupLocationTracking(location);
    } catch (e) {
      print("❌ Erreur lors de l'obtention de la position: $e");
      _showSnackBar("Impossible d'obtenir votre position. Vérifiez que le GPS est activé.");
      setState(() {
        _isUsingLiveLocation = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Configure periodic position updates
  void _setupLocationTracking(Location location) {
    _locationUpdateTimer?.cancel();
    
    if (_isUsingLiveLocation) {
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (!mounted || !_isUsingLiveLocation) {
          timer.cancel();
          return;
        }
        
        try {
          LocationData position = await location.getLocation();
          
          if (_currentPosition != null && position.latitude != null && position.longitude != null) {
            if (_currentPosition!.latitude != null && _currentPosition!.longitude != null) {
              double distance = _calculateDistance(
                _currentPosition!.latitude!, _currentPosition!.longitude!,
                position.latitude!, position.longitude!
              );
              
              if (distance > 50) { // Only if moved more than 50 meters
                setState(() {
                  _currentPosition = position;
                  _initialPosition = LatLng(position.latitude!, position.longitude!);
                });
                
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLng(_initialPosition),
                  );
                }
                
                _fetchFriendsActivity();
                print("📍 Position mise à jour: ${position.latitude}, ${position.longitude}");
              }
            }
          }
        } catch (e) {
          print("❌ Erreur lors de la mise à jour périodique de la position: $e");
        }
      });
      
      print("✅ Suivi de localisation en direct activé");
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * 
      sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Helper function to convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Load friends list from backend
  Future<void> _loadFriendsList() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final friends = await _apiService.getUserFriends(widget.userId ?? '');
      
      if (friends.isEmpty) {
        _showSnackBar("Vous n'avez pas encore d'amis. Ajoutez des amis pour voir leurs activités.");
      } else {
        setState(() {
          _friendsList = friends.map((friend) => {
            '_id': friend.id,
            'name': friend.name,
            'avatar': friend.avatar,
            'status': friend.status,
            'lastSeen': friend.lastSeen,
            'location': friend.location,
            'interests': friend.interests,
            'choices': friend.choices,
          }).toList();
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement de la liste d'amis: $e");
      _showSnackBar("Erreur réseau lors du chargement des amis.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetch friends' activity and create markers
  Future<void> _fetchFriendsActivity() async {
    if (_friendsList.isEmpty) return;

    setState(() {
      _isLoading = true;
      _markers.clear();
    });

    try {
      for (var friend in _friendsList) {
        if (_selectedFriends.isNotEmpty && !_selectedFriends.contains(friend['_id'])) {
          continue;
        }

        // Fetch friend's interests
        if (_showInterests) {
          final interests = await _apiService.getFriendInterests(friend['_id']);
          if (interests.isNotEmpty) {
            _createInterestMarkers(interests, friend);
          }
        }

        // Fetch friend's choices
        if (_showChoices) {
          final choices = await _apiService.getFriendChoices(friend['_id']);
          if (choices.isNotEmpty) {
            _createChoiceMarkers(choices, friend);
          }
        }
      }

      if (_markers.isNotEmpty && _mapController != null) {
        _fitMarkersOnMap();
      }
    } catch (e) {
      print("❌ Erreur lors de la récupération des activités des amis: $e");
      _showSnackBar("Erreur lors du chargement des activités des amis.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Create markers for friend's interests
  void _createInterestMarkers(List<dynamic> interests, Map<String, dynamic> friend) {
    for (var interest in interests) {
      if (interest['venue'] != null && interest['venue']['location'] != null) {
        final coordinates = interest['venue']['location']['coordinates'];
        if (coordinates != null && coordinates.length >= 2) {
          final marker = Marker(
            markerId: MarkerId('interest_${interest['_id']}'),
            position: LatLng(coordinates[1], coordinates[0]),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: interest['venue']['name'] ?? 'Lieu inconnu',
              snippet: 'Intérêt de ${friend['name']}',
            ),
          );
          setState(() {
            _markers.add(marker);
          });
        }
      }
    }
  }

  /// Create markers for friend's choices
  void _createChoiceMarkers(List<dynamic> choices, Map<String, dynamic> friend) {
    for (var choice in choices) {
      if (choice['venue'] != null && choice['venue']['location'] != null) {
        final coordinates = choice['venue']['location']['coordinates'];
        if (coordinates != null && coordinates.length >= 2) {
          final marker = Marker(
            markerId: MarkerId('choice_${choice['_id']}'),
            position: LatLng(coordinates[1], coordinates[0]),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: choice['venue']['name'] ?? 'Lieu inconnu',
              snippet: 'Choix de ${friend['name']}',
            ),
          );
          setState(() {
            _markers.add(marker);
          });
        }
      }
    }
  }

  /// Show interest details dialog
  void _showInterestDetails(Map<String, dynamic> interest, Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête avec image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Image de l'établissement
                    SizedBox(
                      height: 180,
                      child: interest['venue'] != null && 
                             interest['venue']['photo'] != null && 
                             interest['venue']['photo'].toString().isNotEmpty
                          ? Image.network(
                              interest['venue']['photo'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.blue.withOpacity(0.2),
                                  child: const Center(
                                    child: Icon(Icons.interests, size: 50, color: Colors.blue),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.blue.withOpacity(0.2),
                              child: const Center(
                                child: Icon(Icons.interests, size: 50, color: Colors.blue),
                              ),
                            ),
                    ),
                    // Gradient et badge "Intérêt"
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Badge "Intérêt"
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_border, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              "Intérêt",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Nom du lieu
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            interest['venue'] != null ? 
                              (interest['venue']['name'] ?? 'Lieu inconnu') : 
                              'Lieu inconnu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundImage: friend['photo'] != null && friend['photo'].toString().isNotEmpty
                                    ? NetworkImage(friend['photo'])
                                    : null,
                                child: friend['photo'] == null || friend['photo'].toString().isEmpty
                                    ? Text(
                                        friend['name'] != null ? friend['name'][0] : '?',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${friend['name']} est intéressé(e)",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bouton de fermeture
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Contenu principal avec défilement
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Adresse
                      if (interest['venue'] != null && 
                          interest['venue']['address'] != null && 
                          interest['venue']['address'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  interest['venue']['address'],
                                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Catégorie
                      if (interest['venue'] != null && 
                          interest['venue']['category'] != null && 
                          interest['venue']['category'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.category, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  interest['venue']['category'],
                                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Date d'intérêt
                      if (interest['created_at'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Intéressé depuis le ${_formatDate(interest['created_at'])}",
                                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Description
                      if (interest['venue'] != null && 
                          interest['venue']['description'] != null && 
                          interest['venue']['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "À propos de ce lieu",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                interest['venue']['description'],
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      
                      // Commentaire
                      if (interest['comment'] != null && interest['comment'].toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Commentaire",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                interest['comment'],
                                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Boutons d'action
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.person,
                      label: "Profil",
                      color: Colors.purple,
                      onTap: () => _navigateToFriendProfile(friend['_id']),
                    ),
                    _buildActionButton(
                      icon: Icons.directions,
                      label: "Itinéraire",
                      color: Colors.green,
                      onTap: () {
                        // Logique pour l'itinéraire
                        Navigator.pop(context);
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.add_circle_outline,
                      label: "Aussi intéressé",
                      color: Colors.blue,
                      onTap: () {
                        // Logique pour marquer l'intérêt
                        Navigator.pop(context);
                        _showSnackBar("Intérêt enregistré !");
                      },
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

  // Méthode pour afficher les détails d'un choix avec une UI élégante
  void _showChoiceDetails(Map<String, dynamic> choice, Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête avec image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Image de l'établissement
                    SizedBox(
                      height: 180,
                      child: choice['venue'] != null && 
                             choice['venue']['photo'] != null && 
                             choice['venue']['photo'].toString().isNotEmpty
                          ? Image.network(
                              choice['venue']['photo'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.green.withOpacity(0.2),
                                  child: const Center(
                                    child: Icon(Icons.check_circle, size: 50, color: Colors.green),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.green.withOpacity(0.2),
                              child: const Center(
                                child: Icon(Icons.check_circle, size: 50, color: Colors.green),
                              ),
                            ),
                    ),
                    // Gradient et badge "Choix"
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Badge "Choix"
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              "Choix",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Nom du lieu
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            choice['venue'] != null ? 
                              (choice['venue']['name'] ?? 'Lieu inconnu') : 
                              'Lieu inconnu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundImage: friend['photo'] != null && friend['photo'].toString().isNotEmpty
                                    ? NetworkImage(friend['photo'])
                                    : null,
                                child: friend['photo'] == null || friend['photo'].toString().isEmpty
                                    ? Text(
                                        friend['name'] != null ? friend['name'][0] : '?',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${friend['name']} y est allé(e)",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bouton de fermeture
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Contenu principal avec défilement
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date de visite
                      if (choice['visit_date'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.event, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Visite le ${_formatDate(choice['visit_date'])}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Adresse
                      if (choice['venue'] != null && 
                          choice['venue']['address'] != null && 
                          choice['venue']['address'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  choice['venue']['address'],
                                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Catégorie
                      if (choice['venue'] != null && 
                          choice['venue']['category'] != null && 
                          choice['venue']['category'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.category, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  choice['venue']['category'],
                                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Note
                      if (choice['rating'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "${choice['rating'].toStringAsFixed(1)}/5",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "noté par ${friend['name']}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Avis
                      if (choice['review'] != null && choice['review'].toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: friend['photo'] != null && friend['photo'].toString().isNotEmpty
                                        ? NetworkImage(friend['photo'])
                                        : null,
                                    child: friend['photo'] == null || friend['photo'].toString().isEmpty
                                        ? Text(
                                            friend['name'] != null ? friend['name'][0] : '?',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Avis de ${friend['name']}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                choice['review'],
                                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      
                      // Photos
                      if (choice['photos'] != null && choice['photos'] is List && choice['photos'].isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Photos",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: choice['photos'].length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Logique pour afficher la photo en plein écran
                                    },
                                    child: Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: NetworkImage(choice['photos'][index]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              
              // Boutons d'action
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.person,
                      label: "Profil",
                      color: Colors.purple,
                      onTap: () => _navigateToFriendProfile(friend['_id']),
                    ),
                    _buildActionButton(
                      icon: Icons.directions,
                      label: "Itinéraire",
                      color: Colors.green,
                      onTap: () {
                        // Logique pour l'itinéraire
                        Navigator.pop(context);
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.add_circle_outline,
                      label: "Y aller aussi",
                      color: Colors.blue,
                      onTap: () {
                        // Logique pour marquer l'intérêt
                        Navigator.pop(context);
                        _showSnackBar("Intérêt enregistré !");
                      },
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

  // Construit un bouton d'action pour le bas du popup
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Formater une date
  String _formatDate(dynamic date) {
    if (date == null) return "Date inconnue";
    
    DateTime dateTime;
    if (date is String) {
      dateTime = DateTime.tryParse(date) ?? DateTime.now();
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return "Date inconnue";
    }
    
    return "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}";
  }

  // Afficher un message dans la snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Navigate to friend profile screen
  void _navigateToFriendProfile(String friendId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyProfileScreen(userId: friendId, isCurrentUser: false),
      ),
    );
  }

  /// Fit map to show all markers
  void _fitMarkersOnMap() {
    if (_markers.isEmpty || _mapController == null) return;
    
    try {
      double minLat = 90;
      double maxLat = -90;
      double minLng = 180;
      double maxLng = -180;
      
      for (final marker in _markers) {
        if (marker.position.latitude < minLat) minLat = marker.position.latitude;
        if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
        if (marker.position.longitude < minLng) minLng = marker.position.longitude;
        if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
      }
      
      final latPadding = (maxLat - minLat) * 0.2;
      final lngPadding = (maxLng - minLng) * 0.2;
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (e) {
      print("❌ Erreur lors de l'ajustement de la carte: $e");
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 12));
    }
  }

  /// Toggle filter panel visibility
  void _toggleFilterPanel() {
    if (_isPanelAnimating) return;
    
    setState(() {
      _isPanelAnimating = true;
      _isFilterPanelVisible = !_isFilterPanelVisible;
    });
  }

  /// Build filter panel
  Widget _buildFilterPanel() {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterPanelHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section des amis
                    FilterSection(
                      title: 'Amis',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _friendsList.map((friend) => custom.CustomFilterChip(
                          label: friend['name'] ?? 'Ami',
                          isSelected: _selectedFriends.contains(friend['_id']),
                          onToggle: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFriends.add(friend['_id']);
                              } else {
                                _selectedFriends.remove(friend['_id']);
                              }
                            });
                          },
                        )).toList(),
                      ),
                    ),
                    
                    // Section des types d'activité
                    FilterSection(
                      title: 'Types d\'activité',
                      child: Column(
                        children: [
                          FilterToggleCard(
                            title: 'Intérêts',
                            subtitle: 'Lieux préférés des amis',
                            icon: Icons.favorite,
                            isSelected: _showInterests,
                            onTap: () {
                              setState(() {
                                _showInterests = !_showInterests;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          FilterToggleCard(
                            title: 'Choix',
                            subtitle: 'Lieux visités par les amis',
                            icon: Icons.check_circle,
                            isSelected: _showChoices,
                            onTap: () {
                              setState(() {
                                _showChoices = !_showChoices;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Section des catégories
                    FilterSection(
                      title: 'Catégories',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Restaurant', 'Bar', 'Café', 'Parc', 'Musée',
                          'Théâtre', 'Cinéma', 'Shopping', 'Sport'
                        ].map((category) => custom.CustomFilterChip(
                          label: category,
                          isSelected: _selectedCategories.contains(category),
                          onToggle: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                        )).toList(),
                      ),
                    ),
                    
                    // Boutons d'action
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedFriends = [];
                                _selectedCategories = [];
                                _showInterests = true;
                                _showChoices = true;
                              });
                              _fetchFriendsActivity();
                            },
                            child: const Text('Réinitialiser'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _fetchFriendsActivity();
                              _toggleFilterPanel();
                            },
                            child: const Text('Appliquer'),
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
    );
  }

  /// Build filter panel header
  Widget _buildFilterPanelHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 50, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Filtres',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _toggleFilterPanel,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AdaptiveMapWidget(
            initialPosition: _initialPosition,
            initialZoom: 12.0,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              setState(() {
                _isMapReady = true;
              });
              if (_markers.isEmpty && _shouldShowMarkers) {
                _fetchFriendsActivity();
              }
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Chargement des activités...",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          FloatingFilterButton(
            isActive: _isFilterPanelVisible || 
                     _selectedFriends.isNotEmpty || 
                     _selectedCategories.isNotEmpty,
            onTap: _toggleFilterPanel,
            label: 'Filtres',
          ),
          AnimatedPositioned(
            top: _isFilterPanelVisible ? 0 : -MediaQuery.of(context).size.height,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.85,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            onEnd: () {
              setState(() {
                _isPanelAnimating = false;
              });
            },
            child: _buildFilterPanel(),
          ),
        ],
      ),
    );
  }
} 