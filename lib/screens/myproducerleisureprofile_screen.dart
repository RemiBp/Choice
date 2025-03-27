import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'eventLeisure_screen.dart';
import 'utils.dart';
import '../services/payment_service.dart';
import '../utils/leisureHelpers.dart';  // Add this import for getEventImageUrl
import 'login_user.dart';  // Import for LoginUserPage
import 'subscription_screen.dart'; // Import for SubscriptionScreen

class MyProducerLeisureProfileScreen extends StatefulWidget {
  final String userId;

  const MyProducerLeisureProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyProducerLeisureProfileScreen> createState() => _MyProducerLeisureProfileScreenState();
}

class _MyProducerLeisureProfileScreenState extends State<MyProducerLeisureProfileScreen> with TickerProviderStateMixin {
  late Future<Map<String, dynamic>> _producerFuture;
  late TabController _tabController;
  final List<String> _tabs = ['Mon profil', 'Mes événements', 'Statistiques'];
  bool _isLoading = false;
  Map<String, dynamic>? _producerData;
  
  // Pour la création/édition d'événements
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventDescriptionController = TextEditingController();
  final TextEditingController _eventCategoryController = TextEditingController();
  String? _eventImageUrl;
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;
  
  // Animation properties
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Discount related properties
  bool _hasActiveDiscount = false;
  double _discountPercentage = 10.0; // Default discount percentage
  DateTime? _discountEndDate;
  
  // Dans la classe _MyProducerLeisureProfileScreenState, ajouter une section pour Stripe
  // Variables pour les abonnements
  bool _isProcessing = false;
  String _selectedPlan = 'gratuit';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Filtres pour les menus
  Map<String, bool> _menuFilters = {
    'Enfant': false,
    'Végétarien': false,
    'Sans Gluten': false,
    'Bien-être': false,
    'Spécial': false,
  };
  
  // Pour la gestion des campagnes marketing
  bool _hasActiveCampaign = false;
  String _campaignType = '';
  int _campaignReach = 0;
  DateTime? _campaignEndDate;
  
  @override
  void initState() {
    super.initState();
    _producerFuture = _fetchProducerData(widget.userId);
    _tabController = TabController(length: _tabs.length, vsync: this);
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventTitleController.dispose();
    _eventDescriptionController.dispose();
    _eventCategoryController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchProducerData(String userId) async {
    try {
      final baseUrl = getBaseUrl();
      final client = http.Client();
      final endpoints = [
        // Try all possible API endpoints to find the producer
        '/api/producers/$userId',
        '/api/leisureProducers/$userId',
        '/api/Loisir_Paris_Producers/$userId',    // Direct collection access
        '/api/unified/$userId',                   // Unified endpoint if exists
        '/api/venues/$userId',                    // Alternative naming
        // Try standard database endpoints that might be used
        '/api/Loisir&Culture/Loisir_Paris_Producers/$userId'
      ];
      
      print('🔍 Trying to fetch producer data for ID: $userId');
      Map<String, dynamic>? producerData;
      
      // Try each endpoint until we find one that works
      for (final endpoint in endpoints) {
        print('🔍 Trying endpoint: $endpoint');
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, endpoint);
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, endpoint);
        }
        
        try {
          final response = await client.get(url);
          if (response.statusCode == 200) {
            producerData = json.decode(response.body);
            print('✅ Found producer data at endpoint: $endpoint');
            break;
          } else {
            print('❌ Endpoint failed: $endpoint with status: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error accessing endpoint $endpoint: $e');
        }
      }
      
      // If we haven't found producer data, try the unified search endpoint
      if (producerData == null) {
        print('🔍 Trying unified search endpoint');
        final unifiedEndpoint = '/api/search/producers';
        final queryParams = {'id': userId, 'type': 'leisure'};
        
        Uri searchUrl;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          searchUrl = Uri.http(domain, unifiedEndpoint, queryParams);
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          searchUrl = Uri.https(domain, unifiedEndpoint, queryParams);
        }
        
        try {
          final response = await client.get(searchUrl);
          if (response.statusCode == 200) {
            final searchResults = json.decode(response.body);
            if (searchResults is List && searchResults.isNotEmpty) {
              producerData = searchResults[0];
              print('✅ Found producer data via unified search');
            }
          }
        } catch (e) {
          print('❌ Error accessing unified search endpoint: $e');
        }
      }
      
