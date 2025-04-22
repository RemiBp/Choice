import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart' as cluster_manager;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_hotspot.dart' as models;
import '../utils/constants.dart' as constants;
import '../utils/api_config.dart'; // Add ApiConfig import
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart'; // Needed for FilteringTextInputFormatter
import '../services/secure_storage_service.dart'; // Added for auth headers
import '../services/auth_service.dart'; // <<< ADDED AuthService import
import 'package:timeago/timeago.dart' as timeago;
import 'package:collection/collection.dart'; // Added for DeepCollectionEquality
import '../models/user_model.dart'; // <<< ADDED User model import
import 'package:mobile_scanner/mobile_scanner.dart'; // <-- Import scanner
import './offer_scanner_screen.dart'; // <-- Import the new screen (to be created)


void initializeTimeago() {
  try {
    // Simplified initialization - Ensure locales are added during build/main setup if needed
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('en', timeago.EnMessages());
    // Set default locale if needed, error prone if locale messages not loaded
    // timeago.setDefaultLocale('fr');
    print("🕰️ Timeago locales initialized.");
  } catch (e) {
    print("🕰️ Error initializing timeago locales: $e");
  }
}

// Represents items on the map for clustering (Zones or Active Users)
class Place with cluster_manager.ClusterItem {
  final String id; // Hotspot ID or 'active_userId'
  final String name;
  @override
  final LatLng location;
  final bool isZone; // Differentiates between Hotspot zones and Active Users
  final int? visitorCount; // Only for zones
  final DateTime? liveTimestamp; // Only for active users (lastSeen)

  Place({
    required this.id,
    required this.name,
    required this.location,
    required this.isZone,
    this.visitorCount,
    this.liveTimestamp,
  });

  // Note: Direct marker creation is now handled by the _markerBuilder
}

// NearbySearchEvent - Keep if nearby searches feature will be implemented later
class NearbySearchEvent {
  final String searchId; // ID of the UserActivity event
  final String userId;
  final String query;
  final DateTime timestamp;
  final String userName;
  final String? userProfilePicture;
  // Add location if you need to display it or use it
  // final LatLng location;

  NearbySearchEvent({
    required this.searchId,
    required this.userId,
    required this.query,
    required this.timestamp,
    required this.userName,
    this.userProfilePicture,
    // required this.location,
  });

  factory NearbySearchEvent.fromJson(Map<String, dynamic> json) {
    // Basic location parsing (optional, adjust if needed)
    // LatLng loc = const LatLng(0,0);
    // if (json['location']?['coordinates'] is List && json['location']['coordinates'].length == 2) {
    //   try {
    //      loc = LatLng(json['location']['coordinates'][1].toDouble(), json['location']['coordinates'][0].toDouble());
    //   } catch (_){}
    // }

    return NearbySearchEvent(
      searchId: json['searchId'] as String? ?? 'unknown_search_${Random().nextInt(1000)}',
      userId: json['userId'] as String? ?? 'unknown_user',
      query: json['query'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      userName: json['userName'] as String? ?? 'Utilisateur Inconnu',
      userProfilePicture: json['userProfilePicture'] as String?,
      // location: loc,
    );
  }
}

// Public User Profile Model
class PublicUserProfile {
  final String id;
  final String name;
  final String? profilePicture;
  final String? bio;
  final List<String> likedTags;

  PublicUserProfile({
    required this.id,
    required this.name,
    this.profilePicture,
    this.bio,
    this.likedTags = const [],
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      id: json['id'] as String? ?? json['_id'] as String? ?? 'unknown_id_${Random().nextInt(1000)}', // Handle potential null or different ID field (_id)
      name: json['name'] as String? ?? 'Utilisateur',
      profilePicture: json['profilePicture'] as String?,
      bio: json['bio'] as String?,
      likedTags: List<String>.from(json['liked_tags'] ?? []),
    );
  }
}

// Active User Model
class ActiveUser {
  final String userId;
  final String name;
  final String? profilePicture;
  final LatLng location;
  final DateTime lastSeen;
  final double? distance; // Keep distance if the backend provides it

  ActiveUser({
    required this.userId,
    required this.name,
    this.profilePicture,
    required this.location,
    required this.lastSeen,
    this.distance,
  });

  factory ActiveUser.fromJson(Map<String, dynamic> json) {
    LatLng? loc;
    // Handle different possible location structures from backend
    if (json['location'] != null) {
        if (json['location']['type'] == 'Point' && json['location']['coordinates'] is List && json['location']['coordinates'].length == 2) {
            // GeoJSON Point format
             try {
                 // GeoJSON is [longitude, latitude]
                loc = LatLng(json['location']['coordinates'][1].toDouble(), json['location']['coordinates'][0].toDouble());
             } catch (e) {
                 print("Error parsing GeoJSON coordinates: ${json['location']['coordinates']} - $e");
                 loc = const LatLng(0,0);
             }
        } else if (json['location'] is Map && json['location']['latitude'] != null && json['location']['longitude'] != null) {
             // Simple lat/lng map
              try {
                loc = LatLng(json['location']['latitude'].toDouble(), json['location']['longitude'].toDouble());
              } catch (e) {
                 print("Error parsing lat/lng coordinates: ${json['location']} - $e");
                 loc = const LatLng(0,0);
             }
        }
    }
    loc ??= const LatLng(0, 0); // Default if location is missing or invalid

    return ActiveUser(
      // Prefer _id from MongoDB if available, otherwise userId
      userId: json['_id'] as String? ?? json['userId'] as String? ?? 'unknown_user_${Random().nextInt(1000)}',
      name: json['name'] as String? ?? 'Utilisateur Actif',
      profilePicture: json['profilePicture'] as String?,
      location: loc,
      lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(), // Safer parsing
      distance: (json['distance'] as num?)?.toDouble(), // Keep distance if provided
    );
  }

  // Implement == and hashCode for listEquals to work correctly
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          name == other.name &&
          profilePicture == other.profilePicture &&
          location == other.location &&
          lastSeen == other.lastSeen;

  @override
  int get hashCode =>
      userId.hashCode ^
      name.hashCode ^
      profilePicture.hashCode ^
      location.hashCode ^
      lastSeen.hashCode;
}

class HeatmapScreen extends StatefulWidget {
  final String userId;
  
  const HeatmapScreen({super.key, required this.userId});

  @override
  _HeatmapScreenState createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> with TickerProviderStateMixin {
  // Authentication service
  final AuthService _authService = AuthService();

  // Controllers
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customDiscountController = TextEditingController(text: '15');
  final TextEditingController _customDurationController = TextEditingController(text: '1');
  
  // Offer controllers
  final TextEditingController _offerTitleController = TextEditingController();
  final TextEditingController _offerBodyController = TextEditingController();
  final TextEditingController _offerDiscountController = TextEditingController(text: '10');
  final TextEditingController _offerValidityController = TextEditingController(text: '30');
  
  // State variables for data
  bool _isLoading = true;
  bool _showLegend = false;
  String _selectedTimeFilter = 'Tous';
  String _selectedDayFilter = 'Tous';
  
  // +++ ADDED Filter options definition +++
  final List<String> _timeFilterOptions = ['Tous', 'Matin (6-12h)', 'Après-midi (12-18h)', 'Soir (18-24h)', 'Nuit (0-6h)'];
  final List<String> _dayFilterOptions = ['Tous', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  // +++ END Filter options definition +++

  List<models.UserHotspot> _hotspots = []; // Raw hotspot data from API
  List<models.UserHotspot> _filteredHotspots = []; // Filtered hotspots for circles/stats
  
  late cluster_manager.ClusterManager _clusterManager;
  Set<Marker> _clusterMarkers = {}; // Markers generated by ClusterManager
  List<Place> _places = []; // Combined list of Zones and ActiveUsers for ClusterManager
  
  // Nearby Search - Keep structures for future implementation
  List<NearbySearchEvent> _nearbySearches = [];
  Timer? _nearbySearchPollTimer;
  final Duration _nearbySearchPollInterval = const Duration(minutes: 1); // Poll every minute?
  bool _isFetchingSearches = false;
  
  // Active Users State
  List<ActiveUser> _activeUsers = []; // List of active users from polling
  Timer? _activeUserPollTimer;
  final Duration _activeUserPollInterval = const Duration(seconds: 30); // Poll interval (reduced?)
  bool _isFetchingActiveUsers = false; // Loading state for active users polling
  bool _isValidatingOffer = false; // <-- Add state for validation loading
  
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(48.8566, 2.3522), // Default to Paris center
    zoom: 12, // Slightly zoomed out initially
  );

  // Zone Details and Insights State
  Map<String, Map<String, dynamic>> _zoneStats = {}; // Stats for filtered zones
  String? _selectedZoneId; // Currently selected zone for details sheet
  List<Map<String, dynamic>> _zoneInsights = []; // Insights fetched from API
  bool _isLoadingInsights = false; // Loading state for insights

  // Push Notification Dialog Controllers
  final _customPushTitleController = TextEditingController();
  final _customPushBodyController = TextEditingController();
  
  // User Profile State
  PublicUserProfile? _fetchedUserProfile; // Profile fetched when clicking user marker
  bool _isFetchingProfile = false; // Loading state for user profile fetch

   // Cache for generated marker bitmaps
  final Map<String, BitmapDescriptor> _markerBitmapCache = {};

  // State for offer sending dialog
  bool _isSendingOffer = false;

  
  @override
  void initState() {
    super.initState();
    initializeTimeago();
    _clusterManager = _initClusterManager();
    _loadData(); // Loads hotspots, producer location AND insights
    _startActiveUserPolling(); // Start polling for active users
    _startNearbySearchPolling(); // <-- Start polling for searches
    // _initSocket(); // SocketIO not implemented yet
    // Timer.periodic(_searchEventTimeout, (_) => _cleanupSearchEvents()); // Cleanup for future nearby searches
  }
  
  @override
  void dispose() {
    _activeUserPollTimer?.cancel();
    _nearbySearchPollTimer?.cancel(); // <-- Cancel search timer
    _customPushTitleController.dispose();
    _customPushBodyController.dispose();
    _customDiscountController.dispose();
    _customDurationController.dispose();
    _mapController?.dispose();
    _markerBitmapCache.clear();
    _offerTitleController.dispose();
    _offerBodyController.dispose();
    _offerDiscountController.dispose();
    _offerValidityController.dispose();
    super.dispose();
  }
  
  // --- Data Loading ---
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    print("🔄 Loading initial data...");
    try {
      // Fetch producer location first to center map and get coords for hotspots
      final locationData = await _fetchProducerLocation();
      final producerLat = locationData['latitude'] ?? 48.8566;
      final producerLon = locationData['longitude'] ?? 2.3522;

      // Animate map immediately to producer location while other data loads
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(producerLat, producerLon), 14),
      );

