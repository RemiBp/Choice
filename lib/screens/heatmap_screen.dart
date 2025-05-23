import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart' as cluster_manager;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_hotspot.dart' as models;
import '../utils/constants.dart' as constants;
import '../utils/api_config.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:collection/collection.dart';
import '../models/user_model.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import './offer_scanner_screen.dart';
import 'package:choice_app/utils/validation_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

// --- ADDED: Custom dark theme colors ---
class AppColors {
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF252525);
  static const Color accent = Color(0xFF4A6FE5);
  static const Color accentSecondary = Color(0xFF8A50E0);
  static const Color accentTertiary = Color(0xFFE55270);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFBBBBBB);
  
  // Intensity colors with more futuristic feeling
  static Color lowIntensity = const Color(0xFF4A6FE5);
  static Color medIntensity = const Color(0xFF50C5E0); 
  static Color highIntensity = const Color(0xFFE55270);
}

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
  final DateTime? lastSeen; // <<< ADDED: Property for active user timestamps

  Place({
    required this.id,
    required this.name,
    required this.location,
    required this.isZone,
    this.visitorCount,
    this.lastSeen, // <<< ADDED: Add to constructor
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
    // Validate required fields
    final String? searchId = json['searchId'] as String?;
    final String? userId = json['userId'] as String?;
    final String? query = json['query'] as String?;
    final DateTime? timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
    final String? userName = json['userName'] as String?;

    // Check if essential fields are missing or invalid
    if (searchId == null || userId == null || query == null || timestamp == null || userName == null) {
      print("❌ Invalid NearbySearchEvent JSON: Missing required fields. Data: $json");
      // Throw an error or return a specific 'invalid' object if preferred.
      // For now, returning a default but logging error.
      // Consider throwing FormatException('Invalid NearbySearchEvent JSON: $json');
      return NearbySearchEvent(
        searchId: searchId ?? 'invalid_search_${math.Random().nextInt(1000)}',
        userId: userId ?? 'invalid_user',
        query: query ?? 'invalid_query',
        timestamp: timestamp ?? DateTime.now(),
        userName: userName ?? 'Utilisateur Invalide',
        userProfilePicture: json['userProfilePicture'] as String?,
      );
    }

    return NearbySearchEvent(
      searchId: searchId,
      userId: userId,
      query: query,
      timestamp: timestamp,
      userName: userName,
      userProfilePicture: json['userProfilePicture'] as String?,
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
    final String? id = json['id'] as String? ?? json['_id'] as String?; // Handle potential null or different ID field (_id)
    final String? name = json['name'] as String?;

    if (id == null || name == null) {
       print("❌ Invalid PublicUserProfile JSON: Missing ID or Name. Data: $json");
       // Consider throwing FormatException('Invalid PublicUserProfile JSON: $json');
       return PublicUserProfile(
         id: id ?? 'invalid_id_${math.Random().nextInt(1000)}',
         name: name ?? 'Utilisateur Invalide',
         profilePicture: json['profilePicture'] as String?,
         bio: json['bio'] as String?,
         likedTags: List<String>.from(json['liked_tags'] ?? []),
       );
    }

    return PublicUserProfile(
      id: id,
      name: name,
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
             try {
                loc = LatLng(json['location']['coordinates'][1].toDouble(), json['location']['coordinates'][0].toDouble());
             } catch (e) {
                 print("❌ Error parsing GeoJSON coordinates: ${json['location']['coordinates']} - $e");
                 // Keep loc as null if parsing fails
             }
        } else if (json['location'] is Map && json['location']['latitude'] != null && json['location']['longitude'] != null) {
              try {
                loc = LatLng(json['location']['latitude'].toDouble(), json['location']['longitude'].toDouble());
              } catch (e) {
                 print("❌ Error parsing lat/lng coordinates: ${json['location']} - $e");
                 // Keep loc as null
             }
        }
    }
    // loc ??= const LatLng(0, 0); // REMOVED Default: Location is essential

    final String? userId = json['_id'] as String? ?? json['userId'] as String?;
    final String? name = json['name'] as String?;
    final DateTime? lastSeen = DateTime.tryParse(json['lastSeen'] as String? ?? '');

    // Check for essential missing data (ID, Name, Location, Timestamp)
    if (userId == null || name == null || loc == null || lastSeen == null) {
      print("❌ Invalid ActiveUser JSON: Missing required fields (ID, Name, Location, or LastSeen). Data: $json");
      // Consider throwing FormatException('Invalid ActiveUser JSON: $json');
      // Return an 'invalid' user for now, but this should ideally be filtered out.
      return ActiveUser(
        userId: userId ?? 'invalid_user_${math.Random().nextInt(1000)}',
        name: name ?? 'Utilisateur Invalide',
        location: loc ?? const LatLng(0,0), // Still need a default LatLng here for the type
        lastSeen: lastSeen ?? DateTime.now(),
        profilePicture: json['profilePicture'] as String?,
        distance: (json['distance'] as num?)?.toDouble(),
      );
    }

    return ActiveUser(
      userId: userId,
      name: name,
      profilePicture: json['profilePicture'] as String?,
      location: loc, // Use parsed, non-null location
      lastSeen: lastSeen, // Use parsed, non-null timestamp
      distance: (json['distance'] as num?)?.toDouble(),
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
  String? _loadingError; // <<< ADDED: State variable for loading errors
  String _selectedTimeFilter = 'Tous';
  String _selectedDayFilter = 'Tous';
  
  // Add missing state variables
  bool _isValidatingOffer = false; // QR code validation state
  
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

  // +++ ADDED: Controller for Bottom Sheet Tabs +++
  late TabController _bottomSheetTabController;

  // +++ ADDED: Store producer location +++
  LatLng? _producerLocation;
  final Completer<GoogleMapController> _mapControllerCompleter = Completer(); // To ensure map is ready
  
  // +++ ADDED: State for producer marker +++
  Marker? _producerMarker;
  BitmapDescriptor? _producerIcon;

  // Ajouter une variable pour contrôler l'affichage des insights
  bool _showInsightsPanel = true;

  
  @override
  void initState() {
    super.initState();
    _nearbySearches = []; // Initialize empty list
    initializeTimeago();
    _clusterManager = _initClusterManager();
    _bottomSheetTabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadProducerIcon(); // Load the custom icon
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
    // +++ ADDED: Dispose TabController +++
    _bottomSheetTabController.dispose(); 
    super.dispose();
  }
  
  // --- Data Loading ---
  Future<void> _loadData() async {
    if (!mounted) return;
    print("🔄 [_loadData] Starting data load sequence..."); // Log start
    setState(() {
      _isLoading = true;
      _loadingError = null; // Clear previous errors
      _hotspots = []; // Clear previous data
      _filteredHotspots = [];
      _activeUsers = [];
      _nearbySearches = [];
      _zoneInsights = [];
      _places = [];
      _producerLocation = null; // Reset producer location
      // Clear cluster items
       if (_clusterManager != null) { // Check if initialized
          _clusterManager.setItems(<Place>[]); 
       }
    });

    // Cancel existing timers before loading
    _activeUserPollTimer?.cancel();
    _nearbySearchPollTimer?.cancel();
    print("🔄 [_loadData] Timers cancelled."); // Log timer cancellation

    try {
      // Fetch producer location FIRST
      print("🔄 [_loadData] Fetching producer location..."); // Log location fetch start
      _producerLocation = await _fetchProducerLocation(); // Store fetched location
      print("✅ [_loadData] Producer location fetched: ${_producerLocation?.latitude}, ${_producerLocation?.longitude}"); // Log location success

      // +++ ADDED: Create producer marker once location is fetched +++
      _createOrUpdateProducerMarker();

      // +++ ADDED: Center map once controller is ready and location is fetched +++
      if (_producerLocation != null) {
        final GoogleMapController controller = await _mapControllerCompleter.future;
        print("🔄 [_loadData] Animating map to producer location AFTER map ready.");
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_producerLocation!, 14), // Use stored location
        );
      }
      // +++ END ADDED +++

      // Fetch hotspots and insights concurrently
      print("🔄 [_loadData] Fetching hotspots and insights concurrently..."); // Log concurrent fetch start
      // Use fetched producer location if available, otherwise default (though fetch should succeed or throw)
      final lat = _producerLocation?.latitude ?? _initialCameraPosition.target.latitude;
      final lon = _producerLocation?.longitude ?? _initialCameraPosition.target.longitude;

      final results = await Future.wait([
         _fetchHotspots(lat, lon),
         _loadZoneInsights(), // Fetch insights (already handles own loading state)
      ]);
      print("✅ [_loadData] Concurrent fetches completed."); // Log concurrent fetch end
      // ADDED Mount Check
      if (!mounted) { print("🛑 [_loadData] Widget unmounted after concurrent fetches wait."); return; }

      final hotspots = results[0] as List<models.UserHotspot>?; // Result from _fetchHotspots
      // Insights result (results[1]) is handled internally by _loadZoneInsights

      if (hotspots != null) {
         print("✅ [_loadData] Hotspots data available (${hotspots.length} hotspots). Updating state..."); // Log hotspot data processing
         setState(() {
           _hotspots = hotspots;
           _filteredHotspots = List.from(hotspots); // Initialize filtered list
           _generateZoneStats(); // Calculate stats based on initial hotspots
         });
         print("🔄 [_loadData] Starting polling mechanisms..."); // Log polling start
         // Start polling only after initial data load is successful
         _startActiveUserPolling();
         _startNearbySearchPolling();
         print("✅ [_loadData] Polling mechanisms started."); // Log polling end
      } else {
          // Handle case where hotspots failed to load (error should have been caught by _fetchHotspots ideally)
          print("⚠️ [_loadData] Hotspots data is null. Setting error message."); // Log null hotspots
          setState(() {
             _hotspots = [];
             _filteredHotspots = [];
             _generateZoneStats();
             _loadingError = _loadingError ?? 'Impossible de charger les zones d\'intérêt.'; // Set error if not already set
          });
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Impossible de charger les zones d\'intérêt.'), backgroundColor: Colors.orange),
             );
           }
           // Decide if polling should start even if hotspots fail
           print("🔄 [_loadData] Starting polling mechanisms despite hotspot load failure..."); // Log polling start (failure case)
           _startActiveUserPolling();
           _startNearbySearchPolling();
           print("✅ [_loadData] Polling mechanisms started (after hotspot failure)."); // Log polling end (failure case)
      }
      print("✅ [_loadData] Data processing finished successfully."); // Log successful end of try block

    } catch (e, stackTrace) { // Catch stackTrace for more detailed debugging
      print("❌ [_loadData] Error during initial data load: $e"); // Log error
      print("❌ [_loadData] StackTrace: $stackTrace"); // Log stack trace
      if (mounted) {
        setState(() {
          _loadingError = e.toString(); // Store the error message
        });
      }
    } finally {
       print("🏁 [_loadData] Finally block reached. Setting isLoading to false."); // Log finally block
       if (mounted) setState(() { _isLoading = false; });
       print("✅ [_loadData] Initial data loading sequence finished."); // Log final end
    }
  }
  
  // MODIFIED: Now returns LatLng on success or throws an error
  Future<LatLng> _fetchProducerLocation() async {
     print(" LFetching producer location...");
    try {
      // Use the corrected endpoint
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.userId}/location');
      final headers = await ApiConfig.getAuthHeaders();
      print(" Requesting: ${url.toString()}"); // Log URL
      final response = await http.get(url, headers: headers);
      print(" Producer location response: ${response.statusCode}"); // Log status code
      // ADDED Mount Check
      if (!mounted) throw Exception("Widget unmounted during producer location fetch.");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(" Producer location data received: $data"); // Log received data
        final lat = data['latitude'];
        final lon = data['longitude'];
        if (lat != null && lon != null) {
          print(" Producer location parsed: $lat, $lon");
          return LatLng(lat.toDouble(), lon.toDouble());
        } else {
          print('❌ Invalid location data received: $data');
          throw Exception('Données de localisation invalides reçues du serveur.');
        }
      } else {
        print('❌ Error fetching producer location: ${response.statusCode} ${response.body}');
        String errorMessage = 'Erreur ${response.statusCode} lors de la récupération de la localisation.';
        try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
        } catch (_) {
            // Ignore JSON decoding errors if body is not valid JSON
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Exception fetching producer location: $e');
      // Rethrow the exception to be caught by _loadData
      rethrow;
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
     print(" Requesting: ${url.toString()}"); // Log URL
     try {
       final headers = await ApiConfig.getAuthHeaders();
       final response = await http.get(url, headers: headers);
       print(" Hotspots response: ${response.statusCode}"); // Log status code
       // ADDED Mount Check
       if (!mounted) throw Exception("Widget unmounted during hotspot fetch.");

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
          // Throw an error instead of returning empty list to ensure it's caught by _loadData
          String errorMessage = 'Erreur ${response.statusCode} (hotspots).';
          try {
             final errorData = json.decode(response.body);
             errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {}
          throw Exception(errorMessage);
        }
     } catch (e) {
        print('❌ Exception fetching hotspots: $e');
        // Rethrow to be caught by _loadData
        rethrow;
     }
  }

  Future<void> _loadZoneInsights() async {
    // Only proceed if not already loading and widget is mounted
    if (!mounted || _isLoadingInsights) {
       print("⚠️ [_loadZoneInsights] Skipped: Mounted=$mounted, Loading=$_isLoadingInsights");
       return;
    }
    print(" IFetching insights for producer ${widget.userId}...");
    setState(() { _isLoadingInsights = true; });
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/heatmap/action-opportunities/${widget.userId}');
      final headers = await ApiConfig.getAuthHeaders();
      print(" Requesting: ${url.toString()}"); // Log URL
      final response = await http.get(url, headers: headers);
      print(" Insights response: ${response.statusCode}"); // Log status code

      if (!mounted) {
         print("🛑 [_loadZoneInsights] Widget unmounted after fetch."); // Log unmount
         return; // Exit if widget is disposed after the await
      }

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
          _isLoadingInsights = false; // Set loading false on success
        });
      } else {
        print('❌ Erreur chargement insights: ${response.statusCode} ${response.body}');
        if (mounted) {
           setState(() {
              _zoneInsights = []; // Clear on error
              _isLoadingInsights = false; // Set loading false on error
           });
           // Show snackbar, but don't throw error to block _loadData completion
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Erreur chargement insights (${response.statusCode})'), backgroundColor: Colors.orange),
           );
        }
      }
    } catch (e, stackTrace) { // Catch stacktrace
      print('❌ Exception lors du chargement des insights: $e');
      print('❌ StackTrace: $stackTrace'); // Log stacktrace
       if (mounted) {
         setState(() {
            _zoneInsights = []; // Clear on exception
            _isLoadingInsights = false; // Set loading false on exception
         });
         // Show snackbar, but don't throw error
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Erreur réseau (insights).'), backgroundColor: Colors.orange),
         );
       }
    }
    // Removed finally block as state is set within try/catch now
    // ADDED Ensure loading state is always set back, even on error
    finally {
      if (mounted && _isLoadingInsights) {
         setState(() => _isLoadingInsights = false);
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
    final List<String> dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'samedi', 'sunday'];
    final Map<String, String> dayTranslation = {'monday': 'Lun', 'tuesday': 'Mar', 'wednesday': 'Mer', 'thursday': 'Jeu', 'friday': 'Ven', 'samedi': 'Sam', 'sunday': 'Dim'};
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

  Widget _buildStatRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          // --- FIX: Wrap with Flexible to prevent overflow ---
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
          // --- END FIX ---
        ],
      ),
    );
  }

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

  // --- MODIFIED: Helper function for intensity color ---
  Color _getColorForIntensity(double intensity) {
    // Futuristic colors from blue -> teal -> red
    if (intensity < 0.5) {
      return Color.lerp(AppColors.lowIntensity, AppColors.medIntensity, intensity * 2) ?? Colors.grey;
    } else {
      return Color.lerp(AppColors.medIntensity, AppColors.highIntensity, (intensity - 0.5) * 2) ?? Colors.grey;
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
           print("👥 Found ${data.length} active users raw.");
           
           // Filter invalid users during mapping
           List<ActiveUser> fetchedUsers = data
              .map((item) {
                 try {
                   return ActiveUser.fromJson(item);
                 } catch (e) {
                   print("Failed to parse ActiveUser: $e, Item: $item");
                   return null;
                 }
              })
              .whereType<ActiveUser>() // Keep non-nulls
              // Filter out users created with defaults due to missing essential data
              .where((user) => !user.userId.startsWith('invalid_') && user.location != const LatLng(0,0))
              .toList();
              
           print("👥 Parsed ${fetchedUsers.length} valid active users.");

           if (!listEquals(_activeUsers, fetchedUsers)) {
               print(" User list changed, updating state and map.");
              setState(() { _activeUsers = fetchedUsers; });
              _updatePlacesList();
           } else {
               // print(" User list unchanged.");
           }
        } else {
          print('❌ Error fetching active users: ${response.statusCode} ${response.body}');
           if (mounted) setState(() => _activeUsers = []); // Clear on error
        }
     } catch(e) {
        print('❌ Exception fetching active users: $e');
         if (mounted) setState(() => _activeUsers = []); // Clear on exception
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
    for (var activeUser in _activeUsers) {
      if (activeUser.location.latitude != 0 || activeUser.location.longitude != 0) {
        // --- UPDATED: Pass lastSeen to Place object ---
        newPlaces.add(Place(
          id: 'active_${activeUser.userId}',
          name: activeUser.name,
          location: activeUser.location,
          isZone: false,
          lastSeen: activeUser.lastSeen // Pass the timestamp
        ));
        // --- END UPDATE ---
      }
    }
    // Update the cluster manager - this triggers _markerBuilder eventually
    setState(() { _places = newPlaces; });
    // --- ADDED Explicit Cast --- 
    _clusterManager.setItems(_places as List<Place>); // Explicitly cast to List<Place>
    // --- END ADDED Cast --- 
    print(" Updated ClusterManager with ${_filteredHotspots.length} zones and ${_activeUsers.length} users -> ${_places.length} total places.");
  }

  cluster_manager.ClusterManager _initClusterManager() {
    return cluster_manager.ClusterManager<Place>(
      // _places, // Initial list (likely empty) - Pass empty list initially
      <Place>[], // Pass an explicitly typed empty list
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
    final place = cluster.items.first; // We need the place data for user markers too
    final String markerIdStr = isMultiple ? cluster.getId() : place.id;

    BitmapDescriptor icon;
    VoidCallback? onTapAction;
    double zIndex = 0.0;

    // --- Use Place object directly --- 
    // Now we can directly access place.lastSeen for user markers if needed below

    // Use cache for marker icons
    // Cache key generation needs refinement to differentiate marker types better
    String cacheKeyPrefix = isMultiple ? 'cluster' : (place.isZone ? 'zone' : 'user');
    // Include count for clusters, intensity for zones (rounded), and lastSeen status for users
    String cacheKeyData = isMultiple 
        ? cluster.count.toString() 
        : (place.isZone 
            ? ((_hotspots.firstWhereOrNull((h) => h.id == place.id)?.intensity ?? 0.5) * 10).round().toString() // Use rounded intensity
            : (place.lastSeen != null && DateTime.now().difference(place.lastSeen!).inMinutes < 5 ? 'recent' : 'normal')); // Add recency to user key
    final String markerCacheKey = '${cacheKeyPrefix}_${markerIdStr}_$cacheKeyData';

    if (_markerBitmapCache.containsKey(markerCacheKey)) {
      icon = _markerBitmapCache[markerCacheKey]!;
    } else {
      if (isMultiple) {
        // --- Enhanced Cluster Marker --- 
        icon = await _getClusterMarkerBitmap(cluster.count);
      } else if (place.isZone) {
        // --- Enhanced Zone Marker --- 
        final hotspot = _hotspots.firstWhereOrNull((h) => h.id == place.id);
        final intensity = hotspot?.intensity ?? 0.5;
        icon = await _getZoneMarkerBitmap(intensity);
      } else {
        // --- Enhanced User Marker (Pass lastSeen) ---
        // final userPlace = cluster.items.first; // already got place above
        icon = await _getUserMarkerBitmap(place.id.replaceFirst('active_', ''), place.lastSeen);
      }
      _markerBitmapCache[markerCacheKey] = icon; // Store in cache
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
         snippet: place.isZone ? '${place.visitorCount ?? '?'} visiteurs (estimé)' : (place.lastSeen != null ? 'Vu ${timeago.format(place.lastSeen!, locale: 'fr')}' : 'Utilisateur actif')
      ),
      zIndex: zIndex,
    );
  }

  // --- REMOVED Old _getMarkerBitmap --- 

  // --- ADDED: Specific Bitmap Generators ---

  // Generates bitmap for CLUSTERS
  Future<BitmapDescriptor> _getClusterMarkerBitmap(int count, { int size = 110}) async {
    final String cacheKey = 'cluster_$count';
    if (_markerBitmapCache.containsKey(cacheKey)) return _markerBitmapCache[cacheKey]!;

    if (size <= 0) return BitmapDescriptor.defaultMarker;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint1 = Paint()..color = Colors.deepPurple.withOpacity(0.9);
    final Paint paint2 = Paint()..color = Colors.white.withOpacity(0.95);
    final Paint paint3 = Paint()..color = Colors.deepPurple.withOpacity(0.7);

    // Simple depth effect with multiple circles
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint3);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0 * 0.9, paint2);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0 * 0.75, paint1);

    // Text style (slightly larger, bolder)
    TextPainter painter = TextPainter(textDirection: ui.TextDirection.ltr);
    painter.text = TextSpan(
        text: count.toString(),
        style: TextStyle(
            fontSize: size / 2.6, 
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            shadows: [ // Add subtle shadow for readability
                Shadow(blurRadius: 1.0, color: Colors.black.withOpacity(0.5), offset: const Offset(1, 1))
            ]
        )
    );
    painter.layout();
    painter.paint(canvas, Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2));

    try {
       final img = await pictureRecorder.endRecording().toImage(size, size);
       final data = await img.toByteData(format: ui.ImageByteFormat.png);
       if (data == null) throw Exception("Byte data null");
       final bitmap = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
       _markerBitmapCache[cacheKey] = bitmap; // Cache the final bitmap
       return bitmap;
    } catch (e) { print("Error creating cluster bitmap: $e"); return BitmapDescriptor.defaultMarker; }
  }

  // Generates bitmap for ZONES (Intensity Rings)
  Future<BitmapDescriptor> _getZoneMarkerBitmap(double intensity, { int size = 90 }) async {
    final String cacheKey = 'zone_${(intensity * 10).round()}'; // Cache based on rounded intensity
    if (_markerBitmapCache.containsKey(cacheKey)) return _markerBitmapCache[cacheKey]!;

    if (size <= 0) return BitmapDescriptor.defaultMarker;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Color color = _getColorForIntensity(intensity);
    
    // Calculate ring width based on intensity (thicker for higher intensity)
    final double baseStrokeWidth = 2.0;
    final double maxStrokeWidth = 6.0;
    final double strokeWidth = baseStrokeWidth + (intensity * (maxStrokeWidth - baseStrokeWidth));

    final Paint ringPaint = Paint()
      ..color = color.withOpacity(0.85) // Slightly transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    // Draw the ring
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0 - strokeWidth / 2, ringPaint);

    try {
       final img = await pictureRecorder.endRecording().toImage(size, size);
       final data = await img.toByteData(format: ui.ImageByteFormat.png);
       if (data == null) throw Exception("Byte data null");
       final bitmap = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
       _markerBitmapCache[cacheKey] = bitmap; // Cache the final bitmap
       return bitmap;
    } catch (e) { print("Error creating zone marker bitmap: $e"); return BitmapDescriptor.defaultMarker; }
  }

  // Generates bitmap for USERS (with optional recency indicator)
  Future<BitmapDescriptor> _getUserMarkerBitmap(String userId, DateTime? lastSeen) async {
    // Add recency to cache key
    final bool isRecent = lastSeen != null && DateTime.now().difference(lastSeen).inMinutes < 5;
    final String cacheKey = 'user_${userId}_${isRecent ? "recent" : "normal"}'; 
    if (_markerBitmapCache.containsKey(cacheKey)) return _markerBitmapCache[cacheKey]!;

    final user = _activeUsers.firstWhereOrNull((u) => u.userId == userId);
    Uint8List? imageBytes;
    if (user?.profilePicture != null && user!.profilePicture!.isNotEmpty) {
       try {
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
    final Paint borderPaint = Paint()..color = Colors.blueAccent[700]!..style = PaintingStyle.stroke..strokeWidth = 3.5; // Slightly thicker border
    final Paint backgroundPaint = Paint()..color = Colors.white;
    final Paint recentIndicatorPaint = Paint()..color = Colors.greenAccent[400]!..style = PaintingStyle.fill;
    final Paint recentIndicatorBorderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5;

    // Draw background first
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, backgroundPaint);

    // Draw image or placeholder
    if (imageBytes != null) {
       try {
         final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
         final ui.FrameInfo frameInfo = await codec.getNextFrame();
         final ui.Image userImage = frameInfo.image;
         // Clip slightly inside border
         final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2.0 - (borderPaint.strokeWidth / 2))); 
         canvas.save(); 
         canvas.clipPath(clipPath);
         paintImage( canvas: canvas, rect: Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), image: userImage, fit: BoxFit.cover );
         canvas.restore(); 
       } catch (e) {
          print("Error decoding/drawing user image: $e");
          _drawPlaceholderUserIcon(canvas, size); // Draw placeholder if image fails
       }
    } else { 
      _drawPlaceholderUserIcon(canvas, size); 
    } 

    // Draw border on top
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0 - (borderPaint.strokeWidth / 2), borderPaint); 

    // --- ADDED: Draw Recency Indicator --- 
    if (isRecent) {
       const double indicatorRadius = size * 0.12;
       const double indicatorOffset = size * 0.05; // Offset from the top-right edge
       final Offset indicatorCenter = Offset(size - indicatorRadius - indicatorOffset, indicatorRadius + indicatorOffset);
       // Draw white border first for contrast
       canvas.drawCircle(indicatorCenter, indicatorRadius + recentIndicatorBorderPaint.strokeWidth / 2 , recentIndicatorBorderPaint);
       // Draw green indicator
       canvas.drawCircle(indicatorCenter, indicatorRadius, recentIndicatorPaint);
    }
    // --- END ADDED --- 

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

  // +++ ADDED: Method to load producer icon asset +++
  Future<void> _loadProducerIcon() async {
    // Consider using a custom asset or a distinct Material icon
    // Using store icon for now
     try {
       _producerIcon = await BitmapDescriptor.fromAssetImage(
           const ImageConfiguration(size: Size(48, 48)), // Adjust size as needed
           'assets/icons/store_marker.png' // MAKE SURE you have this asset!
       );
       // Fallback if asset loading fails
        _producerIcon ??= BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
     } catch (e) {
        print("Error loading producer icon asset: $e");
         _producerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange); // Fallback color
     }
     // Refresh marker if location is already known
     if (_producerLocation != null) {
        _createOrUpdateProducerMarker();
     }
  }

  // +++ ADDED: Method to create/update the producer marker +++
  void _createOrUpdateProducerMarker() {
     if (!mounted || _producerLocation == null) return;
     
     final Marker marker = Marker(
        markerId: const MarkerId('producer_location'),
        position: _producerLocation!,
        icon: _producerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), // Use loaded icon or fallback
        infoWindow: const InfoWindow(title: 'Mon Établissement'),
        zIndex: 5.0, // Ensure it's visible above others
     );
     
     setState(() {
        _producerMarker = marker;
     });
     print(" Producer marker created/updated at $_producerLocation");
  }

  // --- Main Widget Build ---
  @override
  Widget build(BuildContext context) {
    final bool canShowBottomSheet = _loadingError == null;
    final Set<Marker> allMarkers = {
      ..._clusterMarkers,
      if (_producerMarker != null) _producerMarker!,
    };
    
    // Always use dark theme
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          elevation: 0,
        ),
        cardTheme: const CardTheme(
          color: AppColors.darkCard,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentSecondary,
          surface: AppColors.darkSurface,
          background: AppColors.darkBackground,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
          onBackground: AppColors.textPrimary,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          bodySmall: TextStyle(color: AppColors.textSecondary),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF333333),
        ),
      ),
      child: Scaffold(
      appBar: AppBar(
          title: const Text("Analyse d'Audience", 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            )
          ),
          elevation: 0,
        actions: [ 
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            onPressed: _centerOnProducerLocation,
            tooltip: 'Centrer sur mon établissement',
              color: AppColors.accent, // Highlight this important button
          ),
          ..._buildAppBarActions(),
        ],
        // Use the stylized filter bar
          bottom: _buildFilterBar(ThemeData.dark()),
      ),
      
      // FAB - Styled
      floatingActionButton: FloatingActionButton.extended(
          // MODIFIED: Make the button active as long as not actively loading
          onPressed: _isLoading ? null : () => _showSendPushDialog(), 
        label: const Text('Notifier Zone'),
        icon: const Icon(Icons.campaign_outlined),
        tooltip: 'Envoyer une notification push aux alentours',
          backgroundColor: AppColors.accentSecondary,
          foregroundColor: Colors.white,
          elevation: 6,
      ),
      
      body: Stack(
        children: [
          // Google Map or Error Display
          if (_loadingError == null) 
            GoogleMap(
              initialCameraPosition: _producerLocation != null 
                    ? CameraPosition(target: _producerLocation!, zoom: 15) // Zoom in more
                  : _initialCameraPosition, 
              onMapCreated: _onMapCreated,
              markers: allMarkers, 
                circles: _createHeatmapCircles(),
              myLocationButtonEnabled: false, 
              myLocationEnabled: true, 
              mapType: MapType.normal, 
              buildingsEnabled: true, 
              compassEnabled: false, 
              zoomControlsEnabled: false, 
              trafficEnabled: false,
              onCameraMove: (position) => _clusterManager.onCameraMove(position),
              onCameraIdle: () => _clusterManager.updateMap(),
            )
          else 
            _buildErrorDisplay(),

          // Legend Card
          if (_showLegend && _loadingError == null) 
            _buildLegendCard(),

            // Toggle Insights Button
          if (canShowBottomSheet)
              Positioned(
                bottom: _showInsightsPanel ? null : 20,
                right: 20,
                child: FloatingActionButton.small(
                  heroTag: "toggleInsights",
                  backgroundColor: AppColors.darkCard,
                  elevation: 4,
                  onPressed: () => setState(() => _showInsightsPanel = !_showInsightsPanel),
                  child: Icon(
                    _showInsightsPanel ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: AppColors.accent,
                  ),
                ),
              ),

            // Modified: Bottom Sheet avec option de masquage
            if (canShowBottomSheet && _showInsightsPanel)
            DraggableScrollableSheet(
                initialChildSize: 0.15, // Reduced initial size - more subtle
                minChildSize: 0.12,    // Reduced minimum
                maxChildSize: 0.5,     // Reduced maximum
              expand: false, 
              builder: (context, scrollController) {
                return Container(
                    decoration: const BoxDecoration(
                      color: AppColors.darkSurface, 
                      borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                      boxShadow: [
                      BoxShadow(blurRadius: 15, color: Colors.black38, spreadRadius: 2)
                    ],
                  ),
                  child: ListView(
                    controller: scrollController, 
                    padding: const EdgeInsets.only(top: 10),
                    children: [
                        // Handle
                      Center(
                        child: Container(
                            width: 45, height: 5, 
                          margin: const EdgeInsets.only(bottom: 14), 
                          decoration: BoxDecoration(
                              color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                        // Content sections - Insights minimized
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              // Insights Section - More subtle header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                                      const SizedBox(width: 8),
                                Text('Insights & Opportunités', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500, 
                                          fontSize: 14,
                                          color: Colors.grey[300],
                                        )
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => setState(() => _showInsightsPanel = false),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            SizedBox(
                                height: 120, // Reduced height
                              child: (_isLoadingInsights || _zoneInsights.isEmpty) 
                                ? Center(
                                    child: _isLoadingInsights 
                                      ? const CircularProgressIndicator(strokeWidth: 2) 
                                      : const Text("Aucun insight disponible.", 
                                          style: TextStyle(color: Colors.grey))
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _zoneInsights.length,
                                    itemBuilder: (context, index) => _buildInsightItem(_zoneInsights[index]),
                                  ),
                            ),
                            
                              const SizedBox(height: 16),
                              
                              // Nearby Searches Section - More subtle header
                              Row(
                                children: [
                                  const Icon(Icons.person_search_outlined, size: 16, color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Text('Recherches Proches', 
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500, 
                                      fontSize: 14,
                                      color: Colors.grey[300]
                                    )
                                  )
                                ],
                              ),
                              const SizedBox(height: 10),
                            SizedBox(
                                height: 100, // Reduced height
                              child: (_isFetchingSearches && _nearbySearches.isEmpty) 
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : _nearbySearches.isEmpty
                                  ? const Center(
                                      child: Text("Aucune recherche récente à proximité.", 
                                          style: TextStyle(color: Colors.grey))
                                    )
                                  : ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _nearbySearches.length,
                                      itemBuilder: (context, index) => _buildNearbySearchItem(_nearbySearches[index]),
                                    ),
                            ),
                            
                              const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          
          // Loading Overlay
          if (_isLoading && _loadingError == null)
            _buildLoadingOverlay(),
              
            // Producer highlight animation - fixed implementation that doesn't use screen coordinates
            if (_highlightProducerMarker && _producerLocation != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: SimplePulseEffect(
                      color: AppColors.accent
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Styled Helper Widgets ---

  // Restyled Filter Bar
  PreferredSizeWidget _buildFilterBar(ThemeData theme) {
    final Color dropdownColor = theme.brightness == Brightness.dark 
        ? AppColors.darkSurface
        : Colors.grey[100]!;
    final Color dropdownTextColor = AppColors.textPrimary;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 10), // Add padding
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        color: AppColors.darkSurface, // Match AppBar
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                style: TextStyle(color: dropdownTextColor, fontSize: 12), // Reduced font size
                decoration: InputDecoration(
                  hintText: 'Heure',
                  hintStyle: TextStyle(color: dropdownTextColor.withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25), // More rounded
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: dropdownColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
                  isDense: true,
                  prefixIcon: Icon(Icons.access_time, size: 16, color: dropdownTextColor.withOpacity(0.8)),
                ),
                dropdownColor: dropdownColor, // Match background
                value: _selectedTimeFilter,
                items: _timeFilterOptions.map((value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value == 'Tous' ? 'Toute journée' : value, // Shortened text
                    style: const TextStyle(fontSize: 12), // Explicit font size
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                isExpanded: true, // Fix the overflow
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTimeFilter = value);
                    _applyFilters();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                style: TextStyle(color: dropdownTextColor, fontSize: 12), // Reduced font size
                decoration: InputDecoration(
                  hintText: 'Jour',
                  hintStyle: TextStyle(color: dropdownTextColor.withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25), // More rounded
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: dropdownColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
                  isDense: true,
                  prefixIcon: Icon(Icons.calendar_today, size: 14, color: dropdownTextColor.withOpacity(0.8)),
                ),
                dropdownColor: dropdownColor,
                value: _selectedDayFilter,
                items: _dayFilterOptions.map((value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value == 'Tous' ? 'Tous jours' : value, // Shortened text
                    style: const TextStyle(fontSize: 12), // Explicit font size
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                isExpanded: true, // Fix the overflow
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDayFilter = value);
                    _applyFilters();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED: Improved Notification Dialog with Stepper & Live Offer Focus ---
  void _showSendPushDialog({String? zoneId, ThemeData? theme}) {
    if (!mounted) return;
    final currentTheme = theme ?? Theme.of(context); // Already dark theme applied via Theme widget
    
    // Reset controllers with instant offer defaults
    _customPushTitleController.text = 'Offre Flash ⚡';
    _customPushBodyController.text = 'Venez maintenant et profitez de -15%!';
    _customDiscountController.text = '15';
    _customDurationController.text = '2'; // Default 2 hours

    bool _isTargetingZone = zoneId != null;
    bool _isSending = false; // State for loading indicator
    int _currentPage = 0;

    String _getTargetDescription() {
      if (_isTargetingZone && zoneId != null) {
        final zone = _filteredHotspots.firstWhereOrNull((h) => h.id == zoneId);
        return zone?.zoneName ?? "Zone spécifique";
      } else {
        return "Tous les utilisateurs proches";
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: !_isSending, // Prevent dismissing while sending
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
        return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.all(20),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 10),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: AppColors.accentSecondary, size: 28),
              const SizedBox(width: 12),
                      const Text('Notification Ciblée', 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentPage == 0 ? 'Étape 1: Rédigez votre offre' : 'Étape 2: Choisissez votre cible',
                    style: TextStyle(
                      fontSize: 14, 
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: 400,
                ),
                child: SingleChildScrollView(
                  child: _currentPage == 0 
                      ? _buildPushStep1(setDialogState)
                      : _buildPushStep2(setDialogState, _isTargetingZone, zoneId, _getTargetDescription()),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: _isSending
                ? [const Center(child: CircularProgressIndicator())] // Loading indicator
                : [
                TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                      icon: Icon(_currentPage == 0 ? Icons.arrow_forward_ios_rounded : Icons.send_rounded, size: 16),
                      label: Text(_currentPage == 0 ? 'Suivant' : 'Envoyer Maintenant'),
                  style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage == 0 ? AppColors.accent : AppColors.accentSecondary,
                        foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                  ),
                      onPressed: () async {
                        // Store navigator/messenger states before async gap
                        final NavigatorState navigator = Navigator.of(dialogContext); 
                        final ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(context);

                        if (_currentPage == 0) {
                          setDialogState(() => _currentPage = 1);
                        } else {
                          setDialogState(() => _isSending = true);
                          bool success = false; // Initialize success flag
                          try {
                            success = await _sendPushNotification(
                              zoneId: _isTargetingZone ? zoneId : null,
                              title: _customPushTitleController.text,
                              body: _customPushBodyController.text,
                              discountPercent: int.tryParse(_customDiscountController.text),
                              validityHours: int.tryParse(_customDurationController.text),
                            );
                            
                          } catch (e) {
                             print("Error sending notification: $e");
                             // Set success to false explicitly on catch
                             success = false;
                             if (mounted) {
                               // Show error using stored messenger state
                               scaffoldMessenger.showSnackBar(
                                 SnackBar(content: Text('Erreur inattendue: $e'), backgroundColor: Colors.red),
                               );
                             }
                          } finally {
                             // Always ensure loading state is reset, check mounted
                             if (mounted) {
                               setDialogState(() => _isSending = false);
                             }
                          }

                          // Handle navigation/snackbar after await using stored states, check mounted
                          if (mounted) { 
                            if (success) {
                              navigator.pop(); // Use stored navigator
                              scaffoldMessenger.showSnackBar( // Use stored messenger
                                SnackBar(
                                  content: Row(children: const [Icon(Icons.check_circle_outline, color: Colors.white), SizedBox(width: 8), Text("Notification envoyée avec succès!")]),
                                  backgroundColor: Colors.green[600],
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              // Error snackbar likely already shown in _sendPushNotification or catch block
                            }
                          }
                        }
                      },
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // Helper method for step 1 of the push notification dialog
  Widget _buildPushStep1(StateSetter setState) {
    return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTextField(_customPushTitleController, 'Titre'),
                                  const SizedBox(height: 16),
                                  _buildTextField(_customPushBodyController, 'Message', maxLines: 3),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          _customDiscountController, 
                                          'Réduction (%)', 
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          suffixText: '%'
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildTextField(
                                          _customDurationController, 
                                          'Validité (heures)',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          suffixText: 'h'
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
    );
  }
  
  // Helper method for step 2 of the push notification dialog
  Widget _buildPushStep2(StateSetter setState, bool isTargetingZone, String? zoneId, String targetDescription) {
    return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Envoyer à :',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentSecondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.accentSecondary.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                isTargetingZone ? Icons.location_searching_rounded : Icons.group_rounded,
                                            color: AppColors.accentSecondary,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                      targetDescription,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                      isTargetingZone 
                                                      ? "Utilisateurs dans cette zone"
                                                      : "Tous les utilisateurs actifs (rayon 2km)",
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
        if (!isTargetingZone) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Icon(Icons.people_alt_outlined, size: 16, color: Colors.blue[300]),
                                          const SizedBox(width: 8),
                                          Text('Estimé:', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                                          const Spacer(),
                                          Text(
                                            "${_activeUsers.length}", // Show only current active users
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 18,
                                              color: Colors.blue[300],
                                              shadows: [Shadow(blurRadius: 4, color: Colors.blue.withOpacity(0.3))]
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "utilisateur(s) en ligne",
                                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ],
        const SizedBox(height: 24),
                      // Confirmation Preview Section
        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Aperçu de la notification",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                color: AppColors.accentSecondary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                constraints: BoxConstraints(minHeight: 80),
                                decoration: BoxDecoration(
                color: AppColors.accentSecondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accentSecondary, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                    color: AppColors.accentSecondary.withOpacity(0.25),
                    spreadRadius: 2,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                  backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.local_offer,
                    color: AppColors.accentSecondary,
                                    ),
                                  ),
                                  title: Text(
                                    _customPushTitleController.text.isNotEmpty
                                        ? _customPushTitleController.text
                                        : "Titre de la notification",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: Colors.white,
                    fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _customPushBodyController.text.isNotEmpty
                                        ? _customPushBodyController.text
                                        : "Contenu de la notification",
                                    style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
        ),
      ],
    );
  }

  // --- ADDED: Helper for TextField Styling ---
  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    { int maxLines = 1, 
      TextInputType? keyboardType, 
      List<TextInputFormatter>? inputFormatters, 
      String? suffixText,
      String? Function(String?)? validator // Added validator parameter
    }
  ) {
    // Use TextFormField instead of TextField to enable validation
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.accentSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accentSecondary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.accentSecondary.withOpacity(0.13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: AppColors.accentSecondary)
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 15, color: Colors.black),
      validator: validator, // Pass the validator function to TextFormField
      autovalidateMode: AutovalidateMode.onUserInteraction, // Optional: validate as user types
    );
  }
  
  // --- ADDED: Helper for Notification Preview Card ---
  Widget _buildNotificationPreviewCard({required String title, required String body, String? discount, String? duration}) {
    final bool hasOfferDetails = (discount != null && discount.isNotEmpty) || (duration != null && duration.isNotEmpty);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent, 
                child: Icon(Icons.storefront_outlined, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Mon Établissement",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text("Maintenant",
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(body,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          if (hasOfferDetails) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accentSecondary.withOpacity(0.2), AppColors.accentTertiary.withOpacity(0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentSecondary.withOpacity(0.4))
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (discount != null && discount.isNotEmpty)
                    Row(children: [Icon(Icons.local_offer_outlined, size: 12, color: AppColors.accentSecondary), const SizedBox(width: 4), Text("-$discount%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentSecondary))]),
                  if (discount != null && discount.isNotEmpty && duration != null && duration.isNotEmpty)
                    const Text(" • ", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (duration != null && duration.isNotEmpty)
                    Row(children: [Icon(Icons.timer_outlined, size: 12, color: AppColors.accentTertiary), const SizedBox(width: 4), Text("Valide ${duration}h", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentTertiary))]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // --- ADDED: Actual Notification Sending Logic ---
  Future<bool> _sendPushNotification({
    String? zoneId,
    required String title,
    required String body,
    int? discountPercent,
    int? validityHours,
  }) async {
    print("🚀 Sending push notification...");
    print("   Zone ID: $zoneId");
    print("   Title: $title");
    print("   Body: $body");
    print("   Discount: $discountPercent%");
    print("   Validity: $validityHours hours");

    if (!mounted) return false;
    
    if (title.isEmpty || body.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le titre et le message ne peuvent pas être vides.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    try {
      // Determine the correct endpoint URL
      final url = Uri.parse('${constants.getBaseUrl()}/api/notifications/send-targeted');
      final headers = await ApiConfig.getAuthHeaders();
      
      if (headers == null || headers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur d\'authentification. Veuillez vous reconnecter.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Prepare geographic targeting - handle missing values
      final Map<String, dynamic> geoTarget = zoneId != null 
          ? {'targetZoneId': zoneId}
          : {
              'targetCoordinates': {
                'latitude': _producerLocation?.latitude ?? 0,
                'longitude': _producerLocation?.longitude ?? 0,
                'radiusKm': 2, // Default radius
              }
            };
      
      // Skip sending if no valid geographic targeting
      if (zoneId == null && (_producerLocation?.latitude == null || _producerLocation?.longitude == null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Position du restaurant non disponible. Impossible d\'envoyer la notification.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      final Map<String, dynamic> payload = {
        'producerId': widget.userId,
        'title': title,
        'body': body,
        'data': {
          'screen': 'offerDetails',
          'producerId': widget.userId,
        },
        'offerDetails': {
          if (discountPercent != null && discountPercent > 0) 'discountPercent': discountPercent,
          if (validityHours != null && validityHours > 0) 'validityHours': validityHours,
        },
        ...geoTarget,
      };

      print("   Payload: ${json.encode(payload)}");

      final response = await http.post(
        url,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print("   Response Status: ${response.statusCode}");
      print("   Response Body: ${response.body}");

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        String errorMessage = 'Erreur lors de l\'envoi de la notification.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? 'Erreur ${response.statusCode}';
        } catch (_) {
          errorMessage = 'Erreur ${response.statusCode}: Problème de communication avec le serveur';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange),
          );
        }
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Exception sending push notification: $e');
      print('   StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur réseau ou serveur: ${e.toString().substring(0, math.min(e.toString().length, 100))}'), 
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // --- Extracted Helper Widgets for Build Method --- 

  List<Widget> _buildAppBarActions() {
    return [
      // Scan Offer Button
      IconButton(
        icon: const Icon(Icons.qr_code_scanner_outlined),
        onPressed: _isLoading || _isValidatingOffer || _loadingError != null ? null : _navigateToOfferScanner, 
        tooltip: 'Valider une Offre (QR Code)',
      ),
      // Refresh Button
      IconButton( 
        icon: const Icon(Icons.refresh),
        onPressed: _isLoading || _isFetchingActiveUsers || _isValidatingOffer ? null : _loadData, 
        tooltip: 'Rafraîchir Données' 
      ),
      // Toggle Legend Button
      IconButton( 
        icon: Icon(_showLegend ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _showLegend = !_showLegend), 
        tooltip: 'Afficher/Masquer Légende' 
      ),
    ];
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    
    if (!_mapControllerCompleter.isCompleted) {
       _mapControllerCompleter.complete(controller); // Complete the future
       print("🗺️ Map Controller Completed.");
    } else {
       // Already completed, maybe recreated? Update internal ref if needed.
        print("🗺️ Map Controller Re-assigned.");
    }
     setState(() { _mapController = controller; }); // Keep internal ref if needed elsewhere

    // Always apply dark map style for futuristic appearance
    rootBundle.loadString('assets/map_styles/dark_mode.json').then((mapStyle) {
      if (!mounted) return;
      print("Applying dark map style...");
      controller.setMapStyle(mapStyle).catchError((error) {
          print("Failed to set map style: $error");
      });
    }).catchError((error) {
      print("Failed to load map style: $error");
    });

    _clusterManager.setMapId(controller.mapId);
  }

  Widget _buildErrorDisplay() {
    if (!mounted) return Container();
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.1))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Erreur lors du chargement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(_loadingError ?? 'Une erreur inattendue s\'est produite.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms);
  }

  Widget _buildLegendCard() {
    return Positioned(
      top: 80,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Légende', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              _buildStatRow(Icons.circle, 'Zone Faible Affluence', Colors.blue),
              _buildStatRow(Icons.circle, 'Zone Moyenne Affluence', Colors.green),
              _buildStatRow(Icons.circle, 'Zone Haute Affluence', Colors.red),
              const Divider(),
              _buildStatRow(Icons.person_pin_circle, 'Utilisateur Actif', Colors.blue[700]!),
              _buildStatRow(Icons.group, 'Groupe d\'éléments', Colors.deepPurple),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 300.ms).slideX(begin: 0.2);
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Card(
          elevation: 8,
          color: AppColors.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppColors.accent.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Chargement des données...',
                  style: TextStyle(
                    fontWeight: FontWeight.w500, 
                    fontSize: 16,
                    letterSpacing: 0.5,
                  )
                ),
                const SizedBox(height: 8),
                Text(
                  'Veuillez patienter',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    letterSpacing: 0.3,
                  )
                ),
              ],
            ),
          ),
        ).animate().fade(duration: 300.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
        ),
      ),
    ).animate().fade(duration: 300.ms);
  }

  // Add missing method for nearby search polling
  void _startNearbySearchPolling() {
    print("ℹ️ Starting nearby searches polling...");
    _fetchNearbySearches(); // Fetch immediately
    _nearbySearchPollTimer?.cancel();
    _nearbySearchPollTimer = Timer.periodic(_nearbySearchPollInterval, (_) {
      if (!mounted) { _nearbySearchPollTimer?.cancel(); return; } // Stop if widget disposed
      if (!_isFetchingSearches) { _fetchNearbySearches(); }
    });
  }

  // Add fetch nearby searches implementation
  Future<void> _fetchNearbySearches() async {
    if (!mounted || _isFetchingSearches) return;
    print("📡 Fetching nearby searches...");
    setState(() { _isFetchingSearches = true; });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/heatmap/nearby-searches/${widget.userId}');
       final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(url, headers: headers);

      if (!mounted) return; 

       if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("🔍 Found ${data.length} nearby searches raw.");
        
        // Filter out invalid events during mapping
        final List<NearbySearchEvent> fetchedSearches = data
            .map((item) {
              try {
                return NearbySearchEvent.fromJson(item);
              } catch (e) {
                print("Failed to parse NearbySearchEvent: $e, Item: $item");
                return null; // Return null if parsing fails
              }
            })
            .whereType<NearbySearchEvent>() // Keep only non-null results
            // Optional: Further filter based on content if needed
            .where((event) => !event.userId.startsWith('invalid_'))
            .toList();
        
        print(" Parsed ${fetchedSearches.length} valid nearby searches.");
        setState(() { _nearbySearches = fetchedSearches; });
      } else {
        print('❌ Error fetching nearby searches: ${response.statusCode} ${response.body}');
        // Set searches to empty on error to clear potentially stale data
        if (mounted) setState(() => _nearbySearches = []);
      }
    } catch(e) {
      print('❌ Exception fetching nearby searches: $e');
       if (mounted) setState(() => _nearbySearches = []); // Clear on exception
    } finally {
      if (mounted) { setState(() { _isFetchingSearches = false; }); }
    }
}

  // Add method for fetching user profile info
  Future<void> _fetchPublicUserInfo(String userId) async {
    if (!mounted || _isFetchingProfile) return;
    print("👤 Fetching public user profile for $userId...");
    setState(() { _isFetchingProfile = true; });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/users/$userId/public-profile');
      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(url, headers: headers);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _fetchedUserProfile = PublicUserProfile.fromJson(data);
          _isFetchingProfile = false;
        });
        _showUserProfileDialog(_fetchedUserProfile!);
      } else {
        print('❌ Error fetching user profile: ${response.statusCode} ${response.body}');
        setState(() { _isFetchingProfile = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur indisponible.'), backgroundColor: Colors.orange)
        );
      }
    } catch(e) {
      print('❌ Exception fetching user profile: $e');
      if (mounted) {
        setState(() { _isFetchingProfile = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la récupération du profil.'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // Show user profile dialog
  void _showUserProfileDialog(PublicUserProfile profile) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: profile.profilePicture != null 
                  ? CachedNetworkImageProvider(profile.profilePicture!)
                  : null,
              child: profile.profilePicture == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(profile.name, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              const Text('Bio:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(profile.bio!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],
            const Text('Centres d\'intérêt:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 6,
              children: profile.likedTags.isEmpty
                  ? [const Chip(label: Text('Aucun'))]
                  : profile.likedTags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSendOfferDialog(profile);
            },
            child: const Text('Envoyer une offre'),
          ),
        ],
      ),
    );
  }

  // Show QR code after sending offer
  void _showOfferQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offre Créée avec Succès'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Votre code QR pour cette offre:'),
            const SizedBox(height: 20),
            QrImageView(
              data: 'OFFER:${widget.userId}:${DateTime.now().millisecondsSinceEpoch}',
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            const SizedBox(height: 10),
            const Text('Présentez ce code à votre client pour validation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  // Helper widget for Zone Stats in the bottom sheet
  Widget _buildZoneStatItem(models.UserHotspot hotspot) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: InkWell(
          onTap: () => _selectZone(hotspot.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotspot.zoneName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(),
                Text("${hotspot.visitorCount} visiteurs",
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: hotspot.intensity,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getColorForIntensity(hotspot.intensity)
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for Insights in the bottom sheet
  Widget _buildInsightItem(Map<String, dynamic> insight) {
    final String title = insight['title'] as String? ?? 'Insight';
    final List<String> insights = insight['insights'] as List<String>? ?? [];
    final Color color = insight['color'] as Color? ?? AppColors.accent;
    final IconData icon = insight['icon'] as IconData? ?? Icons.lightbulb_outline;
    
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const Divider(height: 12),
              Expanded(
                child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: insights.length.clamp(0, 3), // Limit to 3 insights
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            insights[index],
                            style: TextStyle(fontSize: 11, color: Colors.grey[300]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                ),
              ),
            ],
        ),
      ),
    );
  }

  // Helper widget to build an entry in the nearby searches section
  Widget _buildNearbySearchItem(NearbySearchEvent search) {
    // Format the time using timeago
    final String timeAgo = timeago.format(search.timestamp, locale: 'fr');
    
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
          child: Padding(
        padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.accent.withOpacity(0.2),
                      backgroundImage: search.userProfilePicture != null 
                          ? CachedNetworkImageProvider(search.userProfilePicture!) 
                          : null,
                      child: search.userProfilePicture == null 
                      ? const Icon(Icons.person, size: 12, color: AppColors.accent)
                          : null,
                    ),
                const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        search.userName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                  '"${search.query}"',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[300],
                    fontStyle: FontStyle.italic,
                  ),
                maxLines: 1,
                  overflow: TextOverflow.ellipsis,
              ),
                ),
                const Spacer(),
                Text(
              timeAgo,
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // +++ ADDED: Method to center on producer +++
  Future<void> _centerOnProducerLocation() async {
    if (_producerLocation == null) {
         ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Localisation de votre établissement non disponible.'), 
        backgroundColor: Colors.orange)
      );
      return;
    }
    
    if (_mapController != null) {
      // Animate to location with high zoom level
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_producerLocation!, 16.0)
      );
      
      // Temporarily highlight the marker
      setState(() { _highlightProducerMarker = true; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _highlightProducerMarker = false; });
      });
    }
  }

  // --- ADDED: Producer marker highlight state ---
  bool _highlightProducerMarker = false;



  Future<bool> _sendTargetedOffer({
    required String targetUserId,
    required String title,
    required String body,
    int? discountPercent,
    int? validityDays,
    String? originalSearchQuery,
    String? triggeringSearchId,
  }) async {
    if (!mounted) return false;
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/offers/send-targeted');
      final headers = await ApiConfig.getAuthHeaders();
      
      final Map<String, dynamic> payload = {
        'producerId': widget.userId,
        'targetUserId': targetUserId,
        'title': title,
        'body': body,
        'discountPercent': discountPercent,
        'validityDays': validityDays,
      };
      
      // Add optional search context if available
      if (originalSearchQuery != null) {
        payload['originalSearchQuery'] = originalSearchQuery;
      }
      if (triggeringSearchId != null) {
        payload['triggeringSearchId'] = triggeringSearchId;
      }
      
      final response = await http.post(
        url,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      
      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offre envoyée avec succès!'), backgroundColor: Colors.green)
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi: ${response.statusCode}'), backgroundColor: Colors.orange)
        );
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exception: $e'), backgroundColor: Colors.red)
        );
      }
      return false;
    }
  }
  
  // Add missing method definition (assuming it exists elsewhere, ensure it's present)
  void _navigateToOfferScanner() async {
    if (!mounted) return;
    
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const OfferScannerScreen()),
    );
    
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      _validateScannedOffer(scannedCode);
    }
  }

  // Add the missing _validateScannedOffer method
  void _validateScannedOffer(String scannedCode) async {
    if (!mounted) return;
    
    try {
      // Decode the scanned QR code
      final data = json.decode(scannedCode);
      
      if (data == null || !data.containsKey('offerId') || !data.containsKey('userId')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code invalide ou mal formaté'), backgroundColor: Colors.red)
        );
        return;
      }
      
      final offerId = data['offerId'];
      final userId = data['userId'];
      
      // Call API to validate offer
      final url = Uri.parse('${constants.getBaseUrl()}/api/offers/validate');
      final headers = await ApiConfig.getAuthHeaders();
      
      final response = await http.post(
        url,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({
          'offerId': offerId,
          'userId': userId,
          'producerId': widget.userId,
        }),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offre validée avec succès!'), backgroundColor: Colors.green)
        );
      } else {
        // Show error message
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Erreur lors de la validation de l\'offre';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // +++ ADDED: Function to show the dialog for sending a targeted offer +++
  void _showSendOfferDialog(dynamic user) {
    if (!mounted) return;
    final currentTheme = Theme.of(context); // Use Theme.of(context) to get the correct theme

    String userId = '';
    String userName = '';
    String? userProfilePic;

    // Extract user details based on the type passed (PublicUserProfile or NearbySearchEvent)
    if (user is PublicUserProfile) {
      userId = user.id;
      userName = user.name;
      userProfilePic = user.profilePicture;
    } else if (user is NearbySearchEvent) {
      userId = user.userId;
      userName = user.userName;
      userProfilePic = user.userProfilePicture;
    } else {
      print("❌ _showSendOfferDialog: Invalid user type provided.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type d\'utilisateur invalide pour envoyer une offre.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Pre-fill controllers (can customize)
    _offerTitleController.text = 'Offre Spéciale pour vous!';
    _offerBodyController.text = 'Profitez de -10% sur votre prochaine visite.';
    _offerDiscountController.text = '10';
    _offerValidityController.text = '7'; // Validity in days for targeted offers
    _isSendingOffer = false; // Reset sending state

    showDialog(
      context: context,
      barrierDismissible: !_isSendingOffer, // Prevent dismissing while sending
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 8),
              title: Row(
                 children: [
                    Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 28),
                    const SizedBox(width: 12),
                    const Text('Envoyer une Offre Directe', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                    ),
                 ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: userProfilePic != null ? CachedNetworkImageProvider(userProfilePic) : null,
                            child: userProfilePic == null ? const Icon(Icons.person, size: 16) : null,
                          ),
                          const SizedBox(width: 8),
                          Text('Pour: $userName', 
                               style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary, fontSize: 14)
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildTextField(_offerTitleController, 'Titre de l\'offre', 
                        validator: (v) => v == null || v.isEmpty ? 'Titre requis' : null
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_offerBodyController, 'Description de l\'offre', 
                        maxLines: 3, 
                        validator: (v) => v == null || v.isEmpty ? 'Description requise' : null
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _offerDiscountController, 
                              'Réduction (%)', 
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              suffixText: '%',
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Invalide';
                                return null;
                              }
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              _offerValidityController, 
                              'Validité (jours)', // Use days for targeted
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              suffixText: 'jours',
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Invalide';
                                return null;
                              }
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: _isSendingOffer
                ? [const Center(child: CircularProgressIndicator())]
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Envoyer l\'Offre'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                      ),
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          setDialogState(() => _isSendingOffer = true);
                          
                          // Determine optional context fields based on user type
                          String? originalSearchQuery;
                          String? triggeringSearchId;
                          if (user is NearbySearchEvent) {
                            originalSearchQuery = user.query;
                            triggeringSearchId = user.searchId;
                          }
                          
                          final success = await _sendTargetedOffer(
                            targetUserId: userId,
                            title: _offerTitleController.text,
                            body: _offerBodyController.text,
                            discountPercent: int.tryParse(_offerDiscountController.text),
                            validityDays: int.tryParse(_offerValidityController.text), // Use days here
                            originalSearchQuery: originalSearchQuery,
                            triggeringSearchId: triggeringSearchId,
                          );
                          
                          if (!mounted) return; // Check mounted state after async call
                          setDialogState(() => _isSendingOffer = false);
                          
                          if (success) {
                            Navigator.pop(dialogContext);
                            _showOfferQRCode(); // Show QR code on success
                          } // Error message handled within _sendTargetedOffer
                        }
                      },
                    ),
                  ],
            );
          },
        );
      },
    );
  }
}  // End of _HeatmapScreenState class

// --- ADDED: Location pulse effect that doesn't require screen coordinates ---
class SimplePulseEffect extends CustomPainter {
  final Color color;
  final double maxRadius;
  final int numCircles;
  final double animationValue; // Value between 0.0 and 1.0
  
  SimplePulseEffect({
    required this.color,
    this.maxRadius = 80.0,
    this.numCircles = 3,
    this.animationValue = 0.5, // Static animation value
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw pulse effect at the center of the screen
    final Offset center = Offset(size.width / 2, size.height / 2);
    
    final Paint paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    // Draw circles with decreasing opacity
    for (int i = 0; i < numCircles; i++) {
      // Opacity decreases from outer to inner circles
      final opacity = 0.8 - (i * 0.2);
      // Make the radius vary with the index
      final radiusScale = 0.4 + (i * 0.3);
      final radius = maxRadius * radiusScale;
      
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(SimplePulseEffect oldDelegate) => true;
}

