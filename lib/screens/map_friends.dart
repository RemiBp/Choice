import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'utils.dart';
import '../widgets/maps/adaptive_map_widget.dart';
import 'map_screen.dart';
import 'map_leisure_screen.dart';
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
    }
  }
  
  // Helper function to convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
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
  
  /// Load the friends list from the backend
  Future<void> _loadFriendsList() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final friends = await _apiService.getFriends(widget.userId ?? '');
      
      if (friends.isEmpty) {
        _showSnackBar("Vous n'avez pas encore d'amis. Ajoutez des amis pour voir leurs activités.");
      } else {
        setState(() {
          _friendsList = friends;
        });
        print("✅ ${_friendsList.length} amis chargés");
      }
    } catch (e) {
      print("❌ Exception lors de la requête de liste d'amis: $e");
      _showSnackBar("Erreur lors du chargement des amis. Veuillez réessayer.");
      _createMockFriendsList();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Create a mock friends list for demo
  void _createMockFriendsList() {
    _friendsList = [
      {
        "id": "1",
        "name": "Sophie Martin",
        "avatar": "https://randomuser.me/api/portraits/women/44.jpg",
        "interests": ["Théâtre", "Musique", "Gastronomie"]
      },
      {
        "id": "2",
        "name": "Thomas Dubois",
        "avatar": "https://randomuser.me/api/portraits/men/32.jpg",
        "interests": ["Cinéma", "Art", "Danse"]
      },
      {
        "id": "3",
        "name": "Julie Laurent",
        "avatar": "https://randomuser.me/api/portraits/women/68.jpg",
        "interests": ["Musique", "Festival", "Bar"]
      },
      {
        "id": "4",
        "name": "Antoine Bernard",
        "avatar": "https://randomuser.me/api/portraits/men/41.jpg",
        "interests": ["Gastronomie", "Vin", "Jazz"]
      },
      {
        "id": "5",
        "name": "Emma Petit",
        "avatar": "https://randomuser.me/api/portraits/women/33.jpg",
        "interests": ["Exposition", "Musée", "Opéra"]
      }
    ];
  }
  
  /// Fetch friends' activity from the backend
  Future<void> _fetchFriendsActivity() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final activities = await _apiService.getFriendsActivity(
        userId: widget.userId ?? '',
        latitude: _initialPosition.latitude,
        longitude: _initialPosition.longitude,
        showInterests: _showInterests,
        showChoices: _showChoices,
        selectedFriends: _selectedFriends,
        selectedCategories: _selectedCategories,
      );

      if (activities.isEmpty) {
        _showSnackBar("Aucune activité trouvée pour vos amis dans cette zone.");
        setState(() {
          _markers.clear();
          _isLoading = false;
        });
        return;
      }

      _processMarkers(activities);
    } catch (e) {
      print("❌ Exception lors de la requête: $e");
      _showSnackBar("Erreur lors du chargement des activités. Veuillez réessayer.");
      _createMockFriendsActivity();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Create mock friends' activity data for demo
  void _createMockFriendsActivity() {
    List<Map<String, dynamic>> mockActivities = [
      {
        "id": "act1",
        "type": "interest",
        "location": {"type": "Point", "coordinates": [2.3522, 48.8566]}, // Paris
        "venue": {
          "id": "v1",
          "name": "Théâtre de la Ville",
          "category": "Théâtre",
          "address": "2 Place du Châtelet, 75004 Paris",
          "photo": "https://images.unsplash.com/photo-1503095396549-807759245b35?w=500&q=80"
        },
        "friends": [
          {"id": "1", "name": "Sophie Martin", "avatar": "https://randomuser.me/api/portraits/women/44.jpg"},
          {"id": "3", "name": "Julie Laurent", "avatar": "https://randomuser.me/api/portraits/women/68.jpg"}
        ],
        "date": "2023-11-15T19:30:00Z"
      },
      {
        "id": "act2",
        "type": "choice",
        "location": {"type": "Point", "coordinates": [2.3488, 48.8534]}, // Near Notre-Dame
        "venue": {
          "id": "v2",
          "name": "Musée du Louvre",
          "category": "Musée",
          "address": "Rue de Rivoli, 75001 Paris",
          "photo": "https://images.unsplash.com/photo-1605628738224-3fbd9b8b75de?w=500&q=80"
        },
        "friends": [
          {"id": "2", "name": "Thomas Dubois", "avatar": "https://randomuser.me/api/portraits/men/32.jpg"},
          {"id": "5", "name": "Emma Petit", "avatar": "https://randomuser.me/api/portraits/women/33.jpg"}
        ],
        "date": "2023-11-10T14:00:00Z"
      },
      {
        "id": "act3",
        "type": "interest",
        "location": {"type": "Point", "coordinates": [2.3404, 48.8600]}, // Near Opéra
        "venue": {
          "id": "v3",
          "name": "Palais Garnier",
          "category": "Opéra",
          "address": "Place de l'Opéra, 75009 Paris",
          "photo": "https://images.unsplash.com/photo-1609881142780-7a1a2a552a9e?w=500&q=80"
        },
        "friends": [
          {"id": "4", "name": "Antoine Bernard", "avatar": "https://randomuser.me/api/portraits/men/41.jpg"},
          {"id": "5", "name": "Emma Petit", "avatar": "https://randomuser.me/api/portraits/women/33.jpg"}
        ],
        "date": "2023-11-20T20:00:00Z"
      },
      {
        "id": "act4",
        "type": "choice",
        "location": {"type": "Point", "coordinates": [2.3580, 48.8637]}, // Near Centre Pompidou
        "venue": {
          "id": "v4",
          "name": "Centre Pompidou",
          "category": "Exposition",
          "address": "Place Georges-Pompidou, 75004 Paris",
          "photo": "https://images.unsplash.com/photo-1575379573799-a6e591618046?w=500&q=80"
        },
        "friends": [
          {"id": "2", "name": "Thomas Dubois", "avatar": "https://randomuser.me/api/portraits/men/32.jpg"},
          {"id": "1", "name": "Sophie Martin", "avatar": "https://randomuser.me/api/portraits/women/44.jpg"}
        ],
        "date": "2023-11-05T11:00:00Z"
      },
      {
        "id": "act5",
        "type": "interest",
        "location": {"type": "Point", "coordinates": [2.3376, 48.8606]}, // Near Comédie Française
        "venue": {
          "id": "v5",
          "name": "La Comédie-Française",
          "category": "Théâtre",
          "address": "1 Place Colette, 75001 Paris",
          "photo": "https://images.unsplash.com/photo-1503095396549-807759245b35?w=500&q=80"
        },
        "friends": [
          {"id": "3", "name": "Julie Laurent", "avatar": "https://randomuser.me/api/portraits/women/68.jpg"}
        ],
        "date": "2023-11-25T19:00:00Z"
      }
    ];
    
    _processMarkers(mockActivities);
  }
  
  /// Process activity data into map markers
  void _processMarkers(List<dynamic> activities) {
    if (!mounted) return;
    
    Set<Marker> newMarkers = {};
    
    for (var activity in activities) {
      try {
        // Verify that location and coordinates exist and are valid
        if (activity['location'] == null || activity['location']['coordinates'] == null) {
          print('❌ Missing coordinates for an activity');
          continue;
        }
        
        final List coordinates = activity['location']['coordinates'];
        
        // Verify that coordinates is a list with at least 2 elements
        if (coordinates.length < 2 || activity['id'] == null) {
          print('❌ Incomplete coordinates or missing ID');
          continue;
        }
        
        // Safely convert to double
        double lon = coordinates[0] is num ? coordinates[0].toDouble() : 0.0;
        double lat = coordinates[1] is num ? coordinates[1].toDouble() : 0.0;
        
        // Verify that coordinates are within valid limits
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          print('❌ Invalid coordinates: out of bounds (lat: $lat, lon: $lon)');
          continue;
        }
        
        final String id = activity['id'];
        final String venueName = activity['venue']?['name'] ?? 'Lieu sans nom';
        final String venueCategory = activity['venue']?['category'] ?? 'Catégorie inconnue';
        final String activityType = activity['type'] ?? 'interest';
        final List<dynamic> friends = activity['friends'] ?? [];
        
        // Get appropriate marker color based on activity type and category
        final BitmapDescriptor markerIcon = _getMarkerIcon(activityType, venueCategory);
        
        // Create the marker
        Marker marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: venueName,
            snippet: "$venueCategory • ${friends.length} ami${friends.length > 1 ? 's' : ''}",
          ),
          onTap: () {
            // Show detailed activity view
            _showActivityDetails(context, activity);
          },
        );
        
        newMarkers.add(marker);
      } catch (e) {
        print("❌ Error creating marker: $e");
      }
    }
    
    setState(() {
      _markers = newMarkers;
    });
    
    // Adjust map to show all markers
    if (_markers.isNotEmpty && _mapController != null) {
      _fitMarkersOnMap();
    }
  }
  
  /// Get a marker icon based on activity type and venue category
  BitmapDescriptor _getMarkerIcon(String activityType, String category) {
    // Colors based on activity type
    if (activityType == 'interest') {
      // Blue hues for interests
      if (category.toLowerCase().contains('théâtre') || category.toLowerCase().contains('theatre')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      } else if (category.toLowerCase().contains('musique') || category.toLowerCase().contains('concert')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      } else if (category.toLowerCase().contains('ciném') || category.toLowerCase().contains('cinema')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      } else {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }
    } else {
      // Green hues for choices (visited places)
      if (category.toLowerCase().contains('théâtre') || category.toLowerCase().contains('theatre')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (category.toLowerCase().contains('musique') || category.toLowerCase().contains('concert')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (category.toLowerCase().contains('ciném') || category.toLowerCase().contains('cinema')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      }
    }
  }
  
  /// Show activity details dialog
  void _showActivityDetails(BuildContext context, Map<String, dynamic> activity) {
    final String venueName = activity['venue']?['name'] ?? 'Lieu sans nom';
    final String venueCategory = activity['venue']?['category'] ?? 'Catégorie inconnue';
    final String venueAddress = activity['venue']?['address'] ?? 'Adresse inconnue';
    final List<dynamic> friends = activity['friends'] ?? [];
    final String activityType = activity['type'] ?? 'interest';
    final String photoUrl = activity['venue']?['photo'] ?? 
      'https://images.unsplash.com/photo-1518998053901-5348d3961a04?w=500&q=80';
    
    // Format date
    String formattedDate = 'Date inconnue';
    if (activity['date'] != null) {
      try {
        DateTime date = DateTime.parse(activity['date']);
        formattedDate = '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        print("❌ Error parsing date: $e");
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header image with venue name overlay
              Stack(
                children: [
                  // Header image
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Gradient overlay for better text readability
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Venue name
                  Positioned(
                    bottom: 10,
                    left: 15,
                    right: 15,
                    child: Text(
                      venueName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Activity type badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: activityType == 'interest' ? Colors.blue : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            activityType == 'interest' ? Icons.star_border : Icons.check_circle,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activityType == 'interest' ? "Intérêt" : "Visité",
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
              
              // Details section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Venue category and date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            venueCategory,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Venue address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            venueAddress,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Friends section
                    const Text(
                      "Amis intéressés :",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    
                    // Friends list
                    if (friends.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(friend['avatar'] ?? ''),
                              radius: 20,
                            ),
                            title: Text(friend['name'] ?? 'Ami inconnu'),
                            subtitle: Text(
                              activityType == 'interest' 
                                ? 'Souhaite y aller' 
                                : 'A visité cet endroit',
                              style: TextStyle(
                                color: activityType == 'interest' ? Colors.blue : Colors.green,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              // Navigate to friend profile
                              Navigator.pop(context); // Close dialog first
                              _navigateToFriendProfile(friend);
                            },
                          );
                        },
                      )
                    else
                      const Center(
                        child: Text(
                          "Aucun ami intéressé par ce lieu",
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('AJOUTER MON INTÉRÊT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showSnackBar("Intérêt ajouté avec succès !");
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.directions),
                          label: const Text('ITINÉRAIRE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showSnackBar("Ouverture de l'itinéraire...");
                          },
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
    );
  }
  
  /// Navigate to friend profile
  void _navigateToFriendProfile(Map<String, dynamic> friend) {
    _showSnackBar("Navigation vers le profil de ${friend['name']}");
    // Implement navigation to friend profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyProfileScreen(userId: friend['id']),
      ),
    );
  }
  
  /// Adjust map to show all markers
  void _fitMarkersOnMap() {
    if (_markers.isEmpty || _mapController == null) return;
    
    try {
      // Calculate bounds to include all markers
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
      
      // Add padding around bounds
      final latPadding = (maxLat - minLat) * 0.2;
      final lngPadding = (maxLng - minLng) * 0.2;
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      
      // Animate camera to include all markers
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (e) {
      print("❌ Error adjusting map: $e");
      // In case of error, revert to initial position with reasonable zoom
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 12));
    }
  }
  
  /// Apply custom style to the map
  Future<void> _setMapStyle(GoogleMapController controller) async {
    const String mapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#f5f5f5"
          }
        ]
      },
      {
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "on"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#f5f5f5"
          }
        ]
      },
      {
        "featureType": "administrative.land_parcel",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "administrative.land_parcel",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#bdbdbd"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#eeeeee"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "poi.attraction",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#f9ebff"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e5e5e5"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#f1f1f1"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#dadada"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      },
      {
        "featureType": "transit.line",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e5e5e5"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#eeeeee"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#c9c9c9"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#d8e9f3"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      }
    ]
    ''';

    try {
      await controller.setMapStyle(mapStyle);
    } catch (e) {
      print("❌ Error applying map style: $e");
    }
  }
  
  /// Show a snackbar
  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
  
  /// Build filter panel
  Widget _buildFilterPanel() {
    return FilterPanel(
      isVisible: _isFilterPanelVisible,
      onClose: () {
        setState(() {
          _isFilterPanelVisible = false;
        });
      },
      onReset: () {
        setState(() {
          _showInterests = true;
          _showChoices = true;
          _selectedFriends.clear();
          _selectedCategories.clear();
        });
        _fetchFriendsActivity();
      },
      filterSections: [
        // Activity type filters
        FilterSection(
          title: "Types d'activités",
          children: [
            Row(
              children: [
                Expanded(
                  child: FilterToggleCard(
                    isSelected: _showInterests,
                    onTap: () {
                      setState(() {
                        _showInterests = !_showInterests;
                      });
                      _fetchFriendsActivity();
                    },
                    icon: Icons.star_border,
                    title: "Intérêts",
                    subtitle: "Lieux qui intéressent vos amis",
                    selectedColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilterToggleCard(
                    isSelected: _showChoices,
                    onTap: () {
                      setState(() {
                        _showChoices = !_showChoices;
                      });
                      _fetchFriendsActivity();
                    },
                    icon: Icons.check_circle_outline,
                    title: "Visités",
                    subtitle: "Lieux que vos amis ont visités",
                    selectedColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // Friend filters
        if (_friendsList.isNotEmpty)
          FilterSection(
            title: "Filtrer par ami",
            trailing: _selectedFriends.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFriends.clear();
                    });
                    _fetchFriendsActivity();
                  },
                  child: Text(
                    "Effacer (${_selectedFriends.length})",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                )
              : null,
            children: [
              FilterChipGroup(
                title: 'Amis',
                filters: _friendsList.map((friend) {
                  final bool isSelected = _selectedFriends.contains(friend['id']);
                  return FilterChipItem(
                    text: friend['name'],
                    isActive: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedFriends.remove(friend['id']);
                        } else {
                          _selectedFriends.add(friend['id']);
                        }
                      });
                      _fetchFriendsActivity();
                    },
                  );
                }).toList(),
                onReset: _selectedFriends.isNotEmpty ? () {
                  setState(() {
                    _selectedFriends.clear();
                  });
                  _fetchFriendsActivity();
                } : null,
              ),
            ],
          ),
        
        // Category filters
        FilterSection(
          title: "Filtrer par catégorie",
          trailing: _selectedCategories.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategories.clear();
                  });
                  _fetchFriendsActivity();
                },
                child: Text(
                  "Effacer (${_selectedCategories.length})",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              )
            : null,
          children: [
            FilterChipGroup(
              title: 'Catégories',
              filters: [
                "Théâtre", "Musique", "Cinéma", "Exposition", "Musée", "Restaurant", "Bar"
              ].map((category) {
                final bool isSelected = _selectedCategories.contains(category);
                return FilterChipItem(
                  text: category,
                  isActive: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCategories.remove(category);
                      } else {
                        _selectedCategories.add(category);
                      }
                    });
                    _fetchFriendsActivity();
                  },
                );
              }).toList(),
              onReset: _selectedCategories.isNotEmpty ? () {
                setState(() {
                  _selectedCategories.clear();
                });
                _fetchFriendsActivity();
              } : null,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: false,
        child: Stack(
          children: [
            // Map
            AdaptiveMapWidget(
              initialPosition: _initialPosition,
              initialZoom: 13.0,
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                setState(() {
                  _isMapReady = true;
                });
                
                _setMapStyle(controller);
                
                if (_markers.isEmpty && _shouldShowMarkers) {
                  _fetchFriendsActivity();
                }
              },
              onTap: (position) {
                setState(() {
                  _isFilterPanelVisible = false;
                });
              },
            ),
            
            // Loading indicator
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
            
            // Filter button
            FloatingFilterButton(
              isActive: _isFilterPanelVisible,
              onTap: () {
                setState(() {
                  _isFilterPanelVisible = !_isFilterPanelVisible;
                });
              },
              label: "Filtres",
              activeColor: Colors.blue,
              inactiveColor: Colors.grey,
            ),
            
            // Filter panel
            if (_isFilterPanelVisible) _buildFilterPanel(),
          ],
        ),
      ),
    );
  }
}