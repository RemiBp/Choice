import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:typed_data'; // Add this for Uint8List
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart' as constants;
import '../models/producer.dart';
import '../models/post.dart';
import '../widgets/profile_post_card.dart';
import 'post_detail_screen.dart';
import 'messaging_screen.dart';
import '../services/app_data_sender_service.dart'; // Import the sender service
import '../utils/location_utils.dart'; // Import location utils
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng
// Added imports
import 'relation_details_screen.dart';
import 'profile_screen.dart';
import 'producerLeisure_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:shimmer/shimmer.dart'; // Import Shimmer
import '../utils.dart' show getImageProvider;
import 'user_list_screen.dart'; // ADD THIS IMPORT

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() {
    return message;
  }
}

// === Helper function to build the correct image widget ===
Widget _buildImageWidget(String imageSource, {BoxFit? fit, Widget? placeholder, Widget? errorWidget}) {
  // Default placeholder and error widgets if not provided
  final defaultPlaceholder = Container(
    color: Colors.grey[300],
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
  final defaultErrorWidget = Container(
    color: Colors.grey[300],
    child: const Icon(Icons.broken_image, color: Colors.white),
  );

  if (imageSource.startsWith('data:image')) {
    try {
      // Find the comma that separates the metadata from the base64 data
      final commaIndex = imageSource.indexOf(',');
      if (commaIndex == -1) {
        print('❌ Invalid Base64 Data URL format (no comma)');
        return errorWidget ?? defaultErrorWidget;
      }
      
      // Extract the base64 part
      final base64String = imageSource.substring(commaIndex + 1);
      
      // Decode the base64 string
      final Uint8List bytes = base64Decode(base64String);
      
      // Return Image.memory
      return Image.memory(
        bytes,
        fit: fit,
        // Error builder for memory image if decoding somehow leads to invalid image data
        errorBuilder: (context, error, stackTrace) {
           print('❌ Error displaying memory image: $error');
          return errorWidget ?? defaultErrorWidget;
        },
      );
    } catch (e) {
      print('❌ Error decoding Base64 image: $e');
      // Fallback to error widget if decoding fails
      return errorWidget ?? defaultErrorWidget;
    }
  } else if (imageSource.startsWith('http')) {
    // It's a network URL, use CachedNetworkImage
    return CachedNetworkImage(
      imageUrl: imageSource,
      fit: fit,
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) {
         print('❌ Error loading network image: $url, error: $error');
         return errorWidget ?? defaultErrorWidget;
      },
    );
  } else {
    // Unknown format, return error widget
    print('❌ Unknown image source format: $imageSource');
    return errorWidget ?? defaultErrorWidget;
  }
}

class ProducerScreen extends StatefulWidget {
  final String producerId;
  final Producer? producer;
  final String? userId;
  final bool isWellness;
  final bool isBeauty;

  const ProducerScreen({
    Key? key, 
    required this.producerId, 
    this.producer,
    this.userId,
    this.isWellness = false,
    this.isBeauty = false,
  }) : super(key: key);

  @override
  State<ProducerScreen> createState() => _ProducerScreenState();
}

