import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'eventLeisure_screen.dart';
import 'utils.dart';
import '../services/payment_service.dart';
import '../utils/leisureHelpers.dart';  // Add this import for getEventImageUrl
import 'login_user.dart';  // Import for LoginUserPage
import 'myeventsmanagement_screen.dart';  // Import for MyEventsManagementScreen
import '../services/api_service.dart';
import '../utils/constants.dart' as constants;
import '../utils.dart' show getImageProvider;

class MyProducerLeisureProfileScreen extends StatefulWidget {
  final String userId;
  final String? token;

  const MyProducerLeisureProfileScreen({
    Key? key, 
    required this.userId,
    this.token,
  }) : super(key: key);

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
  
  // Photo de profil
  Uint8List? _profileImageBytes;
  bool _isUploadingImage = false;
  
  // Animation properties
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Discount related properties
  bool _hasActiveDiscount = false;
  double _discountPercentage = 10.0; // Default discount percentage
  DateTime? _discountEndDate;

  // Ajouter les propriétés manquantes au début de la classe
  String? _error;
  String? _errorEvents;
  bool _isLoadingEvents = false;
  List<dynamic> _producerEvents = [];

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

  // Méthode pour mettre à jour la photo de profil
  Future<void> _updateProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (image == null) return;
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      // Lire l'image en bytes
      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      } else {
        final File imageFile = File(image.path);
        imageBytes = await imageFile.readAsBytes();
      }
      
      setState(() {
        _profileImageBytes = imageBytes;
      });
      
      // Convertir l'image en base64 pour l'envoi
      final base64Image = base64Encode(imageBytes);
      final baseUrl = await constants.getBaseUrl();
      
      // Déterminer l'URL de mise à jour d'image
      final endpoints = [
        '/api/producers/${widget.userId}/photo',
        '/api/leisureProducers/${widget.userId}/photo',
        '/api/venues/${widget.userId}/photo',
      ];
      
      bool success = false;
      
      // Essayer chaque endpoint jusqu'à réussir
      for (final endpoint in endpoints) {
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, endpoint);
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, endpoint);
        }
        
        try {
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'photo': 'data:image/jpeg;base64,$base64Image',
            }),
          );
          
          if (response.statusCode == 200) {
            success = true;
            print('✅ Photo mise à jour avec succès via: $endpoint');
            
            // Actualiser les données du producteur
            setState(() {
              _producerFuture = _fetchProducerData(widget.userId);
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo de profil mise à jour avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            
            break;
          } else {
            print('❌ Échec de mise à jour via $endpoint: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Erreur lors de la mise à jour via $endpoint: $e');
        }
      }
      
      if (!success) {
        // Si tous les endpoints ont échoué, essayer avec photo_url
        for (final endpoint in endpoints) {
          Uri url;
          if (baseUrl.startsWith('http://')) {
            final domain = baseUrl.replaceFirst('http://', '');
            url = Uri.http(domain, endpoint);
          } else {
            final domain = baseUrl.replaceFirst('https://', '');
            url = Uri.https(domain, endpoint);
          }
          
          try {
            final response = await http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'photo_url': 'data:image/jpeg;base64,$base64Image',
              }),
            );
            
            if (response.statusCode == 200) {
              success = true;
              print('✅ Photo mise à jour avec succès via photo_url: $endpoint');
              
              // Actualiser les données du producteur
              setState(() {
                _producerFuture = _fetchProducerData(widget.userId);
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo de profil mise à jour avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
              
              break;
            }
          } catch (e) {
            print('❌ Erreur lors de la mise à jour via photo_url $endpoint: $e');
          }
        }
      }
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de mettre à jour la photo de profil'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors du traitement de l\'image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  // Méthode pour afficher la photo de profil du producteur avec gestion avancée
  Widget _buildProfileImage(Map<String, dynamic> data) {
    // Chercher l'URL de la photo dans différents champs possibles
    final photo = data['photo'] ?? data['photo_url'] ?? data['image'] ?? data['picture'];
    
    return GestureDetector(
      onTap: _updateProfileImage,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _profileImageBytes != null
                ? ClipOval(
                    child: Image.memory(
                      _profileImageBytes!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    ),
                  )
                : ClipOval(
                    child: photo != null
                        ? Image.network(
                            photo,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Erreur de chargement d\'image: $error');
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ?? 1)
                                      : null,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 5,
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithPhoto(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.only(top: 30, bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo de profil
              _buildProfileImage(data),
              const SizedBox(width: 20),
              
              // Informations principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStringSafe(data, ['lieu', 'name']) ?? 'Nom non spécifié',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black26,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Catégorie avec badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStringSafe(data, ['catégorie', 'category']) ?? 'Catégorie non spécifiée',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Adresse
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getStringSafe(data, ['adresse', 'address']) ?? 'Adresse non spécifiée',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Notation 
                    if (data['note'] != null || data['rating'] != null || data['note_google'] != null)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatRating(data)} / 5',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${_formatReviewCount(data)} avis)',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Edit Profile Button
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                onPressed: () => _showEditLeisureProfileDialog(data),
                tooltip: 'Modifier le profil',
              ),
            ),
          ),
          
          // Statistiques rapides
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.calendar_today,
                  value: data['nombre_evenements']?.toString() ?? '0',
                  label: 'Événements',
                ),
                _buildStatItem(
                  icon: Icons.people,
                  value: data['abonnés']?.length.toString() ?? '0',
                  label: 'Abonnés',
                ),
                _buildStatItem(
                  icon: Icons.favorite,
                  value: data['likes']?.toString() ?? '0',
                  label: 'J\'aime',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchProducerData(String userId) async {
    try {
      final baseUrl = await constants.getBaseUrl();
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
      final baseUrl = await constants.getBaseUrl();
      
      // Method 1: Try the dedicated producer events endpoint
      try {
        Uri url;
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, '/api/leisureProducers/$userId/events');
        } else {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, '/api/leisureProducers/$userId/events');
        }
        
        print('🔍 Trying leisureProducers events API: $url');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          List<dynamic> data = [];
          
          if (decoded is Map && decoded.containsKey('events')) {
            // Format: { events: [...] }
            data = List<dynamic>.from(decoded['events']);
          } else if (decoded is List) {
            // Format: direct array
            data = decoded;
          }
          
          print('✅ Found ${data.length} events via leisureProducers events API');
          allEvents.addAll(data);
          anySuccess = true;
        } else {
          print('⚠️ LeisureProducers events API returned ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error with leisureProducers events API: $e');
      }
      
      // Method 2: Try the regular producers events endpoint
      if (allEvents.isEmpty) {
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
            final decoded = json.decode(response.body);
            List<dynamic> data = [];
            
            if (decoded is Map && decoded.containsKey('events')) {
              // Format: { events: [...] }
              data = List<dynamic>.from(decoded['events']);
            } else if (decoded is List) {
              // Format: direct array
              data = decoded;
            }
            
            print('✅ Found ${data.length} events via producer events API');
            allEvents.addAll(data);
            anySuccess = true;
          } else {
            print('⚠️ Producer events API returned ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error with producer events API: $e');
        }
      }
      
      // Method 3: Try the general events endpoint with filtering
      if (allEvents.isEmpty) {
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
            final decoded = json.decode(response.body);
            List<dynamic> data = [];
            
            if (decoded is Map && decoded.containsKey('events')) {
              // Format: { events: [...] }
              data = List<dynamic>.from(decoded['events']);
            } else if (decoded is List) {
              // Format: direct array
              data = decoded;
            }
            
            print('✅ Found ${data.length} events via general events API');
            allEvents.addAll(data);
            anySuccess = true;
          } else {
            print('⚠️ General events API returned ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error with general events API: $e');
        }
      }
      
      // Si nous avons des événements, les normaliser pour avoir un format uniforme
      if (allEvents.isNotEmpty) {
        // Normaliser les événements pour avoir une structure de données cohérente
        return allEvents.map((event) {
          if (event is Map<String, dynamic>) {
            // S'assurer que l'événement a tous les champs nécessaires
            return {
              '_id': event['_id'] ?? event['id'] ?? '',
              'title': event['title'] ?? event['intitulé'] ?? 'Événement sans titre',
              'description': event['description'] ?? event['détail'] ?? '',
              'date': event['date'] ?? event['date_debut'] ?? event['startDate'] ?? '',
              'venue': event['venue'] ?? event['lieu'] ?? '',
              'image': event['image'] ?? event['photo'] ?? '',
              ...event, // Conserver toutes les autres propriétés
            };
          }
          return event;
        }).toList();
      }
      
      // Si aucune méthode n'a fonctionné, retourner une liste vide
      print('⚠️ No events found for producer $userId');
      return [];
    } catch (e) {
      print('❌ Error fetching producer events: $e');
      return [];
    }
  }

  Future<List<dynamic>> _fetchProducerPosts(String userId) async {
    final baseUrl = await constants.getBaseUrl();
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
      final baseUrl = await constants.getBaseUrl();
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

  DateTime? _parseEventDate(String dateStr) {
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
      
      // If we can't parse, return null
      return null;
    } catch (e) {
      // If there's an error, return null
      return null;
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
      final baseUrl = await constants.getBaseUrl();
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
                          Text(
                            DateFormat('dd/MM/yyyy').format(selectedEndDate),
                          ),
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
                  Text('Erreur: ${snapshot.error}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
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

          final producer = snapshot.data!;
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: Colors.blue.shade700,
                  elevation: 0,
                  floating: true,
                  pinned: true,
                  expandedHeight: 320,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeaderWithPhoto(producer),
                  ),
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(producer),
                _buildEventsTab(producer),
                _buildStatisticsTab(producer),
              ],
            ),
          );
        },
      ),
    );
  }

  // Construire l'onglet de profil
  Widget _buildProfileTab(Map<String, dynamic> producer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte d'information du profil
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Informations générales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  if (producer['description'] != null && producer['description'].toString().isNotEmpty) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      producer['description'].toString(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Catégories/Types
                  const Text(
                    'Catégories',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getCategoriesFromProducer(producer).map((category) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Adresse
                  const Text(
                    'Adresse',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          producer['adresse'] ?? producer['address'] ?? 'Non spécifiée',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Coordonnées de contact
                  const Text(
                    'Contact',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (producer['email'] != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          producer['email'],
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (producer['téléphone'] != null || producer['phone'] != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          producer['téléphone'] ?? producer['phone'] ?? 'Non spécifié',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Extraire les catégories du producteur
  List<String> _getCategoriesFromProducer(Map<String, dynamic> producer) {
    final categories = <String>[];
    
    if (producer['catégorie'] != null) {
      if (producer['catégorie'] is String) {
        categories.add(producer['catégorie']);
      } else if (producer['catégorie'] is List) {
        categories.addAll((producer['catégorie'] as List).map((e) => e.toString()));
      }
    }
    
    if (producer['category'] != null) {
      if (producer['category'] is String) {
        categories.add(producer['category']);
      } else if (producer['category'] is List) {
        categories.addAll((producer['category'] as List).map((e) => e.toString()));
      }
    }
    
    if (producer['type'] != null && !categories.contains(producer['type'])) {
      categories.add(producer['type'].toString());
    }
    
    if (categories.isEmpty) {
      categories.add('Loisirs');
    }
    
    return categories;
  }

  // Construire l'onglet d'événements
  Widget _buildEventsTab(Map<String, dynamic> producer) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerEvents(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erreur: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }
        
        final events = snapshot.data ?? [];
        return _buildEventsSection(events);
      },
    );
  }
  
  // Construire l'onglet de statistiques
  Widget _buildStatisticsTab(Map<String, dynamic> producer) {
    // Extract counts safely using the helper function
    final int followersCount = _getSafeCount(producer, 'followers', numberKey: 'abonnés');
    final int interestedCount = _getSafeCount(producer, 'interestedUsers');
    final int choicesCount = _getSafeCount(producer, 'choiceUsers');
    final int eventCount = _getSafeCount(producer, 'evenements', listKey: 'nombre_evenements'); // Use 'nombre_evenements' if 'evenements' isn't a list

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques Clés',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Événements', eventCount.toString(), Icons.event, Colors.blue),
              _buildStatCard('Followers', followersCount.toString(), Icons.people, Colors.purple),
              _buildStatCard('Intéressés', interestedCount.toString(), Icons.star, Colors.amber),
              _buildStatCard('Choix', choicesCount.toString(), Icons.check_circle, Colors.green),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Plus de statistiques bientôt disponibles!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper widget for statistics cards
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Affichage amélioré des événements avec photos et interface cliquable
  Widget _buildEventsSection(List<dynamic> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy,
                size: 70,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun événement disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyEventsManagementScreen(
                      producerId: widget.userId,
                      token: widget.token,
                    ),
                  ),
                ).then((_) {
                  // Recharger les données au retour
                  setState(() {
                    _producerFuture = _fetchProducerData(widget.userId);
                  });
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer un événement'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec bouton d'ajout
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.event_note, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mes événements (${events.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyEventsManagementScreen(
                        producerId: widget.userId,
                        token: widget.token,
                      ),
                    ),
                  ).then((_) {
                    // Recharger les données au retour
                    setState(() {
                      _producerFuture = _fetchProducerData(widget.userId);
                    });
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Liste des événements sous forme de cartes modernes
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final isUpcoming = !isEventPassed(event);
              
              return _buildEventCard(event, isUpcoming);
            },
          ),
        ),
      ],
    );
  }

  // Vérifie si un événement est passé
  bool isEventPassed(Map<String, dynamic> event) {
    try {
      final dateStr = event['date_debut']?.toString() ?? event['prochaines_dates']?.toString() ?? '';
      if (dateStr.isEmpty) return false;

      // Use nullable DateTime
      final DateTime? eventDate = _parseEventDate(dateStr);
      // If date couldn't be parsed, assume it's not passed (or handle as needed)
      if (eventDate == null) return false; 

      return eventDate.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // Carte d'événement modernisée
  Widget _buildEventCard(Map<String, dynamic> event, bool isUpcoming) {
    // Extraire l'URL de l'image avec gestion de différents formats
    final imageUrl = _getEventImageUrl(event);
    final title = event['intitulé'] ?? event['titre'] ?? event['name'] ?? 'Événement sans titre';
    final location = event['lieu'] ?? event['adresse'] ?? '';
    
    // Extraire les dates
    String dateStr = event['date_debut'] ?? event['prochaines_dates'] ?? '';
    if (dateStr.isEmpty && event['date'] != null) {
      dateStr = event['date'].toString();
    }
    
    String formattedDate = 'Date non spécifiée';
    try {
      // Use nullable DateTime
      final DateTime? eventDate = _parseEventDate(dateStr);
      if (eventDate != null) {
      formattedDate = DateFormat('dd/MM/yyyy').format(eventDate);
      }
    } catch (e) {
      // Utiliser la chaîne brute si le parsing échoue
      formattedDate = dateStr;
    }
    
    // Statut de publication
    final isPublished = event['published'] == true || event['status'] == 'published';
    
    return GestureDetector(
      onTap: () => _navigateToEventDetails(context, event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de l'événement
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16/9,
                  child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ?? 1)
                                    : null,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue.shade300,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            Icons.event,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                ),
                
                // Badge de statut (à venir/passé)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isUpcoming ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isUpcoming ? 'À venir' : 'Passé',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                
                // Badge de publication
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPublished ? Colors.blue : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPublished ? 'Publié' : 'Brouillon',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Contenu de l'événement
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Lieu
                  if (location.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Description
                  if (event['description'] != null && event['description'].toString().isNotEmpty) ...[
                    Text(
                      event['description'].toString(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToEventDetails(context, event),
                          icon: Icon(Icons.visibility, size: 16, color: Colors.blue[700]),
                          label: const Text('Voir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[700],
                            side: BorderSide(color: Colors.blue[700]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToEventEdit(event),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Modifier'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blue,
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
          ],
        ),
      ),
    );
  }
  
  // Récupère l'URL de l'image d'un événement avec gestion des différents formats possibles
  String? _getEventImageUrl(Map<String, dynamic> event) {
    // Gestion de tous les formats possibles d'images trouvés dans MongoDB
    final String? imageUrl = event['image'] ?? 
                           event['photo'] ?? 
                           event['image_url'] ?? 
                           event['photo_url'] ??
                           event['cover_image'] ??
                           event['banner_image'];
    
    // Si nous avons une URL d'image valide, la retourner directement
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) return imageUrl;
      if (imageUrl.startsWith('data:image')) return imageUrl;
    }
    
    // Si nous avons un ID d'image Google Places
    final String? photoRef = event['photo_reference'];
    if (photoRef != null && photoRef.isNotEmpty) {
      return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoRef&key=AIzaSyC3M0DEYzY9GurLDWvYi3k_maPI8QMFJtA';
    }
    
    // Si nous avons un ID d'événement, essayer de construire une URL d'image
    final String eventId = event['_id']?.toString() ?? '';
    if (eventId.isNotEmpty) {
      return '${getBaseUrl()}/api/events/$eventId/image';
    }
    
    return null;
  }

  // Navigation vers les détails d'un événement
  void _navigateToEventDetails(BuildContext context, dynamic event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyEventsManagementScreen(
          producerId: widget.userId,
          token: widget.token,
        ),
      ),
    );
  }
  
  // Navigation vers l'édition d'un événement
  void _navigateToEventEdit(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyEventsManagementScreen(
          producerId: widget.userId,
          token: widget.token,
        ),
      ),
    ).then((_) {
      // Recharger les données au retour
      setState(() {
        _producerFuture = _fetchProducerData(widget.userId);
      });
    });
  }

  _editEvent(dynamic event) async {
    print("Édition de l'événement: ${event['_id']}");
    
    // Naviguer vers EventLeisureScreen avec mode édition
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventLeisureScreen(
          eventData: event,
          isEditMode: true,
        ),
      ),
    );
    
    // Recharger les événements après modification
    _loadProducerEvents();
  }

  _manageEvents() async {
    print("Gestion des événements");
    
    // Naviguer vers l'écran de gestion des événements
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyEventsManagementScreen(
          producerId: widget.userId,
          token: widget.token,
        ),
      ),
    );
    
    // Recharger les données
    _loadProducerData();
    _loadProducerEvents();
  }

  Future<void> _loadProducerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Appel à l'API pour récupérer les données du producteur
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/producers/${widget.userId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _producerData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur lors du chargement des données du producteur';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur réseau: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducerEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      // Appel à l'API pour récupérer les événements du producteur
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/producers/${widget.userId}/events'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _producerEvents = data['events'] ?? [];
          _isLoadingEvents = false;
        });
      } else {
        setState(() {
          _errorEvents = 'Erreur lors du chargement des événements';
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorEvents = 'Erreur réseau: $e';
        _isLoadingEvents = false;
      });
    }
  }

  // Show Edit Profile Dialog
  void _showEditLeisureProfileDialog(Map<String, dynamic> currentData) {
    final nameController = TextEditingController(text: _getStringSafe(currentData, ['lieu', 'name']));
    final descriptionController = TextEditingController(text: _getStringSafe(currentData, ['description']));
    final addressController = TextEditingController(text: _getStringSafe(currentData, ['adresse', 'address']));
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Modifier le profil'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du lieu',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Note: Category editing might be complex for a dialog.
                  // Note: Photo editing is handled by tapping the profile picture.
                  if (isUpdating)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
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
                  backgroundColor: Colors.blue,
                ),
                onPressed: isUpdating ? null : () async {
                  setStateDialog(() {
                    isUpdating = true;
                  });
                  final updatedData = {
                    'name': nameController.text,
                    'lieu': nameController.text, // Ensure both are updated if needed
                    'description': descriptionController.text,
                    'address': addressController.text,
                    'adresse': addressController.text, // Ensure both are updated
                  };
                  bool success = await _updateLeisureProfile(updatedData);
                  setStateDialog(() {
                    isUpdating = false;
                  });
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil mis à jour avec succès!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Refresh data
                    setState(() {
                      _producerFuture = _fetchProducerData(widget.userId);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Échec de la mise à jour du profil.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Update Leisure Profile via API
  Future<bool> _updateLeisureProfile(Map<String, dynamic> updateData) async {
    try {
      final baseUrl = await constants.getBaseUrl();
      Uri url;
      // Use the leisureProducers endpoint as it's the one confirmed working for GET
      final endpoint = '/api/leisureProducers/${widget.userId}';
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, endpoint);
      } else {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, endpoint);
      }

      print('⬆️ Sending PUT request to $url with data: ${json.encode(updateData)}');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Add Authorization header if needed
          // 'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        print('✅ Profil leisure mis à jour avec succès');
        return true;
      } else {
        print('❌ Échec de la mise à jour du profil leisure: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur réseau lors de la mise à jour du profil leisure: $e');
      return false;
    }
  }

  // Helper function to safely get a string from dynamic data (handles String and List<String>)
  String _getStringSafe(dynamic data, List<String> possibleKeys, [String defaultValue = '']) {
    for (final key in possibleKeys) {
      if (data is Map && data.containsKey(key)) {
        final value = data[key];
        if (value is String) {
          return value;
        } else if (value is List && value.isNotEmpty && value[0] is String) {
          // If it's a list of strings, return the first element
          return value[0];
        }
      }
    }
    return defaultValue;
  }

  // Helper to parse rating from various fields (note, rating, note_google)
  String _formatRating(Map<String, dynamic> data) {
    dynamic ratingValue = data['note'] ?? data['rating'];
    String ratingStr = '';

    if (ratingValue != null) {
      if (ratingValue is num) {
        ratingStr = ratingValue.toStringAsFixed(1);
      } else if (ratingValue is String) {
        // Try parsing as double, handling potential errors
        final parsedDouble = double.tryParse(ratingValue.replaceAll(',', '.'));
        if (parsedDouble != null) {
          ratingStr = parsedDouble.toStringAsFixed(1);
        }
      }
    }

    // If still no rating, try note_google
    if (ratingStr.isEmpty && data['note_google'] is String) {
      final noteGoogle = data['note_google'] as String;
      // Extract the number before the newline or parenthesis
      final match = RegExp(r'^([\\d,.]+)').firstMatch(noteGoogle);
      if (match != null && match.group(1) != null) {
        final parsedDouble = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (parsedDouble != null) {
          ratingStr = parsedDouble.toStringAsFixed(1);
        }
      }
    }

    return ratingStr.isNotEmpty ? '$ratingStr / 5' : 'N/A';
  }

  // Helper to parse review count from various fields (avis, reviews_count, note_google)
  String _formatReviewCount(Map<String, dynamic> data) {
    int? count;
    if (data['avis'] is List) {
      count = (data['avis'] as List).length;
    } else if (data['reviews_count'] is int) {
      count = data['reviews_count'];
    } else if (data['reviews_count'] is String) {
      count = int.tryParse(data['reviews_count']);
    }

    // If still no count, try note_google
    if (count == null && data['note_google'] is String) {
      final noteGoogle = data['note_google'] as String;
      // Extract the number within parentheses
      final match = RegExp(r'\\(([^\\)]+)\\)').firstMatch(noteGoogle);
      if (match != null && match.group(1) != null) {
        // Remove non-digit characters (like dots or spaces used as thousands separators)
        final cleanedCountStr = match.group(1)!.replaceAll(RegExp(r'\\D'), '');
        count = int.tryParse(cleanedCountStr);
      }
    }

    return '(${count ?? 0} avis)';
  }

  // Helper function to safely calculate counts from various data structures
  int _getSafeCount(Map<String, dynamic> data, String primaryKey, {String? listKey, String? numberKey}) {
    if (data[primaryKey] != null) {
      if (data[primaryKey] is Map && data[primaryKey]['count'] is int) {
        return data[primaryKey]['count'];
      }
      if (data[primaryKey] is List) {
        return (data[primaryKey] as List).length;
      }
    }
    if (listKey != null && data[listKey] is List) {
      return (data[listKey] as List).length;
    }
    if (numberKey != null && data[numberKey] is num) {
      return (data[numberKey] as num).toInt();
    }
    return 0;
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