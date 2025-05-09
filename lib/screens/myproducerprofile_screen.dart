import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'post_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
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
import 'relation_details_screen.dart'; // Added import
import 'create_post_screen.dart'; // Added import
import 'menu_management_screen.dart'; // Added import
import 'edit_item_screen.dart'; // Added import
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../widgets/feed/post_card.dart'; // Import for PostCard
import '../utils.dart' show getImageProvider, safeGetBool;
import '../models/post.dart'; // USE this import for the consolidated Post model
// Corrected imports for widgets relative to screens directory
import 'widgets/profile_header.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../widgets/producer_menu_card.dart'; // Import for ProducerMenuCard


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
      // En cas d'erreur, définir un niveau par défaut
      if (mounted) {
        setState(() {
          _currentSubscription = 'gratuit';
        });
      }
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
        bool hasAccess = false;
        try {
          hasAccess = await _premiumFeatureService.canAccessFeature(
            widget.producerId, 
            feature
          );
        } catch (featureError) {
          print('❌ Erreur lors de la vérification de l\'accès à $feature: $featureError');
          // En cas d'erreur sur une fonctionnalité spécifique, supposer que l'accès est refusé
          hasAccess = false;
        }
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
          // En cas d'erreur globale, définir tous les accès à false
          _premiumFeaturesAccess = Map.fromIterable(
            _premiumFeaturesAccess.keys,
            key: (k) => k,
            value: (_) => false
          );
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
            } else if (postResponse.statusCode == 404) {
              // Ignorer silencieusement les posts qui n'existent plus
              print('ℹ️ Post $postId non trouvé (ignoré)');
              continue;
            } else {
              print('❌ Erreur HTTP pour le post $postId : ${postResponse.statusCode}');
            }
          } catch (e) {
            print('❌ Erreur réseau pour le post $postId : $e');
            // Continuer avec les autres posts en cas d'erreur
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

  // *** ADDED: Helper for Global Menus (adapted from myproducerprofile_screen (2).dart) ***
  List<Widget> _buildGlobalMenusWidgets(Map<String, dynamic> producer) {
    final menus = producer['structured_data']?['Menus Globaux'] ?? [];
    if (menus.isEmpty || !(menus is List)) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text('Aucun menu global disponible.'),
        )
      ];
    }
    
    return menus.map<Widget>((menu) {
      if (menu is! Map<String, dynamic>) return const SizedBox.shrink();
      
      final inclus = menu['inclus'] ?? [];
      final originalPrice = double.tryParse(menu['prix']?.toString() ?? '0') ?? 0;
      final discountedPrice = _hasActivePromotion ? originalPrice * (1 - _promotionDiscount / 100) : null;
      
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_hasActivePromotion && discountedPrice != null)
                        Text(
                          '${originalPrice.toStringAsFixed(2)} €',
                          style: const TextStyle(fontSize: 14, decoration: TextDecoration.lineThrough, color: Colors.grey),
                        ),
                      Text(
                        _hasActivePromotion && discountedPrice != null
                            ? '${discountedPrice.toStringAsFixed(2)} €'
                            : '${originalPrice.toStringAsFixed(2)} €',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _hasActivePromotion ? Colors.red : Colors.black87),
                      ),
                      if (_hasActivePromotion)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                          child: Text('-${_promotionDiscount.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // ExpansionTile for details
            ExpansionTile(
              title: const Text('Voir le détail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.orangeAccent)),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              children: (inclus is List ? inclus as List : []).cast<Map<String, dynamic>>().map<Widget>((inclusItem) { // Fixed cast
                final items = inclusItem['items'] ?? [];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                        child: Text(inclusItem['catégorie'] ?? 'Non spécifié', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      const SizedBox(height: 8),
                      ...(items is List ? items as List : []).cast<Map<String, dynamic>>().map<Widget>((item) { // Fixed cast
                        return Card(
                          elevation: 0, color: Colors.grey[50], margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(item['nom'] ?? 'Nom non spécifié', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                    if (item['note'] != null) _buildCompactRatingStars(item['note']),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(item['description'] ?? 'Pas de description', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
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
    }).toList();
  }
  
  // *** ADDED: Helper for Filtered Items (adapted from myproducerprofile_screen (2).dart) ***
  List<Widget> _buildFilteredItemsWidgets(Map<String, dynamic> producer) {
    if (!producer.containsKey('structured_data') || producer['structured_data'] == null) return [Text('Aucun item indépendant.')];
    final structuredData = producer['structured_data'] as Map<String, dynamic>?;
    if (structuredData == null) return [Text('Données structurées invalides.')];
    final itemsData = structuredData['Items Indépendants'];
    if (itemsData == null || !(itemsData is List) || itemsData.isEmpty) {
      return [Text('Aucun item indépendant trouvé.')];
    }
    
    final List<Widget> filteredWidgets = [];
    
    for (var category in itemsData) {
      if (category is! Map<String, dynamic>) continue;
      final categoryName = category['catégorie']?.toString().trim() ?? 'Autres';
      final categoryItems = category['items'];
      if (categoryItems == null || !(categoryItems is List) || categoryItems.isEmpty) continue;
      
      final List<Widget> itemsInCategory = [];
      for (var item in categoryItems) {
        if (item is! Map<String, dynamic>) continue;
        
        // Safely extract nutritional values
        double carbonFootprint = 0.0;
        try {
          carbonFootprint = double.tryParse(item['carbon_footprint']?.toString() ?? '0') ?? 0.0;
        } catch (_) {}
        String nutriScore = item['nutri_score']?.toString() ?? 'N/A';
        double calories = 0.0;
        try {
          var calVal = item['nutrition']?['calories'] ?? item['calories'];
          calories = double.tryParse(calVal?.toString() ?? '0') ?? 0.0;
        } catch (_) {}
        
        // Apply filters
        bool passesCarbon = carbonFootprint <= (_selectedCarbon == "<3kg" ? 3 : 5);
        bool passesNutri = nutriScore.isNotEmpty && nutriScore.compareTo(_selectedNutriScore == "A-B" ? 'C' : 'D') < 0;
        bool passesCalories = calories <= _selectedMaxCalories;
        
        if (passesCarbon && passesNutri && passesCalories) {
          final originalPrice = double.tryParse(item['prix']?.toString() ?? '0') ?? 0;
          final discountedPrice = _hasActivePromotion ? originalPrice * (1 - _promotionDiscount / 100) : null;
          
          itemsInCategory.add(
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              elevation: 1, color: Colors.grey[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(item['nom'] ?? 'Nom non spécifié', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                  if (item['note'] != null) _buildCompactRatingStars(item['note']),
                                ],
                              ),
                              if (item['description'] != null && item['description'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(item['description'], style: TextStyle(fontSize: 14, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                          ),
                        ),
                        if (originalPrice > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_hasActivePromotion && discountedPrice != null)
                                Text('${originalPrice.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                              Text(_hasActivePromotion && discountedPrice != null ? '${discountedPrice.toStringAsFixed(2)} €' : '${originalPrice.toStringAsFixed(2)} €',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _hasActivePromotion ? Colors.red : Colors.black87),
                              ),
                              if (_hasActivePromotion)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                                  child: Text('-${_promotionDiscount.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8), const Divider(height: 1), const SizedBox(height: 8),
                    Row( // Nutritional info
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [const Icon(Icons.eco, size: 16, color: Colors.green), const SizedBox(width: 4), Text('${carbonFootprint.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500))]),
                        Row(children: [const Icon(Icons.health_and_safety, size: 16, color: Colors.blue), const SizedBox(width: 4), Text('Nutri: $nutriScore', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500))]),
                        Row(children: [const Icon(Icons.local_fire_department, size: 16, color: Colors.orange), const SizedBox(width: 4), Text('${calories.toInt()} cal', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500))]),
                      ],
                    ),
                  ],
                ),
              ),
            )
          );
        }
      }
      
      if (itemsInCategory.isNotEmpty) {
        filteredWidgets.add(
          ExpansionTile(
            initiallyExpanded: true,
            title: Row(
              children: [
                Icon(Icons.category_outlined, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text(categoryName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  child: Text('${itemsInCategory.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
              ],
            ),
            children: itemsInCategory,
          )
        );
      }
    }
    
    if (filteredWidgets.isEmpty) {
      return [Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Aucun plat ne correspond aux filtres.')))];
    }
    
    return filteredWidgets;
  }

  // *** ADDED: Helper for Compact Rating Stars (needed by menu/item builders) ***
  Widget _buildCompactRatingStars(dynamic rating) {
    double ratingValue = rating is int ? rating.toDouble() : 
                        rating is double ? rating : 
                        rating is String ? double.tryParse(rating) ?? 0.0 : 0.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < ratingValue.floor() 
              ? Icons.star 
              : index < ratingValue 
                  ? Icons.star_half 
                  : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tableau de Bord',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.orange.shade700,
        elevation: 2,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orangeAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Icônes d'action avec Tooltips et style cohérent
          Tooltip(
            message: 'Créer un post',
            child: IconButton(
              icon: const Icon(Icons.post_add, color: Colors.white),
              onPressed: () {
                // Vérifier l'accès à la fonctionnalité marketing_tools
                if (_premiumFeaturesAccess['marketing_tools'] == true) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePostScreen(producerId: widget.producerId),
                    ),
                  );
                } else {
                  _showUpgradePrompt('marketing_tools');
                }
              },
            ),
          ),
          Tooltip(
            message: 'Gérer le menu',
            child: IconButton(
              icon: const Icon(Icons.restaurant_menu, color: Colors.white),
              onPressed: () {
                // Vérifier l'accès à la fonctionnalité customizable_menu
                if (_premiumFeaturesAccess['customizable_menu'] == true) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuManagementScreen(producerId: widget.producerId),
                    ),
                  );
                } else {
                  _showUpgradePrompt('customizable_menu');
                }
              },
            ),
          ),
          Tooltip(
            message: _hasActivePromotion == true ? 'Gérer la promotion active' : 'Créer une promotion',
            child: IconButton(
              icon: Icon(
                _hasActivePromotion == true ? Icons.campaign : Icons.campaign_outlined, // Use == true for clarity
                color: _hasActivePromotion == true ? Colors.yellowAccent : Colors.white,
              ),
              onPressed: () {
                // Vérifier l'accès à la fonctionnalité marketing_tools pour gérer les promotions
                if (_premiumFeaturesAccess['marketing_tools'] == true) {
                   if (_hasActivePromotion == true) {
                     // Afficher la boîte de dialogue pour désactiver la promotion
                     showDialog(
                       context: context, // Ajout du context
                       builder: (BuildContext dialogContext) {
                         // TODO: Implémenter la logique de désactivation
                         return AlertDialog(
                           title: Text('Désactiver la promotion'),
                           content: Text('Êtes-vous sûr de vouloir désactiver cette promotion ?'),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Annuler')),
                             TextButton(
                               onPressed: () {
                                  // Appel API pour désactiver
                                  _deactivatePromotion();
                                  Navigator.pop(dialogContext);
                               },
                               child: Text('Désactiver')
                             ),
                           ],
                         );
                       }
                     ); 
                   } else {
                     // Afficher la boîte de dialogue pour activer une promotion
                     _showPromotionDialog();
                   }
                } else {
                   _showUpgradePrompt('marketing_tools');
                }
              },
            ),
          ),
          // Menu hamburger
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: (value) {
              // Gestion des actions du menu
              switch (value) {
                case 'saved_posts':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Publications sauvegardées (Bientôt disponible)')),
                  );
                  break;
                case 'theme_mode':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mode Thème (Bientôt disponible)')),
                  );
                  break;
                case 'financial_history':
                   // Vérifier l'accès à advanced_analytics pour l'historique financier
                   if (_premiumFeaturesAccess['advanced_analytics'] == true) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionHistoryScreen(
                            producerId: widget.producerId,
                          ),
                        ),
                      );
                   } else {
                      _showUpgradePrompt('advanced_analytics');
                   }
                  break;
                case 'blocked_accounts':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comptes bloqués (Bientôt disponible)')),
                  );
                  break;
                case 'logout':
                   Future.delayed(Duration.zero, () {
                     final authService = Provider.of<AuthService>(context, listen: false);
                     authService.logout();
                     Navigator.of(context).pushNamedAndRemoveUntil(
                       '/', // Route vers la page de connexion/accueil
                       (route) => false,
                     );
                   });
                  break;
                case 'manage_subscription':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionScreen(
                        producerId: widget.producerId,
                      ),
                    ),
                  ).then((_) {
                      // Recharger les infos après retour de la page d'abonnement
                      _loadSubscriptionInfo();
                      _checkPremiumFeatureAccess();
                  });
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'manage_subscription',
                child: _buildMenuOption(Icons.subscriptions, 'Gérer l\'abonnement (' + (_currentSubscription.isNotEmpty ? _currentSubscription[0].toUpperCase() + _currentSubscription.substring(1) : '') + ')'),
              ),
               const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'saved_posts',
                child: _buildMenuOption(Icons.bookmark_border, 'Publications sauvegardées'),
              ),
              PopupMenuItem<String>(
                value: 'theme_mode',
                child: _buildMenuOption(
                  Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
                  Theme.of(context).brightness == Brightness.dark ? 'Mode Jour' : 'Mode Nuit',
                ),
              ),
              PopupMenuItem<String>(
                value: 'financial_history',
                child: Row(
                  children: [
                    _buildMenuOption(Icons.receipt_long, 'Historique financier'),
                    if (!(_premiumFeaturesAccess['advanced_analytics'] ?? false)) // Indicateur Premium
                       const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.star, color: Colors.amber, size: 16),
                        ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'blocked_accounts',
                child: _buildMenuOption(Icons.block, 'Comptes bloqués'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: _buildMenuOption(Icons.logout, 'Déconnexion'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _checkingPremiumAccess = true;
            _producerFuture = _fetchProducerDetails(widget.producerId);
            _checkPremiumFeatureAccess();
            _checkActivePromotion();
          });
        },
        color: Colors.orangeAccent,
        child: FutureBuilder<Map<String, dynamic>>(
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
                    Text('Erreur : \${snapshot.error}', style: const TextStyle(fontSize: 16)),
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

            // Add check for null data or backend error structure
            final producer = snapshot.data;
            if (producer == null || producer.containsKey('error')) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.orangeAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Impossible de charger les données du profil. Vérifiez votre connexion ou réessayez.\n${producer?['error'] ?? snapshot.error ?? 'Erreur inconnue'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)
                    ),
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
            
            // Existing successful build logic starts here
            // final producer = snapshot.data!; // <-- REMOVE THIS LINE
            
            // --- DEBUG Print statements --- 
            print("--- DEBUG: Inside FutureBuilder ---");
            print("DEBUG: Raw producer data snippet: ${producer.toString().substring(0, producer.toString().length > 300 ? 300 : producer.toString().length)}..."); 
            final rawPromoActive = producer.containsKey('promotion_active') ? producer['promotion_active'] : producer['promotion']?['active'];
            print("DEBUG: Raw promo value (promotion_active or promotion.active): $rawPromoActive (Type: ${rawPromoActive?.runtimeType})");
            final bool promoActiveValue = safeGetBool(producer, 'promotion_active');
            print("DEBUG: Value after safeGetBool('promotion_active'): $promoActiveValue");
            print("-------------------------------------");
            // --- END DEBUG --- 
            
            // --- Type Error Check: Ensure producer data used in bool contexts is valid --- 
            final bool isProducerVerified = safeGetBool(producer, 'verified'); // Example
            final bool isFeatured = safeGetBool(producer, 'featured');
            // Add checks for any other fields from 'producer' map used as booleans

            return DefaultTabController(
              length: 3, // Matches the number of tabs (Menu, Posts, Photos)
              child: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                   // These are the slivers that show up in the "app bar" area.
                   return <Widget>[
                     SliverOverlapAbsorber(
                       handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                       sliver: SliverAppBar(
                         automaticallyImplyLeading: false,
                         pinned: true,
                         floating: false,
                         // --- ADJUSTED: Reduced header height ---
                         // expandedHeight: 0, // Keep as 0 if no expansion needed
                         collapsedHeight: kToolbarHeight + 60, // Reduced from 80 to make header shorter
                         forceElevated: innerBoxIsScrolled,
                         backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                         flexibleSpace: Column(
                           // Ensure children don't cause overflow issues, though ProfileHeader and TabBar are usually fixed height
                           children: [
                              // ProfileHeader(...) - Check inside ProfileHeader for potential issues if needed
                              ProfileHeader(
                                data: {
                                  ...producer,
                                  // Make sure counts are correctly interpreted as numbers
                                  'followersCount': producer['followers']?['count'] ?? 0,
                                  'followingCount': producer['following']?['count'] ?? 0,
                                  'interestedCount': producer['interestedUsers']?['count'] ?? 0,
                                  'choicesCount': producer['choiceUsers']?.length ?? 0,
                                  // Ensure rating is passed correctly if used inside ProfileHeader
                                  'rating': producer['rating'], 
                                  'user_ratings_total': producer['user_ratings_total'],
                                },
                                // Pass boolean flags explicitly checking for null/true
                                hasActivePromotion: promoActiveValue,
                                promotionDiscount: (producer['promotion']?['discountPercentage'] as num?)?.toDouble() ?? 0.0,
                                onEdit: () => _showEditProfileDialog(producer),
                                onPromotion: () {
                                  // Handle promotion tap
                                  // Use _hasActivePromotion state variable which is already managed
                                   if (_premiumFeaturesAccess['marketing_tools'] == true) {
                                      if (_hasActivePromotion == true) {
                                        // Show dialog to deactivate
                                        showDialog(
                                          context: context, // Ajout du context
                                          builder: (BuildContext dialogContext) {
                                            // TODO: Implémenter la logique de désactivation
                                            return AlertDialog(
                                              title: Text('Désactiver la promotion'),
                                              content: Text('Êtes-vous sûr de vouloir désactiver cette promotion ?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Annuler')),
                                                TextButton(
                                                  onPressed: () {
                                                     // Appel API pour désactiver
                                                     _deactivatePromotion();
                                                     Navigator.pop(dialogContext);
                                                  },
                                                  child: Text('Désactiver')
                                                ),
                                              ],
                                            );
                                          }
                                        ); 
                                      } else {
                                         // Show dialog to activate
                                        _showPromotionDialog();
                                      }
                                   } else {
                                     _showUpgradePrompt('marketing_tools');
                                   }
                                },
                              ),
                              // TabBar(...) - Standard widget, less likely to cause type errors itself
                              TabBar(
                                // PAS besoin de controller: ici
                                labelColor: Theme.of(context).colorScheme.primary,
                                unselectedLabelColor: Colors.grey[600],
                                indicator: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                ),
                                indicatorPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                tabs: const [
                                  Tab(
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.restaurant_menu, size: 18), SizedBox(width: 8), Text('Menu')]),
                                  ),
                                  Tab(
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.dynamic_feed, size: 18), SizedBox(width: 8), Text('Posts')]),
                                  ),
                                  Tab(
                                     child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.photo_library, size: 18), SizedBox(width: 8), Text('Photos')]),
                                  ),
                                ],
                              ),
                           ],
                         ),
                       ),
                     ),
                   ];
                },
                body: Builder( // Garder le Builder ici est ok
                   builder: (BuildContext context) {
                     // Pas besoin de spécifier controller ici, TabBarView le trouve
                     // --- REVERTED: Removed Expanded wrapper --- 
                     return TabBarView(
                       children: [
                         // Onglet Menu - Reste identique
                         SafeArea(
                           top: false,
                           bottom: false,
                           child: Builder(
                             builder: (BuildContext context) {
                               return CustomScrollView(
                                 key: const PageStorageKey<String>('menuTab'),
                                 slivers: <Widget>[
                                   SliverOverlapInjector(
                                     handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                                   ),
                                   SliverPadding(
                                     padding: const EdgeInsets.all(16.0),
                                     sliver: SliverList(
                                       delegate: SliverChildListDelegate([
                                         Text("Menu Complet", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                         const SizedBox(height: 8),
                                         // *** MODIFICATION START: Integrate GlobalMenusList content directly ***
                                         // Instead of calling GlobalMenusList(...), we assume it builds
                                         // a list of widgets representing the menus.
                                         // We'll need to replicate or adjust its build logic here if needed.
                                         // For now, let's add a placeholder or assume it returns appropriate widgets.
                                         // TODO: Replace this with the actual widgets built by GlobalMenusList
                                         ..._buildGlobalMenusWidgets(producer), // Use spread operator
                                         // *** MODIFICATION END ***
                                         const SizedBox(height: 24),
                                         Text("Plats Individuels", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                         const SizedBox(height: 8),
                                         // *** MODIFICATION START: Integrate FilteredItemsList content directly ***
                                         // Similar to GlobalMenusList, avoid nesting lists.
                                         // TODO: Replace this with the actual widgets built by FilteredItemsList
                                         ..._buildFilteredItemsWidgets(producer), // Use spread operator
                                         // *** MODIFICATION END ***
                                       ]),
                                     ),
                                   ),
                                 ],
                               );
                             },
                           ),
                         ),
                         // Onglet Posts - Reste identique
                         SafeArea(
                           top: false,
                           bottom: false,
                           child: Builder(
                             builder: (BuildContext context) {
                               return CustomScrollView(
                                 key: const PageStorageKey<String>('postsTab'),
                                 slivers: <Widget>[
                                   SliverOverlapInjector(
                                     handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                                   ),
                                   SliverPadding(
                                       padding: const EdgeInsets.symmetric(vertical: 8.0),
                                       sliver: _buildPostsSliver(),
                                   ),
                                 ],
                               );
                             },
                           ),
                         ),
                         // Onglet Photos - Reste identique
                         SafeArea(
                           top: false,
                           bottom: false,
                           child: Builder(
                             builder: (BuildContext context) {
                               return CustomScrollView(
                                 key: const PageStorageKey<String>('photosTab'),
                                 slivers: <Widget>[
                                   SliverOverlapInjector(
                                     handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                                   ),
                                   SliverPadding(
                                       padding: const EdgeInsets.all(16.0),
                                       sliver: _buildPhotosSliver(producer['photos'] ?? []),
                                   ),
                                 ],
                               );
                             },
                           ),
                         ),
                       ],
                     );
                     // --- END REVERT --- 
                   }
                 ),
              ),
            );
            // --- END WRAP ---
          },
        ),
      ),
    );
  }

  // Widget stylisé pour les actions profil (followers, etc.)
  Widget _buildProfileActionTile(BuildContext context, {required IconData icon, required String label, required int count, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Icon(icon, color: Colors.orangeAccent, size: 28),
          const SizedBox(height: 4),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // Helper pour extraire les IDs utilisateurs
  List<String> _getUserIds(dynamic field) {
    if (field is List) return field.whereType<String>().toList();
    if (field is Map && field['users'] is List) return (field['users'] as List).whereType<String>().toList();
    return [];
  }

  // Navigation vers la liste détaillée des profils
  void _navigateToRelationDetails(String relationType) async {
    // --- CORRECTION: Ne pas valider les profils ici, RelationDetailsScreen les charge ---
    // final ids = getUserIds(data[relationType.toLowerCase()]); // 'data' n'est pas accessible ici
    // if (ids.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Aucun profil à afficher.')),
    //   );
    //   return;
    // }
    // final validProfiles = await _validateProfiles(ids);
    // if (validProfiles.isNotEmpty && mounted) {

    // --- CORRECTION: Passer uniquement producerId et relationType ---
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RelationDetailsScreen(
          producerId: widget.producerId, // Utilise widget.producerId
          relationType: relationType,
          // --- CORRECTION: Supprimer le paramètre 'profiles' ---
          // profiles: validProfiles,
          ),
        ),
      );
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Aucun profil valide trouvé.')),
    //   );
    // }
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
                                image: getImageProvider(selectedImagePath!) ?? const AssetImage('assets/images/default_background.png'),
                                fit: BoxFit.cover,
                              )
                            : DecorationImage(
                                image: getImageProvider(data['photo'] ?? 'https://via.placeholder.com/100') ?? const AssetImage('assets/images/default_avatar.png'),
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
                          if (data['address'] != null && data['address'].toString().isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(data['address'])}');
                                      if (await canLaunchUrl(url)) await launchUrl(url);
                                    },
                                    child: Text(
                                      data['address'],
                                      style: TextStyle(fontSize: 14, color: Colors.blue[700], decoration: TextDecoration.underline),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                  tooltip: 'Copier l\'adresse',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: data['address']));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adresse copiée !')));
                                  },
                                ),
                              ],
                            ),
                            if (data['phone_number'] != null && data['phone_number'].toString().isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      final url = Uri.parse('tel:${data['phone_number']}');
                                      if (await canLaunchUrl(url)) await launchUrl(url);
                                    },
                                    child: Text(
                                      data['phone_number'],
                                      style: TextStyle(fontSize: 14, color: Colors.blue[700], decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ],
                              ),
                            if (data['website'] != null && data['website'].toString().isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.language, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      final url = Uri.parse(data['website']);
                                      if (await canLaunchUrl(url)) await launchUrl(url);
                                    },
                                    child: Text(
                                      data['website'],
                                      style: TextStyle(fontSize: 14, color: Colors.blue[700], decoration: TextDecoration.underline),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
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
    // --- FIX: More robust check for rating type --- 
    if (rating is num) { // Handles both int and double
      ratingValue = rating.toDouble();
    } else if (rating is String) {
      ratingValue = double.tryParse(rating) ?? 0.0;
    } // If rating is null or other type, ratingValue remains 0.0
    
    // Ensure ratingValue is within a sensible range (e.g., 0-5)
    ratingValue = ratingValue.clamp(0.0, 5.0);
    
    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            if (index < ratingValue.floor()) {
              // Étoile pleine
              return const Icon(Icons.star, color: Colors.amber, size: 20);
            } else if (index < ratingValue.ceil() && ratingValue.floor() != ratingValue.ceil()) {
              // Étoile à moitié pleine
              // --- FIX: Explicit check for non-zero rating needed for half star ---
              if (ratingValue > 0) { 
                return const Icon(Icons.star_half, color: Colors.amber, size: 20);
              } else {
                return const Icon(Icons.star_border, color: Colors.amber, size: 20);
              }
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
    // --- FIX: Add explicit check for boolean, although likely redundant now ---
    final bool highlight = isHighlighted == true;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          // Use the checked boolean variable
          color: highlight ? Colors.orangeAccent : Colors.white,
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
              // Use the checked boolean variable
              color: highlight ? Colors.white : Colors.orangeAccent,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                // Use the checked boolean variable
                color: highlight ? Colors.white : Colors.black87,
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
      print("❌ Erreur lors de l'extraction des données de popularité: $e");
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
                // Onglet Menu - Utilise une CustomScrollView et les helpers existants
                SafeArea(
                  top: false,
                  bottom: false,
                  child: Builder(
                    builder: (BuildContext context) {
                      // Le handle est nécessaire si ce TabBarView est dans un NestedScrollView
                      // S'il n'est pas dans un NestedScrollView, vous pouvez potentiellement
                      // simplifier en utilisant juste un ListView.
                      final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
                      return CustomScrollView(
                        key: const PageStorageKey<String>('menuTab'),
                        slivers: <Widget>[
                          SliverOverlapInjector(handle: handle), // Injecte le padding de l'appBar
                          SliverPadding(
                            padding: const EdgeInsets.all(16.0),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // Titre pour Menus Globaux
                                Text(
                                   "Menu Complet", // Ou un autre titre si vous préférez
                                   style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                                 ),
                                const SizedBox(height: 16), // Espace ajouté
                                // Utiliser votre fonction helper existante pour les menus globaux
                                ..._buildGlobalMenusWidgets(producer), // Utilisation de l'opérateur spread '...'

                                const SizedBox(height: 24), // Espace entre les sections

                                // Titre pour Items Indépendants
                                Text(
                                   "Plats Individuels", // Ou un autre titre
                                   style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                                 ),
                                const SizedBox(height: 16), // Espace ajouté
                                // Section pour les filtres (si vous voulez les garder ici)
                                _buildFilterOptions(),
                                const SizedBox(height: 16), // Espace ajouté
                                // Utiliser votre fonction helper existante pour les items filtrés/indépendants
                                ..._buildFilteredItemsWidgets(producer), // Utilisation de l'opérateur spread '...'
                              ]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
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

    return Padding( // Add Padding around the section
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
          const SizedBox(height: 16), // Add space before grid
        
        GridView.builder(
            shrinkWrap: true, // Important for nested scrolling
            physics: const NeverScrollableScrollPhysics(), // Let outer ListView scroll
            padding: EdgeInsets.zero, // Padding handled by parent Column
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
              final photoSource = photos[index] as String?;
              final imageProvider = getImageProvider(photoSource); // Use helper

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
                              child: Image( // Use Image widget with the provider
                                image: imageProvider ?? const AssetImage('assets/images/placeholder_image.png'), // Provide fallback
                              fit: BoxFit.contain,
                                // Add error builder for network/decode issues
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                ),
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
                    // Use imageProvider directly if it's not null
                    image: imageProvider != null
                        ? DecorationImage(
                            image: imageProvider,
                    fit: BoxFit.cover,
                            // Add error handling for DecorationImage too
                            onError: (error, stackTrace) {
                              print("Error loading DecorationImage: $error");
                            },
                          )
                        : null, // Set image to null if provider failed
                    // Add a background color or fallback icon if image is null
                    color: imageProvider == null ? Colors.grey[200] : null,
                  ),
                   // Display fallback icon if image fails to load
                  child: imageProvider == null
                      ? const Center(child: Icon(Icons.image_not_supported, color: Colors.grey))
                      : null,
                ),
                );
              },
            ),
          // ... (add photos button remains the same) ...
      ],
      ),
    );
  }

  Widget _buildPostsSection() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerPosts(widget.producerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32.0), // Add padding for visibility
            child: CircularProgressIndicator(),
          ));
        } else if (snapshot.hasError) {
          print("Error fetching posts: ${snapshot.error}");
          print("Stack trace: ${snapshot.stackTrace}");
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Erreur de chargement des posts: ${snapshot.error}'),
          ));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
             child: Padding(
               padding: EdgeInsets.all(32.0), // Add padding
            child: Text('Aucun post disponible pour ce producteur.'),
             ),
           );
        }

        final postsMaps = snapshot.data!;

        // --- Correct Mapping from Map to Post --- 
        List<Post> posts = [];
        try {
          posts = postsMaps
              .where((map) => map is Map<String, dynamic>) // Ensure it's a map
              .map((map) => Post.fromJson(map as Map<String, dynamic>)) // Perform mapping
              .toList();
        } catch (e, stackTrace) { // Catch potential mapping errors
           print("Error converting Maps to Post objects: $e");
           print("Stack Trace: $stackTrace");
           return SliverFillRemaining(
             // Use double quotes for the string to avoid issues with the apostrophe
             child: Center(child: Text("Erreur interne lors de l'affichage des posts (mapping). $e")),
           );
        }
        // --- End Mapping ---

        // Remove Option B comment block
        // final posts = postsMaps; // Use the maps directly (REMOVED)

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length, // Iterate over the List<Post>
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          itemBuilder: (context, index) {
            // Get the Post object directly from the mapped list
            final currentPost = posts[index]; 

            // Wrap PostCard with appropriate error handling or check data validity
            try {
              // Fetch ApiService here using the builder context
              final apiService = Provider.of<ApiService>(context, listen: false); 
              
              // Pass the Post object
            return PostCard(
                 apiService: apiService, // Pass the fetched ApiService instance
                 post: currentPost, // Pass the Post object
                 onLike: (p) => _handleLike(p), // Callback expects Post
                 // Pass the ID from the Post object in the callback
              onInterested: (p) => _markInterested(p.id),
              onChoice: (p) => _markChoice(p.id),
              onCommentTap: (p) => _openComments(p),
                 // Pass the Post object to navigate
                 onUserTap: () => _navigateToPostDetailFromPostObject(currentPost), 
                 onShare: (p) {},
                 onSave: (p) {},
              );
            } catch (e, stackTrace) {
              print("Error rendering PostCard for post: ${currentPost.id}");
              print("Error: $e");
              print("Stack Trace: $stackTrace");
              // Return a placeholder or error widget for the specific post
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Erreur d'affichage pour ce post: ${currentPost.id}"),
                ),
              );
            }
          },
        );
      },
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
    int getCount(dynamic field) {
      if (field is int) return field;
      if (field is List) return field.length;
      if (field is Map && field['count'] is int) return field['count'];
      if (field is Map && field.isNotEmpty) return field.values.whereType<String>().length;
      return 0;
    }
    List<String> getUserIds(dynamic field) {
      if (field is List) return field.whereType<String>().toList();
      if (field is Map && field['users'] is List) return (field['users'] as List).whereType<String>().toList();
      if (field is Map && field.isNotEmpty) return field.values.whereType<String>().toList();
      return [];
    }
    void _navigateToRelationDetailsWrapper(String title, List<String> ids) async {
      if (ids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun profil à afficher.')),
        );
        return;
      }
      final validProfiles = await _validateProfiles(ids);
      if (validProfiles.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RelationDetailsScreen(
              producerId: widget.producerId, // Pass producerId
              relationType: title, // Pass relationType
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun profil valide trouvé.')),
        );
      }
    }
    final followersCount = getCount(data['followers'] ?? data['abonnés']);
    final followingCount = getCount(data['following']);
    final interestedCount = getCount(data['interestedUsers']);
    final choicesCount = getCount(data['choiceUsers']);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () => _navigateToRelationDetailsWrapper('Followers', getUserIds(data['followers'])),
            child: Column(
              children: [
                Text('$followersCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Followers'),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _navigateToRelationDetailsWrapper('Following', getUserIds(data['following'])),
            child: Column(
              children: [
                Text('$followingCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Following'),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _navigateToRelationDetailsWrapper('Interested', getUserIds(data['interestedUsers'])),
            child: Column(
              children: [
                Text('$interestedCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Interested'),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _navigateToRelationDetailsWrapper('Choices', getUserIds(data['choiceUsers'])),
            child: Column(
              children: [
                Text('$choicesCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Choices'),
              ],
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

  void _handleLike(dynamic post) {
    // Implémenter la logique de like pour les posts producteur
    // Vous pouvez utiliser la même logique que dans feed_screen.dart
    print('Like post: ${post.id}');
  }

  void _openComments(dynamic post) {
    // Implémenter la logique d'ouverture des commentaires
    // Vous pouvez utiliser la même logique que dans feed_screen.dart
    print('Open comments for post: ${post.id}');
  }

  // --- UPDATED: _buildPostsSection to return a Sliver --- 
  Widget _buildPostsSliver() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerPosts(widget.producerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(child: Padding(
              padding: EdgeInsets.all(16.0), 
              child: Text('Erreur chargement posts: ${snapshot.error}')
            )),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucune publication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Les posts et choices partagés apparaîtront ici'),
                ],
              ),
            )
          );
        }

        final posts = snapshot.data!;
        final postWidgets = posts.map<Widget>((postData) {
          if (postData is Map<String, dynamic>) {
            final normalizedData = postData;
            try {
              // Vérification de type pour résoudre l'erreur bool/double
              if (normalizedData.containsKey('isLiked') && normalizedData['isLiked'] is double) {
                normalizedData['isLiked'] = (normalizedData['isLiked'] as double) > 0;
              }
              
              final post = Post.fromJson(normalizedData);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: PostCard(
                  post: post,
                  apiService: ApiService(),
                  onLike: (p) => _handleLike(p),
                  onInterested: (p) => _markInterested(p.id),
                  onChoice: (p) => _markChoice(p.id),
                  onCommentTap: (p) => _openComments(p),
                  onUserTap: () {
                    if (post.authorId != null && post.authorId != widget.producerId) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: post.authorId!)
                      ));
                    }
                  },
                  onShare: (p) { /* TODO */ },
                  onSave: (p) { /* TODO */ },
                ),
              );
            } catch (e) {
              print("❌ Error creating Post object from JSON: $e\nData: $normalizedData");
              return Card(child: ListTile(
                title: Text('Erreur affichage post'), 
                subtitle: Text(e.toString())
              ));
            }
          } else {
            return Card(child: ListTile(title: Text('Donnée post invalide')));
          }
        }).toList();
        
        return SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(postWidgets),
          ),
        );
      },
    );
  }

  // Helper function to safely get boolean values
  bool safeGetBool(Map<String, dynamic> data, String key) {
    if (!data.containsKey(key)) return false;
    var value = data[key];
    if (value is bool) return value;
    if (value is int) return value > 0;
    if (value is double) return value > 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  // --- UPDATED: _buildPhotosSection to return a Sliver --- 
  Widget _buildPhotosSliver(List<dynamic> photos) {
    if (photos.isEmpty) {
      return SliverFillRemaining( // Use SliverFillRemaining for empty state
        child: Center(
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fonctionnalité en développement')),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Use SliverGrid for the photos
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final photoSource = photos[index] as String?;
          final imageProvider = getImageProvider(photoSource); 

          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: EdgeInsets.zero,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withOpacity(0.7),
                        child: InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4,
                          child: Center(
                            child: Image(
                              image: imageProvider ?? AssetImage('assets/images/placeholder.png'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
                // ... (Container decoration remains the same)
              ),
          );
        },
        childCount: photos.length,
      ),
    );
  }

  void _navigateToPostDetailFromPostObject(Post post) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          postId: post.id,
          userId: widget.producerId,
          // Optionnel si nécessaire
          referringScreen: 'MyProducerProfileScreen',
        ),
      ),
    );
  }
}