      if (producerData != null) {
        // Successfully found producer data, now try to get relations
        final relationEndpoints = [
          '/api/producers/$userId/relations',
          '/api/leisureProducers/$userId/relations',
          '/api/venues/$userId/relations',
          '/api/unified/$userId/relations'
        ];
        
        // Try each relations endpoint
        for (final endpoint in relationEndpoints) {
          Uri relationsUrl;
          if (baseUrl.startsWith('http://')) {
            final domain = baseUrl.replaceFirst('http://', '');
            relationsUrl = Uri.http(domain, endpoint);
          } else {
            final domain = baseUrl.replaceFirst('https://', '');
            relationsUrl = Uri.https(domain, endpoint);
          }
          
          try {
            final relationsResponse = await client.get(relationsUrl);
            if (relationsResponse.statusCode == 200) {
              final relationsData = json.decode(relationsResponse.body);
              producerData.addAll(relationsData);
              print('✅ Added relations data from: $endpoint');
              break;
            }
          } catch (e) {
            print('❌ Error fetching relations from $endpoint: $e');
          }
        }
        
        // Try to fetch additional producer details if needed fields are missing
        if (!producerData.containsKey('evenements') || 
            !producerData.containsKey('nombre_evenements')) {
          print('🔍 Fetching additional events data');
          final eventsEndpoint = '/api/producers/$userId/events';
          
          Uri eventsUrl;
          if (baseUrl.startsWith('http://')) {
            final domain = baseUrl.replaceFirst('http://', '');
            eventsUrl = Uri.http(domain, eventsEndpoint);
          } else {
            final domain = baseUrl.replaceFirst('https://', '');
            eventsUrl = Uri.https(domain, eventsEndpoint);
          }
          
          try {
            final eventsResponse = await client.get(eventsUrl);
            if (eventsResponse.statusCode == 200) {
              final eventsData = json.decode(eventsResponse.body);
              if (eventsData is List) {
                producerData['evenements'] = eventsData;
                producerData['nombre_evenements'] = eventsData.length;
                print('✅ Added events data to producer');
              }
            }
          } catch (e) {
            print('❌ Error fetching events: $e');
          }
        }
        
        // Normalize the data structure to ensure all required fields exist
        _normalizeProducerData(producerData);
        
        // Save producer data for use in events
        _producerData = producerData;
        
        return producerData;
      } else {
        print('❌ Failed to find producer data for ID: $userId');
        // Instead of throwing exception, provide default data
        final defaultData = {
          'lieu': 'Mon lieu de loisir',
          'name': 'Mon lieu de loisir',
          'photo': 'https://via.placeholder.com/400?text=Photo+Indisponible',
          'description': 'Description temporaire - données du producteur non trouvées',
          'type': 'Loisir',
          'adresse': 'Adresse non disponible',
          'evenements': [],
          'posts': [],
          'followers': {'count': 0, 'users': []},
          'following': {'count': 0, 'users': []},
          'interestedUsers': {'count': 0, 'users': []},
          'choiceUsers': {'count': 0, 'users': []},
          '_id': userId
        };
        
        print('⚠️ Using default data for producer ID: $userId');
        _producerData = defaultData;
        return defaultData;
      }
    } catch (e) {
      print('❌ Network error: $e');
      // Create default data on error
      final defaultData = {
        'lieu': 'Mon lieu de loisir',
        'name': 'Mon lieu de loisir',
        'photo': 'https://via.placeholder.com/400?text=Erreur+Réseau',
        'description': 'Erreur réseau: $e',
        'type': 'Loisir',
        'adresse': 'Adresse non disponible',
        'evenements': [],
        'posts': [],
        '_id': userId
      };
      
      print('⚠️ Using default data after network error');
      _producerData = defaultData;
      return defaultData;
    }
  }
  
  /// Ensures the producer data has all required fields in standard format
  void _normalizeProducerData(Map<String, dynamic> data) {
    // Ensure standard profile fields exist
    if (!data.containsKey('photo') && data.containsKey('image')) {
      data['photo'] = data['image'];
    }
    
    if (!data.containsKey('lieu') && data.containsKey('name')) {
      data['lieu'] = data['name'];
    }
    
    if (!data.containsKey('description') || data['description'] == null) {
      data['description'] = 'Description non disponible';
    }
    
    if (!data.containsKey('type') && data.containsKey('category')) {
      final category = data['category'];
      if (category is List && category.isNotEmpty) {
        data['type'] = category[0];
      } else if (category is String) {
        data['type'] = category;
      } else {
        data['type'] = 'Loisir';
      }
    }
    
    // Make sure venue has a location
    if (!data.containsKey('location') && data.containsKey('gps_coordinates')) {
      if (data['gps_coordinates'] is Map) {
        final coords = data['gps_coordinates'];
        data['location'] = {
          'type': 'Point',
          'coordinates': [
            coords['lng'] ?? coords['longitude'] ?? 2.3522,
            coords['lat'] ?? coords['latitude'] ?? 48.8566
          ]
        };
      }
    }
    
    // Make sure evenements is initialized
    if (!data.containsKey('evenements')) {
      data['evenements'] = [];
    }
    
    // Make sure posts is initialized
    if (!data.containsKey('posts')) {
      data['posts'] = [];
    }
  }

  Future<List<dynamic>> _fetchProducerEvents(String userId) async {
    try {
      print('🔍 Fetching events for producer ID: $userId');
      
      // Try multiple approaches to get events
      List<dynamic> allEvents = [];
      bool anySuccess = false;
      final baseUrl = getBaseUrl();
      
      // Method 1: Try the dedicated producer events endpoint
      try {
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/producers/$userId/events');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/producers/$userId/events');
        }
        
        print('🔍 Trying producer events API: $url');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Found ${data.length} events via producer events API');
          allEvents.addAll(data);
          anySuccess = true;
        } else {
          print('❌ Producer events API failed: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with producer events API: $e');
      }
      
      // Method 2: Try to get events from the producer object itself
      try {
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/producers/$userId');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/producers/$userId');
        }
        
        print('🔍 Trying producer API for embedded events: $url');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final producerData = json.decode(response.body);
          
          // Check if producer has embedded events
          if (producerData['evenements'] is List && (producerData['evenements'] as List).isNotEmpty) {
            final embeddedEvents = producerData['evenements'] as List;
            print('✅ Found ${embeddedEvents.length} embedded events in producer');
            
            final List<dynamic> fullEvents = [];
            
            // For each embedded event, check if it has full data or just a reference
            for (final event in embeddedEvents) {
              if (event is Map && event.containsKey('_id') && event.containsKey('intitulé')) {
                // This is likely a full event object, so add it
                fullEvents.add(event);
              } else if (event is Map && event.containsKey('lien_evenement')) {
                // This is a reference, try to fetch the full event
                final String eventPath = event['lien_evenement'];
                final String eventId = eventPath.split('/').last;
                
                try {
                  Uri eventUrl;
                  if (baseUrl.startsWith('http://')) {
                    final domain = baseUrl.replaceFirst('http://', '');
                    eventUrl = Uri.http(domain, '/api/events/$eventId');
                  } else {
                    final domain = baseUrl.replaceFirst('https://', '');
                    eventUrl = Uri.https(domain, '/api/events/$eventId');
                  }
                  
                  final eventResponse = await http.get(eventUrl);
                  if (eventResponse.statusCode == 200) {
                    final eventData = json.decode(eventResponse.body);
                    fullEvents.add(eventData);
                  }
                } catch (e) {
                  print('❌ Error fetching referenced event: $e');
                }
              }
            }
            
            allEvents.addAll(fullEvents);
            anySuccess = true;
          }
        } else {
          print('❌ Producer API failed: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with producer API: $e');
      }
      
      // Method 3: Try the general events endpoint with filtering
      try {
        final queryParams = {
          'producerId': userId,
          'venueId': userId,
        };
        
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/events', queryParams);
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/events', queryParams);
        }
        
        print('🔍 Trying general events API with filtering: $url');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Found ${data.length} events via general events API');
          allEvents.addAll(data);
          anySuccess = true;
        } else {
          print('❌ General events API failed: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with general events API: $e');
      }
      
      // Now we have all events, deduplicate them
      final Map<String, dynamic> uniqueEvents = {};
      for (final event in allEvents) {
        final String eventId = event['_id']?.toString() ?? '';
        if (eventId.isNotEmpty) {
          uniqueEvents[eventId] = event;
        }
      }
      
      // Convert to list and enhance with venue information
      final List<dynamic> finalEvents = uniqueEvents.values.map((event) {
        // Make sure each event has a reference to its venue
        if (event['producer_id'] == null && event['venue_id'] == null) {
          event['producer_id'] = userId;
        }
        
        // Add venue information for better frontend display
        if (event['producer_photo'] == null && event['venue_photo'] == null && _producerData != null) {
          event['producer_photo'] = _producerData!['photo'] ?? '';
        }
        
        return event;
      }).toList();
      
      // Sort events by date
      finalEvents.sort((a, b) {
        // Define a priority based on event date (upcoming events first)
        bool aIsPast = isEventPassed(a);
        bool bIsPast = isEventPassed(b);
        
        // First sort by past/upcoming
        if (aIsPast != bIsPast) {
          return aIsPast ? 1 : -1;
        }
        
        // Then by date (closest first for upcoming, most recent first for past)
        final String aDateStr = a['date_debut'] ?? a['prochaines_dates'] ?? '';
        final String bDateStr = b['date_debut'] ?? b['prochaines_dates'] ?? '';
        
        if (aDateStr.isEmpty || bDateStr.isEmpty) {
          return 0;
        }
        
        try {
          final DateTime aDate = _parseEventDate(aDateStr);
          final DateTime bDate = _parseEventDate(bDateStr);
          
          if (aIsPast) {
            // Most recent first for past events
            return bDate.compareTo(aDate);
          } else {
            // Closest first for upcoming events
            return aDate.compareTo(bDate);
          }
        } catch (e) {
          return 0;
        }
      });
      
      print('✅ Final event count: ${finalEvents.length}');
      
      if (finalEvents.isNotEmpty || anySuccess) {
        return finalEvents;
      }
      
      // If we get here, no events were found using any method
      return [];
    } catch (e) {
      print('❌ Error in event fetching process: $e');
      return [];
    }
  }

  Future<List<dynamic>> _fetchProducerPosts(String userId) async {
    final baseUrl = getBaseUrl();
    final List<dynamic> allPosts = [];
    bool anySuccess = false;
    
    try {
      print('🔍 Fetching posts for producer ID: $userId');
      
      // Method 1: Try direct query with parameters - most modern API approach
      try {
        final queryParams = {
          'limit': '50',
          'producerId': userId,
          'venueOnly': 'true',
          'venue_id': userId,  // Additional parameter to ensure venue filtering
        };
        
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/posts', queryParams);
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/posts', queryParams);
        }
        
        print('🔍 Trying direct posts API: $url');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Found ${data.length} posts via direct API');
          
          // Add these posts to our collection
          allPosts.addAll(data);
          anySuccess = true;
        } else {
          print('❌ Direct API failed: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with direct posts API: $e');
      }
      
      // Method 2: Try to fetch from choice_app.Posts collection
      try {
        final queryParams = {
          'producer_id': userId,
          'collection': 'Posts',
          'venue_id': userId,  // Additional parameter
        };
        
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/db/query', queryParams);
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/db/query', queryParams);
        }
        
        print('🔍 Trying DB query API: $url');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Found ${data.length} posts via DB query');
          
          // Add these posts to our collection
          allPosts.addAll(data);
          anySuccess = true;
        } else {
          print('❌ DB query failed: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with DB query: $e');
      }
      
      // Method 3: Classic method - check if the producer has post IDs and fetch them
      try {
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/producers/$userId');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/producers/$userId');
        }
        
        print('🔍 Trying producer API for post IDs: $url');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final producerData = json.decode(response.body);
          final postIds = producerData['posts'] as List<dynamic>? ?? [];
          
          print('✅ Found ${postIds.length} post IDs in producer');
          
          // Fetch each post by ID
          for (final postId in postIds) {
            final String postIdStr = postId.toString();
            Uri postUrl;
            if (baseUrl.startsWith('http://')) {
              final domain = baseUrl.replaceFirst('http://', '');
              postUrl = Uri.http(domain, '/api/posts/$postIdStr');
            } else {
              final domain = baseUrl.replaceFirst('https://', '');
              postUrl = Uri.https(domain, '/api/posts/$postIdStr');
            }
            
            try {
              final postResponse = await http.get(postUrl);
              if (postResponse.statusCode == 200) {
                final postData = json.decode(postResponse.body);
                allPosts.add(postData);
                anySuccess = true;
              }
            } catch (e) {
              print('❌ Error fetching post $postIdStr: $e');
            }
          }
        } else {
          print('❌ Producer API failed: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with producer API: $e');
      }
      
      // Now we have all posts, remove duplicates (if any)
      final Map<String, dynamic> uniquePosts = {};
      for (final post in allPosts) {
        final String postId = post['_id']?.toString() ?? '';
        if (postId.isNotEmpty) {
          uniquePosts[postId] = post;
        }
      }
      
      // Final filtering to ensure we only have posts for this producer
      final List<dynamic> filteredPosts = uniquePosts.values.where((post) {
        final String producerId = post['producer_id']?.toString() ?? '';
        final String venueId = post['venue_id']?.toString() ?? '';
        final bool isForThisProducer = producerId == userId || venueId == userId;
        final bool isReferencedByThisProducer = 
          post['isProducerPost'] == true && 
          (post['referenced_producer_id']?.toString() == userId || 
           post['referenced_venue_id']?.toString() == userId);
        
        return isForThisProducer || isReferencedByThisProducer;
      }).toList();
      
      // Sort posts by timestamp (newest first)
      filteredPosts.sort((a, b) {
        final DateTime aTime = _parsePostTimestamp(a['time_posted'] ?? a['posted_at'] ?? a['created_at'] ?? '');
        final DateTime bTime = _parsePostTimestamp(b['time_posted'] ?? b['posted_at'] ?? b['created_at'] ?? '');
        return bTime.compareTo(aTime);
      });
      
      print('✅ Final filtered posts count: ${filteredPosts.length}');
      
      if (filteredPosts.isNotEmpty || anySuccess) {
        return filteredPosts;
      }
      
      // As a last resort, try a more general approach
      return await _fetchGeneralPosts(userId);
    } catch (e) {
      print('❌ Error in post fetching process: $e');
      
      // Try the general approach as a last resort
      return await _fetchGeneralPosts(userId);
    }
  }
  
  DateTime _parsePostTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime(2000);
    
    try {
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      print('❌ Error parsing timestamp: $e');
    }
    
    return DateTime(2000);
  }
  
  Future<List<dynamic>> _fetchGeneralPosts(String userId) async {
    print('🔍 Trying general post fetch as fallback');
    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/posts');
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/posts');
      }
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> allPosts = json.decode(response.body);
        
        // Filter to only include posts related to this producer
        final filteredPosts = allPosts.where((post) {
          final String producerId = post['producer_id']?.toString() ?? '';
          final String venueId = post['venue_id']?.toString() ?? '';
          return producerId == userId || venueId == userId;
        }).toList();
        
        print('✅ Found ${filteredPosts.length} posts via general API');
        return filteredPosts;
      }
    } catch (e) {
      print('❌ Error in general post fetch: $e');
    }
    
    return [];
  }

  // Helper method for menu items
  Widget _buildMenuOption(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.deepPurple),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  DateTime _parseEventDate(String dateStr) {
    try {
      // Try common date formats
      if (dateStr.contains('/')) {
        // DD/MM/YYYY format
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } else if (dateStr.contains('-')) {
        // YYYY-MM-DD format
        return DateTime.parse(dateStr);
      }
      
      // If we can't parse, return a far future date
      return DateTime(2099);
    } catch (e) {
      // If there's an error, return a far future date
      return DateTime(2099);
    }
  }

  Future<void> _createPost(String content, String? eventId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final postData = {
        'producer_id': widget.userId,
        'venue_id': widget.userId,  // Add venue_id for proper filtering
        'content': content,
        'target_id': eventId,
        'target_type': 'event',
        'media': _eventImageUrl != null ? [_eventImageUrl] : [],
      };

      final url = Uri.parse('${getBaseUrl()}/api/posts');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post créé avec succès!')),
        );
        setState(() {
          _producerFuture = _fetchProducerData(widget.userId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadMedia(bool isImage) async {
    final ImagePicker picker = ImagePicker();
    final XFile? mediaFile = await (isImage
        ? picker.pickImage(source: ImageSource.gallery)
        : picker.pickVideo(source: ImageSource.gallery));

    if (mediaFile != null) {
      String mediaPath;
      if (kIsWeb) {
        Uint8List bytes = await mediaFile.readAsBytes();
        mediaPath = "data:image/jpeg;base64,${base64Encode(bytes)}";
      } else {
        mediaPath = mediaFile.path;
      }

      setState(() {
        _eventImageUrl = mediaPath;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _validateProfiles(List<String> ids) async {
    List<Map<String, dynamic>> validProfiles = [];

    for (final id in ids) {
      final profile = await _fetchProfileById(id);
      if (profile != null) {
        validProfiles.add(profile);
      }
    }

    return validProfiles;
  }

  Future<Map<String, dynamic>?> _fetchProfileById(String id) async {
    final userUrl = Uri.parse('${getBaseUrl()}/api/users/$id');
    final unifiedUrl = Uri.parse('${getBaseUrl()}/api/unified/$id');

    try {
      final userResponse = await http.get(userUrl);
      if (userResponse.statusCode == 200) {
        return json.decode(userResponse.body);
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }

    try {
      final unifiedResponse = await http.get(unifiedUrl);
      if (unifiedResponse.statusCode == 200) {
        return json.decode(unifiedResponse.body);
      }
    } catch (e) {
      print('Error fetching unified profile: $e');
    }

    return null;
  }


  // Discount related properties and methods  
  Future<void> _setDiscount(double percentage, DateTime endDate) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final baseUrl = getBaseUrl();
      final url = Uri.parse('${baseUrl}/api/producers/${widget.userId}/update-items');
      
      // Get the current structured data first to modify it
      final currentData = _producerData?['structured_data'] ?? {};
      
      // Add discount information to all items
      if (currentData.containsKey('Items Indépendants')) {
        for (var category in currentData['Items Indépendants']) {
          if (category['items'] != null) {
            for (var item in category['items']) {
              item['discount'] = {
                'percentage': percentage,
                'end_date': endDate.toIso8601String(),
              };
            }
          }
        }
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'structured_data': currentData,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _hasActiveDiscount = true;
          _discountPercentage = percentage;
          _discountEndDate = endDate;
          _producerData?['structured_data'] = currentData;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réduction appliquée avec succès! Les modifications seront vérifiées sous 24h.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSetDiscountDialog() {
    final percentageController = TextEditingController(text: _discountPercentage.toString());
    DateTime selectedEndDate = _discountEndDate ?? DateTime.now().add(const Duration(days: 7));
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Définir une réduction sur tous les produits'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: percentageController,
                    decoration: const InputDecoration(
                      labelText: 'Pourcentage de réduction',
                      hintText: 'Ex: 10.0',
                      suffix: Text('%'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  const Text('Date de fin de la réduction:'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedEndDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedEndDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd/MM/yyyy').format(selectedEndDate)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Text(
                      'Note: Les modifications seront soumises à vérification et appliquées sous 24h.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  onPressed: () {
                    final percentage = double.tryParse(percentageController.text) ?? 10.0;
                    Navigator.pop(context);
                    _setDiscount(percentage, selectedEndDate);
                  },
                  child: const Text('Appliquer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _producerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur : ${snapshot.error}',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                    onPressed: () {
                      setState(() {
                        _producerFuture = _fetchProducerData(widget.userId);
                      });
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          
          // Check for active discounts
          if (data.containsKey('structured_data') && 
              data['structured_data'].containsKey('Items Indépendants')) {
            for (var category in data['structured_data']['Items Indépendants']) {
              if (category['items'] != null) {
                for (var item in category['items']) {
                  if (item.containsKey('discount')) {
                    final discount = item['discount'];
                    if (discount != null && discount.containsKey('end_date')) {
                      try {
                        final endDate = DateTime.parse(discount['end_date']);
                        if (endDate.isAfter(DateTime.now())) {
                          setState(() {
                            _hasActiveDiscount = true;
                            _discountPercentage = discount['percentage']?.toDouble() ?? 10.0;
                            _discountEndDate = endDate;
                          });
                          break;
                        }
                      } catch (e) {
                        print('Error parsing discount date: $e');
                      }
                    }
                  }
                }
                if (_hasActiveDiscount) break;
              }
            }
          }
          
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 250.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.deepPurple,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      data['lieu'] ?? 'Mon profil producteur',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image with gradient overlay
                        ShaderMask(
                          shaderCallback: (rect) {
                            return LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.darken,
                          child: Image.network(
                            data['photo'] ?? 'https://via.placeholder.com/500',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                        
                        // Content positioned at the bottom
                        Positioned(
                          bottom: 60,
                          left: 16,
                          right: 16,
                          child: Row(
                            children: [
                              Hero(
                                tag: 'producer_profile_${widget.userId}',
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      (data['photo'] ?? 'https://via.placeholder.com/150'),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name'] ?? 'Nom non spécifié',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 3,
                                            color: Colors.black45,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple.shade300,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            data['type'] ?? 'Loisir',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (_hasActiveDiscount)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade400,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.discount, color: Colors.white, size: 12),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '-${_discountPercentage.toInt()}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _showEditProfileDialog(data),
                      tooltip: 'Modifier le profil',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        // Paramètres
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fonctionnalité de paramètres en développement')),
                        );
                      },
                      tooltip: 'Paramètres',
                    ),
                    // Menu hamburger
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        // Show the menu options
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(100, 80, 0, 0),
                          items: [
                            PopupMenuItem(
                              child: _buildMenuOption(Icons.bookmark, 'Publications sauvegardées'),
                              onTap: () {
                                // Handle saved posts
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Publications sauvegardées')),
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: _buildMenuOption(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Icons.light_mode
                                    : Icons.dark_mode,
                                Theme.of(context).brightness == Brightness.dark
                                    ? 'Mode jour'
                                    : 'Mode nuit',
                              ),
                                onTap: () {
                                  // Toggle theme mode
                                  final currentBrightness = Theme.of(context).brightness;
                                  // Use direct SnackBar instead of ThemeProvider
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Fonctionnalité de thème en développement')),
                                  );
                                },
                            ),
                            PopupMenuItem(
                              child: _buildMenuOption(Icons.block, 'Comptes bloqués'),
                              onTap: () {
                                // Navigate to blocked accounts
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Comptes bloqués')),
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: _buildMenuOption(Icons.logout, 'Déconnexion'),
                              onTap: () {
                                // Logout
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/',
                                  (route) => false,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.deepPurple,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.deepPurple,
                      tabs: _tabs.map((String name) => Tab(text: name)).toList(),
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(data),
                _buildEventsTab(data),
                _buildStatsTab(data),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptionsDialog(),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
        tooltip: 'Créer',
      ),
    );
  }

  void _showEditProfileDialog(Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name'] ?? '');
    final descriptionController = TextEditingController(text: data['description'] ?? '');
    final addressController = TextEditingController(text: data['adresse'] ?? '');
    String? photoUrl = data['photo'];
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifier votre profil'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.deepPurple, width: 2),
                            ),
                            child: ClipOval(
                              child: photoUrl != null
                                ? Image.network(
                                    photoUrl ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60, color: Colors.grey),
                                  )
                                : const Icon(Icons.person, size: 60, color: Colors.grey),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: () async {
                                  await _uploadMedia(true);
                                  if (_eventImageUrl != null) {
                                    setState(() {
                                      photoUrl = _eventImageUrl;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Name
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'établissement',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Address
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Text(
                        'Note: Les modifications seront soumises à vérification et appliquées sous 24h.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  onPressed: () {
                    // TODO: Implement profile update with API
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Votre profil a été mis à jour et sera validé par notre équipe sous 24h.'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProfileTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(data),
          const SizedBox(height: 24),
          _buildMenuSection(data),
          const SizedBox(height: 24),
          _buildCampaignSection(),
          const SizedBox(height: 16),
          _buildMap(data['location']?['coordinates']),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> data) {
    final followersCount = (data['followers'] is Map && data['followers']?['count'] is int)
        ? data['followers']['count']
        : 0;
    final followingCount = (data['following'] is Map && data['following']?['count'] is int)
        ? data['following']['count']
        : 0;
    final interestedCount = (data['interestedUsers'] is Map && data['interestedUsers']?['count'] is int)
        ? data['interestedUsers']['count']
        : 0;
    final choicesCount = (data['choiceUsers'] is Map && data['choiceUsers']?['count'] is int)
        ? data['choiceUsers']['count']
        : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCommunityStats('Followers', followersCount, Icons.people, () {
              _navigateToFollowersList(data, 'followers');
            }),
            _buildCommunityStats('Following', followingCount, Icons.person_add, () {
              _navigateToFollowersList(data, 'following');
            }),
            _buildCommunityStats('Interested', interestedCount, Icons.emoji_objects, () {
              _navigateToFollowersList(data, 'interested');
            }),
            _buildCommunityStats('Choices', choicesCount, Icons.check_circle, () {
              _navigateToFollowersList(data, 'choices');
            }),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          data['description'] ?? 'Description non spécifiée',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        if (data['adresse'] != null)
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.deepPurple, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['adresse'],
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (data['website'] != null)
          Row(
            children: [
              const Icon(Icons.link, color: Colors.deepPurple, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['website'],
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMenuSection(Map<String, dynamic> data) {
    // Récupérer les menus du producteur (adapter selon votre structure de données)
    List<dynamic> menus = data['menus'] ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Carte du Menu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.deepPurple),
                  onPressed: () => _showMenuEditDialog(),
                  tooltip: 'Modifier les menus',
                )
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Filtres pour les menus
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _menuFilters.keys.map((filter) {
                return FilterChip(
                  label: Text(filter),
                  selected: _menuFilters[filter]!,
                  selectedColor: Colors.deepPurple.withOpacity(0.2),
                  checkmarkColor: Colors.deepPurple,
                  onSelected: (selected) {
                    setState(() {
                      _menuFilters[filter] = selected;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Liste des menus disponibles
            ...menus.isEmpty 
                ? [_buildEmptyMenuMessage()]
                : _buildFilteredMenus(menus),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilteredMenus(List<dynamic> menus) {
    // Filtrer les menus selon les critères sélectionnés
    List<dynamic> filteredMenus = menus;
    
    if (_menuFilters.values.any((selected) => selected)) {
      filteredMenus = menus.where((menu) {
        // Vérifier si le menu correspond à au moins un des filtres sélectionnés
        for (var entry in _menuFilters.entries) {
          if (entry.value && (menu['tags']?.contains(entry.key) ?? false)) {
            return true;
          }
        }
        return false;
      }).toList();
    }
    
    if (filteredMenus.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: Text(
            'Aucun menu correspondant aux filtres sélectionnés',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      ];
    }
    
    return filteredMenus.map<Widget>((menu) {
      return _buildMenuCard(menu);
    }).toList();
  }

  Widget _buildMenuCard(dynamic menu) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          menu['name'] ?? 'Menu sans nom',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${menu['price'] ?? '0.00'} €',
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Chip(
          label: Text(
            menu['type'] ?? 'Standard',
            style: TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.deepPurple.withOpacity(0.1),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (menu['description'] != null)
                  Text(
                    menu['description'],
                    style: TextStyle(fontSize: 14),
                  ),
                  
                const SizedBox(height: 16),
                
                const Text(
                  'Détails du menu',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                ...(menu['items'] as List? ?? []).map<Widget>((item) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['name'] ?? 'Item sans nom'),
                    subtitle: item['description'] != null
                        ? Text(item['description'], 
                            style: TextStyle(fontSize: 12))
                        : null,
                    trailing: item['price'] != null
                        ? Text('${item['price']} €',
                            style: TextStyle(fontWeight: FontWeight.bold))
                        : null,
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMenuMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun menu disponible',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un menu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            onPressed: () => _showMenuEditDialog(),
          ),
        ],
      ),
    );
  }

  // Méthode pour l'édition des menus
  void _showMenuEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gestion des menus'),
        content: const Text('Bientôt disponible : éditeur de menus avancé'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Ajout d'une section pour les campagnes marketing
  Widget _buildCampaignSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Campagnes Marketing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_hasActiveCampaign)
              _buildActiveCampaignCard()
            else
              _buildCampaignOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCampaignCard() {
    final daysLeft = _campaignEndDate != null
        ? _campaignEndDate!.difference(DateTime.now()).inDays
        : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Campagne $_campaignType active',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Portée estimée : $_campaignReach utilisateurs'),
          Text('Jours restants : $daysLeft jours'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: const Text('Statistiques'),
                onPressed: () {
                  // Naviguer vers les statistiques de campagne
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.stop_circle),
                label: const Text('Arrêter'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  setState(() {
                    _hasActiveCampaign = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Augmentez votre visibilité avec une campagne ciblée',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            _buildCampaignOptionCard(
              title: 'Boost Local',
              description: 'Visibilité augmentée dans votre quartier',
              price: '29,99 €',
              icon: Icons.location_on,
              color: Colors.green,
              onTap: () => _startCampaign('Boost Local', 2500),
            ),
            _buildCampaignOptionCard(
              title: 'Promo Spéciale',
              description: 'Mise en avant de vos offres promotionnelles',
              price: '49,99 €',
              icon: Icons.local_offer,
              color: Colors.orange,
              onTap: () => _startCampaign('Promo Spéciale', 5000),
            ),
            _buildCampaignOptionCard(
              title: 'Premium',
              description: 'Visibilité maximale et analyses détaillées',
              price: '99,99 €',
              icon: Icons.star,
              color: Colors.purple,
              onTap: () => _startCampaign('Premium', 10000),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCampaignOptionCard({
    required String title,
    required String description,
    required String price,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.42,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startCampaign(String type, int reach) {
    setState(() {
      _hasActiveCampaign = true;
      _campaignType = type;
      _campaignReach = reach;
      _campaignEndDate = DateTime.now().add(const Duration(days: 30));
    });
  }

  Widget _buildCommunityStats(String label, int count, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFollowersList(Map<String, dynamic> data, String type) async {
    List<String> userIds = [];
    String title = '';
    
    if (type == 'followers' && data['followers'] != null) {
      userIds = List<String>.from(data['followers']['users'] ?? []);
      title = 'Followers';
    } else if (type == 'following' && data['following'] != null) {
      userIds = List<String>.from(data['following']['users'] ?? []);
      title = 'Following';
    } else if (type == 'interested' && data['interestedUsers'] != null) {
      userIds = List<String>.from(data['interestedUsers']['users'] ?? []);
      title = 'Interested Users';
    } else if (type == 'choices' && data['choiceUsers'] != null) {
      userIds = List<String>.from(data['choiceUsers']['users'] ?? []);
      title = 'Users Who Chose';
    }
    
    if (userIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun utilisateur à afficher')),
      );
      return;
    }

    final profiles = await _validateProfiles(userIds);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: profiles.isNotEmpty
                        ? ListView.builder(
                            controller: scrollController,
                            itemCount: profiles.length,
                            itemBuilder: (context, index) {
                              final profile = profiles[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    profile['photo'] ?? 'https://via.placeholder.com/150',
                                  ),
                                ),
                                title: Text(profile['name'] ?? 'Nom inconnu'),
                                subtitle: Text(profile['description'] ?? 'Pas de description'),
                              );
                            },
                          )
                        : const Center(
                            child: Text('Aucun profil disponible.'),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final interestedCount = post['interested']?.length ?? 0;
    final choicesCount = post['choices']?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    post['user_photo'] ?? 'https://via.placeholder.com/150',
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['author_name'] ?? 'Nom non spécifié',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (post['created_at'] != null)
                      Text(
                        _formatDate(post['created_at']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Edit button for my posts
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Show options menu
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Modifier'),
                              onTap: () {
                                Navigator.pop(context);
                                // Edit post
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete, color: Colors.red),
                              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                              onTap: () {
                                Navigator.pop(context);
                                // Delete post
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Content
            Text(
              post['content'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            
            if (post['target_id'] != null && post['target_type'] == 'event')
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Text(
                      'Événement associé',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // Navigate to event details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventLeisureScreen(
                              eventId: post['target_id'],
                            ),
                          ),
                        );
                      },
                      child: const Text('Voir'),
                    ),
                  ],
                ),
              ),
            
            // Media
            if (mediaUrls.isNotEmpty)
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(mediaUrls[0]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            // Interaction stats
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text('0'),
                  const SizedBox(width: 16),
                  Icon(Icons.emoji_objects, 
                    color: interestedCount > 0 ? Colors.orange : Colors.grey, 
                    size: 18
                  ),
                  const SizedBox(width: 4),
                  Text('$interestedCount'),
                  const SizedBox(width: 16),
                  Icon(Icons.check_circle, 
                    color: choicesCount > 0 ? Colors.green : Colors.grey, 
                    size: 18
                  ),
                  const SizedBox(width: 4),
                  Text('$choicesCount'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildEventsTab(Map<String, dynamic> data) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerEvents(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final events = snapshot.data ?? [];
        
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun événement pour le moment',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Créer un événement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => _showCreateEventDialog(),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventCard(event);
          },
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    // Extract all possible event fields from different DB structures
    final String title = event['intitulé'] ?? event['titre'] ?? event['name'] ?? event['nom'] ?? 'Sans titre';
    
    // Get proper date information
    final String dateStr = event['prochaines_dates'] ?? event['date_debut'] ?? event['date_fin'] ?? '';
    final String formattedDate = formatEventDate(dateStr);
    final bool isPastEvent = isEventPassed(event);
    
    // Get a proper category
    String category = 'Catégorie non spécifiée';
    if (event['catégorie'] != null) {
      category = event['catégorie'].toString();
      // Handle complex category formats (e.g. "Parent » Child")
      if (category.contains('»')) {
        category = category.split('»').last.trim();
      }
    } else if (event['category'] != null) {
      category = event['category'].toString();
    }
    
    // Get the venue logo/avatar and event image with fallbacks
    final String eventImageUrl = _getEventImage(event);
    final String venuePhotoUrl = _getVenuePhoto(event);
    
    // Build the event card UI
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventLeisureScreen(
                eventId: event['_id'] ?? '',
                eventData: event,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with gradient overlay
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  // Event image
                  eventImageUrl.isNotEmpty
                      ? Image.network(
                          eventImageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 160,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 40),
                          ),
                        )
                      : Container(
                          height: 160,
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.event,
                            size: 50,
                            color: Colors.grey[500],
                          ),
                        ),
                  
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
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
                  
                  // Status badge (past or upcoming)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isPastEvent ? Colors.grey : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPastEvent ? Icons.history : Icons.event_available,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPastEvent ? 'Passé' : 'À venir',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Category badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Venue profile photo
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          venuePhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.place, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Event title at bottom
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 60, // Space for venue photo
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isPastEvent ? Icons.history : Icons.calendar_today,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: TextStyle(
                                  color: isPastEvent ? Colors.white60 : Colors.white,
                                  fontSize: 14,
                                  fontWeight: isPastEvent ? FontWeight.normal : FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.edit,
                    label: 'Modifier',
                    onTap: () {
                      // Edit event functionality
                      _showEditEventDialog(event);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.share,
                    label: 'Partager',
                    onTap: () {
                      // Share event functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fonctionnalité de partage en développement')),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.post_add,
                    label: 'Poster',
                    onTap: () {
                      // Create post about this event
                      _showCreatePostDialog(eventId: event['_id']);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.star,
                    label: 'Premium',
                    onTap: () => _showSubscriptionModal(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Get the best available image for an event across different DB structures
  String _getEventImage(Map<String, dynamic> event) {
    // Try using our helper function from leisureHelpers.dart first
    try {
      final imageUrl = getEventImageUrl(event);
      if (imageUrl.isNotEmpty && !imageUrl.contains('placeholder')) {
        return imageUrl;
      }
    } catch (e) {
      print('❌ Error using getEventImageUrl: $e');
    }
    
    // Fallback to direct field access with different possible field names
    final imageFields = [
      'image', 'image_url', 'photo', 'thumbnail', 'cover', 'cover_image', 
      'banner', 'main_image', 'featured_image'
    ];
    
    for (final field in imageFields) {
      if (event[field] != null && 
          event[field].toString().isNotEmpty && 
          !event[field].toString().contains('placeholder')) {
        return event[field].toString();
      }
    }
    
    // Try to extract from images array if it exists
    if (event['images'] is List && (event['images'] as List).isNotEmpty) {
      final firstImage = event['images'][0];
      if (firstImage is String && firstImage.isNotEmpty) {
        return firstImage;
      } else if (firstImage is Map && firstImage['url'] != null) {
        return firstImage['url'].toString();
      }
    }
    
    // Last resort: check for any URL in any field that looks like an image
    for (final key in event.keys) {
      final value = event[key];
      if (value is String && 
          value.isNotEmpty && 
          (value.startsWith('http') || value.startsWith('https')) &&
          (value.endsWith('.jpg') || value.endsWith('.jpeg') || 
           value.endsWith('.png') || value.endsWith('.webp'))) {
        return value;
      }
    }
    
    // No image found, return placeholder
    return 'https://via.placeholder.com/400x200?text=Événement';
  }
  
  /// Get the venue photo for an event, with multiple fallbacks
  String _getVenuePhoto(Map<String, dynamic> event) {
    // First try direct venue photo fields
    final photoFields = [
      'producer_photo', 'venue_photo', 'venue_image', 'location_photo', 
      'place_photo', 'organizer_photo'
    ];
    
    for (final field in photoFields) {
      if (event[field] != null && 
          event[field].toString().isNotEmpty && 
          !event[field].toString().contains('placeholder')) {
        return event[field].toString();
      }
    }
    
    // Try to get venue information if available
    final String? venueId = event['producer_id'] ?? event['venue_id'] ?? event['location_id'];
    
    // If venue nested object exists, check for photo
    if (event['venue'] is Map || event['producer'] is Map || event['location'] is Map) {
      final venueObj = event['venue'] ?? event['producer'] ?? event['location'];
      if (venueObj['photo'] != null && venueObj['photo'].toString().isNotEmpty) {
        return venueObj['photo'].toString();
      }
      if (venueObj['image'] != null && venueObj['image'].toString().isNotEmpty) {
        return venueObj['image'].toString();
      }
    }
    
    // If we have producer data available, use it
    if (_producerData != null && _producerData!['photo'] != null) {
      return _producerData!['photo'].toString();
    }
    
    // If no photo is found but we have a venue name, generate an avatar
    final venueName = event['lieu'] ?? event['venue_name'] ?? 
                       event['producer_name'] ?? _producerData?['name'] ?? 'Lieu';
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(venueName)}&background=random&size=200';
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool showBadge = false,
  }) {
    // Couleur par défaut (violet pour les loisirs)
    final defaultColor = color ?? Colors.deepPurple;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: defaultColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: defaultColor,
                  size: 24,
                ),
              ),
              if (showBadge)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: const Text(
                      '!',
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
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: defaultColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bar_chart, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Vue d\'ensemble',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        title: 'Événements',
                        value: data['nombre_evenements']?.toString() ?? '0',
                        icon: Icons.event,
                        color: Colors.purple,
                      ),
                      _buildStatCard(
                        title: 'Vues',
                        value: '0',
                        icon: Icons.visibility,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: 'Engagement',
                        value: '0%',
                        icon: Icons.people,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.trending_up, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Croissance des followers',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                                if (value.toInt() >= 0 && value.toInt() < months.length) {
                                  return Text(months[value.toInt()]);
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              const FlSpot(0, 3),
                              const FlSpot(1, 4),
                              const FlSpot(2, 3.5),
                              const FlSpot(3, 5),
                              const FlSpot(4, 6),
                              const FlSpot(5, 8),
                            ],
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.equalizer, color: Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Performance des événements',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 10,
                        barGroups: [
                          _makeBarGroup(0, 5, Colors.blue),
                          _makeBarGroup(1, 8, Colors.blue),
                          _makeBarGroup(2, 6, Colors.blue),
                          _makeBarGroup(3, 9, Colors.blue),
                          _makeBarGroup(4, 7, Colors.blue),
                        ],
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const events = ['Event 1', 'Event 2', 'Event 3', 'Event 4', 'Event 5'];
                                if (value.toInt() >= 0 && value.toInt() < events.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      events[value.toInt()],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pie_chart, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Abonnement Premium',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade100, Colors.purple.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Passez au premium',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Obtenez plus de visibilité et d\'outils analytiques pour développer votre audience.',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  // Upgrade to premium
                                  _showPremiumOptions();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Découvrir les offres'),
                              ),
                            ],
                          ),
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
    );
  }

  void _showPremiumOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Abonnement Premium',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Débloquez toutes les fonctionnalités et développez votre visibilité',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Banner for Apple Pay
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.payments, color: Colors.white, size: 26),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Apple Pay & CB acceptés',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildPlanCard(
                              plan: 'gratuit',
                              title: 'Gratuit',
                              price: 0,
                              features: [
                                'Profil lieu',
                                'Poster',
                                'Voir les posts clients',
                                'Reco IA 1x/semaine',
                                'Stats basiques',
                              ],
                              isRecommended: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPlanCard(
                              plan: 'starter',
                              title: 'Starter',
                              price: 5,
                              features: [
                                'Recos IA quotidiennes',
                                'Stats avancées',
                                'Accès au feed de tendances locales',
                              ],
                              isRecommended: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPlanCard(
                              plan: 'pro',
                              title: 'Pro',
                              price: 10,
                              features: [
                                'Boosts illimités sur la map/feed',
                                'Accès à la Heatmap & Copilot IA',
                                'Campagnes simples',
                              ],
                              isRecommended: true,
                            ),
                            const SizedBox(height: 16),
                            _buildPlanCard(
                              plan: 'legend',
                              title: 'Legend',
                              price: 15,
                              features: [
                                'Classement public',
                                'Ambassadeurs',
                                'Campagnes avancées (ciblage fin)',
                                'Visuels IA stylisés',
                              ],
                              isRecommended: false,
                            ),
                            
                            // Payment security notice
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.security, color: Colors.green.shade700),
                                      const SizedBox(width: 12),
                                      const Text(
                                        "Paiement sécurisé",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Toutes les transactions sont protégées et cryptées. Vous pouvez annuler votre abonnement à tout moment depuis votre profil.",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
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
          },
        );
      },
    );
  }

  Widget _buildPlanCard({
    required String plan,
    required String title,
    required int price,
    required List<String> features,
    required bool isRecommended,
  }) {
    final isPro = plan == 'pro';
    final isGratuit = plan == 'gratuit';
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isRecommended ? Colors.deepPurple.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecommended ? Colors.deepPurple : Colors.grey.shade300,
              width: isRecommended ? 2 : 1,
            ),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isRecommended ? Colors.deepPurple : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$price€",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isRecommended ? Colors.deepPurple : Colors.black,
                    ),
                  ),
                  const Text(
                    "/mois",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: isRecommended ? Colors.deepPurple : Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _subscribe(context, plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isGratuit 
                        ? Colors.grey.shade200 
                        : (isRecommended ? Colors.deepPurple : Colors.purple.shade600),
                    foregroundColor: isGratuit ? Colors.black87 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(isGratuit ? "Sélectionner" : "S'abonner"),
                ),
              ),
            ],
          ),
        ),
        if (isRecommended)
          Positioned(
            top: -12,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Recommandé',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.25,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 12,
          color: color,
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildMap(List<dynamic>? coordinates) {
    try {
      if (coordinates == null || coordinates.length < 2) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Coordonnées GPS non disponibles'),
          ),
        );
      }
      
      if (coordinates[0] == null || coordinates[1] == null || 
          !(coordinates[0] is num) || !(coordinates[1] is num)) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Coordonnées invalides'),
          ),
        );
      }
      
      final double lon = coordinates[0].toDouble();
      final double lat = coordinates[1].toDouble();
      
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Coordonnées hors limites'),
          ),
        );
      }

      final latLng = LatLng(lat, lon);

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
          markers: {
            Marker(
              markerId: const MarkerId('producer_location'),
              position: latLng,
            ),
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        ),
      );
    } catch (e) {
      print('❌ Erreur lors du rendu de la carte: $e');
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Erreur lors du chargement de la carte'),
        ),
      );
    }
  }

  void _showCreateOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Que souhaitez-vous créer ?'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showCreatePostDialog();
            },
            child: const Row(
              children: [
                Icon(Icons.post_add, color: Colors.deepPurple),
                SizedBox(width: 10),
                Text('Nouveau post'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showCreateEventDialog();
            },
            child: const Row(
              children: [
                Icon(Icons.event, color: Colors.deepPurple),
                SizedBox(width: 10),
                Text('Nouvel événement'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog({String? eventId}) {
    final contentController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Créer un post',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Content field
                            TextField(
                              controller: contentController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'Partagez quelque chose avec votre audience...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Event link (if provided)
                            if (eventId != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Ce post sera lié à l\'événement sélectionné',
                                        style: TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, color: Colors.deepPurple),
                                      onPressed: () {
                                        // Show info about linking to event
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Vos followers pourront accéder directement à cet événement depuis votre post.'),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // Media preview
                            if (_eventImageUrl != null)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_eventImageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            
                            // Media upload buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.image),
                                  label: const Text('Ajouter une image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple.withOpacity(0.8),
                                  ),
                                  onPressed: () async {
                                    await _uploadMedia(true);
                                    if (mounted) setState(() {});
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.videocam),
                                  label: const Text('Ajouter une vidéo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple.withOpacity(0.8),
                                  ),
                                  onPressed: () async {
                                    await _uploadMedia(false);
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Post button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (contentController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Veuillez ajouter du contenu à votre post')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  _createPost(contentController.text, eventId);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Publier',
                                  style: TextStyle(fontSize: 16),
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
          },
        );
      },
    );
  }

  void _showCreateEventDialog() {
    _eventTitleController.clear();
    _eventDescriptionController.clear();
    _eventCategoryController.clear();
    _eventImageUrl = null;
    _eventStartDate = null;
    _eventEndDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Créer un événement',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Title field
                            TextField(
                              controller: _eventTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Titre de l\'événement',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Description field
                            TextField(
                              controller: _eventDescriptionController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Category field
                            TextField(
                              controller: _eventCategoryController,
                              decoration: const InputDecoration(
                                labelText: 'Catégorie',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Date pickers
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventStartDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de début',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventStartDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventStartDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: _eventStartDate ?? DateTime.now(),
                                        firstDate: _eventStartDate ?? DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventEndDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de fin',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventEndDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventEndDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Image preview
                            if (_eventImageUrl != null)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_eventImageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            
                            // Image upload button
                            ElevatedButton.icon(
                              icon: const Icon(Icons.image),
                              label: const Text('Ajouter une image'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () async {
                                await _uploadMedia(true);
                                if (mounted) setState(() {});
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Create event button
                            ElevatedButton(
                              onPressed: () {
                                if (_eventTitleController.text.isEmpty || 
                                    _eventDescriptionController.text.isEmpty || 
                                    _eventCategoryController.text.isEmpty ||
                                    _eventStartDate == null ||
                                    _eventEndDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez remplir tous les champs')),
                                  );
                                  return;
                                }
                                
                                // Create event logic
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Événement créé avec succès!')),
                                );
                                
                                // Refresh events
                                setState(() {
                                  _producerFuture = _fetchProducerData(widget.userId);
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text(
                                'Créer l\'événement',
                                style: TextStyle(fontSize: 16),
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
          },
        );
      },
    );
  }

  void _showEditEventDialog(Map<String, dynamic> event) {
    _eventTitleController.text = event['intitulé'] ?? '';
    _eventDescriptionController.text = event['détail'] ?? '';
    _eventCategoryController.text = event['catégorie'] ?? '';
    _eventImageUrl = event['image'];
    
    try {
      if (event['date_debut'] != null) {
        _eventStartDate = DateTime.parse(event['date_debut']);
      }
      if (event['date_fin'] != null) {
        _eventEndDate = DateTime.parse(event['date_fin']);
      }
    } catch (e) {
      print('Error parsing dates: $e');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Modifier l\'événement',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Same fields as create event, but pre-filled
                            TextField(
                              controller: _eventTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Titre de l\'événement',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextField(
                              controller: _eventDescriptionController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextField(
                              controller: _eventCategoryController,
                              decoration: const InputDecoration(
                                labelText: 'Catégorie',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: _eventStartDate ?? DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventStartDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de début',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventStartDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventStartDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: _eventEndDate ?? _eventStartDate ?? DateTime.now(),
                                        firstDate: _eventStartDate ?? DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _eventEndDate = pickedDate;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date de fin',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _eventEndDate != null
                                            ? DateFormat('dd/MM/yyyy').format(_eventEndDate!)
                                            : 'Sélectionner',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (_eventImageUrl != null)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_eventImageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            
                            ElevatedButton.icon(
                              icon: const Icon(Icons.image),
                              label: const Text('Modifier l\'image'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () async {
                                await _uploadMedia(true);
                                if (mounted) setState(() {});
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            ElevatedButton(
                              onPressed: () {
                                if (_eventTitleController.text.isEmpty || 
                                    _eventDescriptionController.text.isEmpty || 
                                    _eventCategoryController.text.isEmpty ||
                                    _eventStartDate == null ||
                                    _eventEndDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez remplir tous les champs')),
                                  );
                                  return;
                                }
                                
                                // Update event logic here
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Événement mis à jour avec succès!')),
                                );
                                
                                // Refresh events
                                setState(() {
                                  _producerFuture = _fetchProducerData(widget.userId);
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text(
                                'Mettre à jour l\'événement',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            OutlinedButton(
                              onPressed: () {
                                // Show delete confirmation
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Supprimer l\'événement ?'),
                                    content: const Text('Cette action est irréversible. Souhaitez-vous vraiment supprimer cet événement ?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context); // Close dialog
                                          Navigator.pop(context); // Close edit sheet
                                          
                                          // Delete event logic
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Événement supprimé avec succès!')),
                                          );
                                          
                                          // Refresh events
                                          setState(() {
                                            _producerFuture = _fetchProducerData(widget.userId);
                                          });
                                        },
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Supprimer'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text('Supprimer l\'événement'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _subscribe(BuildContext context, String plan) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await PaymentService.processPayment(context, plan, widget.userId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Abonnement $plan réussi ! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Erreur lors du paiement. Réessayez."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Erreur : $e"),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Enhanced date formatting functions
  
  String formatEventDate(String dateStr) {
    if (dateStr.isEmpty) return 'Date non spécifiée';
    
    try {
      DateTime date;
      
      // Handle different date formats
      if (dateStr.contains('/')) {
        // French format DD/MM/YYYY
        final parts = dateStr.split('/');
        if (parts.length >= 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2].split(' ')[0]); // Handle potential time
          date = DateTime(year, month, day);
        } else {
          return dateStr; // Return as is if format is unexpected
        }
      } else if (dateStr.contains('-')) {
        // ISO format YYYY-MM-DD
        date = DateTime.parse(dateStr);
      } else {
        return dateStr; // Unknown format
      }
      
      // Check if date is in the past
      final now = DateTime.now();
      final isPast = date.isBefore(now);
      
      // Format based on how far in the future/past
      final difference = date.difference(now).inDays;
      
      if (isPast) {
        // Past event
        if (difference >= -7) {
          // Within last week
          return '${DateFormat('EEEE dd/MM').format(date)} (passé)';
        } else {
          // Older
          return 'Le ${DateFormat('dd/MM/yyyy').format(date)} (passé)';
        }
      } else {
        // Future event
        if (difference == 0) {
          // Today
          return 'Aujourd\'hui';
        } else if (difference < 7) {
          // Within next week
          return DateFormat('EEEE dd/MM').format(date);
        } else {
          // Further in future
          return 'Le ${DateFormat('dd/MM/yyyy').format(date)}';
        }
      }
    } catch (e) {
      print('❌ Error formatting date $dateStr: $e');
      return dateStr; // Return as is if all parsing attempts fail
    }
  }
  
  bool isEventPassed(Map<String, dynamic> event) {
    // Try to determine if the event is in the past with improved logic
    try {
      String? dateStr;
      
      // Check more date fields in priority order
      final dateFields = [
        'date_debut', 'date_fin', 'prochaines_dates', 'start_date', 'end_date', 
        'date', 'event_date', 'date_evenement'
      ];
      
      for (final field in dateFields) {
        if (event.containsKey(field) && 
            event[field] != null && 
            event[field].toString().isNotEmpty) {
          dateStr = event[field].toString();
          break;
        }
      }
      
      // If still no date found and there's a status field, use that
      if (dateStr == null && event['status'] != null) {
        final status = event['status'].toString().toLowerCase();
        return status == 'past' || status == 'ended' || status == 'finished' || 
               status == 'terminé' || status == 'passé';
      }
      
      if (dateStr == null || dateStr.isEmpty) {
        return false; // Default to upcoming if no date found
      }
      
      DateTime eventDate;
      
      // Parse date based on format with improved handling
      if (dateStr.contains('/')) {
        // DD/MM/YYYY format
        final parts = dateStr.split('/');
        if (parts.length >= 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final yearPart = parts[2].split(' ')[0]; // Remove time if present
          final year = int.parse(yearPart);
          eventDate = DateTime(year, month, day);
        } else {
          return false; // Invalid format, default to upcoming
        }
      } else if (dateStr.contains('-')) {
        // YYYY-MM-DD or DD-MM-YYYY format
        final parts = dateStr.split('-');
        if (parts.length >= 3) {
          // Determine format by checking if first part is a 4-digit year
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            eventDate = DateTime.parse(dateStr);
          } else {
            // DD-MM-YYYY
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final yearPart = parts[2].split(' ')[0]; // Remove time if present
            final year = int.parse(yearPart);
            eventDate = DateTime(year, month, day);
          }
        } else {
          return false; // Invalid format, default to upcoming
        }
      } else {
        // Try standard ISO parse
        try {
          eventDate = DateTime.parse(dateStr);
        } catch (e) {
          print('❌ Could not parse date: $dateStr');
          return false; // Default to upcoming if parsing fails
        }
      }
      
      final now = DateTime.now();
      
      // Include events happening today as "upcoming"
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      
      return eventDay.isBefore(today);
    } catch (e) {
      print('❌ Error checking if event is passed: $e');
      return false; // Default to upcoming if there's an error
    }
  }

  // Méthode pour afficher la modal d'abonnement
  void _showSubscriptionModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionScreen(
          producerId: widget.userId,
          isLeisureProducer: true, // Leisure producer
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}