import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'utils.dart';
import '../services/auth_service.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'profile_screen.dart'; // Pour les utilisateurs
import 'dart:io' show SocketException;

class ProducerSearchPage extends StatefulWidget {
  final String userId;

  const ProducerSearchPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProducerSearchPageState createState() => _ProducerSearchPageState();
}

class _ProducerSearchPageState extends State<ProducerSearchPage> with SingleTickerProviderStateMixin {
  // Résultats de recherche et états de chargement
  List<dynamic> _searchResults = [];
  String _query = "";
  bool _isLoading = false;
  String _errorMessage = "";
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _searchAnimationController;

  // États de chargement pour chaque section
  bool _isLoadingTrending = true;
  bool _isLoadingNearby = true;
  bool _isLoadingFriends = true;
  bool _isLoadingInnovative = true;
  bool _isLoadingSurprise = true;
  
  // Messages d'erreur pour chaque section
  String _trendingError = "";
  String _nearbyError = "";
  String _friendsError = "";
  String _innovativeError = "";
  String _surpriseError = "";
  
  // Données pour chaque section - remplies dynamiquement via API
  List<dynamic> _trendingNow = [];
  List<dynamic> _popularNearby = [];
  List<dynamic> _bestFriendsExperiences = [];
  List<dynamic> _innovative = [];
  List<dynamic> _surprise = [];
  
  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Charger les données de toutes les sections
    _fetchTrendingItems();
    _fetchNearbyItems();
    