class _ProducerScreenState extends State<ProducerScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _producerFuture;
  late TabController _tabController;
  bool _isFollowing = false;
  // Updated state variables
  int _followersCount = 0;
  int _followingCount = 0;
  int _interestedCount = 0;
  int _choicesCount = 0;
  List<String> _followerIds = [];
  List<String> _followingIds = [];
  List<String> _interestedUserIds = [];
  List<String> _choiceUserIds = [];

  bool _isSendingMessage = false;
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> _posts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingMenus = false;
  List<dynamic> _menus = [];
  // Changed to Map for categorized items
  Map<String, List<Map<String, dynamic>>> _categorizedItems = {};
  
  @override
  void initState() {
    super.initState();
    print('🔍 Initialisation du ProductScreen avec ID: ${widget.producerId}');
    _producerFuture = _fetchProducerDetails(widget.producerId);
    _tabController = TabController(length: 4, vsync: this);
    
    // Charger les données initiales
    _producerFuture.then((producer) {
      // Check for error state before proceeding
      if (producer.containsKey('error') && producer['error'] == true) {
         print("🔥 Producer details fetch failed, skipping further initializations.");
         return; // Don't proceed if fetch failed
      }

      // Initialiser les données de suivi et relations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          // Helper to safely extract user IDs and count
          Map<String, dynamic> extractRelationData(Map<String, dynamic> data, String key) {
            List<String> ids = [];
            int count = 0;
            dynamic relationData = data['relations']?[key]; // Check within 'relations' first
            if (relationData == null) {
               relationData = data[key]; // Fallback to root level
            }

            if (relationData is List) {
              ids = relationData.whereType<String>().toList();
              count = ids.length;
            } else if (relationData is Map) {
              if (relationData['users'] is List) {
                ids = (relationData['users'] as List).whereType<String>().toList();
              }
              count = (relationData['count'] is int) ? relationData['count'] : ids.length;
            } else if (relationData is int) { // Sometimes only count might be available
              count = relationData;
            } else if (key == 'followers' && data['abonnés'] is int) { // Specific fallback for 'followers' using 'abonnés'
              count = data['abonnés'];
              // Attempt to get IDs if `followers` field exists as list
               if (data['followers'] is List) {
                 ids = (data['followers'] as List).whereType<String>().toList();
                 // Ensure count matches ID list length if IDs are present
                 if (ids.isNotEmpty && count != ids.length) {
                   print("⚠️ Follower count ($count) mismatch with follower ID list length (${ids.length}). Using ID list length.");
                   count = ids.length;
                 }
               }
            } else if (key == 'followers' && data['followers'] is List) { // If 'abonnés' not present but 'followers' list is
                ids = (data['followers'] as List).whereType<String>().toList();
                count = ids.length;
            }

            return {'count': count, 'ids': ids};
          }

          final followerInfo = extractRelationData(producer, 'followers');
          final followingInfo = extractRelationData(producer, 'following');
          final interestedInfo = extractRelationData(producer, 'interestedUsers');
          final choiceInfo = extractRelationData(producer, 'choiceUsers');

          _followersCount = followerInfo['count'];
          _followerIds = followerInfo['ids'];
          _followingCount = followingInfo['count'];
          _followingIds = followingInfo['ids'];
          _interestedCount = interestedInfo['count'];
          _interestedUserIds = interestedInfo['ids'];
          _choicesCount = choiceInfo['count'];
          _choiceUserIds = choiceInfo['ids'];

          // Check following status if user is logged in
          if (widget.userId != null && widget.userId!.isNotEmpty) {
             // Check against the extracted follower IDs
             _isFollowing = _followerIds.contains(widget.userId);
          }
          print('📊 Counts - Followers: $_followersCount, Following: $_followingCount, Interested: $_interestedCount, Choices: $_choicesCount');
        });
      });
      
      // Charger les posts
      _loadPosts();
      
      // Charger les menus
      _loadMenus(producer);

      // Log producer view activity
      _logProducerViewActivity(widget.producerId, producer['type'] ?? 'restaurant'); // Use detected type or default
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // --- Refresh Functions ---
  Future<void> _refreshProducerDetails() async {
     setState(() {
       _producerFuture = _fetchProducerDetails(widget.producerId);
       // Re-trigger downstream loads after fetching details
       _producerFuture.then((producer) {
         if (!(producer.containsKey('error') && producer['error'] == true)) {
           _loadPosts();
           _loadMenus(producer);
           // Update relation counts etc. if necessary
            _updateRelationState(producer);
         }
       });
     });
   }

  Future<void> _refreshPosts() async {
    await _loadPosts();
  }

  Future<void> _refreshMenu() async {
    // Need producer data to load menus
    final producerData = await _producerFuture;
    if (!(producerData.containsKey('error') && producerData['error'] == true)) {
      await _loadMenus(producerData);
    }
  }
  // --- End Refresh Functions ---


  // Fonction pour charger les posts
  Future<void> _loadPosts() async {
    if (_isLoadingPosts) return;
    
    setState(() {
      _isLoadingPosts = true;
    });
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/posts');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final postsData = json.decode(response.body);
        setState(() {
          _posts = postsData['posts'] ?? [];
        });
      } else {
        print('❌ Erreur lors du chargement des posts: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception lors du chargement des posts: $e');
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }
  
  // Fonction pour charger les menus et items (REVAMPED)
  Future<void> _loadMenus(Map<String, dynamic> producer) async {
    if (_isLoadingMenus) return;
    
    setState(() {
      _isLoadingMenus = true;
      _menus = [];
      _categorizedItems = {}; // Reset categorized items
    });
    
    try {
      // Extraire les menus et items des données du producteur
      if (producer['structured_data'] != null && producer['structured_data'] is Map) {
        final structuredData = producer['structured_data'] as Map<String, dynamic>;

        // --- Process Global Menus ---
        if (structuredData['Menus Globaux'] is List) {
          // Filter and cast safely
          final List<Map<String, dynamic>> safeGlobalMenus =
              List<Map<String, dynamic>>.from(
                  (structuredData['Menus Globaux'] as List).whereType<Map<String, dynamic>>()
              );
          print('🍽️ Found ${safeGlobalMenus.length} global menus.');
          setState(() {
            _menus = safeGlobalMenus;
          });
        } else {
           print('⚠️ Menus Globaux is not a List or is null.');
        }

        // --- Process Independent Items ---
        if (structuredData['Items Indépendants'] is List) {
          final Map<String, List<Map<String, dynamic>>> groupedItems = {};
          final categoriesData = structuredData['Items Indépendants'] as List;

          for (var categoryData in categoriesData) {
            if (categoryData is Map<String, dynamic>) {
              final categoryName = categoryData['catégorie']?.toString().trim() ?? 'Autres'; // Default category name
              final itemsList = categoryData['items'];

              if (itemsList is List) {
                 // Filter for valid map items only
                 final List<Map<String, dynamic>> validItems = itemsList
                      .whereType<Map<String, dynamic>>() // Ensure item is a Map
                      .toList();

                if (validItems.isNotEmpty) {
                   groupedItems.putIfAbsent(categoryName, () => []).addAll(validItems);
                   print('🛒 Category "$categoryName": Found ${validItems.length} independent items.');
                }
              } else {
                 print('⚠️ Items list for category "$categoryName" is not a List or is null.');
              }
            } else {
               print('⚠️ Category data is not a Map.');
            }
          }
           print('🛒 Total categorized items: ${groupedItems.values.map((list) => list.length).reduce((a, b) => a + b)} across ${groupedItems.keys.length} categories.');
          setState(() {
            _categorizedItems = groupedItems;
          });
        } else {
            print('⚠️ Items Indépendants is not a List or is null.');
        }

      } else {
         print('⚠️ structured_data is null or not a Map.');
      }
    } catch (e, stacktrace) {
      print('❌ Exception lors du chargement des menus: $e');
      print(stacktrace); // Print stacktrace for detailed debugging
    } finally {
      setState(() {
        _isLoadingMenus = false;
      });
    }
  }

  // Helper to update relation counts and following status after refresh
  void _updateRelationState(Map<String, dynamic> producer) {
      setState(() {
         // Helper to safely extract user IDs and count
         Map<String, dynamic> extractRelationData(Map<String, dynamic> data, String key) {
           List<String> ids = [];
           int count = 0;
           dynamic relationData = data['relations']?[key]; // Check within 'relations' first
           if (relationData == null) {
              relationData = data[key]; // Fallback to root level
           }

           if (relationData is List) {
             ids = relationData.whereType<String>().toList();
             count = ids.length;
           } else if (relationData is Map) {
             if (relationData['users'] is List) {
               ids = (relationData['users'] as List).whereType<String>().toList();
             }
             count = (relationData['count'] is int) ? relationData['count'] : ids.length;
           } else if (relationData is int) { // Sometimes only count might be available
             count = relationData;
           } else if (key == 'followers' && data['abonnés'] is int) { // Specific fallback for 'followers' using 'abonnés'
             count = data['abonnés'];
             // Attempt to get IDs if `followers` field exists as list
              if (data['followers'] is List) {
                ids = (data['followers'] as List).whereType<String>().toList();
                // Ensure count matches ID list length if IDs are present
                if (ids.isNotEmpty && count != ids.length) {
                  print("⚠️ Follower count ($count) mismatch with follower ID list length (${ids.length}). Using ID list length.");
                  count = ids.length;
                }
              }
           } else if (key == 'followers' && data['followers'] is List) { // If 'abonnés' not present but 'followers' list is
               ids = (data['followers'] as List).whereType<String>().toList();
               count = ids.length;
           }

           return {'count': count, 'ids': ids};
         }

         final followerInfo = extractRelationData(producer, 'followers');
         final followingInfo = extractRelationData(producer, 'following');
         final interestedInfo = extractRelationData(producer, 'interestedUsers');
         final choiceInfo = extractRelationData(producer, 'choiceUsers');

         _followersCount = followerInfo['count'];
         _followerIds = followerInfo['ids'];
         _followingCount = followingInfo['count'];
         _followingIds = followingInfo['ids'];
         _interestedCount = interestedInfo['count'];
         _interestedUserIds = interestedInfo['ids'];
         _choicesCount = choiceInfo['count'];
         _choiceUserIds = choiceInfo['ids'];


         // Check following status if user is logged in
         if (widget.userId != null && widget.userId!.isNotEmpty) {
            // Check against the extracted follower IDs
            _isFollowing = _followerIds.contains(widget.userId);
         }
         print('🔄 Refreshed Counts - Followers: $_followersCount, Following: $_followingCount, Interested: $_interestedCount, Choices: $_choicesCount');
       });
  }

  void _testApi() async {
    final producerId = widget.producerId;
    print('🔍 Test API avec producerId: $producerId');
    
    // Validate MongoDB ObjectID format
    final bool isValidObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(producerId);
    if (!isValidObjectId) {
      print('⚠️ ID potentiellement invalide: $producerId - ne semble pas être un ObjectId MongoDB');
    }

    // Try multiple possible endpoints
    List<String> endpointsToTest = [
      '/api/producers/$producerId',
      '/api/producers/$producerId/relations',
      '/api/unified/$producerId',
      '/api/leisureProducers/$producerId',
    ];
    
    final baseUrl = await constants.getBaseUrl();
    print('🔄 URL de base utilisée: $baseUrl');
    
    for (String endpoint in endpointsToTest) {
      try {
        print('🔍 Test : appel à $endpoint');
        Uri url = Uri.parse('$baseUrl$endpoint');
        
        print('🌐 URL complète: $url');
        
        final response = await http.get(url).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Délai d'attente dépassé"),
        );
        
        print('Réponse pour $endpoint : ${response.statusCode}');
        if (response.statusCode == 200) {
          print('✅ Requête $endpoint réussie');
          print('Body (aperçu): ${response.body.substring(0, min(150, response.body.length))}...');
          break; // Sortir de la boucle si une requête réussit
        } else {
          print('❌ Échec de la requête $endpoint: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Erreur réseau pour $endpoint : $e');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchProducerDetails(String producerId) async {
    // Validation MongoDB ObjectID
    final bool isValidObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(producerId);
    if (!isValidObjectId) {
      print('⚠️ Warning: ID potentiellement invalide: $producerId');
      // Optionally return error immediately if ID format is strictly required
      // return {'error': true, 'error_message': 'ID de producteur invalide'};
    }

    final baseUrl = await constants.getBaseUrl();
    print('🌐 URL de base pour les requêtes API: $baseUrl');

    final producerUrl = Uri.parse('$baseUrl/api/producers/$producerId');
    // Assuming the backend controller handles fetching relations within this endpoint or provides a separate one
    // Let's assume the relation data might be included or fetched separately
    final relationsUrl = Uri.parse('$baseUrl/api/producers/$producerId/relations'); // Specific endpoint for relations

    Map<String, dynamic> producerData = {};
    Map<String, dynamic> relationsData = {};
    String? errorMessage;

    try {
      print('🔍 Fetching producer data from $producerUrl');
      final producerResponse = await http.get(producerUrl).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Délai expiré pour les données principales du producteur'),
      );

      if (producerResponse.statusCode == 200) {
        print('✅ Données principales récupérées (status ${producerResponse.statusCode})');
        producerData = json.decode(producerResponse.body);
        _normalizeProducerData(producerData, 'producer'); // Normalize primary data
      } else {
        print('❌ Échec de récupération des données principales: ${producerResponse.statusCode}');
        errorMessage = 'Erreur ${producerResponse.statusCode} lors de la récupération des données principales.';
        // Try fallback if provided
         if (widget.producer != null) {
           print('🔄 Utilisation des données du producteur fournies par le widget comme fallback');
           producerData = { // Convert Producer object to Map
             '_id': widget.producer!.id,
             'place_id': widget.producer!.id, // Assuming place_id is same as id
             'name': widget.producer!.name,
             'description': widget.producer!.description,
             'address': widget.producer!.address,
             'photo': widget.producer!.photo, // Assuming photo field exists
             'category': widget.producer!.category is List ? widget.producer!.category : [widget.producer!.category],
             'primary_category': widget.producer!.category is List ? (widget.producer!.category as List).first : widget.producer!.category,
             'structured_data': {}, // Assume no structured data from widget
             'relations': {'followers': [], 'following': [], 'interestedUsers': [], 'choiceUsers': []},
             '_dataSource': 'widget.producer fallback',
           };
           _normalizeProducerData(producerData, 'producer_fallback');
            errorMessage = null; // Clear error if fallback is used
         }
      }

      // Fetch relations data only if primary fetch was successful or fallback was used
      if (producerData.isNotEmpty) {
         try {
           print('🔍 Fetching relations data from $relationsUrl');
           final relationsResponse = await http.get(relationsUrl).timeout(
             const Duration(seconds: 10),
             onTimeout: () => throw TimeoutException('Délai expiré pour les données de relations'),
           );

           if (relationsResponse.statusCode == 200) {
             print('✅ Données de relations récupérées (status ${relationsResponse.statusCode})');
             relationsData = json.decode(relationsResponse.body);
             // Merge relations into producerData under a 'relations' key
              producerData['relations'] = {
                 'followers': relationsData['followers'] ?? [], // Ensure lists exist
                 'following': relationsData['following'] ?? [],
                 'interestedUsers': relationsData['interestedUsers'] ?? [],
                 'choiceUsers': relationsData['choiceUsers'] ?? []
              };
             print('📊 Relations data merged.');
           } else {
             print('⚠️ Échec de récupération des relations: ${relationsResponse.statusCode}. Utilisation de valeurs par défaut.');
             // Ensure default relation structure exists even if fetch fails
             producerData['relations'] ??= {'followers': [], 'following': [], 'interestedUsers': [], 'choiceUsers': []};
           }
         } catch (e) {
           print('⚠️ Erreur lors de la récupération/fusion des relations: $e');
            producerData['relations'] ??= {'followers': [], 'following': [], 'interestedUsers': [], 'choiceUsers': []};
         }
      }


    } catch (e) {
      print('❌ Erreur générale lors du fetch: $e');
      errorMessage = e.toString();
       // Try fallback if primary fetch fails completely due to network error etc.
       if (widget.producer != null && producerData.isEmpty) {
          print('🔄 Utilisation des données du producteur fournies par le widget comme fallback après erreur réseau');
           producerData = { // Convert Producer object to Map
             '_id': widget.producer!.id,
             'place_id': widget.producer!.id,
             'name': widget.producer!.name,
             'description': widget.producer!.description,
             'address': widget.producer!.address,
             'photo': widget.producer!.photo,
             'category': widget.producer!.category is List ? widget.producer!.category : [widget.producer!.category],
             'primary_category': widget.producer!.category is List ? (widget.producer!.category as List).first : widget.producer!.category,
             'structured_data': {},
             'relations': {'followers': [], 'following': [], 'interestedUsers': [], 'choiceUsers': []},
             '_dataSource': 'widget.producer fallback',
           };
           _normalizeProducerData(producerData, 'producer_fallback');
           errorMessage = null; // Clear error if fallback is used
       }
    }

    // Final check and return
    if (producerData.isNotEmpty) {
      // Ensure 'relations' key exists before returning
       producerData['relations'] ??= {'followers': [], 'following': [], 'interestedUsers': [], 'choiceUsers': []};
      return producerData;
    } else {
      print('❌ Fetch failed completely. Returning error.');
      return {
        'error': true,
        'error_message': errorMessage ?? 'Impossible de récupérer les données du producteur',
      };
    }
  }
  
  // Fonction pour normaliser les données du producteur selon leur source
  void _normalizeProducerData(Map<String, dynamic> data, String sourceType) {
    // Vérifier et corriger les champs obligatoires
    if (data['_id'] == null && data['id'] != null) {
      data['_id'] = data['id'];
    }
    
    if (data['_id'] == null && data['place_id'] != null) {
      data['_id'] = data['place_id'];
    }
    
    if (data['place_id'] == null && data['_id'] != null) {
      data['place_id'] = data['_id'];
    }
    
    // Normaliser le champ photo
    _normalizePhotoField(data);
    
    // Vérifier la structure des données
    if (data['structured_data'] == null) {
      data['structured_data'] = {};
    }
    
    // S'assurer que structured_data contient les sous-objets nécessaires
    if (!data['structured_data'].containsKey('Menus Globaux')) {
      data['structured_data']['Menus Globaux'] = [];
    }
    
    if (!data['structured_data'].containsKey('Items Indépendants')) {
      data['structured_data']['Items Indépendants'] = [];
    }
    
    // Correction pour le type de données de Restaurant_GooglePlaces_Results
    if (sourceType == 'restaurant_places' || sourceType == 'place') {
      // Remapper les champs du format GooglePlaces vers le format producers si nécessaire
      if (data['primary_category'] == null && data['types'] != null) {
        // Extraire la catégorie principale des types
        final types = data['types'];
        if (types is List && types.isNotEmpty) {
          data['primary_category'] = types[0];
          // Ensure category is always an array
          if (data['category'] == null) {
            data['category'] = [types[0]];
          } else if (data['category'] is String) {
            // Convert string to list if it's a string
            data['category'] = [data['category']];
          }
        }
      }
      
      // S'assurer que les menus sont accessibles
      if (data['structured_data']['Menus Globaux'] == null) {
        // Vérifier si les menus sont stockés sous un autre format
        if (data['menus'] != null) {
          data['structured_data']['Menus Globaux'] = data['menus'];
        } else {
          data['structured_data']['Menus Globaux'] = [];
        }
      }
      
      // Harmoniser les coordonnées GPS
      if (data['gps_coordinates'] == null && data['geometry'] != null && data['geometry']['location'] != null) {
        final location = data['geometry']['location'];
        data['gps_coordinates'] = {
          'type': 'Point',
          'coordinates': [location['lng'], location['lat']]
        };
      }
    }
    
    // Vérifier les champs obligatoires et fournir des valeurs par défaut si nécessaires
    if (data['name'] == null) data['name'] = 'Sans nom';
    if (data['description'] == null) data['description'] = '';
    if (data['address'] == null) data['address'] = 'Adresse non disponible';
    
    // Ensure category is always an array
    if (data['category'] == null) {
      data['category'] = ['Non catégorisé'];
    } else if (data['category'] is String) {
      data['category'] = [data['category']];
    }
    
    // Set primary_category based on the first category
    if (data['primary_category'] == null && data['category'] != null) {
      if (data['category'] is List && (data['category'] as List).isNotEmpty) {
        data['primary_category'] = (data['category'] as List)[0];
      } else if (data['category'] is String) {
        data['primary_category'] = data['category'];
      } else {
        data['primary_category'] = 'Non catégorisé';
      }
    } else if (data['primary_category'] == null) {
      data['primary_category'] = 'Non catégorisé';
    }
    
    // Log pour le débogage
    print('🔄 Données normalisées depuis la source: $sourceType');
  }
  
  // Fonction pour normaliser le champ photo et traiter correctement les références photos Google Maps
  void _normalizePhotoField(Map<String, dynamic> data) {
    print('🔍 Normalizing photo field for data: ${data['name']} with photo type: ${data['photo']?.runtimeType}');
    
    // Si photo est une liste, prendre le premier élément
    if (data['photo'] is List) {
      if ((data['photo'] as List).isNotEmpty) {
        // Extraction de l'URL ou de la référence photo
        var photoItem = (data['photo'] as List)[0];
        if (photoItem is Map<String, dynamic> && photoItem.containsKey('photo_reference')) {
          // Cas d'une référence photo Google Maps
          String photoReference = photoItem['photo_reference'];
          print('📸 Found Google Maps photo reference: $photoReference');
          data['photo'] = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400'
              '&photoreference=$photoReference'
              '&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE';
          print('🔗 Created Google Maps photo URL: ${data['photo']}');
        } else if (photoItem is String) {
          data['photo'] = photoItem;
          print('🖼️ Found photo as string: ${data['photo']}');
        } else {
          // Valeur par défaut si le format n'est pas reconnu
          print('⚠️ Unrecognized photo format: ${photoItem.runtimeType}');
          data['photo'] = 'https://via.placeholder.com/400x200?text=Pas+d%27image';
        }
      } else {
        print('⚠️ Empty photo list');
        data['photo'] = 'https://via.placeholder.com/400x200?text=Pas+d%27image';
      }
    }
    
    // Vérifier les références photos Google Maps
    if (data['photo'] == null || (data['photo'] is String && data['photo'].toString().isEmpty)) {
      print('🔍 No photo found, checking photos field');
      // Rechercher une photo dans d'autres champs
      if (data['photos'] != null) {
        print('📸 Photos field exists with type: ${data['photos'].runtimeType}');
        if (data['photos'] is List && (data['photos'] as List).isNotEmpty) {
          var photoItem = (data['photos'] as List)[0];
          print('📸 First photo item type: ${photoItem.runtimeType}');
          
          if (photoItem is Map<String, dynamic> && photoItem.containsKey('photo_reference')) {
            // Cas d'une référence photo Google Maps
            String photoReference = photoItem['photo_reference'];
            print('📸 Found Google Maps photo reference in photos: $photoReference');
            data['photo'] = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400'
                '&photoreference=$photoReference'
                '&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE';
            print('🔗 Created Google Maps photo URL from photos: ${data['photo']}');
          } else if (photoItem is String) {
            data['photo'] = photoItem;
            print('🖼️ Found photo string in photos: ${data['photo']}');
          }
        }
      }
    }
    
    // Si toujours pas de photo, vérifier le champ maps_url pour construire une URL statique Maps
    if (data['photo'] == null || (data['photo'] is String && data['photo'].toString().isEmpty)) {
      if (data['maps_url'] != null && data['maps_url'].toString().isNotEmpty) {
        print('🗺️ No photo found, using maps_url for static map image');
        // Extract place_id or coordinates from maps_url if available
        if (data['gps_coordinates'] != null) {
          try {
            var lat = data['gps_coordinates']['lat'] ?? data['gps_coordinates']['latitude'];
            var lng = data['gps_coordinates']['lng'] ?? data['gps_coordinates']['longitude'];
            // Generate a static Maps image as fallback
            data['photo'] = 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=16&size=600x300&markers=color:red%7C$lat,$lng&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE';
            print('🗺️ Created static map image URL: ${data['photo']}');
          } catch (e) {
            print('❌ Error creating static map image: $e');
          }
        }
      }
    }
    
    // Si toujours pas de photo, utiliser une image par défaut
    if (data['photo'] == null || (data['photo'] is String && data['photo'].toString().isEmpty)) {
      print('⚠️ No usable photo found, using default placeholder');
      data['photo'] = 'https://via.placeholder.com/400x200?text=Pas+d%27image';
    }
  }
  
  // Fonction pour suivre ou ne plus suivre un producteur
  Future<void> _toggleFollow(String producerId) async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour suivre un producteur')),
      );
      return;
    }
    
    // --- ADDED: Log follow/unfollow action --- 
    final actionType = _isFollowing ? 'unfollow_producer' : 'follow_producer';
    _logGenericProducerAction(actionType);
    // --- End Log --- 
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId/follow');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': widget.userId}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isFollowing = data['isFollowing'] ?? !_isFollowing;
          _followersCount = _isFollowing ? _followersCount + 1 : _followersCount - 1;
          if (_followersCount < 0) _followersCount = 0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing 
              ? 'Vous suivez maintenant ce producteur' 
              : 'Vous ne suivez plus ce producteur'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        print('❌ Erreur lors du suivi: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour du suivi')),
        );
      }
    } catch (e) {
      print('❌ Exception lors du suivi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau lors de la mise à jour du suivi')),
      );
    }
  }
  
  // Fonction pour envoyer un message au producteur
  Future<void> _sendMessage(String producerId, String message) async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour envoyer un message')),
      );
      return;
    }
    
    if (message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un message')),
      );
      return;
    }
    
    // --- ADDED: Log send message action --- 
    _logGenericProducerAction('send_message_producer');
    // --- End Log --- 
    
    setState(() {
      _isSendingMessage = true;
    });
    
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/conversations/new-message');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': widget.userId,
          'recipientIds': [producerId],
          'content': message,
        }),
      );
      
      if (response.statusCode == 201) {
        _messageController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message envoyé avec succès')),
        );
        
        // Naviguer vers l'écran de messagerie
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MessagingScreen(
                userId: widget.userId!,
              ),
            ),
          );
        }
      } else {
        print('❌ Erreur lors de l\'envoi du message: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du message')),
        );
      }
    } catch (e) {
      print('❌ Exception lors de l\'envoi du message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau lors de l\'envoi du message')),
      );
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }
  
  // Fonction pour partager le profil du producteur
  void _shareProducerProfile(Map<String, dynamic> producer) {
    final String name = producer['name'] ?? 'Producteur';
    final String description = producer['description'] ?? '';
    final String shareText = 'Découvrez $name sur Choice App.\n$description';
    
    // --- ADDED: Log share action --- 
    _logGenericProducerAction('share_producer');
    // --- End Log --- 
    
    _shareViaSystem(shareText);
  }
  
  // Méthode alternative pour partager
  Future<void> _shareViaSystem(String text) async {
    // Utilisation de url_launcher avec scheme particulier pour partager
    // ou simplement afficher un message
    try {
      // Sur les plateformes où c'est supporté
      final Uri uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Message de repli
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partage non disponible sur cet appareil')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de partager: $e')),
      );
    }
  }
  
  // Fonction pour ouvrir Google Maps avec l'adresse du producteur
  Future<void> _openMaps(Map<String, dynamic> producer) async {
    String? address = producer['address'];
    if (address == null || address.isEmpty) {
      address = producer['formatted_address'] ?? producer['vicinity'];
    }
    
    if (address == null || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse non disponible')),
      );
      return;
    }
    
    // Coordonnées GPS si disponibles
    double? lat;
    double? lng;
    
    if (producer['gps_coordinates'] != null && 
        producer['gps_coordinates']['coordinates'] != null &&
        producer['gps_coordinates']['coordinates'] is List &&
        producer['gps_coordinates']['coordinates'].length >= 2) {
      lng = producer['gps_coordinates']['coordinates'][0];
      lat = producer['gps_coordinates']['coordinates'][1];
    } else if (producer['geometry'] != null && 
               producer['geometry']['location'] != null) {
      lat = producer['geometry']['location']['lat'];
      lng = producer['geometry']['location']['lng'];
    }
    
    String mapsUrl;
    if (lat != null && lng != null) {
      mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else {
      mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    }
    
    final Uri url = Uri.parse(mapsUrl);
    // --- ADDED: Log open maps action --- 
    _logGenericProducerAction('open_maps');
    // --- End Log --- 
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Google Maps')),
      );
    }
  }
  
  // Fonction pour appeler le producteur
  Future<void> _callProducer(Map<String, dynamic> producer) async {
    String? phone = producer['phone_number'] ?? producer['formatted_phone_number'] ?? producer['international_phone_number'];
    
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone non disponible')),
      );
      return;
    }
    
    // Nettoyer le numéro de téléphone
    phone = phone.replaceAll(RegExp(r'\s+'), '');
    
    final Uri url = Uri.parse('tel:$phone');
    // --- ADDED: Log call action --- 
    _logGenericProducerAction('call_producer');
    // --- End Log --- 
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'effectuer l\'appel')),
      );
    }
  }
  
  // Fonction pour ouvrir le site web du producteur
  Future<void> _openWebsite(Map<String, dynamic> producer) async {
    String? website = producer['website'] ?? producer['url'];
    
    if (website == null || website.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Site web non disponible')),
      );
      return;
    }
    
    final Uri url = Uri.parse(website);
    // --- ADDED: Log open website action --- 
    _logGenericProducerAction('open_website');
    // --- End Log --- 
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le site web')),
      );
    }
  }
  
  // Fonction pour afficher la boîte de dialogue de message
  void _showMessageDialog(BuildContext context, String producerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Envoyer un message',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Votre message...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSendingMessage
                        ? null
                        : () {
                            _sendMessage(producerId, _messageController.text);
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Envoyer'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
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
            // return const Center(child: CircularProgressIndicator());
            return _buildLoadingShimmer(); // Use Shimmer effect
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty || snapshot.data!['error'] == true) {
            // return Center(
            //   child: Column(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       const Icon(Icons.error_outline, size: 48, color: Colors.red),
            //       const SizedBox(height: 16),
            //       Text('Erreur: ${snapshot.error}'),
            //       const SizedBox(height: 16),
            //       ElevatedButton(
            //         onPressed: () {
            //           setState(() {
            //             _producerFuture = _fetchProducerDetails(widget.producerId);
            //           });
            //         },
            //         child: const Text('Réessayer'),
            //       ),
            //     ],
            //   ),
            // );
            return _buildErrorWidget(
              snapshot.error?.toString() ?? snapshot.data!['error_message'] ?? 'Erreur inconnue ou producteur non trouvé.',
              _refreshProducerDetails
            );
          } else {
            final producer = snapshot.data!;

            // Call _updateRelationState here to ensure counts are updated AFTER successful fetch
            // NOTE: Consider if _updateRelationState should be called within _fetchProducerDetails success path instead.
            // If _fetchProducerDetails returns the final data including relations, calling it here might be redundant
            // or cause issues if snapshot.data is updated incrementally.
            // Let's assume _fetchProducerDetails handles setting state internally or returns complete data.
            // _updateRelationState(producer); // REMOVE THIS LINE

            return _buildProducerProfile(producer);
          }
        },
      ),
    );
  }
  
  Widget _buildProducerProfile(Map<String, dynamic> producer) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(producer),
          _buildHeader(producer),
          // +++ ADD PRODUCER STATS SECTION +++
          SliverToBoxAdapter(
             child: _ProducerStats(
               followersCount: _followersCount,
               followingCount: _followingCount, // Assuming producers can follow others? If not, remove.
               interestedCount: _interestedCount,
               choicesCount: _choicesCount,
               followerIds: _followerIds,
               followingIds: _followingIds, // Pass IDs if following exists for producers
               interestedUserIds: _interestedUserIds,
               choiceUserIds: _choiceUserIds,
               onNavigateToUserList: _navigateToUserList,
             ),
           ),
          // +++ END PRODUCER STATS SECTION +++
          _buildTabBar(), // Keep the TabBar
        ];
      },
      body: TabBarView( // Keep the TabBarView
        controller: _tabController,
        children: [
          _buildInfoTab(producer),
          _buildMenuTab(producer),
          _buildPostsTab(producer),
          _buildReviewsTab(producer),
        ],
      ),
    );
  }

  Widget _buildAppBar(Map<String, dynamic> producer) {
    final imageSource = producer['photo'] ?? 'https://via.placeholder.com/500x300?text=No+Image';

    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.teal,
      flexibleSpace: FlexibleSpaceBar(
        // Use the helper function here
        background: (() {
          final imageProvider = getImageProvider(imageSource);
          return imageProvider != null
            ? Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.restaurant, size: 50, color: Colors.white),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.restaurant, size: 50, color: Colors.white),
              );
        })(),
        title: Text(
          producer['name'] ?? 'Sans nom',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3.0,
                color: Color.fromARGB(150, 0, 0, 0),
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        collapseMode: CollapseMode.parallax,
      ),
      actions: [
        IconButton(
          icon: Icon(_isFollowing ? Icons.favorite : Icons.favorite_border),
          color: _isFollowing ? Colors.redAccent : Colors.white, // Highlight when following
          tooltip: _isFollowing ? 'Ne plus suivre' : 'Suivre',
          onPressed: () => _toggleFollow(producer['_id']),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          color: Colors.white,
          tooltip: 'Partager le profil',
          onPressed: () => _shareProducerProfile(producer),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          color: Colors.white,
          tooltip: "Plus d'options", // Use double quotes for the string
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => _buildMoreOptions(context, producer),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> producer) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Name, Rating, Price, Category
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Name, Rating, Followers/Following
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producer['name'] ?? 'Sans nom',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Rating and Relation Counts Row
                      Row(
                        children: [
                           // Rating
                           if (producer['rating'] != null) ...[
                             const Icon(Icons.star, color: Colors.amber, size: 18),
                             const SizedBox(width: 4),
                             Text(
                               producer['rating'] is num 
                                   ? (producer['rating'] as num).toStringAsFixed(1)
                                   : producer['rating'].toString(),
                               style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.bold),
                             ),
                             const SizedBox(width: 12),
                           ],

                          // Followers Count (Tappable)
                          GestureDetector(
                             onTap: () => _navigateToRelationDetails('Abonnés', _followerIds),
                             child: Row(
                               children: [
                                 const Icon(Icons.people_outline, size: 16, color: Colors.teal),
                                 const SizedBox(width: 4),
                                 Text(
                                   '$_followersCount',
                                   style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.bold),
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(width: 12),

                           // Following Count (Tappable)
                           GestureDetector(
                             onTap: () => _navigateToRelationDetails('Abonnements', _followingIds),
                             child: Row(
                                children: [
                                 const Icon(Icons.person_add_alt_1_outlined, size: 16, color: Colors.teal),
                                 const SizedBox(width: 4),
                                  Text(
                                    '$_followingCount',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                             ),
                           ),
                        ],
                      ),
                       const SizedBox(height: 8),
                       // Address
                       Row(
                         children: [
                           Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                           const SizedBox(width: 4),
                           Expanded(
                             child: Text(
                               producer['address'] ?? 'Adresse non disponible',
                               style: TextStyle(color: Colors.grey[700], fontSize: 14),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                       ),
                    ],
                  ),
                ),
                // Right Side: Price Level, Category
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (producer['price_level'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getPriceLevel(producer['price_level']),
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (producer['primary_category'] != null)...[
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                         decoration: BoxDecoration(
                           color: Colors.orange.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(
                           producer['primary_category'] ?? 'Non catégorisé',
                           style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                           textAlign: TextAlign.center,
                         ),
                       ),
                    ] else if (producer['category'] is List && (producer['category'] as List).isNotEmpty)...[
                       Container( // Fallback to first category if primary is missing
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                         decoration: BoxDecoration(
                           color: Colors.orange.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(
                           (producer['category'] as List)[0],
                           style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                           textAlign: TextAlign.center,
                         ),
                       ),
                    ]
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.map_outlined,
                  label: 'Itinéraire',
                  onPressed: () => _openMaps(producer),
                ),
                _buildActionButton(
                  icon: Icons.phone_outlined,
                  label: 'Appeler',
                  onPressed: () => _callProducer(producer),
                ),
                _buildActionButton(
                  icon: Icons.message_outlined,
                  label: 'Message',
                  onPressed: () => _showMessageDialog(context, producer['_id']),
                ),
                _buildActionButton(
                  icon: Icons.language_outlined,
                  label: 'Site web',
                  onPressed: () => _openWebsite(producer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Info'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
            Tab(icon: Icon(Icons.photo_library), text: 'Posts'),
            Tab(icon: Icon(Icons.star_border), text: 'Avis'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> producer) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- About Card ---
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias, // Ensure content respects border radius
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'À propos',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                if (producer['description'] != null && producer['description'].isNotEmpty)
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.grey[50],
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.grey[200]!),
                     ),
                     child: Text(
                       producer['description'],
                       style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                     ),
                   )
                 else
                    Text('Aucune description disponible.', style: TextStyle(color: Colors.grey[600])),

                // Tags (Specialties, Cuisine Type)
                _buildTagsSection(producer, 'Spécialités', 'specialties', Colors.teal),
                _buildTagsSection(producer, 'Type de cuisine', 'cuisine_type', Colors.orange),
                _buildTagsSection(producer, 'Catégories', 'category', Colors.purple), // Display all categories as tags too
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // --- Relation Counts Card ---
        Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           clipBehavior: Clip.antiAlias,
           child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                     // Card Header
                     Row(
                       children: [
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             color: Colors.blue.withOpacity(0.1),
                             shape: BoxShape.circle,
                           ),
                           child: const Icon(Icons.favorite_border, color: Colors.blue), // Example icon
                         ),
                         const SizedBox(width: 12),
                         const Text(
                           'Engagement',
                           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                         ),
                       ],
                     ),
                    const SizedBox(height: 16),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceAround,
                       children: [
                          _buildCountChip('Intéressés', _interestedCount, Icons.emoji_objects_outlined, Colors.orange, () => _navigateToRelationDetails('Intéressés', _interestedUserIds)),
                          _buildCountChip('Choix', _choicesCount, Icons.check_circle_outline, Colors.green, () => _navigateToRelationDetails('Choix', _choiceUserIds)),
                       ],
                    )
                 ],
              ),
           ),
        ),

        const SizedBox(height: 16),

        // --- Opening Hours Card ---
        Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           clipBehavior: Clip.antiAlias,
           child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header
                 Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: Colors.blueGrey.withOpacity(0.1),
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.access_time, color: Colors.blueGrey),
                     ),
                     const SizedBox(width: 12),
                     const Text(
                       'Horaires d\'ouverture',
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                     ),
                   ],
                 ),
                const SizedBox(height: 16),
                _buildOpeningHours(producer),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // --- Contact Info Card ---
        Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           clipBehavior: Clip.antiAlias,
           child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 // Card Header
                 Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: Colors.indigo.withOpacity(0.1),
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.contact_phone_outlined, color: Colors.indigo),
                     ),
                     const SizedBox(width: 12),
                     const Text(
                       'Contact',
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                     ),
                   ],
                 ),
                const SizedBox(height: 16),
                _buildContactInfo(producer),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // --- Photos Card ---
        if (producer['photos'] != null && producer['photos'] is List && (producer['photos'] as List).isNotEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
                   Row(
                     children: [
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: Colors.pink.withOpacity(0.1),
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.photo_library_outlined, color: Colors.pink),
                       ),
                       const SizedBox(width: 12),
                       const Text(
                         'Photos',
                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink),
                       ),
                     ],
                   ),
                  const SizedBox(height: 16),
                  _buildPhotosGrid(producer['photos']),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Helper to build tag sections in Info Tab
  Widget _buildTagsSection(Map<String, dynamic> producer, String title, String key, Color color) {
    final tags = producer[key];
    if (tags == null || !(tags is List) || tags.isEmpty) {
      return const SizedBox.shrink(); // Return empty space if no tags
    }

    return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
           const SizedBox(height: 16),
           Text(
             title,
             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 8),
           Wrap(
             spacing: 8,
             runSpacing: 8,
             children: tags.map<Widget>((tag) {
                // Ensure tag is a string before displaying
                final String tagString = tag?.toString() ?? '';
                if (tagString.isEmpty) return const SizedBox.shrink(); // Skip empty tags

                return Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                 ),
                 child: Text(
                    tagString,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                 ),
                );
             }).toList(),
           ),
        ],
    );
  }

  // Helper to build count chips in Info Tab
  Widget _buildCountChip(String label, int count, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        avatar: Icon(icon, color: color, size: 18),
        label: Text('$count $label', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildOpeningHours(Map<String, dynamic> producer) {
    final openingHours = producer['opening_hours'];
    
    if (openingHours == null || 
        !(openingHours is List) || 
        (openingHours as List).isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Horaires non disponibles',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    
    final List<String> daysOfWeek = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    
    return Column(
      children: List.generate(
        min(openingHours.length, daysOfWeek.length),
        (index) {
          final String dayLabel = daysOfWeek[index];
          final String hourText = openingHours[index];
          
          // Déterminer si c'est le jour actuel
          bool isToday = DateTime.now().weekday - 1 == index;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isToday)
                      const Icon(Icons.today, size: 16, color: Colors.blue),
                    SizedBox(width: isToday ? 8 : 0),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? Colors.blue : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  hourText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactInfo(Map<String, dynamic> producer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (producer['phone_number'] != null || producer['formatted_phone_number'] != null) ...[
          GestureDetector(
            onTap: () => _callProducer(producer),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Téléphone',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          producer['phone_number'] ?? producer['formatted_phone_number'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        if (producer['website'] != null) ...[
          GestureDetector(
            onTap: () => _openWebsite(producer),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Site web',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          producer['website'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        GestureDetector(
          onTap: () => _openMaps(producer),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adresse',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        producer['address'] ?? 'Adresse non disponible',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.teal,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getPriceLevel(dynamic priceLevel) {
    if (priceLevel == null) return '';
    
    int level;
    if (priceLevel is int) {
      level = priceLevel;
    } else if (priceLevel is String) {
      level = int.tryParse(priceLevel) ?? 0;
    } else {
      return '';
    }
    
    switch (level) {
      case 0:
        return 'Gratuit';
      case 1:
        return '€';
      case 2:
        return '€€';
      case 3:
        return '€€€';
      case 4:
        return '€€€€';
      default:
        return '€';
    }
  }

  Widget _buildPostsTab(Map<String, dynamic> producer) {
    return RefreshIndicator(
        onRefresh: _refreshPosts, // Call the refresh function
        child: _buildPostsList(producer),
     );
  }

  Widget _buildPostsList(Map<String, dynamic> producer) {
    if (_isLoadingPosts) {
      // return const Center(child: CircularProgressIndicator());
      return _buildPostsShimmer(); // Shimmer for posts
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun post disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      // Removed physics: NeverScrollableScrollPhysics() - RefreshIndicator needs it
      padding: const EdgeInsets.all(8),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return GestureDetector(
          onTap: () {
            // Navigation vers le détail du post
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  postId: post['_id'] ?? post['id'] ?? '',
                  userId: widget.userId ?? '',
                ),
              ),
            );
          },
          child: ProfilePostCard(
            post: post,
            userId: widget.userId ?? '',
            onRefresh: _loadPosts,
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(Map<String, dynamic> producer) {
    final reviews = producer['reviews'] ?? [];
    
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.star_border,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun avis disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    // Calculer la note moyenne
    double averageRating = 0;
    int totalRatings = 0;
    
    for (var review in reviews) {
      if (review['rating'] != null) {
        averageRating += review['rating'];
        totalRatings++;
      }
    }
    
    if (totalRatings > 0) {
      averageRating = averageRating / totalRatings;
    }
    
    // Compter les avis par note (5★, 4★, etc.)
    Map<int, int> ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    
    for (var review in reviews) {
      if (review['rating'] != null) {
        int rating = review['rating'];
        if (ratingDistribution.containsKey(rating)) {
          ratingDistribution[rating] = ratingDistribution[rating]! + 1;
        }
      }
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Résumé des avis
        _buildReviewSummary(averageRating, totalRatings, ratingDistribution),
        
        const SizedBox(height: 24),
        
        // En-tête de la section des avis
        Row(
          children: [
            const Icon(Icons.comment, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              'Avis des clients (${reviews.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Liste des avis
        ...List.generate(reviews.length, (index) => _buildReviewCard(reviews[index])),
      ],
    );
  }
  
  // Widget pour afficher le résumé des avis
  Widget _buildReviewSummary(double averageRating, int totalRatings, Map<int, int> ratingDistribution) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Note moyenne en grand
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < averageRating.round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalRatings avis',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Séparateur vertical
                Container(
                  height: 100,
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                
                // Distribution des notes (barres)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: List.generate(
                      5,
                      (index) {
                        final ratingValue = 5 - index;
                        final count = ratingDistribution[ratingValue] ?? 0;
                        final percentage = totalRatings > 0 
                            ? count / totalRatings 
                            : 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '$ratingValue',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getRatingColor(ratingValue),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Fonction pour obtenir la couleur en fonction de la note
  Color _getRatingColor(int rating) {
    switch (rating) {
      case 5: return Colors.green;
      case 4: return Colors.lightGreen;
      case 3: return Colors.amber;
      case 2: return Colors.orange;
      case 1: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final String name = review['author_name'] ?? 'Utilisateur anonyme';
    final String text = review['text'] ?? '';
    final int rating = review['rating'] ?? 0;
    final String timeStr = review['relative_time_description'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar de l'utilisateur avec bordure
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    backgroundImage: review['profile_photo_url'] != null
                        ? getImageProvider(review['profile_photo_url'])
                        : null,
                    child: review['profile_photo_url'] == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Stars with custom color
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: index < rating ? Colors.amber : Colors.grey[400],
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (timeStr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
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
            if (text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),
            ],
            
            // Boutons d'action (optionnels)
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // Fonctionnalité à implémenter
                  },
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: const Text('Utile'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Fonctionnalité à implémenter
                  },
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Signaler'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptions(BuildContext context, Map<String, dynamic> producer) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(bottom: 20),
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Signaler'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implémenter la fonctionnalité de signalement
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité de signalement à venir')),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.language, color: Theme.of(context).colorScheme.secondary), // Use Theme color
            title: const Text('Voir le site web'),
            onTap: () {
              Navigator.pop(context);
              _openWebsite(producer);
            },
          ),
          if (producer['phone_number'] != null || producer['formatted_phone_number'] != null)
            ListTile(
              leading: Icon(Icons.phone, color: Theme.of(context).colorScheme.secondary), // Use Theme color
              title: const Text('Appeler'),
              onTap: () {
                Navigator.pop(context);
                _callProducer(producer);
              },
            ),
          ListTile(
            leading: Icon(Icons.share, color: Theme.of(context).colorScheme.secondary), // Use Theme color
            title: const Text('Partager'),
            onTap: () {
              Navigator.pop(context);
              _shareProducerProfile(producer);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosGrid(List<dynamic> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      // Limit the grid display for visual clarity, can be adjusted
      itemCount: photos.length > 9 ? 9 : photos.length,
      itemBuilder: (context, index) {
        final photoItem = photos[index];
        String photoSource; // Use a generic 'source' term

        // Determine the source string (handle various types)
        if (photoItem is String) {
          photoSource = photoItem;
        } else if (photoItem is Map && photoItem['photo_reference'] != null) {
          // This case might become less relevant if only Base64 is stored
          photoSource = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400'
              '&photoreference=${photoItem['photo_reference']}'
              '&key=AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE'; // Replace with your actual key if needed elsewhere
        } else {
          photoSource = 'https://via.placeholder.com/150'; // Default placeholder URL
        }
        
        return GestureDetector(
          onTap: () {
            // TODO: Implement full-screen image view
            print("Tapped on image $index: $photoSource");
          },
          // Use the helper function here
          child: ClipRRect( // Add ClipRRect for rounded corners if desired
             borderRadius: BorderRadius.circular(8.0),
             child: (() {
               final imageProvider = getImageProvider(photoSource);
               return imageProvider != null
                 ? Image(
                     image: imageProvider,
                     fit: BoxFit.cover,
                     errorBuilder: (context, error, stackTrace) => Container(
                       color: Colors.grey[300],
                       child: const Icon(Icons.broken_image, color: Colors.white),
                     ),
                   )
                 : Container(
                     color: Colors.grey[300],
                     child: const Icon(Icons.broken_image, color: Colors.white),
                   );
             })(),
          ),
        );
      },
    );
  }

  Widget _buildMenuTab(Map<String, dynamic> producer) {
    return RefreshIndicator(
       onRefresh: _refreshMenu, // Call the refresh function
       child: _buildMenuList(producer),
     );
  }

  Widget _buildMenuList(Map<String, dynamic> producer) {
    if (_isLoadingMenus) {
      // return const Center(child: CircularProgressIndicator(color: Colors.teal));
      return _buildMenuShimmer(); // Shimmer for menu
    }

    // Combine global menus and categorized items for display
    bool hasGlobalMenus = _menus.isNotEmpty;
    bool hasIndependentItems = _categorizedItems.isNotEmpty;

    if (!hasGlobalMenus && !hasIndependentItems) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aucun menu ou article disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[700], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
             Text(
               'Ce producteur n\'a pas encore ajouté son menu.',
               style: TextStyle(fontSize: 14, color: Colors.grey[600]),
               textAlign: TextAlign.center,
             ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section des menus globaux (if any)
        if (hasGlobalMenus) ...[
          _buildSectionHeader('Menus', Icons.menu_book, Colors.amber),
          const SizedBox(height: 16),
          ..._menus.map((menu) => _buildGlobalMenuCard(menu)).toList(),
          if (hasIndependentItems) const SizedBox(height: 24), // Add spacing if both sections exist
        ],

        // Section des items indépendants (if any)
        if (hasIndependentItems) ...[
          _buildSectionHeader('À la carte', Icons.restaurant_menu, Colors.deepPurple),
          const SizedBox(height: 16),
          ..._categorizedItems.entries.map((entry) {
            return _buildCategoryExpansionTile(entry.key, entry.value);
          }).toList(),
        ],
      ],
    );
  }

  // Helper for section headers
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
     return Row(
       children: [
         Container(
           padding: const EdgeInsets.all(8),
           decoration: BoxDecoration(
             color: color.withOpacity(0.1),
             shape: BoxShape.circle,
           ),
           child: Icon(icon, color: color),
         ),
         const SizedBox(width: 12),
         Text(
           title,
           style: TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: color,
           ),
         ),
       ],
     );
  }

  // Méthode pour construire la carte d'un menu global (REVAMPED STYLE)
  Widget _buildGlobalMenuCard(Map<String, dynamic> menu) {
    final String title = menu['name'] ?? menu['title'] ?? 'Menu sans nom';
    final String description = menu['description'] ?? '';
    final dynamic price = menu['price'] ?? menu['prix']; // Check both price/prix
    final String formattedPrice = (price != null && price.toString().isNotEmpty)
        ? '${price.toString()} €'
        : 'Prix non spécifié';
    final List<dynamic> includedCategories = menu['inclus'] ?? []; // Items are nested under 'inclus' -> 'items'

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Ensures content respects border radius
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Price
          Container(
             padding: const EdgeInsets.all(16),
             color: Colors.amber.withOpacity(0.1),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(
                   child: Text(
                     title,
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                   ),
                 ),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                   decoration: BoxDecoration(
                     color: Colors.amber,
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Text(
                     formattedPrice,
                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                   ),
                 ),
               ],
             ),
          ),

          // Optional Description
          if (description.isNotEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               child: Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
             ),

          // Included Items (Collapsible)
          if (includedCategories.isNotEmpty)
             ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                title: const Text('Voir les plats inclus', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w500)),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: includedCategories.map<Widget>((categoryData) {
                    if (categoryData is! Map<String, dynamic>) return const SizedBox.shrink();
                    final categoryName = categoryData['catégorie'] ?? 'Section';
                    final items = categoryData['items'];
                    if (items == null || items is! List || items.isEmpty) return const SizedBox.shrink();

                    return Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Padding(
                             padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                             child: Text(
                                categoryName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54)
                             ),
                          ),
                          ...items.whereType<Map<String, dynamic>>().map((item) => _buildMenuItemRow(item, Colors.amber.shade100)).toList(), // Pass color
                          const SizedBox(height: 8),
                       ],
                    );
                }).toList(),
             )
          else
             const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text('Aucun plat inclus dans ce menu.', style: TextStyle(color: Colors.grey)),
             ),
        ],
      ),
    );
  }

  // Méthode pour construire une rangée d'item de menu (Globaux et Indépendants)
  Widget _buildMenuItemRow(Map<String, dynamic> item, Color? backgroundColor) {
    final String name = item['name'] ?? item['nom'] ?? 'Item sans nom';
    final String description = item['description'] ?? '';

    // Extract nutritional info safely
    final double? rating = (item['note'] is num) ? (item['note'] as num).toDouble() : null;
    final double? carbon = (item['carbon_footprint'] is num) ? (item['carbon_footprint'] as num).toDouble() : null;
    final String? nutriScore = item['nutri_score']?.toString();
    final double? calories = (item['nutrition'] is Map && item['nutrition']['calories'] is num)
        ? (item['nutrition']['calories'] as num).toDouble()
        : (item['calories'] is num ? (item['calories'] as num).toDouble() : null); // Fallback check

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
       decoration: BoxDecoration(
          color: backgroundColor ?? Colors.grey[50], // Use provided color or default
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!)
       ),
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Name and Rating
           Row(
             children: [
               Expanded(
                 child: Text(
                   name,
                   style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                 ),
               ),
               if (rating != null) _buildCompactRatingStars(rating), // Compact stars
             ],
           ),
           // Description
           if (description.isNotEmpty) ...[
             const SizedBox(height: 4),
             Text(
               description,
               style: TextStyle(fontSize: 13, color: Colors.grey[700]),
             ),
           ],
           // Nutritional Info Chips (if available)
           if (carbon != null || nutriScore != null || calories != null) ...[
              const SizedBox(height: 8),
              Wrap(
                 spacing: 8,
                 runSpacing: 4,
                 children: [
                    if (carbon != null) _buildNutritionalChip('${carbon.toStringAsFixed(1)} kg CO2', Icons.eco_outlined, Colors.green),
                    if (nutriScore != null && nutriScore.isNotEmpty && nutriScore != 'N/A') _buildNutritionalChip('Nutri: $nutriScore', Icons.health_and_safety_outlined, _getNutriScoreColor(nutriScore)),
                    if (calories != null) _buildNutritionalChip('${calories.toInt()} cal', Icons.local_fire_department_outlined, Colors.orange),
                 ],
              )
           ]
         ],
      ),
    );
  }

   // Helper for nutritional info chips
   Widget _buildNutritionalChip(String label, IconData icon, Color color) {
      return Chip(
        avatar: Icon(icon, color: color, size: 16),
        label: Text(label, style: TextStyle(fontSize: 11, color: color)),
        backgroundColor: color.withOpacity(0.1),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         side: BorderSide.none,
      );
   }

   // Helper to get color based on NutriScore
   Color _getNutriScoreColor(String score) {
      switch (score.toUpperCase()) {
         case 'A': return Colors.green.shade700;
         case 'B': return Colors.lightGreen.shade700;
         case 'C': return Colors.yellow.shade800;
         case 'D': return Colors.orange.shade700;
         case 'E': return Colors.red.shade700;
         default: return Colors.grey;
      }
   }

   // Helper for compact rating stars
    Widget _buildCompactRatingStars(dynamic rating) {
      double ratingValue = 0.0;
      if (rating is num) {
        ratingValue = rating.toDouble();
      } else if (rating is String) {
        ratingValue = double.tryParse(rating) ?? 0.0;
      }
      if (ratingValue <= 0) return const SizedBox.shrink(); // Don't show if no rating

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 2),
          Text(
            ratingValue.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      );
   }

  // Méthode pour construire les items indépendants par catégorie avec ExpansionTile
  Widget _buildCategoryExpansionTile(String category, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
       margin: const EdgeInsets.only(bottom: 12),
       elevation: 1,
       shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey[200]!),
       ),
       clipBehavior: Clip.antiAlias,
       child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // No border when closed
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // No border when closed
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          title: Text(
             category,
             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Padding inside
          children: items.map((item) => _buildDetailedItemCard(item)).toList(),
       ),
    );
  }

  // Widget pour afficher une carte détaillée d'item indépendant (à la carte)
  Widget _buildDetailedItemCard(Map<String, dynamic> item) {
    final String name = item['name'] ?? item['nom'] ?? 'Item sans nom';
    final String description = item['description'] ?? '';
    final dynamic price = item['price'] ?? item['prix'];
    final String formattedPrice = (price != null && price.toString().isNotEmpty)
        ? price is num 
            ? '${(price as num).toStringAsFixed(2)} €' // Format numbers only
            : '$price €' // For string prices, just append the € symbol
        : ''; // Empty if no price

     // Extract nutritional info safely
    final double? rating = (item['note'] is num) ? (item['note'] as num).toDouble() : null;
    final double? carbon = (item['carbon_footprint'] is num) ? (item['carbon_footprint'] as num).toDouble() : null;
    final String? nutriScore = item['nutri_score']?.toString();
    final double? calories = (item['nutrition'] is Map && item['nutrition']['calories'] is num)
        ? (item['nutrition']['calories'] as num).toDouble()
        : (item['calories'] is num ? (item['calories'] as num).toDouble() : null); // Fallback check

    return Container(
      margin: const EdgeInsets.only(top: 12), // Spacing between items within category
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Rating
                 Row(
                   children: [
                     Expanded(
                       child: Text(
                         name,
                         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                       ),
                     ),
                     if (rating != null) _buildCompactRatingStars(rating),
                   ],
                 ),
                // Description
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
                 // Nutritional Info Chips (if available)
                 if (carbon != null || nutriScore != null || calories != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                       spacing: 8,
                       runSpacing: 4,
                       children: [
                          if (carbon != null) _buildNutritionalChip('${carbon.toStringAsFixed(1)} kg CO2', Icons.eco_outlined, Colors.green),
                          if (nutriScore != null && nutriScore.isNotEmpty && nutriScore != 'N/A') _buildNutritionalChip('Nutri: $nutriScore', Icons.health_and_safety_outlined, _getNutriScoreColor(nutriScore)),
                          if (calories != null) _buildNutritionalChip('${calories.toInt()} cal', Icons.local_fire_department_outlined, Colors.orange),
                       ],
                    )
                 ]
              ],
            ),
          ),
          // Right Column: Price
          if (formattedPrice.isNotEmpty) ...[
            const SizedBox(width: 16),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
               decoration: BoxDecoration(
                 color: Colors.deepPurple.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Text(
                 formattedPrice,
                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 15),
               ),
             ),
          ],
        ],
      ),
    );
  }

  /// Logs the producer profile view activity.
  Future<void> _logProducerViewActivity(String producerId, String producerType) async {
    // Use the userId passed to the widget, assuming it's the logged-in user
    final String? currentUserId = widget.userId; 
    if (currentUserId == null || currentUserId.isEmpty) {
      print('📊 Cannot log producer view: Current user ID not available.');
      return; // Don't log if no user is logged in
    }

    // Get current location (handle null)
    final LatLng? currentLocation = await LocationUtils.getCurrentLocation();
    final LatLng locationToSend = currentLocation ?? LocationUtils.defaultLocation();

    print('📊 Logging producer view: User: $currentUserId, Viewed Producer ID: $producerId, Type: $producerType, Location: $locationToSend');

    // Use the correct producerType based on fetched data or widget param
    String finalProducerType = 'restaurant'; // Default
    if (widget.isWellness) {
      finalProducerType = 'wellness';
    } else if (widget.isBeauty) {
       finalProducerType = 'beauty'; // Assuming a type for beauty
    } else if (producerType.toLowerCase().contains('leisure')) {
       finalProducerType = 'leisure';
    }
    // Add more logic if needed based on producer data fields

    AppDataSenderService.sendActivityLog(
      userId: currentUserId,
      action: 'view_producer', // Specific action type
      location: locationToSend,
      producerId: producerId,
      producerType: finalProducerType, // Use determined type
    );
  }

  /// Generic helper to log producer interaction actions.
  Future<void> _logGenericProducerAction(String action) async {
    final String? currentUserId = widget.userId;
    if (currentUserId == null || currentUserId.isEmpty) {
      // FIXED: Use correct string interpolation
      print('📊 Cannot log action \'$action\': Current user ID not available.');
      return;
    }

    // Get current location
    final LatLng? currentLocation = await LocationUtils.getCurrentLocation();
    final LatLng locationToSend = currentLocation ?? LocationUtils.defaultLocation();

    // Determine producer type more robustly
    String finalProducerType = 'restaurant'; // Default
    if (widget.isWellness) {
      finalProducerType = 'wellness';
    } else if (widget.isBeauty) {
       finalProducerType = 'beauty';
    } else {
        // Try to infer from future data if available
        try {
          final producer = await _producerFuture;
           String? fetchedType = producer['type']?.toString().toLowerCase();
           if (fetchedType != null) {
               if (fetchedType.contains('leisure')) finalProducerType = 'leisure';
               // Add other type checks if needed
           }
        } catch (_) { /* Ignore error if future hasn't completed */ }
    }

    print('📊 Logging Action: User: $currentUserId, Action: $action, Producer: ${widget.producerId}, Type: $finalProducerType, Location: $locationToSend');

    AppDataSenderService.sendActivityLog(
      userId: currentUserId,
      action: action,
      location: locationToSend,
      producerId: widget.producerId, 
      producerType: finalProducerType,
      // Add more metadata if needed (e.g., button clicked)
    );
  }

  // Fetch profile details by ID (adapted from MyProducerProfileScreen)
  Future<Map<String, dynamic>?> _fetchProfileById(String id) async {
    final baseUrl = await constants.getBaseUrl();
    final List<String> endpointsToTry = [
       '$baseUrl/api/users/$id',
       '$baseUrl/api/producers/$id', // Try producer endpoint too
       '$baseUrl/api/unified/$id',
       '$baseUrl/api/leisureProducers/$id',
    ];

    for (final endpoint in endpointsToTry) {
       try {
         print('🔍 Fetching profile details from: $endpoint');
         final response = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 7));
         if (response.statusCode == 200) {
            print('✅ Profile found via $endpoint');
            final profileData = json.decode(response.body);
            // Basic check if it's a valid profile structure (e.g., contains an _id or name)
            if (profileData is Map<String, dynamic> && (profileData.containsKey('_id') || profileData.containsKey('name'))) {
               return profileData;
            } else {
                print('⚠️ Invalid profile structure received from $endpoint');
            }
         } else {
           print('ℹ️ Profile not found or error at $endpoint (Status: ${response.statusCode})');
         }
       } catch (e) {
         print('❌ Network error or timeout fetching from $endpoint: $e');
       }
    }

    print('❌ Aucun profil valide trouvé pour l\'ID : $id across all endpoints.');
    return null;
  }

  // Validate a list of profile IDs (adapted from MyProducerProfileScreen)
  Future<List<Map<String, dynamic>>> _validateProfiles(List<String> ids) async {
    List<Map<String, dynamic>> validProfiles = [];
    print('🔍 Validating ${ids.length} profile IDs: ${ids.join(', ')}');

    // Use Future.wait for parallel fetching
    final List<Future<Map<String, dynamic>?>> fetchFutures = ids.map(_fetchProfileById).toList();
    final List<Map<String, dynamic>?> results = await Future.wait(fetchFutures);

    for (final profile in results) {
      if (profile != null) {
        validProfiles.add(profile);
      }
    }
    print('✅ Validation complete. Found ${validProfiles.length} valid profiles.');
    return validProfiles;
  }

  // Navigate to relation details screen (adapted from MyProducerProfileScreen)
  void _navigateToRelationDetails(String title, List<String> ids) async {
     if (ids.isEmpty) {
        print('ℹ️ No IDs provided for "$title". Cannot navigate.');
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Aucun profil à afficher pour "$title".')),
        );
        return;
     }

     // Show loading indicator while fetching profiles
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (context) => const Center(child: CircularProgressIndicator()),
     );

     try {
       final validProfiles = await _validateProfiles(ids);
       Navigator.pop(context); // Close loading indicator

       if (validProfiles.isNotEmpty && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RelationDetailsScreen(
                title: title,
                profiles: validProfiles,
              ),
            ),
          );
       } else {
          print('❌ Aucun profil valide trouvé pour les IDs de "$title".');
          if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Aucun profil valide trouvé pour "$title".')),
             );
          }
       }
     } catch (e) {
        Navigator.pop(context); // Close loading indicator on error
        print('❌ Error validating profiles for "$title": $e');
        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Erreur lors de la récupération des profils pour "$title".')),
            );
        }
     }
  }

  // --- Shimmer Widgets ---

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(), // Disable scroll for shimmer
        children: [
          // App Bar Placeholder
          Container(height: 200, color: Colors.white),
          // Header Placeholder
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 200, height: 24.0, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 150, height: 16.0, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 250, height: 16.0, color: Colors.white),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (_) => const CircleAvatar(radius: 25, backgroundColor: Colors.white)),
                ),
              ],
            ),
          ),
          // Tab Bar Placeholder
          Container(height: 50, color: Colors.white),
          // Tab Content Placeholder (basic)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(5, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(width: double.infinity, height: 80.0, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              )),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPostsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 5, // Show 5 shimmer cards
        itemBuilder: (_, __) => Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 20, backgroundColor: Colors.white),
                    const SizedBox(width: 12),
                    Container(width: 100, height: 16, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 12),
                Container(width: 200, height: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuShimmer() {
     return Shimmer.fromColors(
       baseColor: Colors.grey[300]!,
       highlightColor: Colors.grey[100]!,
       child: ListView.builder(
         padding: const EdgeInsets.all(16),
         itemCount: 6, // Show 6 shimmer items/cards
         itemBuilder: (_, __) => Padding(
           padding: const EdgeInsets.only(bottom: 16.0),
           child: Container(
             height: 100,
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(16),
             ),
           ),
         ),
       ),
     );
   }

  // --- End Shimmer Widgets ---

  // --- Error Widget ---
  Widget _buildErrorWidget(String errorMessage, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              "Oups ! Quelque chose s'est mal passé", // Use double quotes for the string
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: onRetry, // Use the passed retry function
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary, // Use Theme color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- End Error Widget ---

  // +++ ADD NAVIGATION FUNCTION +++
  // Navigate to the user list screen
  void _navigateToUserList(String listType, List<String> userIds) {
    if (!mounted) return;
    print("Navigating to user list: type=$listType, count=${userIds.length}");
    if (userIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("La liste '$listType' est vide.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserListScreen(
          parentId: widget.producerId, // Pass producer ID
          listType: listType,
          initialUserIds: userIds, // Pass the IDs directly
          // Optional: Pass a function to fetch user info if needed within UserListScreen
          // fetchUserInfoFunction: _fetchMinimalUserInfo, // Needs _fetchMinimalUserInfo implementation here or passed
        ),
      ),
    );
  }
  // +++ END NAVIGATION FUNCTION +++

  // +++ ADD _ProducerStats WIDGET (Similar to _ProfileStats) +++
  //==============================================================================
  // WIDGET: _ProducerStats
  //==============================================================================
  Widget _ProducerStats({
    required int followersCount,
    required int followingCount,
    required int interestedCount,
    required int choicesCount,
    required List<String> followerIds,
    required List<String> followingIds,
    required List<String> interestedUserIds,
    required List<String> choiceUserIds,
    required Function(String, List<String>) onNavigateToUserList,
  }) {
    return Container(
      color: Colors.white, // Match profile style
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatButton(
            context,
            icon: Icons.people_outline,
            label: 'Abonnés', // Followers
            count: followersCount,
            onTap: () => onNavigateToUserList('Abonnés', followerIds) // Use 'Abonnés' or 'followers'
          ),
          _verticalDivider(),
          // Only include Following if producers can follow others
          // _buildStatButton(
          //   context,
          //   icon: Icons.person_add_alt_1_outlined, // Or appropriate icon
          //   label: 'Abonnements', // Following
          //   count: followingCount,
          //   onTap: () => onNavigateToUserList('Abonnements', followingIds) // Use 'Abonnements' or 'following'
          // ),
          // _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.emoji_objects_outlined, // Interested
            label: 'Intéressés',
            count: interestedCount,
            onTap: () => onNavigateToUserList('Intéressés', interestedUserIds) // Use 'Intéressés' or 'interested'
          ),
          _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.check_circle_outline, // Choices
            label: 'Choices',
            count: choicesCount,
            onTap: () => onNavigateToUserList('Choices', choiceUserIds) // Use 'Choices' or 'choices'
          ),
        ],
      ),
    );
  }

  // Copied from myprofile_screen.dart - needed by _ProducerStats
  Widget _buildStatButton(BuildContext context, {required IconData icon, required String label, required int count, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(minWidth: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.teal, size: 24),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Copied from myprofile_screen.dart - needed by _ProducerStats
  Widget _verticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[200]);
  }
  // +++ END _ProducerStats WIDGET +++
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context, 
    double shrinkOffset, 
    bool overlapsContent,
  ) {
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