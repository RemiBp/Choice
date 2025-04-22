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
import 'package:cached_network_image/cached_network_image.dart'; // Import CachedNetworkImage
// Add necessary imports for AuthService and Provider
import 'package:provider/provider.dart' as provider_pkg;
import '../services/auth_service.dart';

import 'eventLeisure_screen.dart';
import 'utils.dart';
import '../services/payment_service.dart';
import '../utils/leisureHelpers.dart';  // Add this import for getEventImageUrl
import 'login_user.dart';  // Import for LoginUserPage
import 'myeventsmanagement_screen.dart';  // Import for MyEventsManagementScreen
import 'myeventsmanagement_screen.dart' show formatDisplayDate;
// Import a potential User List Screen (adjust path if needed)
// import 'user_list_screen.dart'; 
// Import a potential Event Detail Screen (adjust path if needed)
// import 'event_detail_screen.dart'; 
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

  // State variables for stats
  int _followersCount = 0;
  int _followingCount = 0;
  int _interestedCount = 0;
  int _choiceCount = 0;
  int _eventsCount = 0;

  /// Formatte une date pour l'affichage selon le format français
  String formatDisplayDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'Date non disponible';
      
      DateTime date;
      
      // Convertir une chaîne en DateTime
      if (dateValue is String) {
        // Essayer différents formats de date
        try {
          date = DateTime.parse(dateValue);
        } catch (e) {
          // Gérer le format DD/MM/YYYY
          if (dateValue.contains('/')) {
            final parts = dateValue.split('/');
            if (parts.length == 3) {
              final day = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              date = DateTime(year, month, day);
            } else {
              return dateValue; // Retourner la valeur d'origine si non parsable
            }
          } else {
            return dateValue; // Retourner la valeur d'origine si non parsable
          }
        }
      } 
      // Utiliser directement un DateTime
      else if (dateValue is DateTime) {
        date = dateValue;
      }
      // Cas non géré
      else {
        return dateValue.toString();
      }
      
      // Formater la date pour l'affichage en français
      final DateFormat formatter = DateFormat('EEE d MMMM yyyy', 'fr_FR');
      return formatter.format(date).toLowerCase();
    } catch (e) {
      print('❌ Erreur lors du formatage de la date "$dateValue": $e');
      return 'Date invalide';
    }
  }

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
    final photo = _getStringSafe(data, ['photo', 'photo_url', 'image', 'picture', 'avatar', 'logoUrl']);
    final imageProvider = getImageProvider(photo); // Use utility function
    
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
                    // Use CachedNetworkImage for better handling
                    child: imageProvider != null
                      ? CachedNetworkImage(
                          imageUrl: photo, // Assume photo is the URL string
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                          ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                            Icons.festival, // More relevant icon for leisure
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
          // Use a purple gradient for leisure
          colors: [Colors.deepPurple.shade700, Colors.purple.shade500],
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
                  mainAxisAlignment: MainAxisAlignment.center, // Vertically center content
                  children: [
                    Text(
                      _getStringSafe(data, ['lieu', 'name']) ?? 'Lieu de Loisir', // Default text
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
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getStringSafe(data, ['adresse', 'address']) ?? 'Adresse non spécifiée',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 2, // Allow 2 lines for address
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
                          const SizedBox(width: 6),
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
          Align(
             alignment: Alignment.topRight,
             child: Padding(
               padding: const EdgeInsets.only(top: 4.0), // Adjust padding
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                   icon: const Icon(Icons.edit, color: Colors.white, size: 18), // Smaller icon
                onPressed: () => _showEditLeisureProfileDialog(data),
                tooltip: 'Modifier le profil',
                   constraints: BoxConstraints(), // Remove default constraints for smaller button
                   padding: EdgeInsets.all(6), // Adjust padding
              ),
            ),
          ),
           )
        ], // Row: Image + Text
      ), // Container padding
    ); // Outer Container
  }
  
  // NEW: Widget for the stats bar
  Widget _buildStatsBar(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Reduced horizontal padding
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
          _buildStatItemClickable(
            // Use state variables updated in _fetchProducerData
                  label: 'Événements',
            value: _eventsCount, 
            icon: Icons.event_note, 
            onTap: () { _tabController.animateTo(1); } // Navigate to Events tab
                ),
          _buildStatItemClickable(
                  label: 'Abonnés',
            value: _followersCount, 
            icon: Icons.people_outline, // Use outline icons
            onTap: () => _navigateToUserList('followers', data['_id'])
          ),
          _buildStatItemClickable(
            label: 'Intéressés', 
            value: _interestedCount,
            icon: Icons.star_border, // Use outline icons
            onTap: () => _navigateToUserList('interested', data['_id'])
          ),
          _buildStatItemClickable(
            label: 'Choix', 
            value: _choiceCount,
            icon: Icons.check_circle_outline, // Use outline icons
            onTap: () => _navigateToUserList('choices', data['_id'])
          ),
        ],
      ),
    );
  }
  
  // NEW: Reusable clickable stat item
  Widget _buildStatItemClickable({
    required String label,
    required int value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // Add padding
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevent taking too much space
      children: [
            Icon(icon, color: Colors.white, size: 22), // Slightly smaller icon
            const SizedBox(height: 4),
        Text(
              NumberFormat.compact().format(value), // Format large numbers
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
                fontSize: 16, // Slightly smaller font
          ),
        ),
            const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
                fontSize: 11, // Smaller label font
          ),
        ),
      ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchProducerData(String userId) async {
    _isLoading = true; // Set loading state
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
        
        // ---> Update state variables for stats bar
        setState(() {
          // Check if _producerData is not null before accessing it
          if (_producerData != null) {
            _followersCount = _getSafeCount(_producerData!, 'followers', numberKey: 'abonnés');
            _followingCount = _getSafeCount(_producerData!, 'following'); // Assuming 'following' key exists
            _interestedCount = _getSafeCount(_producerData!, 'interestedUsers');
            _choiceCount = _getSafeCount(_producerData!, 'choiceUsers');
            // Prioritize count field, then array length, then default to 0
            _eventsCount = _getSafeCount(_producerData!, 'nombre_evenements', listKey: 'evenements');
          } else {
             // Set counts to 0 if _producerData is null
             _followersCount = 0;
             _followingCount = 0;
             _interestedCount = 0;
             _choiceCount = 0;
             _eventsCount = 0;
          }
        });
        // <--- End stats update
        
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
          'nombre_evenements': 0, // Ensure default count is 0
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
    } finally {
      if(mounted) { // Check if mounted before calling setState
        setState(() {
          _isLoading = false; // Clear loading state
        });
      }
    }
  }
  
  /// Ensures the producer data has all required fields in standard format
  void _normalizeProducerData(Map<String, dynamic> data) {
    // Ensure standard profile fields exist
    if (!data.containsKey('photo') && data.containsKey('image')) {
      data['photo'] = data['image'];
    }
    if (!data.containsKey('photo') && data.containsKey('photo_url')) {
      data['photo'] = data['photo_url'];
    }
    // Ensure a default photo if none found
    if (!data.containsKey('photo') || data['photo'] == null || data['photo'].toString().isEmpty) {
        data['photo'] = 'https://via.placeholder.com/150?text=Lieu'; // Default placeholder
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
    
    // Make sure evenements is initialized (as list or ensure count field)
    if (!data.containsKey('evenements') && !data.containsKey('nombre_evenements')) {
      data['evenements'] = [];
      data['nombre_evenements'] = 0;
    } else if (data.containsKey('evenements') && data['evenements'] is List && !data.containsKey('nombre_evenements')) {
      // If only the list exists, add the count field
      data['nombre_evenements'] = (data['evenements'] as List).length;
    } else if (!data.containsKey('evenements') && data.containsKey('nombre_evenements')) {
      // If only the count exists, initialize an empty list (less common)
      data['evenements'] = [];
    }
    
    // Make sure posts is initialized
    if (!data.containsKey('posts')) {
      data['posts'] = [];
    }
  }

  Future<List<dynamic>> _fetchProducerEvents(String userId) async {
    // First, check if events are already in _producerData
    if (_producerData != null && _producerData!['evenements'] is List && (_producerData!['evenements'] as List).isNotEmpty) {
        print('ℹ️ Using events already fetched within producer data.');
        return List<dynamic>.from(_producerData!['evenements']);
    }

    print('🔍 Producer data did not contain events, attempting separate fetch for events for producer ID: $userId');

    try {
      // Try multiple approaches to get events (keep existing logic as fallback)
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
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) { // Show indicator also when _isLoading is true
            // Use Shimmer for a nicer loading effect
            return _buildLoadingShimmer(); 
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
                  expandedHeight: 440, // Adjusted height to accommodate stats bar comfortably
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeaderWithPhoto(producer),
                    // Remove title to prevent overlap
                    titlePadding: EdgeInsets.zero,
                    title: null,
                  ),
                  // Add actions for the menu button
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      tooltip: 'Menu',
                      onPressed: () => _showMainMenu(context), // Call the menu function
                    ),
                  ],
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
                // Pass producer data to events tab if needed
                _buildEventsTabForProfile(producer), 
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
  Widget _buildEventsTabForProfile(Map<String, dynamic> producer) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerEvents(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
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
                  onPressed: () => setState(() {}), // Simple refresh trigger
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }
        
        final events = snapshot.data ?? [];
        
        // ---> NEW: Calculate aggregated stats from events
        int totalInterested = 0;
        int totalChoices = 0;
        for (var event in events) {
          if (event is Map<String, dynamic>) {
            // Use interest_count if available, otherwise length of interestedUsers array
            final interestCount = event['interest_count'] ?? 
                                  (event['interestedUsers'] is List ? event['interestedUsers'].length : 0);
            final choiceCount = event['choice_count'] ?? 0;
            
            totalInterested += (interestCount is int) ? interestCount : 0;
            totalChoices += (choiceCount is int) ? choiceCount : 0;
          }
        }
        
        // ---> NEW: Update state variables after frame build
        // Use WidgetsBinding.instance.addPostFrameCallback to avoid calling setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (_interestedCount != totalInterested || _choiceCount != totalChoices)) {
            setState(() {
              _interestedCount = totalInterested;
              _choiceCount = totalChoices;
              // Note: _eventsCount should probably be events.length, ensure it's updated elsewhere if needed
              // _eventsCount = events.length; 
            });
          }
        });
        // <--- End stats calculation and update
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Mes événements (${events.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    // Navigate to management screen without specific ID for creation
                    onPressed: () => _navigateToManagementScreen(null),
                    icon: const Icon(Icons.settings, size: 18), // Use settings icon
                    label: const Text('Gérer tout'), // Changed label
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple, // Match theme
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('Aucun événement programmé', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                             onPressed: () => _navigateToManagementScreen(null),
                             icon: const Icon(Icons.add),
                             label: const Text('Créer un événement'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.deepPurple,
                               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                             ),
                           ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        // Use the new simplified card for profile view
                        return _buildEventCardForProfile(event); 
                      },
                    ),
            ),
          ],
        );
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
    // Use the utility function to get an ImageProvider
    final imageProvider = getImageProvider(imageUrl);

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
            // Image de l'événement (using CachedNetworkImage)
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16/9,
                  child: imageProvider != null
                    ? CachedNetworkImage(
                        // Assume imageUrl is the string URL here
                        imageUrl: imageUrl!, 
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.event_busy, size: 40, color: Colors.grey)),
                        ),
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
    final eventId = event['_id']?.toString();
    if (eventId != null) {
      print("Navigating to details for event: $eventId");
      // TODO: Implement EventDetailScreen or use a fallback screen
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => EventDetailScreen(eventId: eventId), 
      //   ),
      // );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("L'écran de détail d'événement n'est pas encore disponible.")),
      );
    } else {
      print("Error: Event ID is null, cannot navigate.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'afficher les détails de cet événement.")), 
      );
    }
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
      final match = RegExp(r'\\(([^\\)]+)\\)').firstMatch(noteGoogle); // Escaped parentheses
      if (match != null && match.group(1) != null) {
        // Remove non-digit characters (like dots or spaces used as thousands separators)
        final cleanedCountStr = match.group(1)!.replaceAll(RegExp(r'\\D'), ''); // Escaped \D
        count = int.tryParse(cleanedCountStr);
      }
    }

    // Format with compact notation for large numbers
    return '(${NumberFormat.compact().format(count ?? 0)} avis)';
  }

  // Helper function to safely calculate counts from various data structures
  int _getSafeCount(Map<String, dynamic> data, String primaryKey, {String? listKey, String? numberKey}) {
    // 1. Prioritize the explicit numberKey if provided and valid
    if (numberKey != null && data.containsKey(numberKey)) {
      final numValue = data[numberKey];
      if (numValue is num) {
        return numValue.toInt();
      } else if (numValue is String) {
        // Try parsing if it's a string representation of a number
        final parsedNum = int.tryParse(numValue);
        if (parsedNum != null) return parsedNum;
      }
    }
    // 2. Check the primary key structure (Map with 'count')
    if (data.containsKey(primaryKey) && data[primaryKey] is Map && data[primaryKey]['count'] is int) {
      return data[primaryKey]['count'];
    }
    // 3. Check the primary key structure (List)
    if (data.containsKey(primaryKey) && data[primaryKey] is List) {
      return (data[primaryKey] as List).length;
    }
    // 4. Check the listKey structure (List)
    if (listKey != null && data.containsKey(listKey) && data[listKey] is List) {
      return (data[listKey] as List).length;
    }
    // 5. Default to 0 if no valid count found
    return 0;
  }

  // NEW: Navigation to User List Screen
  void _navigateToUserList(String listType, String producerId) {
    // TODO: Implement UserListScreen or use a fallback screen
    print("Navigating to user list: type=$listType, producerId=$producerId");
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => UserListScreen(
    //       parentId: producerId, 
    //       listType: listType, // e.g., 'followers', 'following', 'interested', 'choices'
    //     ),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("L'écran de liste d'utilisateurs n'est pas encore disponible.")),
    );
  }

  // Build Shimmer Loading Placeholder
  Widget _buildLoadingShimmer() {
    return Scaffold(
      body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(), // Disable scroll while loading
          child: Column(
            children: [
              // Shimmer Header (Adjust height to match new expandedHeight)
              Container(
                height: 440, // Match adjusted expanded AppBar height
                color: Colors.white,
              ),
              // Shimmer Tab Content Placeholder
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 150.0, color: Colors.white),
                    const SizedBox(height: 16),
                    Container(width: double.infinity, height: 100.0, color: Colors.white),
                    const SizedBox(height: 16),
                    Container(width: 200, height: 20.0, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Simplified Event Card for the Profile Screen
  Widget _buildEventCardForProfile(Map<String, dynamic> event) {
    // Use the helper function to get image URL robustly
    final imageUrl = getProducerImageUrl(event);
    final imageProvider = getImageProvider(imageUrl);
    final title = event['intitulé'] ?? event['titre'] ?? event['name'] ?? 'Événement sans titre';
    final dateStr = event['date_debut'] ?? event['prochaines_dates'] ?? event['date']?.toString() ?? '';
    final formattedDate = dateStr.isNotEmpty ? formatDisplayDate(dateStr) : 'Date inconnue';
    final isPublished = event['published'] ?? true; // Assume published if null
    final eventId = event['_id']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image and Status Badge
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: imageProvider != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!, 
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400])),
                      )
                    : Container(color: Colors.grey[200], child: Icon(Icons.event, color: Colors.grey[400], size: 50)),
              ),
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublished ? Colors.green.withOpacity(0.8) : Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPublished ? 'Publié' : 'Brouillon',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          // Text Content and Manage Button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Manage Button
                TextButton.icon(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Gérer'),
                  style: TextButton.styleFrom(
                     foregroundColor: Colors.deepPurple,
                     backgroundColor: Colors.deepPurple.withOpacity(0.1),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Smaller padding
                     textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600), // Smaller text
                  ),
                  onPressed: eventId != null 
                      ? () => _navigateToManagementScreen(eventId) 
                      : null, // Disable if no ID
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // MODIFIED: Navigate to Management Screen (optionally with specific event)
  void _navigateToManagementScreen(String? eventId) {
     print("Navigating to management screen${eventId != null ? ' for event $eventId' : ''}");
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => MyEventsManagementScreen(
           producerId: widget.userId,
           token: widget.token,
           initialEventId: eventId, // Pass the event ID
         ),
       ),
     ).then((_) {
       // Refresh data when returning from management screen
       setState(() {
         _producerFuture = _fetchProducerData(widget.userId);
       });
     });
  }

  // Method to show the main menu (adapted from MyProfileScreen)
  void _showMainMenu(BuildContext context) {
    if (!mounted) return;
    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              // Add other relevant menu options here if needed
              // e.g., _buildMenuOption(icon: Icons.settings, text: 'Paramètres', onTap: () { ... }),
              const Divider(height: 1),
              _buildMenuOption(icon: Icons.logout, text: 'Déconnexion', color: Colors.red, onTap: () async {
                 Navigator.pop(modalContext); // Close modal
                 await authService.logout();
                 if (mounted) {
                   // Navigate to login or home screen after logout
                   Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                 }
               }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // Helper to get producer image URL robustly
  String? getProducerImageUrl(Map<String, dynamic>? producerData) {
    if (producerData == null) return null;
    // Check common keys in order of preference
    final potentialKeys = ['photo', 'photo_url', 'image', 'logoUrl', 'imageUrl'];
    for (final key in potentialKeys) {
      final value = producerData[key];
      if (value is String && value.isNotEmpty) {
        // Basic validation: check if it looks like a URL or base64
        if (value.startsWith('http') || value.startsWith('data:image')) {
          return value;
        }
      }
    }
    return null; // Return null if no valid URL found
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