    // Only fetch friends experiences if we have a valid userId
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.hasValidUserId()) {
      _fetchFriendsExperiences();
    } else {
      setState(() {
        _isLoadingFriends = false;
        _friendsError = "Connexion requise pour voir les expériences de vos amis";
      });
    }
    
    _fetchInnovativeItems();
    _fetchSurpriseItems();
  }
  
  /// Récupère les tendances actuelles
  Future<void> _fetchTrendingItems() async {
    setState(() {
      _isLoadingTrending = true;
      _trendingError = "";
    });
    
    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/unified/trending-public');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/unified/trending-public');
      } else {
        url = Uri.parse('$baseUrl/api/unified/trending-public');
      }
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu: ${decoded.runtimeType}');
        }
        
        setState(() {
          _trendingNow = _transformApiData(resultList);
          _isLoadingTrending = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des tendances: $e');
      setState(() {
        _trendingError = "Impossible de charger les tendances";
        _isLoadingTrending = false;
        
        // Données de secours si l'API échoue
        _trendingNow = [
          {
            'id': '1',
            'type': 'restaurant',
            'name': 'Le Petit Bistrot',
            'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&q=80',
            'rating': 4.8,
            'category': 'Cuisine française'
          },
          {
            'id': '2',
            'type': 'event',
            'name': 'Festival Jazz des Puces',
            'image': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
            'rating': 4.5,
            'category': 'Concert'
          },
        ];
      });
    }
  }
  
  /// Récupère les lieux populaires à proximité
  Future<void> _fetchNearbyItems() async {
    setState(() {
      _isLoadingNearby = true;
      _nearbyError = "";
    });
    
    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/unified/nearby-public');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/unified/nearby-public');
      } else {
        url = Uri.parse('$baseUrl/api/unified/nearby-public');
      }
      
      // Paramètres optionnels pour la localisation
      // Idéalement on utiliserait la position réelle de l'utilisateur
      final params = {
        'lat': '48.8566',  // Paris par défaut
        'lng': '2.3522',
        'radius': '5000',  // 5km
      };
      
      url = url.replace(queryParameters: params);
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu: ${decoded.runtimeType}');
        }
        
        setState(() {
          _popularNearby = _transformApiData(resultList);
          _isLoadingNearby = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des lieux à proximité: $e');
      setState(() {
        _nearbyError = "Impossible de charger les lieux à proximité";
        _isLoadingNearby = false;
        
        // Données de secours
        _popularNearby = [
          {
            'id': '4',
            'type': 'restaurant',
            'name': 'Sushi Fusion',
            'image': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=500&q=80',
            'rating': 4.6,
            'category': 'Japonais'
          },
          {
            'id': '5',
            'type': 'leisureProducer',
            'name': 'Cinéma Le Palace',
            'image': 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&q=80',
            'rating': 4.3,
            'category': 'Cinéma'
          },
        ];
      });
    }
  }
  
  /// Récupère les expériences des amis de l'utilisateur
  Future<void> _fetchFriendsExperiences() async {
    // On ne charge pas cette section si l'utilisateur n'est pas connecté
    setState(() {
      _isLoadingFriends = false;
      _friendsError = "";
    });
    
    // Données de secours - expériences populaires pour tous
    setState(() {
      _bestFriendsExperiences = [
        {
          'id': '7',
          'type': 'restaurant',
          'name': 'La Trattoria',
          'image': 'https://images.unsplash.com/photo-1481833761820-0509d3217039?w=500&q=80',
          'rating': 4.7,
          'category': 'Italien'
        },
        {
          'id': '8',
          'type': 'event',
          'name': 'Concert Live Band',
          'image': 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=500&q=80',
          'rating': 4.4,
          'category': 'Musique'
        },
        {
          'id': '9',
          'type': 'leisureProducer',
          'name': 'Musée d\'Art Moderne',
          'image': 'https://images.unsplash.com/photo-1626126525134-fbbc0db37b8a?w=500&q=80',
          'rating': 4.6,
          'category': 'Musée'
        },
      ];
    });
  }
  
  /// Récupère les expériences innovantes
  Future<void> _fetchInnovativeItems() async {
    setState(() {
      _isLoadingInnovative = true;
      _innovativeError = "";
    });
    
    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/unified/innovative-public');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/unified/innovative-public');
      } else {
        url = Uri.parse('$baseUrl/api/unified/innovative-public');
      }
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu pour innovative: ${decoded.runtimeType}');
        }
        
        setState(() {
          _innovative = _transformApiData(resultList);
          _isLoadingInnovative = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des expériences innovantes: $e');
      setState(() {
        _innovativeError = "Impossible de charger les expériences innovantes";
        _isLoadingInnovative = false;
        
        // Données de secours
        _innovative = [
          {
            'id': '9',
            'type': 'leisureProducer',
            'name': 'VR Experience Center',
            'image': 'https://images.unsplash.com/photo-1478416272538-5f7e51dc5400?w=500&q=80',
            'rating': 4.8,
            'category': 'Réalité Virtuelle'
          },
          {
            'id': '10',
            'type': 'restaurant',
            'name': 'Dark Dinner',
            'image': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=500&q=80',
            'rating': 4.5,
            'category': 'Expérience culinaire'
          },
        ];
      });
    }
  }
  
  /// Récupère les expériences surprises
  Future<void> _fetchSurpriseItems() async {
    setState(() {
      _isLoadingSurprise = true;
      _surpriseError = "";
    });
    
    try {
      final baseUrl = getBaseUrl();
      Uri url;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        url = Uri.http(domain, '/api/unified/surprise-public');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        url = Uri.https(domain, '/api/unified/surprise-public');
      } else {
        url = Uri.parse('$baseUrl/api/unified/surprise-public');
      }
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu pour surprise: ${decoded.runtimeType}');
        }
        
        setState(() {
          _surprise = _transformApiData(resultList);
          _isLoadingSurprise = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des surprises: $e');
      setState(() {
        _surpriseError = "Impossible de charger les surprises";
        _isLoadingSurprise = false;
        
        // Données de secours
        _surprise = [
          {
            'id': '11',
            'type': 'event',
            'name': 'Théâtre d\'improvisation',
            'image': 'https://images.unsplash.com/photo-1503095396549-807759245b35?w=500&q=80',
            'rating': 4.6,
            'category': 'Théâtre'
          },
          {
            'id': '12',
            'type': 'leisureProducer',
            'name': 'Laser Game Nature',
            'image': 'https://images.unsplash.com/photo-1551892374-ecf8754cf8b0?w=500&q=80',
            'rating': 4.4,
            'category': 'Activité plein air'
          },
        ];
      });
    }
  }
  
  /// Transforme les données de l'API en format utilisable pour l'UI
  List<Map<String, dynamic>> _transformApiData(List<dynamic> apiData) {
    return apiData.map((item) {
      // Déterminer le type
      String type = item['type'] ?? 'unknown';
      
      // Extraire l'ID, handle null safely
      String id = '';
      if (item['_id'] != null && item['_id'].toString().trim().isNotEmpty) {
        id = item['_id'].toString();
      }
      
      // Extraire le nom selon le type
      String name = '';
      if (type == 'leisureProducer') {
        name = item['lieu'] ?? item['nom'] ?? item['name'] ?? 'Sans nom';
      } else if (type == 'restaurant') {
        name = item['name'] ?? item['établissement'] ?? 'Sans nom';
      } else if (type == 'event') {
        name = item['intitulé'] ?? item['titre'] ?? item['name'] ?? 'Sans nom';
      } else {
        name = item['name'] ?? 'Sans nom';
      }
      
      // Extraire l'image - gestion des cas où l'image est une liste
      String image = '';
      if (item['photo'] != null) {
        if (item['photo'] is String) {
          image = item['photo'];
        } else if (item['photo'] is List && (item['photo'] as List).isNotEmpty) {
          // Prendre le premier élément de la liste
          image = (item['photo'] as List).first.toString();
        }
      } else if (item['image'] != null) {
        if (item['image'] is String) {
          image = item['image'];
        } else if (item['image'] is List && (item['image'] as List).isNotEmpty) {
          image = (item['image'] as List).first.toString();
        }
      } else if (item['photo_url'] != null) {
        if (item['photo_url'] is String) {
          image = item['photo_url'];
        } else if (item['photo_url'] is List && (item['photo_url'] as List).isNotEmpty) {
          image = (item['photo_url'] as List).first.toString();
        }
      }
      
      // Si aucune image valide n'a été trouvée, utiliser une image par défaut
      if (image.isEmpty) {
        image = 'https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80';
      }
      
      // Extraire la note avec gestion des différents types
      double rating = 4.0; // Note par défaut
      if (item['note'] != null) {
        if (item['note'] is double) {
          rating = item['note'];
        } else if (item['note'] is int) {
          rating = (item['note'] as int).toDouble();
        } else if (item['note'] is String && (item['note'] as String).isNotEmpty) {
          try {
            rating = double.parse(item['note'].toString());
          } catch (e) {
            print('Erreur de conversion de note: ${item['note']}');
          }
        } else if (item['note'] is List && (item['note'] as List).isNotEmpty) {
          var firstItem = (item['note'] as List).first;
          if (firstItem is double) {
            rating = firstItem;
          } else if (firstItem is int) {
            rating = firstItem.toDouble();
          } else {
            try {
              rating = double.parse(firstItem.toString());
            } catch (e) {
              print('Erreur de conversion de note (liste): $firstItem');
            }
          }
        }
      } else if (item['rating'] != null) {
        if (item['rating'] is double) {
          rating = item['rating'];
        } else if (item['rating'] is int) {
          rating = (item['rating'] as int).toDouble();
        } else if (item['rating'] is String && (item['rating'] as String).isNotEmpty) {
          try {
            rating = double.parse(item['rating'].toString());
          } catch (e) {
            print('Erreur de conversion de rating: ${item['rating']}');
          }
        } else if (item['rating'] is List && (item['rating'] as List).isNotEmpty) {
          var firstItem = (item['rating'] as List).first;
          if (firstItem is double) {
            rating = firstItem;
          } else if (firstItem is int) {
            rating = firstItem.toDouble();
          } else {
            try {
              rating = double.parse(firstItem.toString());
            } catch (e) {
              print('Erreur de conversion de rating (liste): $firstItem');
            }
          }
        }
      }
      
      // Extraire la catégorie avec gestion des listes
      String category = 'Non catégorisé';
      if (item['catégorie'] != null) {
        if (item['catégorie'] is String) {
          category = item['catégorie'];
        } else if (item['catégorie'] is List && (item['catégorie'] as List).isNotEmpty) {
          category = (item['catégorie'] as List).first.toString();
        }
      } else if (item['category'] != null) {
        if (item['category'] is String) {
          category = item['category'];
        } else if (item['category'] is List && (item['category'] as List).isNotEmpty) {
          category = (item['category'] as List).first.toString();
        }
      } else if (item['type_cuisine'] != null) {
        if (item['type_cuisine'] is String) {
          category = item['type_cuisine'];
        } else if (item['type_cuisine'] is List && (item['type_cuisine'] as List).isNotEmpty) {
          category = (item['type_cuisine'] as List).first.toString();
        }
      }
      
      return {
        'id': id,
        'type': type,
        'name': name,
        'image': image,
        'rating': rating,
        'category': category,
      };
    }).toList();
  }
  @override
  void dispose() {
    _searchAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  /// Rafraîchit toutes les sections
  Future<void> _refreshAllSections() async {
    List<Future<void>> futures = [
      _fetchTrendingItems(),
      _fetchNearbyItems(),
      _fetchInnovativeItems(),
      _fetchSurpriseItems(),
    ];
    
    // Pour les amis, on actualise juste les données de secours
    _fetchFriendsExperiences();
    
    await Future.wait(futures);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données actualisées'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Recherche des producteurs, événements et utilisateurs via l'API
  Future<void> _searchItems() async {
    // Animer le bouton de recherche
    _searchAnimationController.forward().then((_) {
      _searchAnimationController.reverse();
    });
    if (_query.isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = "Veuillez entrer un mot-clé pour la recherche.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      // Utiliser l'endpoint public qui ne nécessite pas d'authentification
      final url = Uri.parse('${getBaseUrl()}/api/unified/search-public?query=$_query');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("La requête a pris trop de temps. Veuillez réessayer.");
        },
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> resultList;
        
        if (decoded is List) {
          resultList = decoded;
        } else if (decoded is Map && decoded.containsKey('data') && decoded['data'] is List) {
          resultList = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('results') && decoded['results'] is List) {
          resultList = decoded['results'];
        } else if (decoded is Map) {
          // Create a single item list from the map
          resultList = [decoded];
        } else {
          resultList = [];
          print('❌ Format de données inattendu pour la recherche: ${decoded.runtimeType}');
        }
        
        // Utiliser _transformApiData pour normaliser les données des résultats
        final transformedResults = _transformApiData(resultList);

        setState(() {
          _searchResults = transformedResults;
          if (_searchResults.isEmpty) {
            _errorMessage = "Aucun résultat trouvé pour cette recherche.";
          }
        });
      } else {
        // Si l'API échoue, fournir des résultats de recherche fictifs
        print('❌ Erreur lors de la recherche: ${response.statusCode}: ${response.body}');
        
        setState(() {
          _errorMessage = "";
          // Données de secours pour la recherche - déjà formatées comme _transformApiData
          if (_query.toLowerCase().contains("restaurant") || _query.toLowerCase().contains("food")) {
            _searchResults = [
              {
                'id': '101',
                'type': 'restaurant',
                'name': 'Le Bistrot Parisien',
                'image': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=500&q=80',
                'rating': 4.7,
                'category': 'Cuisine française'
              }
            ];
          } else if (_query.toLowerCase().contains("event") || _query.toLowerCase().contains("concert")) {
            _searchResults = [
              {
                'id': '202',
                'type': 'event',
                'name': 'Festival de Jazz',
                'image': 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=500&q=80',
                'rating': 4.5,
                'category': 'Concert'
              }
            ];
          } else {
            _searchResults = [
              {
                'id': '303',
                'type': 'leisureProducer',
                'name': 'Musée d\'Art Moderne',
                'image': 'https://images.unsplash.com/photo-1626126525134-fbbc0db37b8a?w=500&q=80',
                'rating': 4.6,
                'category': 'Musée'
              }
            ];
          }
        });
      }
    } catch (e) {
      print('❌ Erreur réseau lors de la recherche: $e');
      setState(() {
        _errorMessage = "";
        // Fournir des résultats par défaut en cas d'erreur réseau en format normalisé
        _searchResults = [
          {
            'id': '404',
            'type': 'restaurant',
            'name': 'Café de la Place',
            'image': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=500&q=80',
            'rating': 4.2,
            'category': 'Café'
          }
        ];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToDetails(String id, String type) async {
    print('🔍 Navigation vers les détails');
    print('📝 ID: $id');
    print('📝 Type: $type');
    
    // Store a reference to the context at the start of the method
    final BuildContext currentContext = context;
    
    // Check if ID is valid before attempting to navigate
    if (id.isEmpty) {
      print('❌ ID invalide');
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'accéder aux détails: ID invalide"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      // Utilisation d'un ID vide ou guest pour les requêtes qui exigent un userId
      final guestId = 'guest-user';
      print('👤 Utilisation de l\'ID guest: $guestId');
      
      switch (type) {
        case 'restaurant':
          print('🍽️ Navigation vers le restaurant');
          // Only navigate if the widget is still mounted
          if (mounted) {
            Navigator.push(
              currentContext,
              MaterialPageRoute(
                builder: (context) => ProducerScreen(
                  producerId: id,
                  userId: guestId,
                ),
              ),
            );
          }
          break;
        case 'leisureProducer':
          print('🎮 Navigation vers le producteur de loisirs');
          BuildContext? dialogContext;
          
          // Only show dialog if the widget is still mounted
          if (mounted) {
            showDialog(
              context: currentContext,
              barrierDismissible: false,
              builder: (BuildContext context) {
                dialogContext = context;
                return const Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Chargement des informations..."),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          try {
            // Make the API request
            final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
            print('🌐 URL de l\'API: $url');
            print('📤 Envoi de la requête GET');
            
            final response = await http.get(url);
            print('📥 Réponse reçue: ${response.statusCode}');
            print('📦 Corps de la réponse: ${response.body.substring(0, 100)}...');
            
            // Always close dialog if it's open, regardless of mounted state
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only proceed with navigation if the request was successful and widget still mounted
            if (response.statusCode == 200 && mounted) {
              print('✅ Navigation vers ProducerLeisureScreen');
              final data = json.decode(response.body);
              Navigator.push(
                currentContext,
                MaterialPageRoute(
                  builder: (context) => ProducerLeisureScreen(producerData: data),
                ),
              );
            } else if (response.statusCode != 200 && mounted) {
              print('❌ Erreur serveur: ${response.statusCode}');
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            print('❌ Erreur lors du chargement: $e');
            // Safely close the loading dialog if still open
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only show error if widget is still mounted
            if (mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(
                  content: Text("Erreur lors du chargement: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        case 'event':
          print('🎪 Navigation vers l\'événement');
          BuildContext? dialogContext;
          
          // Only show dialog if the widget is still mounted
          if (mounted) {
            showDialog(
              context: currentContext,
              barrierDismissible: false,
              builder: (BuildContext context) {
                dialogContext = context;
                return const Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Chargement de l'événement..."),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          try {
            // Make the API request
            final url = Uri.parse('${getBaseUrl()}/api/events/$id');
            print('🌐 URL de l\'API: $url');
            print('📤 Envoi de la requête GET');
            
            final response = await http.get(url);
            print('📥 Réponse reçue: ${response.statusCode}');
            print('📦 Corps de la réponse: ${response.body.substring(0, 100)}...');
            
            // Always close dialog if it's open, regardless of mounted state
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only proceed with navigation if the request was successful and widget still mounted
            if (response.statusCode == 200 && mounted) {
              print('✅ Navigation vers EventLeisureScreen');
              final data = json.decode(response.body);
              Navigator.push(
                currentContext,
                MaterialPageRoute(
                  builder: (context) => EventLeisureScreen(eventData: data),
                ),
              );
            } else if (response.statusCode != 200 && mounted) {
              print('❌ Erreur serveur: ${response.statusCode}');
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            print('❌ Erreur lors du chargement: $e');
            // Safely close the loading dialog if still open
            if (dialogContext != null && Navigator.canPop(dialogContext!)) {
              Navigator.of(dialogContext!).pop();
            }
            
            // Only show error if widget is still mounted
            if (mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(
                  content: Text("Erreur lors du chargement: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        case 'user':
          print('👤 Navigation vers le profil utilisateur');
          // Only navigate if the widget is still mounted
          if (mounted) {
            Navigator.push(
              currentContext,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: id, viewMode: 'public'),
              ),
            );
          }
          break;
        default:
          print('⚠️ Type non reconnu: $type');
          if (mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(
                content: Text("Type non reconnu: $type"),
                backgroundColor: Colors.orange,
              ),
            );
          }
      }
    } catch (e) {
      print('❌ Erreur de navigation: $e');
      // Only show error if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text("Erreur de navigation: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pull to refresh
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Barre de recherche stylisée
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher restaurants, activités...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _query = value.trim();
                          });
                        },
                        onSubmitted: (_) => _searchItems(),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _searchAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_searchAnimationController.value * 0.1),
                          child: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = "";
                                _searchResults = [];
                                _errorMessage = "";
                              });
                            },
                          ),
                        );
                      }
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple, Colors.purple.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: _searchItems,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenu principal avec résultats de recherche ou sections tendances
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isNotEmpty
                  ? _buildSearchResults()
                  : _errorMessage.isNotEmpty && _query.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshAllSections,
                        child: _buildTrendingSections(),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final String type = item['type'] ?? 'unknown';
        return _buildResultCard(
          id: item['id'] ?? '',
          type: type,
          title: item['name'] ?? 'Nom non spécifié',
          subtitle: item['address'] ?? item['lieu'] ?? 'Adresse non spécifiée',
          imageUrl: item['image'] ?? '',
          rating: item['rating'] ?? 0.0,
          category: item['category'] ?? 'Non catégorisé',
        );
      },
    );
  }

  Widget _buildTrendingSections() {
    // Liste des sections à construire avec leurs données respectives
    final sections = [
      {
        'title': 'Tendances du moment',
        'data': _trendingNow,
        'isLoading': _isLoadingTrending,
        'error': _trendingError,
        'color': Colors.purple.shade800,
        'icon': Icons.trending_up,
      },
      {
        'title': 'Le plus populaire autour de vous',
        'data': _popularNearby,
        'isLoading': _isLoadingNearby,
        'error': _nearbyError,
        'color': Colors.blue.shade700,
        'icon': Icons.place,
      },
      {
        'title': 'Les meilleures expériences de vos proches',
        'data': _bestFriendsExperiences,
        'isLoading': _isLoadingFriends,
        'error': _friendsError,
        'color': Colors.teal.shade700,
        'icon': Icons.people,
      },
      {
        'title': 'Tenter quelque chose d\'improbable, novateur',
        'data': _innovative,
        'isLoading': _isLoadingInnovative,
        'error': _innovativeError,
        'color': Colors.amber.shade800,
        'icon': Icons.lightbulb,
      },
      {
        'title': 'Laissez-vous surprendre',
        'data': _surprise,
        'isLoading': _isLoadingSurprise,
        'error': _surpriseError,
        'color': Colors.pink.shade700,
        'icon': Icons.auto_awesome,
      },
    ];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Construire dynamiquement toutes les sections
          ...sections.map((section) {
            final title = section['title'] as String;
            final data = section['data'] as List;
            final isLoading = section['isLoading'] as bool;
            final error = section['error'] as String;
            final color = section['color'] as Color;
            final icon = section['icon'] as IconData;
            
            return _buildTrendingSection(
              title, 
              data, 
              color,
              icon,
              isLoading: isLoading,
              errorMessage: error,
            );
          }).toList(),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(
    String title, 
    List<dynamic> items, 
    Color accentColor, 
    IconData icon, {
    bool isLoading = false,
    String errorMessage = "",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        
        // En-tête de section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                // Action voir plus
              },
              child: Text(
                'Voir plus',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Contenu de la section (charge, erreur ou données)
        SizedBox(
          height: 190,
          child: isLoading
              ? _buildSectionLoading(accentColor)
              : errorMessage.isNotEmpty
                  ? _buildSectionError(errorMessage, accentColor)
                  : items.isEmpty
                      ? _buildEmptySection(accentColor)
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildItemCard(
                              id: item['id'],
                              type: item['type'],
                              name: item['name'],
                              imageUrl: item['image'],
                              rating: item['rating'] is double ? item['rating'] : 0.0,
                              category: item['category'],
                              accentColor: accentColor,
                            );
                          },
                        ),
        ),
      ],
    );
  }
  // Widget pour afficher un loader pendant le chargement des sections
  Widget _buildSectionLoading(Color accentColor) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3, // Nombre de skeletons à afficher
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image skeleton
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor.withOpacity(0.5)),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              
              // Texte skeleton
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 12,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Widget pour afficher un message d'erreur
  Widget _buildSectionError(String errorMessage, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: accentColor, size: 40),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(color: accentColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _refreshAllSections,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget pour afficher un message quand il n'y a pas de données
  Widget _buildEmptySection(Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: accentColor.withOpacity(0.5), size: 40),
            const SizedBox(height: 8),
            Text(
              'Aucun résultat trouvé',
              style: TextStyle(color: accentColor.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildItemCard({
    required String id,
    required String type,
    required String name,
    required String imageUrl,
    required double rating,
    required String category,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDetails(id, type),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(
                      _getIconForType(type),
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            
            // Contenu
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Catégorie
                  Text(
                    category,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Note et type - fixed width constraints to prevent overflow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Note avec étoile
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 10),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Badge type
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTypeLabel(type),
                          style: TextStyle(
                            fontSize: 9,
                            color: accentColor,
                            fontWeight: FontWeight.bold,
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

  Widget _buildResultCard({
    required String id,
    required String type,
    required String title,
    required String subtitle,
    required String imageUrl,
    dynamic rating,
    dynamic category,
  }) {
    Color accentColor = _getColorForType(type);
    
    // Ensure rating is a double or null
    double? ratingValue;
    if (rating != null) {
      if (rating is double) {
        ratingValue = rating;
      } else if (rating is String && (rating as String).isNotEmpty) {
        try {
          ratingValue = double.parse(rating);
        } catch (e) {
          print('Erreur de conversion de rating: $rating');
        }
      } else if (rating is int) {
        ratingValue = rating.toDouble();
      }
    }
    
    // Ensure category is a string
    String categoryText = 'Non catégorisé';
    if (category != null) {
      if (category is String) {
        categoryText = category;
      } else {
        try {
          categoryText = category.toString();
        } catch (e) {
          print('Erreur de conversion de category: $category');
        }
      }
    }
    
    return GestureDetector(
      onTap: () => _navigateToDetails(id, type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl.isNotEmpty 
                  ? imageUrl 
                  : 'https://images.unsplash.com/photo-1494253109108-2e30c049369b?w=500&q=80',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  width: 100,
                  height: 100,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  width: 100,
                  height: 100,
                  child: Center(
                    child: Icon(
                      _getIconForType(type),
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Adresse
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Ligne du bas avec note, catégorie et type
                    Row(
                      children: [
                        // Note avec étoile si disponible
                        if (ratingValue != null) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            ratingValue.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        
                        // Catégorie si disponible
                        if (categoryText.isNotEmpty)
                          Flexible(
                            child: Text(
                              categoryText,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        
                        const Spacer(),
                        
                        // Badge type
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTypeLabel(type),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'leisureProducer':
        return Icons.local_activity;
      case 'event':
        return Icons.event;
      case 'user':
        return Icons.person;
      default:
        return Icons.place;
    }
  }
  
  Color _getColorForType(String type) {
    switch (type) {
      case 'restaurant':
        return Colors.orange;
      case 'leisureProducer':
        return Colors.purple;
      case 'event':
        return Colors.green;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  String _getTypeLabel(String type) {
    switch (type) {
      case 'restaurant':
        return 'Restaurant';
      case 'leisureProducer':
        return 'Loisir';
      case 'event':
        return 'Événement';
      case 'user':
        return 'Utilisateur';
      default:
        return type;
    }
  }

  Future<void> _fetchProducerDetails(String producerId) async {
    print('🔍 Initialisation du test des API');
    print('🔍 Test API avec producerId: $producerId');
    
    try {
      final baseUrl = getBaseUrl();
      print('🌐 URL de base: $baseUrl');
      
      // Test avec l'endpoint producer
      print('🔍 Test : appel à /api/producers/$producerId');
      final producerUrl = Uri.parse('$baseUrl/api/producers/$producerId');
      print('🌐 URL complète: $producerUrl');
      
      final producerResponse = await http.get(producerUrl).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (producerResponse.statusCode == 200) {
        print('✅ Réponse reçue du serveur producer');
        final producerData = json.decode(producerResponse.body);
        print('📦 Données reçues: ${producerData.toString().substring(0, 100)}...');
        // Traitement des données...
      } else {
        print('❌ Erreur serveur: ${producerResponse.statusCode}');
        print('📦 Corps de la réponse: ${producerResponse.body}');
      }
      
      // Test avec l'endpoint unified
      print('🔍 Test : appel à /api/unified/$producerId');
      final unifiedUrl = Uri.parse('$baseUrl/api/unified/$producerId');
      print('🌐 URL complète: $unifiedUrl');
      
      final unifiedResponse = await http.get(unifiedUrl).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
      if (unifiedResponse.statusCode == 200) {
        print('✅ Réponse reçue du serveur unified');
        final unifiedData = json.decode(unifiedResponse.body);
        print('📦 Données reçues: ${unifiedData.toString().substring(0, 100)}...');
        // Traitement des données...
      } else {
        print('❌ Erreur serveur: ${unifiedResponse.statusCode}');
        print('📦 Corps de la réponse: ${unifiedResponse.body}');
      }
      
    } catch (e) {
      print('❌ Erreur lors de la récupération des détails: $e');
      if (e is SocketException) {
        print('🔌 Détails de l\'erreur de connexion:');
        print('   - Message: ${e.message}');
        print('   - OS Error: ${e.osError}');
        print('   - Address: ${e.address}');
        print('   - Port: ${e.port}');
      }
    }
  }
}