      // Fetch hotspots and insights concurrently
      final results = await Future.wait([
         _fetchHotspots(producerLat, producerLon),
         _loadZoneInsights(), // Fetch insights (already handles own loading state)
      ]);

      final hotspots = results[0] as List<models.UserHotspot>?; // Result from _fetchHotspots

      if (!mounted) return; // Check again after awaits

      if (hotspots != null) {
         setState(() {
           _hotspots = hotspots;
           _filteredHotspots = List.from(hotspots); // Initialize filtered list
           _generateZoneStats(); // Calculate stats based on initial hotspots
           _updatePlacesList(); // Update cluster manager with initial zones (+ any existing active users)
         });
      } else {
          // Handle case where hotspots failed to load but insights might have succeeded
          setState(() {
             _hotspots = [];
             _filteredHotspots = [];
        _generateZoneStats();
             _updatePlacesList();
          });
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Impossible de charger les zones d\'intérêt.'), backgroundColor: Colors.orange),
             );
           }
      }

    } catch (e) {
      print('❌ Error loading initial data: $e');
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement données: $e'), backgroundColor: Colors.red),
      );
      }
    } finally {
       if (mounted) { setState(() { _isLoading = false; }); }
        print("✅ Initial data loading finished.");
    }
  }
  
  Future<Map<String, dynamic>> _fetchProducerLocation() async {
     print(" LFetching producer location...");
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.userId}/location');
      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
         print(" Producer location: ${data['latitude']}, ${data['longitude']}");
         return data;
      } else {
        print('❌ Error fetching producer location: ${response.statusCode} ${response.body}');
        return {'latitude': 48.8566, 'longitude': 2.3522}; // Default fallback Paris
      }
    } catch (e) {
      print('❌ Exception fetching producer location: $e');
      return {'latitude': 48.8566, 'longitude': 2.3522}; // Default fallback Paris
    }
  }
  
  Future<List<models.UserHotspot>> _fetchHotspots(double latitude, double longitude) async {
     print(" HFetching hotspots around $latitude, $longitude...");
    final url = Uri.parse('${constants.getBaseUrl()}/api/location-history/hotspots').replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': '2000', // Radius in meters (2km) - Make configurable?
      },
    );
    
     try {
       final headers = await ApiConfig.getAuthHeaders();
       final response = await http.get(url, headers: headers);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
           print(" Found ${data.length} hotspots raw.");
           final hotspots = data
          .map((item) => models.UserHotspot.fromJson(item))
              .where((hotspot) => hotspot.latitude != 0 || hotspot.longitude != 0) // Ensure valid coordinates
          .toList();
           print(" Parsed ${hotspots.length} valid hotspots.");
           return hotspots;
    } else {
          print('❌ Erreur récupération hotspots: ${response.statusCode} ${response.body}');
          return []; // Return empty list on error
        }
     } catch (e) {
        print('❌ Exception fetching hotspots: $e');
        return []; // Return empty list on exception
     }
  }

  Future<void> _loadZoneInsights() async {
    if (!mounted || _isLoadingInsights) return;
    print(" IFetching insights...");
    setState(() { _isLoadingInsights = true; });
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/heatmap/action-opportunities/${widget.userId}');
      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(url, headers: headers);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
         print(" Found ${data.length} insights.");
        setState(() {
          _zoneInsights = List<Map<String, dynamic>>.from(data.map((item) {
            final type = item['type'] as String?;
            return {
              'title': item['title'] ?? 'Insight',
              'insights': List<String>.from(item['insights'] ?? []),
              'type': type,
              'color': _getColorForInsight(type), // Use helper functions
              'icon': _getIconForInsight(type),
            };
          }));
        });
      } else {
        print('❌ Erreur chargement insights: ${response.statusCode} ${response.body}');
        setState(() { _zoneInsights = []; }); // Clear on error
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Erreur chargement insights (${response.statusCode})'), backgroundColor: Colors.orange),
           );
         }
      }
    } catch (e) {
      print('❌ Exception lors du chargement des insights: $e');
       if (mounted) {
         setState(() { _zoneInsights = []; }); // Clear on exception
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Erreur réseau (insights).'), backgroundColor: Colors.orange),
         );
       }
    } finally {
      if (mounted) {
        setState(() { _isLoadingInsights = false; });
      }
    }
  }

  // --- Filtering and Selection ---
  void _applyFilters() {
    if (!mounted) return;
    print(" Applying filters: Time=${_selectedTimeFilter}, Day=${_selectedDayFilter}");
    setState(() {
      _filteredHotspots = _hotspots.where((hotspot) {
        // Time Filter Logic
        if (_selectedTimeFilter != 'Tous') {
          final timeDistribution = hotspot.timeDistribution;
          final morning = timeDistribution['morning'] ?? 0.0;
          final afternoon = timeDistribution['afternoon'] ?? 0.0;
          final evening = timeDistribution['evening'] ?? 0.0;
          const threshold = 0.1; // Min 10% activity in the period
          if (_selectedTimeFilter == 'Matin' && morning < threshold) return false;
          if (_selectedTimeFilter == 'Après-midi' && afternoon < threshold) return false;
          if (_selectedTimeFilter == 'Soir' && evening < threshold) return false;
        }

        // Day Filter Logic
        if (_selectedDayFilter != 'Tous') {
          final dayDistribution = hotspot.dayDistribution;
          String dayKey = _selectedDayFilter.toLowerCase();
          const Map<String, String> dayMap = {'lundi':'monday', 'mardi':'tuesday', 'mercredi':'wednesday', 'jeudi':'thursday', 'vendredi':'friday', 'samedi':'saturday', 'dimanche':'sunday'};
          dayKey = dayMap[dayKey] ?? dayKey; // Map French name to backend key
          const threshold = 0.05; // Min 5% activity on the day
          if ((dayDistribution[dayKey] ?? 0.0) < threshold) return false;
        }
        return true; // Keep hotspot if no filters exclude it
      }).toList();
      
      _generateZoneStats(); // Update stats based on filtered hotspots
      _updatePlacesList(); // Update map markers (filtered zones + active users)
       print(" Filtered to ${_filteredHotspots.length} hotspots.");
    });
  }
  
  void _selectZone(String zoneId) {
    if (!mounted) return;
    print(" Selecting Zone ID: $zoneId");
    try {
      // Use firstWhereOrNull from collection package to avoid exception
      final selectedHotspot = _hotspots.firstWhereOrNull((hotspot) => hotspot.id == zoneId);

      if (selectedHotspot != null) {
         setState(() { _selectedZoneId = zoneId; });
         _showZoneDetailsSheet(selectedHotspot);
      } else {
         print("Error: Could not find selected hotspot details for ID: $zoneId in _hotspots list.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Détails de zone indisponibles.'), backgroundColor: Colors.orange),
            );
          }
      }
    } catch (e) { // Catch potential errors during find
       print("Error finding hotspot $zoneId: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur interne (sélection zone).'), backgroundColor: Colors.red),
          );
        }
    }
  }

  // --- UI Components ---
  void _showZoneDetailsSheet(models.UserHotspot selectedHotspot) {
     print(" Showing details for Zone: ${selectedHotspot.zoneName}");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, // Start at 60% height
        minChildSize: 0.3,   // Min height 30%
        maxChildSize: 0.9,   // Max height 90%
        expand: false, // Important: set to false
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              boxShadow: [ BoxShadow(blurRadius: 10, color: Colors.black26)] // Add shadow
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40, height: 5, margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 8, bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined, color: _getColorForIntensity(selectedHotspot.intensity)), // Use intensity color
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(selectedHotspot.zoneName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[300]),
                // Scrollable Content
                Expanded(
                  child: ListView(
                    controller: scrollController, // Link controller
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildStatCard(
                        icon: Icons.people_alt_outlined,
                        title: 'Visiteurs Uniques (Estimé)',
                        value: '${selectedHotspot.visitorCount}',
                        subtitle: 'Basé sur l\'historique récent',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 20),
                      
                      const Text('Activité par Heure', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        height: 180, padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                        child: _buildTimeDistributionFlChart(selectedHotspot.timeDistribution),
                      ),
                      const SizedBox(height: 24),
                      
                      const Text('Activité par Jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        height: 200, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                        child: _buildDayDistributionFlChart(selectedHotspot.dayDistribution),
                      ),
                      const SizedBox(height: 24),
                      
                       // --- Action Recommendations Section (Using Backend Data) ---
                      if (selectedHotspot.recommendations.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recommandations Basées Données', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ...selectedHotspot.recommendations.map((rec) {
                              // Determine color/icon based on type or use defaults
                              // You might need helper functions similar to _getColorForInsight/_getIconForInsight
                              // if the backend provides a 'type' field for recommendations.
                              // For now, using generic styling.
                              final String title = rec['title'] as String? ?? 'Recommandation';
                              final String description = rec['description'] as String? ?? '-';
                              final Color color = Colors.teal; // Example default color
                              final IconData icon = Icons.lightbulb_outline; // Example default icon

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                                  color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color.withOpacity(0.3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(icon, color: color, size: 28),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 6),
                                          Text(description, style: const TextStyle(height: 1.4, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        )
                      else // Show message if no recommendations from backend
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: Text("Aucune recommandation spécifique fournie par le serveur.", style: TextStyle(color: Colors.grey))),
                        ),
                      // --- End Action Recommendations Section ---
                       const SizedBox(height: 24),

                       // Action Button: Target this specific zone
                       Center( // Center the button
                         child: ElevatedButton.icon(
                           icon: const Icon(Icons.campaign_outlined, size: 20),
                           label: const Text("Cibler cette zone (Offre -30%)"),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.orangeAccent, // Button color
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                             textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)) // Rounded button
                           ),
                           onPressed: () {
                              Navigator.pop(context); // Close the sheet first
                              _showSendPushDialog(zoneId: selectedHotspot.id); // Pass zone ID to push dialog
                           },
                         ),
                       ),
                       const SizedBox(height: 20), // Bottom padding

                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildTimeDistributionFlChart(Map<String, double> timeDistribution) {
    final morningValue = (timeDistribution['morning'] ?? 0.0);
    final afternoonValue = (timeDistribution['afternoon'] ?? 0.0);
    final eveningValue = (timeDistribution['evening'] ?? 0.0);
    final total = morningValue + afternoonValue + eveningValue;
    final double safeTotal = total == 0 ? 1.0 : total;

    const Color morningColor = Colors.orangeAccent;
    const Color afternoonColor = Colors.lightBlueAccent;
    const Color eveningColor = Colors.purpleAccent;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 1.0, // Represents 100%
        barTouchData: BarTouchData( // Configure tooltips
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label;
              switch (group.x.toInt()) {
                case 0: label = 'Matin'; break;
                case 1: label = 'Après-midi'; break;
                case 2: label = 'Soir'; break;
                default: label = '';
              }
              return BarTooltipItem(
                 "$label\n",
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                     text: '${(rod.toY * 100).toStringAsFixed(0)}%', // Show percentage
                    style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData( // Configure axis titles
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              getTitlesWidget: (value, meta) {
                String text = '';
                switch (value.toInt()) { case 0: text = 'Matin'; break; case 1: text = 'A-Midi'; break; case 2: text = 'Soir'; break; }
                return Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(text, style: const TextStyle(fontSize: 11))); // Smaller font
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 40, interval: 0.2, // Show 0, 20, 40, 60, 80, 100%
              getTitlesWidget: (value, meta) {
                if (value == 0 || value > 1.0) return Container(); // Hide 0% and > 100% labels
                return Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [ // Bar data
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: morningValue / safeTotal, color: morningColor, width: 25, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: afternoonValue / safeTotal, color: afternoonColor, width: 25, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: eveningValue / safeTotal, color: eveningColor, width: 25, borderRadius: BorderRadius.circular(4))]),
        ],
        gridData: FlGridData(show: false),
      ),
    );
  }

  Widget _buildDayDistributionFlChart(Map<String, double> dayDistribution) {
    final List<String> dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final Map<String, String> dayTranslation = {'monday': 'Lun', 'tuesday': 'Mar', 'wednesday': 'Mer', 'thursday': 'Jeu', 'friday': 'Ven', 'saturday': 'Sam', 'sunday': 'Dim'};
    // Normalize values to percentages if they represent counts or relative values
    final totalValue = dayDistribution.values.fold(0.0, (sum, v) => sum + v);
    final double safeTotal = totalValue == 0 ? 1.0 : totalValue;
    double maxValue = dayDistribution.values.fold(0.0, (max, v) => max > (v/safeTotal) ? max : (v/safeTotal));
    if (maxValue == 0) maxValue = 0.1; // Ensure max is not zero for chart scaling

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.15, // Scale max Y to give padding (e.g., 115% of max value)
        barTouchData: BarTouchData( // Tooltip config
          enabled: true,
           touchTooltipData: BarTouchTooltipData(
             getTooltipColor: (group) => Colors.blueGrey.withOpacity(0.8),
             getTooltipItem: (group, groupIndex, rod, rodIndex) {
               if (groupIndex >= dayKeys.length) return null; // Safety check
              String day = dayTranslation[dayKeys[groupIndex]] ?? '';
               // Display percentage
               String valueText = '${(rod.toY / maxValue * 100).toStringAsFixed(0)}%';
               // Or display raw value if preferred: String valueText = (dayDistribution[dayKeys[groupIndex]] ?? 0.0).toStringAsFixed(1);
              return BarTooltipItem(
                 "$day\n",
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                 children: <TextSpan>[ TextSpan(text: valueText, style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500)), ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData( // Axis titles
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              getTitlesWidget: (value, meta) {
                 final index = value.toInt();
                 if (index >= dayKeys.length) return Container();
                 final dayKey = dayKeys[index];
                 return Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(dayTranslation[dayKey] ?? '', style: const TextStyle(fontSize: 11)));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(dayKeys.length, (index) {
          final dayKey = dayKeys[index];
          final value = (dayDistribution[dayKey] ?? 0.0);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value / safeTotal, // Normalize to percentage of total for consistent height? Or use raw value and rely on maxY scaling? Let's use normalized.
                // toY: value, // Use raw value (requires careful maxY setting)
                color: Colors.primaries[index % Colors.primaries.length].withOpacity(0.8),
                width: 18, // Bar width
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)), // Rounded top corners
              )
            ],
          );
        }),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildStatCard({ required IconData icon, required String title, required String value, required String subtitle, required Color color }) { return Container( padding: const EdgeInsets.all(16), decoration: BoxDecoration( color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2)) ), child: Row( children: [ Container( padding: const EdgeInsets.all(12), decoration: BoxDecoration( color: color.withOpacity(0.2), shape: BoxShape.circle ), child: Icon(icon, color: color, size: 28) ), const SizedBox(width: 16), Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])) ] ) ) ] ) ); }

  Widget _buildStatRow(IconData icon, String text, Color color) { return Padding( padding: const EdgeInsets.only(top: 4.0), child: Row( children: [ Icon(icon, size: 14, color: color), const SizedBox(width: 6), Expanded( child: Text( text, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis) ) ] ) ); }

  // --- Helper Functions ---
  void _generateZoneStats() {
    _zoneStats = {};
    for (var hotspot in _filteredHotspots) {
      _zoneStats[hotspot.id] = {
        'visitorCount': hotspot.visitorCount,
        'intensity': hotspot.intensity,
        'bestTime': _getBestTimeSlot(hotspot.timeDistribution),
        'bestDay': _getBestDay(hotspot.dayDistribution),
      };
    }
    // print("Generated stats for ${_zoneStats.length} filtered zones.");
  }

  // Add missing _getBestTimeSlot method
  String _getBestTimeSlot(Map<String, dynamic>? timeDistribution) {
    if (timeDistribution == null || timeDistribution.isEmpty) {
      return '-';
    }
    
    String bestSlot = '';
    double maxValue = 0;
    
    timeDistribution.forEach((slot, value) {
      if (value > maxValue) {
        maxValue = value.toDouble();
        bestSlot = slot;
      }
    });
    
    return bestSlot;
  }
  
  // Add missing _getBestDay method
  String _getBestDay(Map<String, dynamic>? dayDistribution) {
    if (dayDistribution == null || dayDistribution.isEmpty) {
      return '-';
    }
    
    String bestDay = '';
    double maxValue = 0;
    
    dayDistribution.forEach((day, value) {
      if (value > maxValue) {
        maxValue = value.toDouble();
        bestDay = day;
      }
    });
    
    return bestDay;
  }

  Color _getColorForInsight(String? type) {
    switch (type?.toLowerCase()) {
      case 'opportunity': return Colors.green;
      case 'trend': return Colors.blue;
      case 'warning': return Colors.orange;
      case 'high_traffic': return Colors.purple;
      default: return Colors.grey[700]!;
    }
  }

  IconData _getIconForInsight(String? type) {
     switch (type?.toLowerCase()) {
      case 'opportunity': return Icons.lightbulb_outline;
      case 'trend': return Icons.trending_up;
      case 'warning': return Icons.warning_amber_outlined;
      case 'high_traffic': return Icons.directions_walk;
      default: return Icons.info_outline;
    }
  }

  Set<Circle> _createHeatmapCircles() {
    if (_filteredHotspots.isEmpty) return {};
    Set<Circle> circles = {};
    for (var hotspot in _filteredHotspots) {
      final intensity = (hotspot.intensity ?? 0.0).clamp(0.0, 1.0);
      final color = _getColorForIntensity(intensity);
      final radius = 30 + (intensity * 120); // Base radius + scaled radius by intensity

      circles.add(
        Circle(
          circleId: CircleId('heatmap_${hotspot.id}'),
          center: LatLng(hotspot.latitude, hotspot.longitude),
          radius: radius,
          fillColor: color.withOpacity(0.4), // Adjust opacity
          strokeWidth: 0, // No border
        ),
      );
    }
    return circles;
  }

  Color _getColorForIntensity(double intensity) {
    // Interpolate from Blue (0.0) -> Green (0.5) -> Red (1.0)
    if (intensity < 0.5) {
      return Color.lerp(Colors.blue, Colors.green, intensity * 2) ?? Colors.grey;
    } else {
      return Color.lerp(Colors.green, Colors.red, (intensity - 0.5) * 2) ?? Colors.grey;
    }
  }

  // --- Active User Polling ---
  void _startActiveUserPolling() {
     print("ℹ️ Starting active user polling...");
     _fetchActiveUsers(); // Fetch immediately
     _activeUserPollTimer?.cancel();
     _activeUserPollTimer = Timer.periodic(_activeUserPollInterval, (_) {
        if (!mounted) { _activeUserPollTimer?.cancel(); return; } // Stop if widget disposed
        if (!_isFetchingActiveUsers) { _fetchActiveUsers(); }
     });
  }

 Future<void> _fetchActiveUsers() async {
     if (!mounted || _isFetchingActiveUsers) return;
     print("📡 Fetching active users...");
     setState(() { _isFetchingActiveUsers = true; });

     try {
        final url = Uri.parse('${constants.getBaseUrl()}/api/heatmap/active-users/${widget.userId}');
        final headers = await ApiConfig.getAuthHeaders();
        final response = await http.get(url, headers: headers);

        if (!mounted) return;

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
           // print("👥 Found ${data.length} active users raw.");
           List<ActiveUser> fetchedUsers = data
              .map((item) => ActiveUser.fromJson(item))
              .where((user) => user.location.latitude != 0 || user.location.longitude != 0) // Filter invalid locations
              .toList();
           print("👥 Parsed ${fetchedUsers.length} valid active users.");

           // Check if the list actually changed before updating state and places
           if (!listEquals(_activeUsers, fetchedUsers)) {
               print(" User list changed, updating state and map.");
              setState(() { _activeUsers = fetchedUsers; });
              _updatePlacesList(); // Update map with new user locations
           } else {
               // print(" User list unchanged.");
           }
        } else {
          print('❌ Error fetching active users: ${response.statusCode} ${response.body}');
            if (mounted) {
              // Only show snackbar occasionally on error?
              // ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erreur utilisateurs actifs (${response.statusCode})'), backgroundColor: Colors.orange) );
            }
        }
     } catch(e) {
        print('❌ Exception fetching active users: $e');
         if (mounted) {
           // Only show snackbar occasionally on error?
           // ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erreur réseau (utilisateurs actifs).'), backgroundColor: Colors.orange) );
         }
     } finally {
       if (mounted) { setState(() { _isFetchingActiveUsers = false; }); }
     }
  }

  // Helper to compare lists of ActiveUser
  bool listEquals<ActiveUser>(List<ActiveUser>? a, List<ActiveUser>? b) {
    // Use DeepCollectionEquality from collection package for robust comparison
    return const DeepCollectionEquality().equals(a, b);
  }

  // --- Cluster Manager Setup ---
  void _updatePlacesList() {
    if (!mounted) return;
    List<Place> newPlaces = [];
    // Add filtered hotspots
    for (var hotspot in _filteredHotspots) { newPlaces.add(Place( id: hotspot.id, name: hotspot.zoneName, location: LatLng(hotspot.latitude, hotspot.longitude), isZone: true, visitorCount: hotspot.visitorCount )); }
    // Add valid active users
    for (var activeUser in _activeUsers) { if (activeUser.location.latitude != 0 || activeUser.location.longitude != 0) { newPlaces.add(Place( id: 'active_${activeUser.userId}', name: activeUser.name, location: activeUser.location, isZone: false, liveTimestamp: activeUser.lastSeen )); } }
    // Update the cluster manager - this triggers _markerBuilder eventually
    setState(() { _places = newPlaces; });
    _clusterManager.setItems(_places);
    print(" Updated ClusterManager with ${_filteredHotspots.length} zones and ${_activeUsers.length} users -> ${_places.length} total places.");
  }

  cluster_manager.ClusterManager _initClusterManager() {
    return cluster_manager.ClusterManager<Place>(
      _places, // Initial list (likely empty)
      _updateMarkers, // Function to call when markers are ready
      markerBuilder: _markerBuilder, // Function to build each marker/cluster
      levels: const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0], // Zoom levels for clustering
      extraPercent: 0.2, // Clustering radius adjustment
      stopClusteringZoom: 17.0, // Zoom level to stop clustering
    );
  }

  // Callback from ClusterManager with the set of markers to display
  void _updateMarkers(Set<Marker> markers) {
    if (!mounted) return;
    // print(' Updating map with ${markers.length} markers/clusters.');
    setState(() { _clusterMarkers = markers; });
  }

  // --- Marker Builders ---
  Future<Marker> _markerBuilder(cluster_manager.Cluster<Place> cluster) async {
    final isMultiple = cluster.isMultiple;
    final place = cluster.items.first;
    final String markerIdStr = isMultiple ? cluster.getId() : place.id;

    BitmapDescriptor icon;
    VoidCallback? onTapAction;
    double zIndex = 0.0;

    // Use cache for marker icons
    if (_markerBitmapCache.containsKey(markerIdStr)) {
      icon = _markerBitmapCache[markerIdStr]!;
       // print(" Cache hit for marker: $markerIdStr");
    } else {
       // print(" Cache miss for marker: $markerIdStr, generating...");
      if (isMultiple) {
        icon = await _getMarkerBitmap(110, text: cluster.count.toString(), color: Colors.deepPurple.withOpacity(0.9));
      } else if (place.isZone) {
        final hotspot = _hotspots.firstWhereOrNull((h) => h.id == place.id);
        final intensity = hotspot?.intensity ?? 0.5;
        icon = await _getMarkerBitmap(80, color: _getColorForIntensity(intensity).withOpacity(0.85));
      } else {
        icon = await _getUserMarkerBitmap(place.id.replaceFirst('active_', ''));
      }
      _markerBitmapCache[markerIdStr] = icon; // Store in cache
    }

    // Define onTap actions and zIndex based on type
    if (isMultiple) {
      onTapAction = () async {
        final currentZoom = await _mapController?.getZoomLevel() ?? 14.0;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(cluster.location, currentZoom + 1.5));
      };
      zIndex = 3.0; // Clusters highest
    } else if (place.isZone) {
      onTapAction = () => _selectZone(place.id);
      zIndex = 1.0; // Zones lowest
    } else { // Active User
      onTapAction = () => _fetchPublicUserInfo(place.id.replaceFirst('active_', ''));
      zIndex = 2.0; // Users above zones
    }

    return Marker(
      markerId: MarkerId(markerIdStr),
      position: cluster.location,
      icon: icon,
      onTap: onTapAction,
      infoWindow: isMultiple ? InfoWindow.noText : InfoWindow(
         title: place.name,
         snippet: place.isZone ? '${place.visitorCount ?? '?'} visiteurs (estimé)' : (place.liveTimestamp != null ? 'Vu ${timeago.format(place.liveTimestamp!, locale: 'fr')}' : 'Utilisateur actif')
      ),
      zIndex: zIndex,
    );
  }

 Future<BitmapDescriptor> _getMarkerBitmap(int size, {String? text, Color color = Colors.deepPurple}) async {
    final String cacheKey = 'cluster_${size}_${color.value}_$text';
    if (_markerBitmapCache.containsKey(cacheKey)) return _markerBitmapCache[cacheKey]!;

    if (size <= 0) return BitmapDescriptor.defaultMarker;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint1 = Paint()..color = color;
    final Paint paint2 = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint1);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0 * 0.9, paint2);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0 * 0.7, paint1);
    if (text != null) {
      TextPainter painter = TextPainter(textDirection: ui.TextDirection.ltr);
      painter.text = TextSpan( text: text, style: TextStyle( fontSize: size / 2.8, color: Colors.white, fontWeight: FontWeight.bold) ); // Adjusted size
      painter.layout();
      painter.paint( canvas, Offset(size/2 - painter.width/2, size/2 - painter.height/2) );
    }
    try {
       final img = await pictureRecorder.endRecording().toImage(size, size);
       final data = await img.toByteData(format: ui.ImageByteFormat.png);
       if (data == null) throw Exception("Byte data null");
       final bitmap = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
       _markerBitmapCache[cacheKey] = bitmap; // Cache the final bitmap
       return bitmap;
    } catch (e) { print("Error creating cluster bitmap: $e"); return BitmapDescriptor.defaultMarker; }
 }

 Future<BitmapDescriptor> _getUserMarkerBitmap(String userId) async {
    final String cacheKey = 'user_$userId'; // Simple cache key based on user ID
    if (_markerBitmapCache.containsKey(cacheKey)) return _markerBitmapCache[cacheKey]!;

    final user = _activeUsers.firstWhereOrNull((u) => u.userId == userId);
    Uint8List? imageBytes;
    if (user?.profilePicture != null && user!.profilePicture!.isNotEmpty) {
       try {
         // Use CachedNetworkImage to fetch bytes (handles caching)
          final imageProvider = CachedNetworkImageProvider(user.profilePicture!);
          final completer = Completer<Uint8List>();
          final listener = ImageStreamListener((ImageInfo imageInfo, bool syncCall) async {
              final byteData = await imageInfo.image.toByteData(format: ui.ImageByteFormat.png);
              if (byteData != null) {
                  completer.complete(byteData.buffer.asUint8List());
              } else {
                   completer.completeError("Failed to get byte data from cached image");
              }
              imageInfo.dispose();
          }, onError: (dynamic exception, StackTrace? stackTrace) {
              completer.completeError(exception);
          });

          final stream = imageProvider.resolve(const ImageConfiguration());
          stream.addListener(listener);
          imageBytes = await completer.future.timeout(const Duration(seconds: 5)); // Add timeout
          stream.removeListener(listener); // Clean up listener

       } catch (e) { print("Error fetching/processing profile picture for marker ($userId): $e"); }
    }

    const int size = 85;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint borderPaint = Paint()..color = Colors.blueAccent[700]!..style = PaintingStyle.stroke..strokeWidth = 3; // Stronger border
    final Paint backgroundPaint = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, backgroundPaint);

    if (imageBytes != null) {
       try {
         final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
         final ui.FrameInfo frameInfo = await codec.getNextFrame();
         final ui.Image userImage = frameInfo.image;
         final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2.0 - 2)); // Clip slightly inside border
         canvas.save(); // Save canvas state before clipping
         canvas.clipPath(clipPath);
         // Paint image centered and covering the circle
         paintImage( canvas: canvas, rect: Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), image: userImage, fit: BoxFit.cover );
         canvas.restore(); // Restore canvas state after drawing image
       } catch (e) {
          print("Error decoding/drawing user image: $e");
          _drawPlaceholderUserIcon(canvas, size); // Draw placeholder if image fails
       }
    } else { _drawPlaceholderUserIcon(canvas, size); } // Draw placeholder if no image URL or fetch failed

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0 - 1.5, borderPaint); // Draw border on top

    try {
       final img = await pictureRecorder.endRecording().toImage(size, size);
       final data = await img.toByteData(format: ui.ImageByteFormat.png);
       if (data == null) throw Exception("Byte data null");
       final bitmap = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
       _markerBitmapCache[cacheKey] = bitmap; // Cache the final bitmap
       return bitmap;
    } catch (e) { print("Error creating user marker bitmap ($userId): $e"); return BitmapDescriptor.defaultMarker; }
 }

  // Helper to draw the placeholder person icon
  void _drawPlaceholderUserIcon(Canvas canvas, int size) {
      final icon = Icons.person;
      TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr); // Use ui.TextDirection
      textPainter.text = TextSpan( text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: size * 0.6, fontFamily: icon.fontFamily, color: Colors.blueAccent[100]) );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size/2 - textPainter.width/2, size/2 - textPainter.height/2));
  }

  // --- Main Widget Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heatmap & Audience', style: TextStyle(fontSize: 18)),
        elevation: 2, // Add subtle shadow
        actions: [
          // Scan Offer Button
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: _navigateToOfferScanner,
            tooltip: 'Valider une Offre (QR Code)',
          ),
          // Refresh Button
          IconButton( icon: const Icon(Icons.refresh), onPressed: _isLoading || _isFetchingActiveUsers || _isValidatingOffer ? null : _loadData, tooltip: 'Rafraîchir Données' ),
           // Send Generic Push Button
           IconButton( icon: const Icon(Icons.campaign_outlined), onPressed: _isLoading || _isFetchingActiveUsers || _isValidatingOffer ? null : () => _showSendPushDialog(), tooltip: 'Envoyer Offre aux Alentours' ),
          // Toggle Legend Button
          IconButton( icon: Icon(_showLegend ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _showLegend = !_showLegend), tooltip: 'Afficher/Masquer Légende' ),
        ],
      ),
      body: Stack(
        children: [
          // --- Google Map ---
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (controller) {
              if (!mounted) return;
              setState(() { _mapController = controller; });
              // Optional: Apply custom map style (load from JSON file in assets)
              // rootBundle.loadString('assets/map_style.json').then((style) { if(mounted) controller.setMapStyle(style); });
              _clusterManager.setMapId(controller.mapId);
            },
            markers: _clusterMarkers, // Markers managed by ClusterManager
            circles: _createHeatmapCircles(), // Heatmap overlay
            myLocationButtonEnabled: true, myLocationEnabled: true,
            mapType: MapType.normal, buildingsEnabled: true, compassEnabled: true,
            zoomControlsEnabled: false, // Disable default zoom controls
            trafficEnabled: false,
            onCameraMove: (position) => _clusterManager.onCameraMove(position),
            onCameraIdle: () => _clusterManager.updateMap(),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.40, top: 100), // Adjust padding dynamically
          ),
          // --- End Google Map ---

          // --- Filter Card ---
          Positioned( top: 10, left: 10, right: 10, child: Card(
             elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             child: Padding( padding: const EdgeInsets.all(12.0),
               child: Column( mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                   const Text('Filtres d\'Affluence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                   const SizedBox(height: 8),
                   Row( children: [
                       Expanded( child: DropdownButtonFormField<String>( decoration: InputDecoration( labelText: 'Heure', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true, prefixIcon: const Icon(Icons.access_time, size: 18) ), value: _selectedTimeFilter, items: _timeFilterOptions.map((value) => DropdownMenuItem( value: value, child: Text(value == 'Tous' ? 'Toute la journée' : value, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (value) { if (value != null) { setState(() => _selectedTimeFilter = value); _applyFilters(); } } ) ),
                       const SizedBox(width: 10),
                       Expanded( child: DropdownButtonFormField<String>( decoration: InputDecoration( labelText: 'Jour', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true, prefixIcon: const Icon(Icons.calendar_today, size: 16) ), value: _selectedDayFilter, items: _dayFilterOptions.map((value) => DropdownMenuItem( value: value, child: Text(value == 'Tous' ? 'Tous les jours' : value, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (value) { if (value != null) { setState(() => _selectedDayFilter = value); _applyFilters(); } } ) )
                   ] )
               ] )
             )
          ) ),

          // --- Legend Card ---
          if (_showLegend) Positioned( top: 115, right: 10, child: Card(
             elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
             child: Padding( padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                   const Text('Légende', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                   const SizedBox(height: 6),
                   _buildLegendItem(color: Colors.blue, label: 'Très Faible'),
                   _buildLegendItem(color: Colors.green, label: 'Moyenne'),
                   _buildLegendItem(color: Colors.red, label: 'Très Forte'),
                   const Divider(height: 10),
                   Row(children: const [
                     Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 18),
                     SizedBox(width:4),
                     Text('Utilisateur Actif', style: TextStyle(fontSize: 12))
                   ]),
                   Row(children: const [
                     Icon(Icons.place, color: Colors.orange, size: 18),
                     SizedBox(width:4),
                     Text('Zone d\'Intérêt', style: TextStyle(fontSize: 12))
                   ]),
                   Row(children: const [
                     Icon(Icons.bubble_chart, color: Colors.deepPurple, size: 18),
                     SizedBox(width:4),
                     Text('Groupe', style: TextStyle(fontSize: 12))
                   ]),
                  ] )
                 )
                )
              ),

          // --- Bottom Stats/Insights Card ---
          Positioned( left: 0, right: 0, bottom: 0, child: Card(
             margin: EdgeInsets.zero, elevation: 8, shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))
             ),
             child: Container( padding: const EdgeInsets.only(top: 8, left: 0, right: 0, bottom: 8),
                constraints: BoxConstraints( maxHeight: MediaQuery.of(context).size.height * 0.40 ),
                child: Column( mainAxisSize: MainAxisSize.min, children: [
                    Container( width: 40, height: 5, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)) ),
                    Expanded( child: ListView( padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                           Row( children: const [
                        Icon(Icons.analytics_outlined, size: 20, color: Colors.deepPurple),
                        SizedBox(width: 8),
                              Text('Statistiques Zones Filtrées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                           ] ),
                    const SizedBox(height: 12),
                          SizedBox( height: 130, child: (
                             _isLoading || _filteredHotspots.isEmpty) ? Center(child: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Text("Aucune zone selon filtres.", style: TextStyle(color: Colors.grey))
                             ) : ListView.builder( scrollDirection: Axis.horizontal, itemCount: _filteredHotspots.length, itemBuilder: (context, index) { final hotspot = _filteredHotspots[index]; final stats = _zoneStats[hotspot.id]; if (stats == null) return const SizedBox.shrink(); final intensityColor = _getColorForIntensity(stats['intensity'] ?? 0.5); return GestureDetector( onTap: () => _selectZone(hotspot.id), child: Container( width: 180, margin: const EdgeInsets.only(right: 12, bottom: 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2)) ] ), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( children: [ Container(width: 10, height: 10, decoration: BoxDecoration(color: intensityColor, shape: BoxShape.circle)), const SizedBox(width: 6), Expanded( child: Text( hotspot.zoneName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis) ) ] ), const Spacer(), _buildStatRow(Icons.people_alt_outlined, '${stats['visitorCount'] ?? '?'} vist.', Colors.blue[600]!), _buildStatRow(Icons.access_time_outlined, 'Pic: ${stats['bestTime'] ?? '-'}', Colors.orange[800]!), _buildStatRow(Icons.calendar_today_outlined, 'Jour: ${stats['bestDay'] ?? '-'}', Colors.green[700]!) ] ) ) ); } ) ),
                          const SizedBox(height: 20),
                          Row( children: const [
                             Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
                             SizedBox(width: 8),
                             Text('Insights & Opportunités', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                          ] ),
                    const SizedBox(height: 12),
                          SizedBox( height: 160, child: (
                             _isLoadingInsights || _zoneInsights.isEmpty) ? Center(child: _isLoadingInsights ? const CircularProgressIndicator(strokeWidth: 2) : const Text("Aucun insight disponible.", style: TextStyle(color: Colors.grey))
                             ) : ListView.builder( scrollDirection: Axis.horizontal, itemCount: _zoneInsights.length, itemBuilder: (context, index) { final insight = _zoneInsights[index]; final color = insight['color'] as Color? ?? _getColorForInsight(null); final icon = insight['icon'] as IconData? ?? _getIconForInsight(null); return Container( width: 290, margin: const EdgeInsets.only(right: 12, bottom: 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration( borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.6)), color: color.withOpacity(0.03) ), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( children: [ Icon(icon, size: 18, color: color), const SizedBox(width: 8), Expanded( child: Text( insight['title'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color), maxLines: 1, overflow: TextOverflow.ellipsis ) ) ] ), const Divider(height: 16), Expanded( child: ListView.builder( physics: const NeverScrollableScrollPhysics(), itemCount: (insight['insights'] as List).length, itemBuilder: (context, insightIndex) { final insightText = insight['insights'][insightIndex] as String; return Padding( padding: const EdgeInsets.only(bottom: 6), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('• ', style: TextStyle(fontSize: 12, color: Colors.grey[700])), Expanded( child: Text( insightText, style: const TextStyle(fontSize: 12, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis ) ) ] ) ); } ) ) ] ) ); } ) ),
                          const SizedBox(height: 10),

                          // +++ Nearby Searches Section +++
                          Row( children: const [
                             Icon(Icons.person_search_outlined, size: 20, color: Colors.blueAccent),
                             SizedBox(width: 8),
                             Text('Recherches Utilisateurs Proches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                          ] ),
                          const SizedBox(height: 12),
                          SizedBox( height: 150, // Adjust height as needed
                            child: (
                             _isFetchingSearches && _nearbySearches.isEmpty) // Show loading only when fetching initially
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : _nearbySearches.isEmpty
                                ? const Center(child: Text("Aucune recherche récente à proximité.", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                                  itemCount: _nearbySearches.length,
                              itemBuilder: (context, index) {
                                    final search = _nearbySearches[index];
                                    return Container(
                                      width: 260, // Adjust width as needed
                                      margin: const EdgeInsets.only(right: 12, bottom: 4),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[200]!),
                                      boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2))
                                        ]
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundImage: (search.userProfilePicture != null && search.userProfilePicture!.isNotEmpty)
                                                  ? CachedNetworkImageProvider(search.userProfilePicture!) as ImageProvider
                                                  : const AssetImage('assets/images/default_avatar.png'),
                                                backgroundColor: Colors.grey[200],
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                      search.userName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                      maxLines: 1, overflow: TextOverflow.ellipsis
                                                    ),
                                            Text(
                                                      timeago.format(search.timestamp, locale: 'fr'),
                                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                                )
                                        ),
                                      ],
                                    ),
                                          const Divider(height: 16),
                                          Text(
                                            'Recherche:',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '"${search.query}"' ?? '-',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                                            maxLines: 2, overflow: TextOverflow.ellipsis
                                          ),
                                          const Spacer(),
                    SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.local_offer_outlined, size: 16),
                                              label: const Text('Envoyer Offre', style: TextStyle(fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.orange[800],
                                                side: BorderSide(color: Colors.orange[200]!),
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                              ),
                                              onPressed: () {
                                                // Show the offer dialog
                                                _showSendOfferDialog(search);
                                              },
                                            ),
                                          )
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                          // +++ End Nearby Searches Section +++

                          const SizedBox(height: 10), // Add padding at the end
                       ]
                    ) ),
                ] )
             )
           )
          ),
          
          if (_isLoading)
            Container( color: Colors.black.withOpacity(0.5), child: const Center(
               child: Column( mainAxisSize: MainAxisSize.min, children: [
                   CircularProgressIndicator(color: Colors.white),
                   SizedBox(height: 16),
                   Text("Chargement initial...", style: TextStyle(color: Colors.white, fontSize: 16))
                 ]
               )
             )
            ),
        ],
      ),
    );
  }

 // --- Helper Widgets ---
 Widget _buildLegendItem({required Color color, required String label}) { return Padding( padding: const EdgeInsets.only(bottom: 4.0), child: Row( children: [ Container( width: 14, height: 14, decoration: BoxDecoration(color: color.withOpacity(0.7), shape: BoxShape.circle, border: Border.all(color: color, width:1.5))), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 12)) ] ) ); }

 // +++ ADDED _showSendPushDialog method +++
  void _showSendPushDialog({String? zoneId}) {
     final titleController = TextEditingController();
     final messageController = TextEditingController();
     final formKey = GlobalKey<FormState>();

     // Use existing controllers for discount/duration if needed, or create new ones
     final discount = _customDiscountController.text; // Example: Reuse existing
     final duration = _customDurationController.text; // Example: Reuse existing

     // Pre-fill title/message if needed based on zone or generic offer
     if (zoneId != null) {
       titleController.text = 'Offre Spéciale dans la Zone !';
       messageController.text = 'Profitez de -$discount% pendant $duration heure(s) !';
     } else {
       titleController.text = 'Offre Flash aux Alentours !';
       messageController.text = 'Venez vite: -$discount% pendant $duration heure(s) !';
     }

     showDialog(
       context: context,
       builder: (context) {
         // Use StatefulWidget for the dialog content if it needs its own loading state
         return AlertDialog(
           title: Text(zoneId != null ? 'Envoyer offre à la zone' : 'Envoyer Push aux alentours'),
           content: Form(
             key: formKey,
            child: Column(
               mainAxisSize: MainAxisSize.min,
              children: [
                 TextFormField(
                   controller: titleController,
                   decoration: const InputDecoration(labelText: 'Titre de la Notification'),
                   validator: (value) => value == null || value.isEmpty ? 'Titre requis' : null,
                 ),
                 const SizedBox(height: 10),
                 TextFormField(
                   controller: messageController,
                   decoration: const InputDecoration(labelText: 'Message de la Notification'),
                   maxLines: 3,
                   validator: (value) => value == null || value.isEmpty ? 'Message requis' : null,
                 ),
                 // Optionally add fields for discount/duration if needed here
              ],
            ),
          ),
           actions: [
             TextButton(
               onPressed: () => Navigator.of(context).pop(),
               child: const Text('Annuler'),
             ),
             ElevatedButton(
               // Consider if the dialog needs its own loading state or uses the screen's _isLoading
               onPressed: _isLoading ? null : () {
                 if (formKey.currentState!.validate()) {
                   if (zoneId != null) {
                     _sendOfferToZone(zoneId, titleController.text, messageController.text);
                   } else {
                     _sendPushToCurrentArea(titleController.text, messageController.text);
                   }
                 }
               },
               // Show loading indicator based on screen's state
               child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Envoyer'),
             ),
           ],
         );
       },
     );
   }
   // +++ END _showSendPushDialog method +++

   // +++ ADDED _sendOfferToZone method +++
   Future<void> _sendOfferToZone(String zoneId, String title, String message) async {
     if (!mounted) return;
     setState(() => _isLoading = true);
     Navigator.of(context).pop(); // Close the dialog immediately

     try {
       final String apiUrl = '${constants.getBaseUrl()}/api/notifications/send/area';
       final headers = await ApiConfig.getAuthHeaders();

       final models.UserHotspot? zone = _hotspots.firstWhereOrNull((h) => h.id == zoneId);

       if (zone == null) throw Exception("Zone non trouvée pour l'envoi.");

       final body = json.encode({
         'latitude': zone.latitude,
         'longitude': zone.longitude,
         'radius': 500,
         'title': title,
         'body': message,
         'data': { 'type': 'zone_offer', 'zoneId': zoneId, 'producerId': widget.userId }
       });

       final response = await http.post(Uri.parse(apiUrl), headers: {...headers, 'Content-Type': 'application/json'}, body: body);

       if (!mounted) return;

       if (response.statusCode == 200) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Offre envoyée à la zone avec succès !'), backgroundColor: Colors.green),
         );
    } else {
         print('Failed to send zone offer: ${response.statusCode} - ${response.body}');
         throw Exception('Échec envoi offre zone: ${response.statusCode}');
       }
     } catch (e) {
       print('Error sending zone offer: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur envoi zone: $e'), backgroundColor: Colors.red),
         );
       }
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
   }
   // +++ END _sendOfferToZone method +++

   // +++ ADDED _sendPushToCurrentArea method +++
   Future<void> _sendPushToCurrentArea(String title, String message) async {
      // Need producer's current location for this, fetch it if not available?
      // Or use a default/estimated center if location fetch fails.
      // For now, let's assume we have producer's location (fetched in _loadData)
      final locationData = await _fetchProducerLocation(); // Refetch or use stored?
      final producerLat = locationData['latitude'];
      final producerLon = locationData['longitude'];

     if (producerLat == null || producerLon == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Localisation producteur inconnue.'), backgroundColor: Colors.orange) );
        return;
     }

     if (!mounted) return;
     setState(() => _isLoading = true);
     Navigator.of(context).pop(); // Close dialog

     try {
       final String apiUrl = '${constants.getBaseUrl()}/api/notifications/send/area';
       final headers = await ApiConfig.getAuthHeaders();

       final body = json.encode({
         'latitude': producerLat,
         'longitude': producerLon,
         'radius': 1000, // Default radius (e.g., 1km) around producer
         'title': title,
         'body': message,
         'data': { 'type': 'general_offer', 'producerId': widget.userId }
       });

       final response = await http.post(Uri.parse(apiUrl), headers: {...headers, 'Content-Type': 'application/json'}, body: body);

        if (!mounted) return;

       if (response.statusCode == 200) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Notification envoyée aux alentours !'), backgroundColor: Colors.green),
         );
           } else {
         print('Failed to send area push: ${response.statusCode} - ${response.body}');
         throw Exception('Échec envoi push zone: ${response.statusCode}');
       }
     } catch (e) {
       print('Error sending area push: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur push zone: $e'), backgroundColor: Colors.red),
         );
       }
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
   }
   // +++ END _sendPushToCurrentArea method +++

   // +++ ADDED _fetchPublicUserInfo method +++
   Future<void> _fetchPublicUserInfo(String userId) async {
      if (!mongoose.isValidObjectId(userId)) {
         print('Invalid User ID format for public profile fetch: $userId');
         if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('ID utilisateur invalide.'), backgroundColor: Colors.orange) );
         return;
      }

     if (!mounted || _isFetchingProfile) return;
     print(" Fetching public profile for $userId...");
     setState(() { _isFetchingProfile = true; _fetchedUserProfile = null; });

     try {
       final String apiUrl = '${constants.getBaseUrl()}/api/users/$userId/public-profile';
       // Public profile likely doesn't need auth, but include if it does
       // final headers = await _authService.getAuthHeaders();

       final response = await http.get(Uri.parse(apiUrl)/*, headers: headers*/);

       if (!mounted) return;

       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         final userProfile = PublicUserProfile.fromJson(data);
         setState(() { _fetchedUserProfile = userProfile; });
         _showUserProfileSheet(userProfile); // Show the profile in a bottom sheet
       } else if (response.statusCode == 404) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Profil utilisateur non trouvé.'), backgroundColor: Colors.orange) );
       } else {
         print('Failed to load public user info: ${response.statusCode} - ${response.body}');
         throw Exception('Échec récupération profil: ${response.statusCode}');
       }
     } catch (e) {
       print('Error fetching public user info: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur profil: $e'), backgroundColor: Colors.red),
         );
       }
     } finally {
       if (mounted) setState(() { _isFetchingProfile = false; });
     }
   }
   // +++ END _fetchPublicUserInfo method +++

   // +++ ADDED _showUserProfileSheet method +++
    void _showUserProfileSheet(PublicUserProfile user) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.4, maxChildSize: 0.6, minChildSize: 0.2, expand: false,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: [ BoxShadow(blurRadius: 10, color: Colors.black26)]
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                       CircleAvatar(
                         radius: 35,
                         backgroundImage: (user.profilePicture != null && user.profilePicture!.isNotEmpty)
                             ? CachedNetworkImageProvider(user.profilePicture!) as ImageProvider
                             : const AssetImage('assets/images/default_avatar.png'), // Ensure you have a default avatar
                       ),
                       const SizedBox(width: 15),
                       Expanded(
                         child: Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                       ),
                       IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (user.bio != null && user.bio!.isNotEmpty)
                     Padding(padding: const EdgeInsets.only(bottom: 15.0), child: Text(user.bio!, style: const TextStyle(fontSize: 14, color: Colors.black87))),
                  if (user.likedTags.isNotEmpty)
                    Wrap( // Display tags nicely
                      spacing: 8.0, // gap between adjacent chips
                      runSpacing: 4.0, // gap between lines
                      children: user.likedTags.map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blueGrey[50],
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      )).toList(),
                    ),
                  const SizedBox(height: 20),
                  // Add maybe a button to view full profile if applicable
                  // ElevatedButton(onPressed: (){ /* Navigate to full profile */ }, child: Text("Voir profil complet"))
                ],
          ),
        );
      },
        ),
      );
    }
   // +++ END _showUserProfileSheet method +++

   // +++ ADDED Nearby Searches Polling +++
   void _startNearbySearchPolling() {
     print("ℹ️ Starting nearby search polling...");
     _fetchNearbySearches(); // Fetch immediately
     _nearbySearchPollTimer?.cancel();
     _nearbySearchPollTimer = Timer.periodic(_nearbySearchPollInterval, (_) {
        if (!mounted) { _nearbySearchPollTimer?.cancel(); return; }
        if (!_isFetchingSearches) { _fetchNearbySearches(); }
     });
   }

   Future<void> _fetchNearbySearches() async {
     if (!mounted || _isFetchingSearches) return;
     print("📡 Fetching nearby searches...");
     setState(() { _isFetchingSearches = true; });

     try {
        final url = Uri.parse('${constants.getBaseUrl()}/api/heatmap/nearby-searches/${widget.userId}');
        // Optional: add query params for minutes/radius if needed, e.g.:
        // .replace(queryParameters: {'minutes': '15', 'radius': '1000'});
        final headers = await ApiConfig.getAuthHeaders();
        final response = await http.get(url, headers: headers);

        if (!mounted) return;

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          List<NearbySearchEvent> fetchedSearches = data
             .map((item) => NearbySearchEvent.fromJson(item))
             .toList();
          print("🔎 Parsed ${fetchedSearches.length} nearby searches.");

          // Update state only if data changed (optional optimization)
          if (!const DeepCollectionEquality().equals(_nearbySearches, fetchedSearches)) {
             setState(() { _nearbySearches = fetchedSearches; });
          }
           } else {
          print('❌ Error fetching nearby searches: ${response.statusCode} ${response.body}');
          // Optionally show snackbar on error, but maybe less frequent than active users?
        }
     } catch(e) {
        print('❌ Exception fetching nearby searches: $e');
     } finally {
       if (mounted) { setState(() { _isFetchingSearches = false; }); }
     }
   }
   // +++ END Nearby Searches Polling +++

   // +++ ADDED Offer Sending Dialog and Logic +++

  void _showSendOfferDialog(NearbySearchEvent search) {
    // Pre-fill based on search query if possible
    _offerTitleController.text = 'Offre Spéciale pour votre recherche !';
    _offerBodyController.text = 'Profitez de -${_offerDiscountController.text}% sur \"${search.query}\" pendant ${_offerValidityController.text} minutes !';

    final formKey = GlobalKey<FormState>();
    // Use a StatefulWidget for the dialog content to manage its own loading state
    showDialog(
      context: context,
      barrierDismissible: !_isSendingOffer, // Prevent dismissal while sending
      builder: (context) {
        return StatefulBuilder( // Allows updating dialog content (e.g., loading indicator)
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Envoyer Offre à ${search.userName}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView( // Make content scrollable
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Basé sur la recherche : "${search.query}"' , style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey)),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _offerTitleController,
                        decoration: const InputDecoration(labelText: 'Titre de l\'offre', border: OutlineInputBorder()),
                        validator: (value) => value == null || value.isEmpty ? 'Titre requis' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _offerBodyController,
                        decoration: const InputDecoration(labelText: 'Détails de l\'offre', border: OutlineInputBorder()),
                        maxLines: 3,
                        validator: (value) => value == null || value.isEmpty ? 'Détails requis' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _offerDiscountController,
                              decoration: const InputDecoration(labelText: 'Remise (%)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Requis';
                                final percent = int.tryParse(value);
                                if (percent == null || percent <= 0 || percent > 100) return 'Invalide (1-100)';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _offerValidityController,
                              decoration: const InputDecoration(labelText: 'Validité (min)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Requis';
                                final mins = int.tryParse(value);
                                if (mins == null || mins <= 0) return 'Invalide (>0)';
                                return null;
                              },
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSendingOffer ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  icon: _isSendingOffer
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(_isSendingOffer ? 'Envoi...' : 'Envoyer'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                  onPressed: _isSendingOffer ? null : () {
                    if (formKey.currentState!.validate()) {
                      // Use setDialogState to update the dialog's loading state
                      setDialogState(() => _isSendingOffer = true);
                      _sendTargetedOffer(
                        targetUserId: search.userId,
                        title: _offerTitleController.text,
                        body: _offerBodyController.text,
                        discountPercentage: int.parse(_offerDiscountController.text),
                        validityDurationMinutes: int.parse(_offerValidityController.text),
                        originalSearchQuery: search.query,
                        triggeringSearchId: search.searchId,
                      ).then((success) {
                          // Update state regardless of success/failure
                          setDialogState(() => _isSendingOffer = false);
                          if (success) {
                            Navigator.of(context).pop(); // Close dialog on success
                          }
                          // Error snackbar is shown within _sendTargetedOffer
                      });
                    }
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<bool> _sendTargetedOffer({
    required String targetUserId,
    required String title,
    required String body,
    required int discountPercentage,
    required int validityDurationMinutes,
    String? originalSearchQuery,
    String? triggeringSearchId,
  }) async {
    print(' SEnding targeted offer to $targetUserId...');
    final url = Uri.parse('${constants.getBaseUrl()}/api/offers/send');
    bool success = false;

    try {
      final headers = await ApiConfig.getAuthHeaders();
      final requestBody = json.encode({
        'targetUserId': targetUserId,
        'title': title,
        'body': body,
        'discountPercentage': discountPercentage,
        'validityDurationMinutes': validityDurationMinutes,
        'originalSearchQuery': originalSearchQuery,
        'triggeringSearchId': triggeringSearchId,
      });

      final response = await http.post(url, headers: {...headers, 'Content-Type': 'application/json'}, body: requestBody);

      if (!mounted) return false;

      if (response.statusCode == 201) {
        print(' Offer sent successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offre envoyée avec succès !'), backgroundColor: Colors.green),
        );
        success = true;
      } else {
        print(' Offer send failed: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec envoi offre: ${errorData['message'] ?? 'Erreur inconnue'}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print(' Exception sending offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réseau lors de l\'envoi de l\'offre: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Loading state is handled by the dialog's StatefulBuilder
    }
    return success;
  }

  // +++ END Offer Sending Dialog and Logic +++

  // +++ ADDED Navigation and Validation Logic +++

  Future<void> _navigateToOfferScanner() async {
    // Navigate to the scanner screen and wait for a result (the scanned code)
    final String? scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const OfferScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      print(' Scanned Offer Code: $scannedCode');
      _validateScannedOffer(scannedCode);
    }
  }

  Future<void> _validateScannedOffer(String offerCode) async {
    if (!mounted || _isValidatingOffer) return;
    print(' Validating offer code: $offerCode...');
    setState(() { _isValidatingOffer = true; });

    final url = Uri.parse('${constants.getBaseUrl()}/api/offers/validate');

    try {
      final headers = await ApiConfig.getAuthHeaders();
      final requestBody = json.encode({
        'offerCode': offerCode,
      });

      final response = await http.post(url, headers: {...headers, 'Content-Type': 'application/json'}, body: requestBody);

      if (!mounted) return;

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        print(' Offer validated successfully: ${responseData['offer']?['_id']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offre \"${responseData['offer']?['title'] ?? offerCode}\" validée avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        // Optional: Update local state or refetch data if needed
      } else {
        print(' Offer validation failed: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec validation: ${responseData['message'] ?? 'Erreur inconnue'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print(' Exception validating offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réseau validation: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isValidatingOffer = false; });
      }
    }
  }

  // +++ END Navigation and Validation Logic +++

} // End of _HeatmapScreenState

 // +++ ADDED Mongoose helper class +++
 class mongoose {
   static bool isValidObjectId(String id) {
     // Basic check for 24-character hex string
     return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id);
   }
 }
 // +++ END Mongoose helper class +++

