import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'post_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
import 'producerLeisure_screen.dart';
import 'producer_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/payment_service.dart';
import '../services/auth_service.dart'; // Import for AuthService
import 'package:provider/provider.dart'; // Import for Provider
import '../utils/constants.dart' as constants; // Importer constants au lieu de utils
import 'dart:typed_data';
import 'dart:io'; // Add import for File class
import 'package:intl/intl.dart';
import 'login_user.dart'; // Import for LoginUserPage
import 'heatmap_screen.dart'; // Import for HeatMap screen
import 'subscription_screen.dart'; // Import for SubscriptionScreen
import '../services/premium_feature_service.dart'; // Import for premium features check
import 'restaurant_stats_screen.dart'; // Import for RestaurantStatsScreen
import 'clients_list_screen.dart'; // Import for ClientsListScreen
import 'transaction_history_screen.dart'; // Import for TransactionHistoryScreen

class MyProducerProfileScreen extends StatefulWidget {
  final String producerId;

  const MyProducerProfileScreen({Key? key, required String userId})
      : producerId = userId, // Mapper userId en producerId
        super(key: key);

  @override
  State<MyProducerProfileScreen> createState() => _MyProducerProfileScreenState();
}

class _MyProducerProfileScreenState extends State<MyProducerProfileScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _producerFuture;
  int _selectedDay = 0; // Pour les horaires populaires
  String _selectedCarbon = "<3kg";
  String _selectedNutriScore = "A-C";
  double _selectedMaxCalories = 500;
  
  // Service pour les fonctionnalités premium
  final PremiumFeatureService _premiumFeatureService = PremiumFeatureService();
  String _currentSubscription = 'gratuit';
  bool _checkingPremiumAccess = true;
  Map<String, bool> _premiumFeaturesAccess = {
    'advanced_analytics': false,
    'premium_placement': false,
    'customizable_menu': false,
    'detailed_heatmap': false,
    'marketing_tools': false,
  };
  
  // Variables pour la promotion
  bool _hasActivePromotion = false;
  DateTime? _promotionEndDate;
  double _promotionDiscount = 10.0; // Pourcentage de réduction (10% par défaut)
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late Map<String, dynamic> post; // Post à modifier localement
  late int interestedCount;
  late int choicesCount;
  bool _isMarkingInterested = false; // Loading flag for Interested
  bool _isMarkingChoice = false;     // Loading flag for Choice

  @override
  void initState() {
    super.initState();
    print('🔍 Initialisation du test des API');
    _testApi(); // Appel à la méthode de test
    _producerFuture = _fetchProducerDetails(widget.producerId);
    _checkActivePromotion();
    
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
    
    // Charger les informations d'abonnement
    _loadSubscriptionInfo();
    _checkPremiumFeatureAccess();
  }
  
  // Charger le niveau d'abonnement actuel
  Future<void> _loadSubscriptionInfo() async {
    try {
      final subscriptionData = await _premiumFeatureService.getSubscriptionInfo(widget.producerId);
      if (mounted) {
        setState(() {
          _currentSubscription = subscriptionData['subscription']?['level'] ?? 'gratuit';
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement du niveau d\'abonnement: $e');
    }
  }
  
  // Vérifier l'accès aux fonctionnalités premium
  Future<void> _checkPremiumFeatureAccess() async {
    if (mounted) {
      setState(() {
        _checkingPremiumAccess = true;
      });
    }
    
    try {
      // Vérifier l'accès à chaque fonctionnalité premium
      Map<String, bool> accessResults = {};
      
      for (final feature in _premiumFeaturesAccess.keys) {
        final hasAccess = await _premiumFeatureService.canAccessFeature(
          widget.producerId, 
          feature
        );
        accessResults[feature] = hasAccess;
      }
      
      if (mounted) {
        setState(() {
          _premiumFeaturesAccess = accessResults;
          _checkingPremiumAccess = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des accès premium: $e');
      if (mounted) {
        setState(() {
          _checkingPremiumAccess = false;
        });
      }
    }
  }
  
  // Afficher le dialogue de mise à niveau pour une fonctionnalité
  void _showUpgradePrompt(String featureId) {
    if (_currentSubscription == 'gratuit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubscriptionScreen(
            producerId: widget.producerId,
          ),
        ),
      ).then((_) {
        // Recharger les accès après le retour
        _loadSubscriptionInfo();
        _checkPremiumFeatureAccess();
      });
    }
  }
  
  // Déterminer le niveau d'abonnement requis pour une fonctionnalité
  String _getRequiredSubscriptionLevel(String featureId) {
    switch (featureId) {
      case 'advanced_analytics':
        return 'starter';
      case 'premium_placement':
        return 'starter';
      case 'customizable_menu':
        return 'pro';
      case 'detailed_heatmap':
        return 'pro';
      case 'marketing_tools':
        return 'legend';
      default:
        return 'starter';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Vérifier si une promotion est active
  Future<void> _checkActivePromotion() async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/promotion');
      final response = await http.get(url);
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['active'] == true && data['endDate'] != null) {
          setState(() {
            _hasActivePromotion = true;
            _promotionEndDate = DateTime.parse(data['endDate']);
            _promotionDiscount = data['discountPercentage'] ?? 10.0;
          });
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des promotions: $e');
    }
  }
  // Activer une promotion
  Future<void> _activatePromotion(int durationDays) async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/promotion');
      
      // Calculer la date de fin
      final endDate = DateTime.now().add(Duration(days: durationDays));
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'active': true,
          'discountPercentage': _promotionDiscount,
          'endDate': endDate.toIso8601String(),
        }),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _hasActivePromotion = true;
          _promotionEndDate = endDate;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promotion de $_promotionDiscount% activée jusqu\'au ${DateFormat('dd/MM/yyyy').format(endDate)}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Rafraîchir les données
        setState(() {
          _producerFuture = _fetchProducerDetails(widget.producerId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'activation de la promotion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de l\'activation de la promotion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Désactiver une promotion
  Future<void> _deactivatePromotion() async {
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/promotion');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'active': false,
        }),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _hasActivePromotion = false;
          _promotionEndDate = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promotion désactivée'),
            backgroundColor: Colors.blue,
          ),
        );
        
        // Rafraîchir les données
        setState(() {
          _producerFuture = _fetchProducerDetails(widget.producerId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la désactivation de la promotion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la désactivation de la promotion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Afficher la boîte de dialogue de promotion
  void _showPromotionDialog() {
    int selectedDuration = 7; // Valeur par défaut (7 jours)
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activer une promotion'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appliquer une réduction de $_promotionDiscount% sur tous les plats pendant:',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                // Sélecteur de durée
                DropdownButton<int>(
                  value: selectedDuration,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 jour')),
                    DropdownMenuItem(value: 3, child: Text('3 jours')),
                    DropdownMenuItem(value: 7, child: Text('7 jours')),
                    DropdownMenuItem(value: 14, child: Text('14 jours')),
                    DropdownMenuItem(value: 30, child: Text('30 jours')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedDuration = value;
                      });
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            onPressed: () {
              Navigator.pop(context);
              _activatePromotion(selectedDuration);
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }
  void _testApi() async {
    final producerId = widget.producerId;

    try {
      print('🔍 Test : appel à /producers/$producerId');
      final producerUrl = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId');
      final producerResponse = await http.get(producerUrl);
      print('Réponse pour /producers : ${producerResponse.statusCode}');
      print('Body : ${producerResponse.body}');

      print('🔍 Test : appel à /producers/$producerId/relations');
      final relationsUrl = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId/relations');
      final relationsResponse = await http.get(relationsUrl);
      print('Réponse pour /producers/relations : ${relationsResponse.statusCode}');
      print('Body : ${relationsResponse.body}');

      if (producerResponse.statusCode == 200 && relationsResponse.statusCode == 200) {
        print('✅ Les deux requêtes ont réussi.');
      } else {
        print('❌ Une ou plusieurs requêtes ont échoué.');
      }
    } catch (e) {
      print('❌ Erreur réseau ou autre : $e');
    }
  }

  Future<Map<String, dynamic>> _fetchProducerDetails(String producerId) async {
    final producerUrl = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId');
    final relationsUrl = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId/relations');

    try {
      final responses = await Future.wait([
        http.get(producerUrl),
        http.get(relationsUrl),
      ]);

      Map<String, dynamic> resultData = {};

      // Traiter les données du producteur
      if (responses[0].statusCode == 200) {
        try {
          final producerData = json.decode(responses[0].body);
          if (producerData is Map<String, dynamic>) {
            resultData.addAll(producerData);
            print('✅ Found producer data at endpoint: /api/producers/$producerId');
          } else {
            print('⚠️ Producer data is not a map: ${producerData.runtimeType}');
            resultData['error_producer'] = 'Invalid format';
          }
        } catch (e) {
          print('❌ Error decoding producer data: $e');
          resultData['error_producer'] = e.toString();
        }
      } else {
        print('❌ Producer API failed: ${responses[0].statusCode}');
        resultData['error_producer'] = 'HTTP ${responses[0].statusCode}';
      }

      // Traiter les données de relations
      if (responses[1].statusCode == 200) {
        try {
          final relationsData = json.decode(responses[1].body);
          if (relationsData is Map<String, dynamic>) {
            resultData.addAll(relationsData);
            print('✅ Added relations data from: /api/producers/$producerId/relations');
          } else {
            print('⚠️ Relations data is not a map: ${relationsData.runtimeType}');
            resultData['error_relations'] = 'Invalid format';
          }
        } catch (e) {
          print('❌ Error decoding relations data: $e');
          resultData['error_relations'] = e.toString();
        }
      } else {
        print('❌ Relations API failed: ${responses[1].statusCode}');
        resultData['error_relations'] = 'HTTP ${responses[1].statusCode}';
      }

      // Sécuriser les structures de données importantes
      _ensureDataStructure(resultData, 'followers', {'count': 0, 'users': []});
      _ensureDataStructure(resultData, 'following', {'count': 0, 'users': []});
      _ensureDataStructure(resultData, 'interestedUsers', {'count': 0, 'users': []});
      _ensureDataStructure(resultData, 'choiceUsers', {'count': 0, 'users': []});
      _ensureDataStructure(resultData, 'structured_data', {'Menus Globaux': [], 'Items Indépendants': []});
      
      if (!resultData.containsKey('events')) {
        resultData['events'] = [];
      }
      print('🔍 Fetching additional events data');
      
      try {
        print('🔍 Fetching events for producer ID: $producerId');
        Map<String, dynamic> eventData = {};
        
        // Premier essai : endpoint spécifique
        try {
          final eventsUrl = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId/events');
          final eventsResponse = await http.get(eventsUrl);
          
          if (eventsResponse.statusCode == 200) {
            final dynamic events = json.decode(eventsResponse.body);
            if (events is List) {
              eventData['events'] = events;
              print('✅ Found ${events.length} events from producer events API');
            } else if (events is Map && events.containsKey('events')) {
              final eventsList = events['events'];
              if (eventsList is List) {
                eventData['events'] = eventsList;
                print('✅ Found ${eventsList.length} events from producer events API');
              } else {
                // Format inattendu mais on évite l'erreur
                eventData['events'] = [];
                print('⚠️ Events data is not in expected format, using empty list');
              }
            } else {
              // Format inattendu mais on évite l'erreur
              eventData['events'] = [];
              print('⚠️ Events data is not in expected format, using empty list');
            }
          } else {
            print('❌ Producer events API failed: ${eventsResponse.statusCode}');
            eventData['events'] = []; // Initialiser avec une liste vide par défaut
          }
        } catch (e) {
          print('❌ Error fetching producer events: $e');
          eventData['events'] = []; // Initialiser avec une liste vide en cas d'erreur
        }
        
        // Si pas d'événements, vérifier dans les données du producteur
        if (!eventData.containsKey('events') || !(eventData['events'] is List) || (eventData['events'] as List).isEmpty) {
          if (resultData.containsKey('events') && resultData['events'] is List && (resultData['events'] as List).isNotEmpty) {
            eventData['events'] = resultData['events'];
            print('✅ Found ${(resultData['events'] as List).length} events embedded in producer data');
          } else {
            // S'assurer que eventData['events'] est toujours une liste
            eventData['events'] = [];
          }
        }
        
        // Troisième tentative avec l'API générale
        if (!eventData.containsKey('events') || !(eventData['events'] is List) || (eventData['events'] as List).isEmpty) {
          try {
            final eventsUrl = Uri.parse('${constants.getBaseUrl()}/api/events?producerId=$producerId&venueId=$producerId');
            final eventsResponse = await http.get(eventsUrl);
            
            if (eventsResponse.statusCode == 200) {
              final dynamic events = json.decode(eventsResponse.body);
              if (events is List) {
                eventData['events'] = events;
                print('✅ Found ${events.length} events from general events API');
              } else if (events is Map && events.containsKey('events')) {
                final eventsList = events['events'];
                if (eventsList is List) {
                  eventData['events'] = eventsList;
                  print('✅ Found ${eventsList.length} events from general events API');
                } else {
                  // Si pas une liste, utiliser une liste vide
                  print('⚠️ Events data from general API is not in expected format, using empty list');
                  eventData['events'] = [];
                }
              } else {
                print('⚠️ Events data from general API is not in expected format, using empty list');
                eventData['events'] = [];
              }
            } else {
              print('❌ General events API failed: ${eventsResponse.statusCode}');
              eventData['events'] = []; // Initialiser avec liste vide si l'API échoue
            }
          } catch (e) {
            print('❌ Error fetching from general events API: $e');
            eventData['events'] = []; // Utiliser une liste vide en cas d'erreur
          }
        }
        
        // Mise à jour des données d'événements en s'assurant que c'est toujours une liste
        if (eventData.containsKey('events') && eventData['events'] is List) {
          resultData['events'] = eventData['events'];
          print('✅ Final event count: ${(eventData['events'] as List).length}');
        } else {
          resultData['events'] = [];
          print('✅ Final event count: 0');
        }
      } catch (e) {
        print('❌ Error during events data processing: $e');
        resultData['events'] = [];
      }

      return resultData;
    } catch (e) {
      print('❌ Erreur lors de la récupération des détails du producteur: $e');
      return {'error': e.toString()};
    }
  }

  // Méthode utilitaire pour garantir la structure des données
  void _ensureDataStructure(Map<String, dynamic> data, String key, dynamic defaultValue) {
    if (!data.containsKey(key) || data[key] == null) {
      data[key] = defaultValue;
      return;
    }
    
    // Si la clé existe mais n'est pas du bon type (Map attendu pour certaines structures)
    if (defaultValue is Map && data[key] is! Map) {
      data[key] = defaultValue;
    }
  }

  /// Fonction pour récupérer les posts d'un producteur
  Future<List<dynamic>> _fetchProducerPosts(String producerId) async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/producers/$producerId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final producerData = json.decode(response.body);
        final postIds = producerData['posts'] as List<dynamic>? ?? [];

        if (postIds.isEmpty) {
          return [];
        }

        // Récupérer les détails de chaque post à partir des IDs
        final List<dynamic> posts = [];
        for (final postId in postIds) {
          final postUrl = Uri.parse('${constants.getBaseUrl()}/api/posts/$postId');
          try {
            final postResponse = await http.get(postUrl);
            if (postResponse.statusCode == 200) {
              posts.add(json.decode(postResponse.body));
            } else {
              print('❌ Erreur HTTP pour le post $postId : ${postResponse.statusCode}');
            }
          } catch (e) {
            print('❌ Erreur réseau pour le post $postId : $e');
          }
        }
        return posts;
      } else {
        throw Exception('Erreur lors de la récupération des données du producteur.');
      }
    } catch (e) {
      print('Erreur réseau : $e');
      return [];
    }
  }

  Future<void> _markInterested(String targetId) async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/choicexinterest/interested');
    final body = {'userId': widget.producerId, 'targetId': targetId};

    if (_isMarkingInterested) return; // Prevent double taps
    setState(() { _isMarkingInterested = true; });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedInterested = json.decode(response.body)['interested'];
        setState(() {
          post['interested'] = updatedInterested; // Mettez à jour le post localement
        });
        print('✅ Interested ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout à Interested : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout à Interested : $e');
    }
    finally {
      if (mounted) {
        setState(() { _isMarkingInterested = false; });
      }
    }
  }

  Future<void> _markChoice(String targetId) async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/choicexinterest/choice');
    final body = {'userId': widget.producerId, 'targetId': targetId};

    if (_isMarkingChoice) return; // Prevent double taps
    setState(() { _isMarkingChoice = true; });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedChoices = json.decode(response.body)['choices'];
        setState(() {
          post['choices'] = updatedChoices; // Mettez à jour le post localement
        });
        print('✅ Choice ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout à Choices : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout à Choices : $e');
    }
    finally {
      if (mounted) {
        setState(() { _isMarkingChoice = false; });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchProfileById(String id) async {
    final userUrl = Uri.parse('${constants.getBaseUrl()}/api/users/$id');
    final unifiedUrl = Uri.parse('${constants.getBaseUrl()}/api/unified/$id');

    // Tenter l'appel vers `/api/users/:id`
    try {
      print('🔍 Tentative avec /api/users/:id pour l\'ID : $id');
      final userResponse = await http.get(userUrl);

      if (userResponse.statusCode == 200) {
        print('✅ Profil trouvé via /api/users/:id');
        return json.decode(userResponse.body);
      } else {
        print('❌ Échec avec /api/users/:id : ${userResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour /api/users/:id : $e');
    }

    // Si l'appel précédent échoue, tenter avec `/api/unified/:id`
    try {
      print('🔍 Tentative avec /api/unified/:id pour l\'ID : $id');
      final unifiedResponse = await http.get(unifiedUrl);

      if (unifiedResponse.statusCode == 200) {
        print('✅ Profil trouvé via /api/unified/:id');
        return json.decode(unifiedResponse.body);
      } else {
        print('❌ Échec avec /api/unified/:id : ${unifiedResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur réseau pour /api/unified/:id : $e');
    }

    // Si les deux requêtes échouent, retourner null
    print('❌ Aucun profil valide trouvé pour l\'ID : $id');
    return null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord Restaurant'),
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add),
            tooltip: 'Créer un post',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreatePostScreen(producerId: widget.producerId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Modifier le menu',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MenuManagementScreen(producerId: widget.producerId),
                ),
              );
            },
          ),
          // Bouton Promotion
          IconButton(
            icon: _hasActivePromotion 
                ? const Icon(Icons.discount, color: Colors.yellow)
                : const Icon(Icons.discount_outlined),
            tooltip: _hasActivePromotion ? 'Promotion active' : 'Créer une promotion',
            onPressed: () {
              if (_hasActivePromotion) {
                // Afficher la boîte de dialogue pour désactiver la promotion
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Promotion active'),
                    content: _promotionEndDate != null
                        ? Text(
                            'Une promotion de $_promotionDiscount% est active jusqu\'au ${DateFormat('dd/MM/yyyy').format(_promotionEndDate!)}. Voulez-vous la désactiver?')
                        : const Text('Une promotion est active. Voulez-vous la désactiver?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _deactivatePromotion();
                        },
                        child: const Text('Désactiver'),
                      ),
                    ],
                  ),
                );
              } else {
                // Afficher la boîte de dialogue pour activer une promotion
                _showPromotionDialog();
              }
            },
          ),
          // Menu button (hamburger)
          IconButton(
            icon: const Icon(Icons.menu),
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
                      // Use the current brightness directly from Theme
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fonctionnalité de thème en développement')),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: _buildMenuOption(Icons.receipt_long, 'Historique financier'),
                    onTap: () {
                      // Navigate to transaction history screen
                      Future.delayed(Duration.zero, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionHistoryScreen(
                              producerId: widget.producerId,
                            ),
                          ),
                        );
                      });
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
                      // We need to handle logout differently since PopupMenuItem.onTap
                      // is called after the menu is dismissed, which can cause context issues
                      // Using a callback with Future.delayed to ensure proper execution
                      Future.delayed(Duration.zero, () {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        authService.logout();
                        // Navigate to the landing page and clear the navigation stack
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/',
                          (route) => false,
                        );
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _producerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                    onPressed: () {
                      setState(() {
                        _producerFuture = _fetchProducerDetails(widget.producerId);
                      });
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final producer = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bannière de promotion si active
                if (_hasActivePromotion) _buildPromotionBanner(),
                
                _buildHeader(producer),
                _buildProfileActions(producer),
                const Divider(height: 20, thickness: 2),
                _buildFrequencyGraph(producer),
                const Divider(height: 20, thickness: 2),
                _buildFilterOptions(),
                const Divider(height: 20, thickness: 2),
                _buildTabs(producer),
                const Divider(height: 20, thickness: 2),
                _buildFilteredItems(producer),
                const Divider(height: 20, thickness: 2),
                _buildMap(producer['gps_coordinates']),
                const Divider(height: 20, thickness: 2),
                _buildContactDetails(producer),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // Bannière de promotion active
  Widget _buildPromotionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orangeAccent, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Promotion active!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_promotionEndDate != null)
                  Text(
                    'Réduction de $_promotionDiscount% sur tous les plats jusqu\'au ${DateFormat('dd/MM/yyyy').format(_promotionEndDate!)}',
                    style: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Désactiver la promotion?'),
                  content: const Text('Voulez-vous vraiment désactiver la promotion en cours?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _deactivatePromotion();
                      },
                      child: const Text('Désactiver'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Méthode pour afficher le dialogue d'édition du profil
  void _showEditProfileDialog(Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final descriptionController = TextEditingController(text: data['description']);
    final addressController = TextEditingController(text: data['address']);
    String? selectedImagePath;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Modifier votre profil'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo de profil
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      
                      if (image != null) {
                        setState(() {
                          selectedImagePath = image.path;
                        });
                      }
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        image: selectedImagePath != null
                            ? DecorationImage(
                                image: kIsWeb
                                    ? NetworkImage(selectedImagePath!)
                                    : FileImage(File(selectedImagePath!)) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : DecorationImage(
                                image: NetworkImage(data['photo'] ?? 'https://via.placeholder.com/100'),
                                fit: BoxFit.cover,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Align(
                        alignment: Alignment.bottomRight,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Nom du restaurant
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du restaurant',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Adresse
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Message de vérification
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Information',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Les modifications seront examinées et appliquées sous 24h après vérification manuelle.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
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
                  backgroundColor: Colors.orangeAccent,
                ),
                onPressed: () {
                  // Traitement des données (à implémenter avec API)
                  Navigator.pop(context);
                  
                  // Affichage du message de confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Modifications envoyées pour vérification. Elles seront appliquées sous 24h.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 5),
                    ),
                  );
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
                    // Photo de profil améliorée
                    GestureDetector(
                      onTap: () {
                        _showEditProfileDialog(data);
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Hero(
                          tag: 'producer-photo-${widget.producerId}',
                          child: ClipOval(
                            child: Image.network(
                              data['photo'] ?? 'https://via.placeholder.com/100',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
                                ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Informations principales
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data['name'] ?? 'Nom non spécifié',
                                  style: const TextStyle(
                                    fontSize: 24, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.black87,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              _hasActivePromotion 
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '-${_promotionDiscount.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Note avec étoiles améliorée
                          Row(
                            children: [
                              _buildRatingStars(data['rating']),
                              const SizedBox(width: 8),
                              Text(
                                '(${data['user_ratings_total'] ?? 0})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Adresse avec icône
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data['address'] ?? 'Adresse non spécifiée',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          
                          // Description
                          Text(
                            data['description'] ?? 'Description non spécifiée',
                            style: TextStyle(
                              fontSize: 14, 
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Boutons d'action améliorés
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'Éditer',
                      onTap: () {
                        _showEditProfileDialog(data);
                      },
                    ),
                    
                    _buildActionButton(
                      icon: Icons.monetization_on_outlined,
                      label: _hasActivePromotion ? 'Promo active' : 'Promotion',
                      onTap: () {
                        if (_hasActivePromotion) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Promotion active'),
                              content: _promotionEndDate != null
                                  ? Text(
                                      'Une promotion de $_promotionDiscount% est active jusqu\'au ${DateFormat('dd/MM/yyyy').format(_promotionEndDate!)}. Voulez-vous la désactiver?')
                                  : const Text('Une promotion est active. Voulez-vous la désactiver?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deactivatePromotion();
                                  },
                                  child: const Text('Désactiver'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          _showPromotionDialog();
                        }
                      },
                      isHighlighted: _hasActivePromotion,
                    ),
                    
                    _buildActionButton(
                      icon: Icons.insights,
                      label: 'Statistiques',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantStatsScreen(producerId: widget.producerId),
                          ),
                        );
                      },
                    ),
                    
                    _buildActionButton(
                      icon: Icons.people,
                      label: 'Clients',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClientsListScreen(producerId: widget.producerId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Widget pour afficher les étoiles de notation
  Widget _buildRatingStars(dynamic rating) {
    double ratingValue = 0.0;
    if (rating is int) {
      ratingValue = rating.toDouble();
    } else if (rating is double) {
      ratingValue = rating;
    } else if (rating is String) {
      ratingValue = double.tryParse(rating) ?? 0.0;
    }
    
    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            if (index < ratingValue.floor()) {
              // Étoile pleine
              return const Icon(Icons.star, color: Colors.amber, size: 20);
            } else if (index < ratingValue.ceil() && ratingValue.floor() != ratingValue.ceil()) {
              // Étoile à moitié pleine
              return const Icon(Icons.star_half, color: Colors.amber, size: 20);
            } else {
              // Étoile vide
              return const Icon(Icons.star_border, color: Colors.amber, size: 20);
            }
          }),
        ),
        const SizedBox(width: 4),
        Text(
          '$ratingValue',
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: Colors.amber,
          ),
        ),
      ],
    );
  }
  
  // Widget pour les boutons d'action dans le header
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.orangeAccent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isHighlighted ? Colors.white : Colors.orangeAccent,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isHighlighted ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyGraph(Map<String, dynamic> producer) {
    final popularTimes = producer['popular_times'] ?? [];
    if (popularTimes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            'Données de fréquentation non disponibles',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    // Extraction sécurisée des données de popularité
    List<int> filteredTimes = [];
    try {
      if (popularTimes[_selectedDay] is Map && 
          popularTimes[_selectedDay]['data'] is List) {
        
        final data = popularTimes[_selectedDay]['data'] as List;
        
        // Si la liste est suffisamment longue, prendre les heures 8-24
        if (data.length >= 24) {
          for (int i = 8; i < 24 && i < data.length; i++) {
            if (data[i] is int) {
              filteredTimes.add(data[i] as int);
            } else if (data[i] is double) {
              filteredTimes.add((data[i] as double).toInt());
            } else if (data[i] != null) {
              // Essayer de convertir en entier
              try {
                filteredTimes.add(int.parse(data[i].toString()));
              } catch (e) {
                filteredTimes.add(0); // Valeur par défaut
              }
            } else {
              filteredTimes.add(0); // Valeur par défaut
            }
          }
        } else {
          // Fallback si la liste est trop courte
          filteredTimes = List.generate(16, (index) => 0);
        }
      } else {
        // Format inattendu, générer des données par défaut
        filteredTimes = List.generate(16, (index) => 0);
      }
    } catch (e) {
      print('❌ Erreur lors de l\'extraction des données de popularité: $e');
      filteredTimes = List.generate(16, (index) => 0);
    }

    // Garantir qu'il y a au moins 16 éléments (pour les heures 8-24)
    if (filteredTimes.length < 16) {
      filteredTimes = List.generate(16, (index) => 
        index < filteredTimes.length ? filteredTimes[index] : 0
      );
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                child: const Icon(Icons.people, color: Colors.orangeAccent),
              ),
              const SizedBox(width: 12),
              const Text(
                'Fréquentation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sélecteur de jour amélioré
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(30),
            ),
            child: DropdownButton<int>(
              value: _selectedDay,
              underline: const SizedBox(),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.orangeAccent),
              items: List.generate(popularTimes.length, (index) {
                return DropdownMenuItem(
                  value: index,
                  child: Text(
                    popularTimes[index]['name'],
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }),
              onChanged: (value) {
                setState(() {
                  _selectedDay = value!;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Légende améliorée
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Heures (8h - Minuit)', 
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('Niveau d\'affluence', 
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(filteredTimes.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: filteredTimes[index].toDouble(),
                          width: 16,
                          color: Colors.orangeAccent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            colors: [Colors.orangeAccent, Colors.orange[700]!],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, _) {
                          int hour = value.toInt() + 8;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '$hour h',
                              style: TextStyle(
                                fontSize: 12, 
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
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
                  borderData: FlBorderData(show: false),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.filter_alt, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filtres nutritionnels',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              Tooltip(
                message: 'Les filtres aident vos clients à trouver des plats correspondant à leurs besoins nutritionnels',
                child: IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.grey),
                  onPressed: () {
                    // Afficher une information sur l'utilité des filtres
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('À propos des filtres'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Les filtres nutritionnels permettent à vos clients de trouver facilement des plats correspondant à leurs besoins diététiques spécifiques.'),
                            SizedBox(height: 12),
                            Text('• Le bilan carbone indique l\'impact environnemental des plats'),
                            Text('• Le NutriScore donne une indication de la qualité nutritionnelle'),
                            Text('• Les calories permettent aux clients soucieux de leur apport calorique de faire des choix éclairés'),
                            SizedBox(height: 12),
                            Text('Proposer des plats avec de bons scores améliore votre visibilité auprès des clients soucieux de leur santé et de l\'environnement.'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Compris'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Filtre Bilan Carbone
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.eco, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Bilan Carbone",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCarbon = "<3kg";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedCarbon == "<3kg" ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedCarbon == "<3kg" ? Colors.green : Colors.grey.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.eco, color: Colors.green),
                            const SizedBox(height: 8),
                            const Text(
                              "<3kg",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Faible impact",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCarbon = "<5kg";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedCarbon == "<5kg" ? Colors.amber.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedCarbon == "<5kg" ? Colors.amber : Colors.grey.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.eco, color: Colors.amber),
                            const SizedBox(height: 8),
                            const Text(
                              "<5kg",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Impact modéré",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Filtre NutriScore
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.health_and_safety, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "NutriScore",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedNutriScore = "A-B";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedNutriScore == "A-B" ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedNutriScore == "A-B" ? Colors.green : Colors.grey.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "A",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "B",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Excellents scores",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedNutriScore = "A-C";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedNutriScore == "A-C" ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedNutriScore == "A-C" ? Colors.blue : Colors.grey.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "A",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  "B",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.lightGreen,
                                  ),
                                ),
                                Text(
                                  "C",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Bons scores",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Slider de calories
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Calories maximales",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      "${_selectedMaxCalories.toInt()} cal",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.red,
                  inactiveTrackColor: Colors.red.withOpacity(0.2),
                  thumbColor: Colors.white,
                  overlayColor: Colors.red.withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                    elevation: 4,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                  trackHeight: 8,
                  valueIndicatorColor: Colors.red,
                  valueIndicatorTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  showValueIndicator: ShowValueIndicator.always,
                ),
                child: Slider(
                  value: _selectedMaxCalories,
                  min: 100,
                  max: 1000,
                  divisions: 9,
                  label: "${_selectedMaxCalories.toInt()} cal",
                  onChanged: (value) {
                    setState(() {
                      _selectedMaxCalories = value;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "100 cal",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      "1000 cal",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          
          // Bouton d'application des filtres
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text("Appliquer les filtres"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () {
                // Appliquer les filtres et mettre à jour l'affichage
                setState(() {
                  // Les filtres sont déjà appliqués via les variables d'état
                  // Notification à l'utilisateur
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Filtres appliqués avec succès"),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredItems(Map<String, dynamic> producer) {
    // Vérifier et sécuriser l'accès aux données structurées
    if (!producer.containsKey('structured_data') || producer['structured_data'] == null) {
      producer['structured_data'] = {'Items Indépendants': []};
    } else if (producer['structured_data'] is! Map) {
      producer['structured_data'] = {'Items Indépendants': []};
    }
    
    // Vérifier et sécuriser l'accès aux items indépendants
    final structuredData = producer['structured_data'] as Map<String, dynamic>;
    final items = structuredData['Items Indépendants'];
    
    if (items == null || !(items is List) || items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_food, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun item disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Filtrer et traiter les items de manière sécurisée
    final filteredItems = <String, List<Map<String, dynamic>>>{};
    
    for (var category in items) {
      if (category is! Map<String, dynamic>) continue;
      
      final categoryName = category['catégorie']?.toString().trim() ?? 'Autres';
      final categoryItems = category['items'];
      
      if (categoryItems == null || !(categoryItems is List) || categoryItems.isEmpty) continue;
      
      for (var item in categoryItems) {
        if (item is! Map<String, dynamic>) continue;
        
        // Extraire les valeurs nutritionnelles de façon sécurisée
        double carbonFootprint = 0;
        String nutriScore = 'N/A';
        double calories = 0;
        
        try {
          // Récupérer le bilan carbone
          final carbonValue = item['carbon_footprint'];
          if (carbonValue != null) {
            if (carbonValue is num) {
              carbonFootprint = carbonValue.toDouble();
            } else {
              carbonFootprint = double.tryParse(carbonValue.toString()) ?? 0;
            }
          }
          
          // Récupérer le nutriscore
          nutriScore = item['nutri_score']?.toString() ?? 'N/A';
          
          // Récupérer les calories
          if (item['nutrition'] is Map<String, dynamic>) {
            final nutritionData = item['nutrition'] as Map<String, dynamic>;
            final caloriesValue = nutritionData['calories'];
            if (caloriesValue != null) {
              if (caloriesValue is num) {
                calories = caloriesValue.toDouble();
              } else {
                calories = double.tryParse(caloriesValue.toString()) ?? 0;
              }
            }
          } else if (item['calories'] != null) {
            // Alternative si les calories sont directement dans l'item
            final caloriesValue = item['calories'];
            if (caloriesValue is num) {
              calories = caloriesValue.toDouble();
            } else {
              calories = double.tryParse(caloriesValue.toString()) ?? 0;
            }
          }
        } catch (e) {
          print('❌ Erreur lors de l\'extraction des données nutritionnelles: $e');
        }
        
        // Appliquer les filtres
        if (carbonFootprint <= (_selectedCarbon == "<3kg" ? 3 : 5) && 
            (nutriScore.compareTo(_selectedNutriScore == "A-B" ? 'C' : 'D') <= 0) && 
            calories <= _selectedMaxCalories) {
          
          filteredItems.putIfAbsent(categoryName, () => []);
          filteredItems[categoryName]!.add(item);
        }
      }
    }

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun item ne correspond aux critères',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Modifier les filtres'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                // Scroll vers les options de filtres - fonctionnalité simplifiée
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Utilisez les filtres en haut de la page')),
                );
              },
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Plats Filtrés',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Chip(
                  label: Text('Carbone: $_selectedCarbon'),
                  avatar: const Icon(Icons.eco, size: 16, color: Colors.green),
                  backgroundColor: Colors.green.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('NutriScore: $_selectedNutriScore'),
                  avatar: const Icon(Icons.health_and_safety, size: 16, color: Colors.blue),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('Max: ${_selectedMaxCalories.toInt()} cal'),
                  avatar: const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                  backgroundColor: Colors.orange.withOpacity(0.1),
                ),
              ],
            ),
          ),
          
          ...filteredItems.entries.map((entry) {
            final categoryName = entry.key;
            final categoryItems = entry.value;
            return ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                children: [
                  const Icon(Icons.category, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${categoryItems.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              children: categoryItems.map<Widget>((item) {
                // Calculer le prix après réduction si une promotion est active
                final originalPrice = double.tryParse(item['prix']?.toString() ?? '0') ?? 0;
                final discountedPrice = _hasActivePromotion 
                    ? originalPrice * (1 - _promotionDiscount / 100) 
                    : null;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête avec nom du plat, prix et éventuellement notation
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nom et notation
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['nom'] ?? 'Nom non spécifié',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (item['note'] != null)
                                        _buildCompactRatingStars(item['note']),
                                    ],
                                  ),
                                  if (item['description'] != null && item['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item['description'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Prix avec éventuelle réduction
                            if (originalPrice > 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (_hasActivePromotion && discountedPrice != null)
                                    Text(
                                      '${originalPrice.toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    _hasActivePromotion && discountedPrice != null
                                        ? '${discountedPrice.toStringAsFixed(2)} €'
                                        : '${originalPrice.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _hasActivePromotion ? Colors.red : Colors.black87,
                                    ),
                                  ),
                                  if (_hasActivePromotion)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '-${_promotionDiscount.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        
                        // Informations nutritionnelles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Bilan carbone
                            Row(
                              children: [
                                const Icon(Icons.eco, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['carbon_footprint']} kg',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            
                            // NutriScore
                            Row(
                              children: [
                                const Icon(Icons.health_and_safety, size: 16, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  'NutriScore: ${item['nutri_score'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Calories
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['nutrition']?['calories'] ?? 'N/A'} cal',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTabs(Map<String, dynamic> producer) {
    return DefaultTabController(
      length: 4, // Augmenté à 4 pour inclure l'onglet Abonnement
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Carte du Menu'),
              Tab(text: 'Photos'),
              Tab(text: 'Posts'),
              Tab(text: 'Abonnement'), // Nouvel onglet
            ],
            labelColor: Colors.orangeAccent,
            indicatorColor: Colors.orangeAccent,
            isScrollable: true, // Pour s'assurer que tous les onglets sont visibles
          ),
          SizedBox(
            height: 500, // Augmenter la hauteur pour l'onglet d'abonnement
            child: TabBarView(
              children: [
                _buildMenuDetails(producer),
                _buildPhotosSection(producer['photos'] ?? []),
                _buildPostsSection(),
                _buildSubscriptionTab(), // Nouvel onglet d'abonnement
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Construction de l'onglet d'abonnement
  Widget _buildSubscriptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière d'abonnement 
          _buildSubscriptionBanner(),
          const SizedBox(height: 20),
          
          // Section fonctionnalités premium
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
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.star, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Fonctionnalités Premium',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grille de fonctionnalités premium
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                    childAspectRatio: 3.0,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildPremiumFeatureTeaser(
                        title: 'Analytics Avancés',
                        description: 'Obtenez des données détaillées sur vos clients et votre audience.',
                        featureId: 'advanced_analytics',
                        icon: Icons.analytics,
                        color: Colors.purple,
                      ),
                      _buildPremiumFeatureTeaser(
                        title: 'Placement Premium',
                        description: 'Apparaissez en haut des résultats de recherche et des recommandations.',
                        featureId: 'premium_placement',
                        icon: Icons.trending_up,
                        color: Colors.orange,
                      ),
                      _buildPremiumFeatureTeaser(
                        title: 'Menu Personnalisable',
                        description: 'Options avancées de personnalisation de votre menu avec photos et descriptions détaillées.',
                        featureId: 'customizable_menu',
                        icon: Icons.restaurant_menu,
                        color: Colors.teal,
                      ),
                      _buildPremiumFeatureTeaser(
                        title: 'Carte de Chaleur Détaillée',
                        description: 'Visualisez précisément les mouvements et préférences de vos clients.',
                        featureId: 'detailed_heatmap',
                        icon: Icons.map,
                        color: Colors.blue,
                      ),
                      _buildPremiumFeatureTeaser(
                        title: 'Outils Marketing',
                        description: 'Campagnes marketing avancées et automatisation des promotions.',
                        featureId: 'marketing_tools',
                        icon: Icons.campaign,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Section avantages d'abonnement
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
                        child: const Icon(Icons.lightbulb, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pourquoi s\'abonner ?',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.green),
                    title: const Text('Augmentez votre visibilité'),
                    subtitle: const Text('Jusqu\'à 300% plus de vues sur votre restaurant'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.green),
                    title: const Text('Attirez plus de clients'),
                    subtitle: const Text('Les restaurants premium convertissent 2,5x plus de visiteurs'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.insights, color: Colors.green),
                    title: const Text('Optimisez votre service'),
                    subtitle: const Text('Comprenez le comportement de vos clients pour mieux les servir'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome, color: Colors.green),
                    title: const Text('Support prioritaire'),
                    subtitle: const Text('Assistance dédiée et réponses en moins de 24h'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuDetails(Map<String, dynamic> producer) {
    final menus = producer['structured_data']['Menus Globaux'] ?? [];
    if (menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun menu disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un menu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MenuManagementScreen(producerId: widget.producerId),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: Colors.orangeAccent),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Menus Disponibles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuManagementScreen(producerId: widget.producerId),
                    ),
                  );
                },
                tooltip: 'Modifier les menus',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...menus.map<Widget>((menu) {
            final inclus = menu['inclus'] ?? [];
            // Calculer le prix après réduction si une promotion est active
            final originalPrice = double.tryParse(menu['prix']?.toString() ?? '0') ?? 0;
            final discountedPrice = _hasActivePromotion 
                ? originalPrice * (1 - _promotionDiscount / 100) 
                : null;
                
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête du menu avec prix et éventuelle réduction
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            menu['nom'] ?? 'Menu sans nom',
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_hasActivePromotion && discountedPrice != null)
                              Text(
                                '${originalPrice.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              _hasActivePromotion && discountedPrice != null
                                  ? '${discountedPrice.toStringAsFixed(2)} €'
                                  : '${originalPrice.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _hasActivePromotion ? Colors.red : Colors.black87,
                              ),
                            ),
                            if (_hasActivePromotion)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '-${_promotionDiscount.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenu du menu avec les items inclus
                  ExpansionTile(
                    title: const Text(
                      'Voir le détail',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    children: inclus.map<Widget>((inclusItem) {
                      final items = inclusItem['items'] ?? [];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inclusItem['catégorie'] ?? 'Non spécifié',
                                style: const TextStyle(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...items.map<Widget>((item) {
                              return Card(
                                elevation: 0,
                                color: Colors.grey[50],
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['nom'] ?? 'Nom non spécifié',
                                              style: const TextStyle(
                                                fontSize: 16, 
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (item['note'] != null)
                                            _buildCompactRatingStars(item['note']),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['description'] ?? 'Pas de description',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  // Widget pour afficher les étoiles de notation en format compact
  Widget _buildCompactRatingStars(dynamic rating) {
    double ratingValue = 0.0;
    if (rating is int) {
      ratingValue = rating.toDouble();
    } else if (rating is double) {
      ratingValue = rating;
    } else if (rating is String) {
      ratingValue = double.tryParse(rating) ?? 0.0;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 2),
        Text(
          ratingValue.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(List<dynamic> photos) {
    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune photo disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Ajouter des photos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                // Fonctionnalité d'ajout de photos à implémenter
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité en développement')),
                );
              },
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Galerie Photos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              Text(
                '${photos.length} photos',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                // Afficher la photo en plein écran avec un dialogue simple
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          // Image en plein écran
                          InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4,
                            child: Image.network(
                              photos[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Bouton de fermeture
                          Positioned(
                            top: 20,
                            right: 20,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(photos[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
        
        // Bouton pour ajouter des photos
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Ajouter des photos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité en développement')),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerPosts(widget.producerId), // Appel correct
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(
            child: Text('Aucun post disponible pour ce producteur.'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post);
          },
        );
      },
    );
  }


  Widget _buildPostCard(Map<String, dynamic> post) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final producerId = post['producer_id']; // ID du producer
    final isProducerPost = producerId != null; // Vérification si c'est un producer
    final interestedCount = post['interested']?.length ?? 0;
    final choicesCount = post['choices']?.length ?? 0;

    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(
                      post['user_photo'] ?? 'https://via.placeholder.com/150',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post['author_name'] ?? 'Nom non spécifié',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                post['title'] ?? 'Titre non spécifié',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Content
              Text(post['content'] ?? 'Contenu non disponible'),
              const SizedBox(height: 10),

              // Media
              if (mediaUrls.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView(
                    children: mediaUrls.map((url) {
                      return Image.network(url, fit: BoxFit.cover, width: double.infinity);
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 10),

              // Actions (Like, Interested, Choice, Share)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like Button (Placeholder)
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () {
                          print('Like functionality not yet implemented');
                        },
                      ),
                      const Text('Like'), // Placeholder text
                    ],
                  ),

                  // Interested Button (🤔)
                  if (isProducerPost)
                    Column(
                      children: [
                        _isMarkingInterested
                            ? const SizedBox(width: 48, height: 48, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))) // Show loader aligned with IconButton
                            : IconButton(
                                icon: Icon(
                                  post['interested']?.contains(widget.producerId) ?? false
                                      ? Icons.emoji_objects
                                      : Icons.emoji_objects_outlined,
                                  color: post['interested']?.contains(widget.producerId) ?? false
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                                onPressed: () => _markInterested(producerId!), // Passez `post`
                              ),
                        Padding(padding: EdgeInsets.only(top: _isMarkingInterested ? 0 : 0), child: Text('$interestedCount Interested')),
                      ],
                    ),

                  // Choice Button (✅)
                  if (isProducerPost)
                    Column(
                      children: [
                        _isMarkingChoice
                            ? const SizedBox(width: 48, height: 48, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))) // Show loader
                            : IconButton(
                                icon: Icon(
                                  post['choices']?.contains(widget.producerId) ?? false
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  color: post['choices']?.contains(widget.producerId) ?? false
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  if (producerId != null) {
                                    _markChoice(producerId);
                                  }
                                },
                              ),
                        Padding(padding: EdgeInsets.only(top: _isMarkingChoice ? 0: 0), child: Text('$choicesCount Choices')),
                      ],
                    ),

                  // Share Button
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      print('Share functionality triggered');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: post, // Passez les données du post directement
          producerId: widget.producerId, // Utilisez le userId pour les actions
        ),
      ),
    );
  }

  Widget _buildMap(Map<String, dynamic>? coordinates) {
    try {
      // Vérification que coordinates et coordinates['coordinates'] existent
      if (coordinates == null || coordinates['coordinates'] == null) {
        return const Text('Coordonnées GPS non disponibles.');
      }
      
      // Vérification que coordinates['coordinates'] est une liste avec au moins 2 éléments
      final List? coords = coordinates['coordinates'];
      if (coords == null || coords.length < 2) {
        print('❌ Format de coordonnées invalide');
        return const Text('Format de coordonnées invalide.');
      }
      
      // Vérification que les coordonnées sont numériques
      if (coords[0] == null || coords[1] == null || 
          !(coords[0] is num) || !(coords[1] is num)) {
        print('❌ Coordonnées invalides: valeurs non numériques');
        return const Text('Coordonnées invalides: valeurs non numériques.');
      }
      
      // Convertir en double de manière sécurisée
      final double lon = coords[0].toDouble();
      final double lat = coords[1].toDouble();
      
      // Vérifier que les coordonnées sont dans les limites valides
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        print('❌ Coordonnées invalides: hors limites (lat: $lat, lon: $lon)');
        return const Text('Coordonnées invalides: hors limites.');
      }

      final latLng = LatLng(lat, lon);

      return SizedBox(
        height: 200,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
          markers: {Marker(markerId: const MarkerId('producer'), position: latLng)},
        ),
      );
    } catch (e) {
      print('❌ Erreur lors du rendu de la carte: $e');
      return const Text('Erreur lors du chargement de la carte.');
    }
  }

  Widget _buildContactDetails(Map<String, dynamic> producer) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (producer['phone_number'] != null)
            Text('Téléphone : ${producer['phone_number']}',
                style: const TextStyle(fontSize: 14, color: Colors.black)),
          if (producer['website'] != null)
            Text('Site web : ${producer['website']}',
                style: const TextStyle(fontSize: 14, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildProfileActions(Map<String, dynamic> data) {
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

    void _navigateToRelationDetails(String title, dynamic ids) async {
      if (ids == null) {
        print('❌ Les IDs sont null.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur : Aucune donnée disponible.')),
        );
        return;
      }

      if (ids is! List) {
        print('❌ Les IDs ne sont pas une liste valide.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur : Les IDs ne sont pas valides.')),
        );
        return;
      }

      // Convertir de manière sécurisée les IDs en liste de chaînes
      List<String> validIds = [];
      for (var id in ids) {
        if (id != null) {
          validIds.add(id.toString());
        }
      }

      if (validIds.isEmpty) {
        print('❌ Aucun ID valide trouvé après conversion.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur : Aucun ID valide trouvé.')),
        );
        return;
      }

      final validProfiles = await _validateProfiles(validIds);

      if (validProfiles.isNotEmpty) {
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
        print('❌ Aucun profil valide trouvé pour les IDs : $ids');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun profil valide trouvé.')),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              final users = data['followers']?['users'] as List<dynamic>? ?? [];
              _navigateToRelationDetails('Followers', users.cast<String>());
            },
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  Text(
                    '$followersCount',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text('Followers'),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              final users = data['following']?['users'] as List<dynamic>? ?? [];
              _navigateToRelationDetails('Following', users.cast<String>());
            },
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  Text(
                    '$followingCount',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text('Following'),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              final users = data['interestedUsers']?['users'] as List<dynamic>? ?? [];
              _navigateToRelationDetails('Interested', users.cast<String>());
            },
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  Text(
                    '$interestedCount',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text('Interested'),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              final users = data['choiceUsers']?['users'] as List<dynamic>? ?? [];
              _navigateToRelationDetails('Choices', users.cast<String>());
            },
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  Text(
                    '$choicesCount',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text('Choices'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour afficher la bannière d'abonnement
  Widget _buildSubscriptionBanner() {
    final Map<String, Color> levelColors = {
      'gratuit': Colors.grey,
      'starter': Colors.blue,
      'pro': Colors.indigo,
      'legend': Colors.amber.shade800,
    };
    
    final Map<String, IconData> levelIcons = {
      'gratuit': Icons.card_giftcard,
      'starter': Icons.star,
      'pro': Icons.verified,
      'legend': Icons.workspace_premium,
    };
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubscriptionScreen(
            producerId: widget.producerId,
          ),
        ),
      ).then((_) {
        _loadSubscriptionInfo();
        _checkPremiumFeatureAccess();
      }),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              levelColors[_currentSubscription]!.withOpacity(0.8),
              levelColors[_currentSubscription]!.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              levelIcons[_currentSubscription] ?? Icons.card_giftcard,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Abonnement ${_currentSubscription.toUpperCase()}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget pour afficher un teaser de fonctionnalité premium
  Widget _buildPremiumFeatureTeaser({
    required String title,
    required String description,
    required String featureId,
    required IconData icon,
    Color? color,
  }) {
    final bool hasAccess = _premiumFeaturesAccess[featureId] ?? false;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: hasAccess ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: hasAccess ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasAccess ? Colors.green : (color ?? Colors.blue)).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: hasAccess ? Colors.green : (color ?? Colors.blue),
                  size: 20,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                hasAccess ? Icons.check_circle : Icons.lock,
                color: hasAccess ? Colors.green : Colors.grey,
                size: 18,
              ),
            ],
          ),
          if (!hasAccess) ...[
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => _showUpgradePrompt(featureId),
              style: TextButton.styleFrom(
                foregroundColor: color ?? Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size(double.infinity, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: color ?? Colors.blue),
                ),
              ),
              child: Text(
                'Débloquer',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? producerId;

  const PostDetailScreen({Key? key, required this.post, this.producerId}) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, dynamic> post; // Post à modifier localement
  late int interestedCount;
  late int choicesCount;
  bool _isMarkingInterested = false; // Loading flag for Interested
  bool _isMarkingChoice = false;     // Loading flag for Choice

  @override
  void initState() {
    super.initState();
    post = widget.post;
    interestedCount = post['interested']?.length ?? 0;
    choicesCount = post['choices']?.length ?? 0;
  }

  Future<void> _markInterested(String targetId) async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/choicexinterest/interested');
    final body = {'userId': widget.producerId, 'targetId': targetId};

    if (_isMarkingInterested) return; // Prevent double taps
    setState(() { _isMarkingInterested = true; });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedInterested = json.decode(response.body)['interested'];
        setState(() {
          post['interested'] = updatedInterested;
          interestedCount = updatedInterested.length; // Mise à jour du compteur
        });
        print('✅ Interested ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout à Interested : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout à Interested : $e');
    }
    finally {
      if (mounted) {
        setState(() { _isMarkingInterested = false; });
      }
    }
  }

  Future<void> _markChoice(String targetId) async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/choicexinterest/choice');
    final body = {'userId': widget.producerId, 'targetId': targetId};

    if (_isMarkingChoice) return; // Prevent double taps
    setState(() { _isMarkingChoice = true; });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final updatedChoices = json.decode(response.body)['choices'];
        setState(() {
          post['choices'] = updatedChoices;
          choicesCount = updatedChoices.length; // Mise à jour du compteur
        });
        print('✅ Choice ajouté avec succès');
      } else {
        print('❌ Erreur lors de l\'ajout à Choices : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de l\'ajout à Choices : $e');
    }
    finally {
      if (mounted) {
        setState(() { _isMarkingChoice = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final producerId = post['producer_id']; // ID du producteur associé au post

    return Scaffold(
      appBar: AppBar(
        title: Text(post['title'] ?? 'Détails du Post'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images du post
              if (mediaUrls.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView(
                    children: mediaUrls.map((url) {
                      return Image.network(url, fit: BoxFit.cover);
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),

              // Contenu du post
              Text(
                post['content'] ?? 'Contenu non disponible',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Boutons d'actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Interested Button
                  Column(
                    children: [
                      _isMarkingInterested
                          ? const SizedBox(width: 48, height: 48, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))) // Show loader aligned with IconButton
                          : IconButton(
                              icon: Icon(
                                post['interested']?.contains(widget.producerId) ?? false
                                    ? Icons.emoji_objects
                                    : Icons.emoji_objects_outlined,
                                color: post['interested']?.contains(widget.producerId) ?? false
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                if (producerId != null) {
                                  _markInterested(producerId);
                                }
                              },
                            ),
                      Padding(padding: EdgeInsets.only(top: _isMarkingInterested ? 0 : 0), child: Text('$interestedCount Interested')),
                    ],
                  ),

                  // Choice Button
                  Column(
                    children: [
                      _isMarkingChoice
                          ? const SizedBox(width: 48, height: 48, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))) // Show loader
                          : IconButton(
                              icon: Icon(
                                post['choices']?.contains(widget.producerId) ?? false
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: post['choices']?.contains(widget.producerId) ?? false
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                if (producerId != null) {
                                  _markChoice(producerId);
                                }
                              },
                            ),
                      Padding(padding: EdgeInsets.only(top: _isMarkingChoice ? 0: 0), child: Text('$choicesCount Choices')),
                    ],
                  ),

                  // Like Button (à implémenter plus tard)
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up_alt_outlined),
                        onPressed: () {
                          print('Like functionality not yet implemented');
                        },
                      ),
                      const Text('Like'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelationDetailsScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> profiles; // Liste des profils à afficher

  const RelationDetailsScreen({Key? key, required this.title, required this.profiles})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orangeAccent,
      ),
      body: profiles.isNotEmpty
          ? ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                try {
                  final profile = profiles[index];
                  if (profile == null || profile is! Map<String, dynamic>) {
                    print('❌ Profil invalide à l\'index $index');
                    return const SizedBox.shrink();
                  }

                  // Récupération des données de manière sécurisée
                  final userId = profile['_id']?.toString();
                  final producerId = profile['producerId']?.toString();
                  
                  // Vérifier que producerData est bien un Map si présent
                  final producerData = profile['producerData'] is Map ? 
                      profile['producerData'] as Map<String, dynamic> : null;
                  
                  // Utiliser la première photo valide trouvée
                  String photoUrl = 'https://via.placeholder.com/150';
                  for (var key in ['photo', 'photo_url', 'avatar', 'image']) {
                    if (profile[key] != null && profile[key].toString().isNotEmpty) {
                      photoUrl = profile[key].toString();
                      break;
                    }
                  }
                  
                  // Récupérer le nom avec fallback pour divers champs possibles
                  String name = 'Nom inconnu';
                  for (var key in ['name', 'username', 'displayName', 'title', 'nom']) {
                    if (profile[key] != null && profile[key].toString().isNotEmpty) {
                      name = profile[key].toString();
                      break;
                    }
                  }
                  
                  // Récupérer la description avec fallback pour divers champs possibles
                  String description = 'Pas de description';
                  for (var key in ['description', 'bio', 'about', 'summary']) {
                    if (profile[key] != null && profile[key].toString().isNotEmpty) {
                      description = profile[key].toString();
                      break;
                    }
                  }

                  // Détection du type de profil
                  final isUser = userId != null && producerId == null && producerData == null;
                  final isProducer = producerId != null;
                  final isLeisureProducer = producerData != null;

                  // Vérification des profils non valides
                  if (!isUser && !isProducer && !isLeisureProducer) {
                    print('❌ Profil non valide à l\'index $index (aucun type reconnu)');
                    return const SizedBox.shrink(); // Ignore les entrées non valides
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(photoUrl),
                        onBackgroundImageError: (_, __) {
                          // Gérer l'erreur d'image silencieusement
                          print('⚠️ Erreur de chargement d\'image pour le profil à l\'index $index');
                        },
                        backgroundColor: Colors.grey[300],
                        child: photoUrl == 'https://via.placeholder.com/150' 
                            ? const Icon(Icons.person, color: Colors.grey) 
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        description,
                        style: const TextStyle(color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _navigateToProfile(context, userId, producerId, producerData, isUser, isProducer, isLeisureProducer),
                    ),
                  );
                } catch (e) {
                  print('❌ Erreur de rendu pour le profil à l\'index $index: $e');
                  return const SizedBox.shrink();
                }
              },
            )
          : Center(
              child: Text(
                'Aucun profil disponible.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
    );
  }
  
  void _navigateToProfile(
    BuildContext context,
    String? userId,
    String? producerId,
    Map<String, dynamic>? producerData,
    bool isUser,
    bool isProducer,
    bool isLeisureProducer
  ) async {
    try {
      // Gestion des navigations selon le type de profil
      if (isUser && userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: userId),
          ),
        );
        return;
      }
      
      if (isProducer && producerId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: producerId,
            ),
          ),
        );
        return;
      }
      
      if (isLeisureProducer && producerData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(
              producerData: producerData,
            ),
          ),
        );
        return;
      }
      
      // Si aucune condition n'est satisfaite, afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir ce profil: données insuffisantes'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('❌ Erreur de navigation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la navigation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class CreatePostScreen extends StatefulWidget {
  final String producerId;

  const CreatePostScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _mediaUrl; // Chemin local du fichier média sélectionné
  String? _mediaType; // "image" ou "video"
  bool _isLoading = false;

  List<dynamic> _searchResults = []; // Liste pour stocker les résultats de recherche
  String? _selectedLocationId; // ID de l'élément sélectionné
  String? _selectedLocationType; // Type de l'élément sélectionné (restaurant ou event)
  String? _selectedLocationName; // Nom de l'élément sélectionné

  /// Fonction pour créer un post
  Future<void> _createPost() async {
    final content = _contentController.text;

    if (content.isEmpty || _selectedLocationId == null || _selectedLocationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le contenu et sélectionner un lieu ou un événement.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final postData = {
      'producer_id': widget.producerId,
      'content': content,
      'tags': ['example'], // Exemple de tags, à personnaliser
      'media': _mediaUrl != null ? [_mediaUrl] : [],
      'target_id': _selectedLocationId, // ID du lieu ou événement sélectionné
      'target_type': _selectedLocationType == 'restaurant' ? 'producer' : _selectedLocationType, // Convertir 'restaurant' en 'producer'
      'choice': true, // Ajouter un choix par défaut
    };

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/posts');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post créé avec succès !')),
        );
        Navigator.pop(context); // Revenir au profil après la création
      } else {
        print('Erreur : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création du post.')),
        );
      }
    } catch (e) {
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fonction pour sélectionner une photo ou une vidéo
  Future<void> _uploadMedia(bool isImage) async {
    final XFile? mediaFile = await (isImage
        ? _picker.pickImage(source: ImageSource.gallery, imageQuality: 50)
        : _picker.pickVideo(source: ImageSource.gallery));

    if (mediaFile != null) {
      String mediaPath;

      if (kIsWeb) {
        // Utilisation de `webImage` pour récupérer l'URL de l'image sur Web
        Uint8List bytes = await mediaFile.readAsBytes();
        mediaPath = "data:image/jpeg;base64,${base64Encode(bytes)}"; // Convertit en Base64
      } else {
        mediaPath = mediaFile.path; // Normal pour Android/iOS
      }

      if (mounted) {
        setState(() {
          _mediaUrl = mediaPath;
          _mediaType = isImage ? "image" : "video";
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun fichier sélectionné.')),
        );
      }
    }
  }


  /// Fonction pour effectuer une recherche
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/unified/search?query=$query');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List<dynamic>;
        setState(() {
          _searchResults = results;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun résultat trouvé.')),
        );
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau.')),
      );
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedLocationId = null;
      _selectedLocationType = null;
      _selectedLocationName = null;
      _locationNameController.clear();
    });
  }

  Widget _buildMediaPreview() {
    if (_mediaUrl == null) return const SizedBox.shrink();

    return Image.network(_mediaUrl!, height: 200, width: double.infinity, fit: BoxFit.cover);
  }




  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contenu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Partagez votre expérience...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rechercher un lieu associé',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _locationNameController,
              onChanged: _performSearch,
              enabled: _selectedLocationId == null, // Désactiver si un lieu est sélectionné
              decoration: const InputDecoration(
                hintText: 'Recherchez un restaurant ou un événement...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_searchResults.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView(
                  children: _searchResults.map((item) {
                    final String type = item['type'] ?? 'unknown';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          item['image'] ?? item['photo'] ?? '',
                        ),
                      ),
                      title: Text(item['name'] ?? item['intitulé'] ?? 'Nom non spécifié'),
                      subtitle: Text(item['type'] ?? 'Type inconnu'),
                      onTap: () {
                        setState(() {
                          _selectedLocationId = item['_id'];
                          _selectedLocationType = item['type'];
                          _selectedLocationName = item['name'] ?? item['intitulé'];
                          _searchResults = [];
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            if (_selectedLocationId != null && _selectedLocationType != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lieu sélectionné : $_selectedLocationName (Type : $_selectedLocationType)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _resetSelection,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Ajouter un média',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _uploadMedia(true),
                  child: const Text('Sélectionner une image'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _uploadMedia(false),
                  child: const Text('Sélectionner une vidéo'),
                ),
              ],
            ),
            if (_mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: kIsWeb
                    ? Image.network(
                        _mediaUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ) // Web
                    : _buildMediaPreview()
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createPost,
                    child: const Text('Poster'),
                  ),
          ],
        ),
      ),
    );
  }
}

class MenuManagementScreen extends StatefulWidget {
  final String producerId;

  const MenuManagementScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<Map<String, dynamic>> globalMenus = [];
  Map<String, List<Map<String, dynamic>>> independentItems = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenuData();
  }

  /// Récupère les données du menu depuis le backend
  Future<void> _fetchMenuData() async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Données du backend : $data");

        // Vérification de la structure des menus globaux
        List<Map<String, dynamic>> safeGlobalMenus = [];
        if (data['structured_data']['Menus Globaux'] is List) {
          safeGlobalMenus = List<Map<String, dynamic>>.from(data['structured_data']['Menus Globaux']);
        }

        // Vérification des items indépendants et regroupement par catégorie
        Map<String, List<Map<String, dynamic>>> groupedItems = {};
        if (data['structured_data']['Items Indépendants'] is List) {
          for (var category in data['structured_data']['Items Indépendants']) {
            if (category is! Map<String, dynamic>) continue;

            final categoryName = category['catégorie']?.toString().trim() ?? 'Autres';
            final items = category['items'] is List
                ? List<Map<String, dynamic>>.from(category['items'].whereType<Map<String, dynamic>>())
                : [];

            groupedItems.putIfAbsent(categoryName, () => <Map<String, dynamic>>[]).addAll(
              items.whereType<Map<String, dynamic>>() // Filtrer uniquement les bons types
            );
          }
        }

        setState(() {
          globalMenus = safeGlobalMenus;
          independentItems = groupedItems;
          isLoading = false;
        });
      } else {
        _showError("Erreur lors de la récupération des données.");
      }
    } catch (e) {
      _showError("Erreur réseau : $e");
    }
  }

  void _submitUpdates() async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/update-items');

    final updatedData = {
      "Menus Globaux": globalMenus,
      "Items Indépendants": independentItems,
    };

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updatedData),
      );

      if (response.statusCode == 200) {
        print("✅ Menus et items mis à jour avec succès !");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mise à jour réussie")),
        );
      } else {
        print("❌ Erreur lors de la mise à jour : ${response.body}");
      }
    } catch (e) {
      print("❌ Erreur réseau : $e");
    }
  }
  /// Affiche un message d'erreur
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Affiche un message de succès
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Gestion des menus globaux
  void _addGlobalMenu() {
    setState(() {
      globalMenus.add({
        "nom": "",
        "prix": "",
        "inclus": [],
      });
    });
  }

  void _deleteGlobalMenu(int index) {
    setState(() {
      globalMenus.removeAt(index);
    });
  }

  void _addCategoryToMenu(int menuIndex) {
    setState(() {
      globalMenus[menuIndex]["inclus"].add({
        "catégorie": "",
        "items": [],
      });
    });
  }

  void _addItemToCategory(int menuIndex, int categoryIndex) {
    setState(() {
      globalMenus[menuIndex]["inclus"][categoryIndex]["items"].add({
        "nom": "",
        "description": "",
      });
    });
  }

  void _deleteItemFromCategory(int menuIndex, int categoryIndex, int itemIndex) {
    setState(() {
      globalMenus[menuIndex]["inclus"][categoryIndex]["items"].removeAt(itemIndex);
    });
  }

  /// Gestion des items indépendants
  void _addIndependentItem(String category) {
    setState(() {
      independentItems[category] ??= [];
      independentItems[category]!.add({
        "nom": "",
        "description": "",
        "prix": "",
      });
    });
  }

  void _deleteIndependentItem(String category, int itemIndex) {
    setState(() {
      independentItems[category]!.removeAt(itemIndex);
      if (independentItems[category]!.isEmpty) {
        independentItems.remove(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Menus"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitUpdates,
            tooltip: "Enregistrer les modifications",
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlobalMenusSection(),
                  const SizedBox(height: 20),
                  _buildIndependentItemsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildGlobalMenusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Menus Globaux", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...globalMenus.asMap().entries.map((entry) {
          final menuIndex = entry.key;
          final menu = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ExpansionTile(
              title: Text(menu["nom"] ?? "Nouveau Menu"),
              subtitle: Text("Prix du menu : ${menu["prix"] ?? "N/A"}"),
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: "Nom"),
                  onChanged: (value) {
                    setState(() {
                      globalMenus[menuIndex]["nom"] = value;
                    });
                  },
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Prix du menu"),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      globalMenus[menuIndex]["prix"] = value;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _deleteGlobalMenu(menuIndex),
                      child: const Text("Supprimer"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditItemScreen(
                              producerId: widget.producerId,
                              item: menu,
                              onSave: (updatedMenu) {
                                setState(() {
                                  globalMenus[menuIndex] = updatedMenu;
                                });
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text("Modifier"),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
        ElevatedButton(
          onPressed: _addGlobalMenu,
          child: const Text("Ajouter un Menu Global"),
        ),
      ],
    );
  }


  Widget _buildIndependentItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Items Indépendants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...independentItems.entries.map((entry) {
          final category = entry.key;
          final items = entry.value ?? [];

          return ExpansionTile(
            title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: items.asMap().entries.map((entry) {
              final itemIndex = entry.key;
              final item = entry.value;

              return Card(
                child: ListTile(
                  title: Text(item["nom"] ?? "Nom inconnu"),
                  subtitle: Text("Prix : ${item["prix"] ?? "N/A"}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditItemScreen(
                                producerId: widget.producerId,
                                item: item,
                                onSave: (updatedItem) {
                                  setState(() {
                                    independentItems[category]![itemIndex] = updatedItem;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            independentItems[category]!.removeAt(itemIndex);
                            if (independentItems[category]!.isEmpty) {
                              independentItems.remove(category);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
        ElevatedButton(
          onPressed: () {
            _addIndependentItem("Nouvelle Catégorie");
          },
          child: const Text("Ajouter un Item Indépendant"),
        ),
      ],
    );
  }
}

class EditItemScreen extends StatefulWidget {
  final String producerId; // 🔥 Ajout de producerId
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onSave;

  const EditItemScreen({
    Key? key,
    required this.producerId, // 🔥 Ajout ici
    required this.item,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  
  Future<void> _updateSingleItem() async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/items/${widget.item['_id']}');


    final body = jsonEncode({
      "nom": nameController.text,
      "description": descriptionController.text,
      "prix": priceController.text.isNotEmpty ? double.parse(priceController.text) : null,
    });

    print('📤 Envoi de la requête PUT pour modifier un item...');
    print('📦 Données envoyées : $body');

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print('🛠 Status Code Backend : ${response.statusCode}');
      print('🛠 Réponse Backend : ${response.body}');

      if (response.statusCode == 200) {
        _showSuccess("Item mis à jour avec succès !");
        Navigator.pop(context); // Fermer l'écran après mise à jour
      } else {
        _showError("Erreur : ${response.body}");
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour : $e');
      _showError("Erreur réseau : $e");
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }


  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item['nom'] ?? '');
    descriptionController = TextEditingController(text: widget.item['description'] ?? '');
    priceController = TextEditingController(text: widget.item['prix']?.toString() ?? '');
  }

  void _saveChanges() {
    print('🔄 Sauvegarde des changements');
    print('📦 Avant mise à jour : ${jsonEncode(widget.item)}');

    widget.onSave({
      "nom": nameController.text,
      "description": descriptionController.text,
      "prix": priceController.text,
    });

    print('✅ Après mise à jour : ${jsonEncode(widget.item)}');
    Navigator.pop(context);
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier l'élément")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nom"),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: "Prix"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateSingleItem,
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionScreen extends StatefulWidget {
  final String producerId;

  const SubscriptionScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedPlan = 'gratuit';
  
  @override
  void initState() {
    super.initState();
    print("📢 SubscriptionScreen chargé avec producerId: ${widget.producerId}");
    
    // Initialiser les animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    _animationController.dispose();
    super.dispose();
  }

  void _subscribe(BuildContext context, String plan) async {
    setState(() {
      _isProcessing = true;
      _selectedPlan = plan;
    });

    try {
      bool success = await PaymentService.processPayment(context, plan, widget.producerId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Abonnement $plan réussi ! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Retour au profil
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
    }

    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Abonnement Premium"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Hero Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 24,
                                  child: Icon(Icons.star, color: Colors.deepPurple.shade700, size: 30),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Premium",
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        "Choisissez le forfait adapté à vos besoins",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.payments, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    "Apple Pay & Carte bancaire acceptés",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Plan Cards
                      _buildPlanCard(
                        plan: 'gratuit',
                        title: 'Gratuit',
                        price: 0,
                        features: PaymentService.subscriptionTiers['gratuit']!['features'] as List<String>,
                        isRecommended: false,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildPlanCard(
                        plan: 'starter',
                        title: 'Starter',
                        price: 5,
                        features: PaymentService.subscriptionTiers['starter']!['features'] as List<String>,
                        isRecommended: false,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildPlanCard(
                        plan: 'pro',
                        title: 'Pro',
                        price: 10,
                        features: PaymentService.subscriptionTiers['pro']!['features'] as List<String>,
                        isRecommended: true,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildPlanCard(
                        plan: 'legend',
                        title: 'Legend',
                        price: 15,
                        features: PaymentService.subscriptionTiers['legend']!['features'] as List<String>,
                        isRecommended: false,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Secure Payment Notice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
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
              ),
            ),
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
}

class ClientsListScreen extends StatelessWidget {
  final String producerId;
  
  const ClientsListScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes clients'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Fonctionnalité en développement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vous pourrez bientôt voir la liste de vos clients fidèles et analyser leurs préférences.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantStatsScreen extends StatelessWidget {
  final String producerId;
  
  const RestaurantStatsScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques du restaurant'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Fonctionnalité en développement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Les statistiques détaillées de votre établissement seront bientôt disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}




