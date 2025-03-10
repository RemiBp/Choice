import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // Pour les graphiques
import '../services/api_service.dart';
import 'post_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
import 'producerLeisure_screen.dart';
import 'producer_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ⚠️ Pour détecter le Web
import '../services/payment_service.dart';
import 'utils.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class MyProducerProfileScreen extends StatefulWidget {
  final String producerId;

  const MyProducerProfileScreen({Key? key, required String userId})
      : producerId = userId, // Mapper userId en producerId
        super(key: key);


  @override
  State<MyProducerProfileScreen> createState() => _MyProducerProfileScreenState();
}

class _MyProducerProfileScreenState extends State<MyProducerProfileScreen> {
  late Future<Map<String, dynamic>> _producerFuture;
  int _selectedDay = 0; // Pour les horaires populaires
  String _selectedCarbon = "<3kg";
  String _selectedNutriScore = "A-C";
  double _selectedMaxCalories = 500;
  
  // Variables pour la promotion
  bool _hasActivePromotion = false;
  DateTime? _promotionEndDate;
  double _promotionDiscount = 10.0; // Pourcentage de réduction (10% par défaut)

  @override
  void initState() {
    super.initState();
    print('🔍 Initialisation du test des API');
    _testApi(); // Appel à la méthode de test
    _producerFuture = _fetchProducerDetails(widget.producerId);
    _checkActivePromotion();
  }
  
  // Vérifier si une promotion est active
  Future<void> _checkActivePromotion() async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/promotion');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
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
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/promotion');
      
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
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/promotion');
      
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
      final producerUrl = Uri.parse('${getBaseUrl()}/api/producers/$producerId');
      final producerResponse = await http.get(producerUrl);
      print('Réponse pour /producers : ${producerResponse.statusCode}');
      print('Body : ${producerResponse.body}');

      print('🔍 Test : appel à /producers/$producerId/relations');
      final relationsUrl = Uri.parse('${getBaseUrl()}/api/producers/$producerId/relations');
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
    final producerUrl = Uri.parse('${getBaseUrl()}/api/producers/$producerId');
    final relationsUrl = Uri.parse('${getBaseUrl()}/api/producers/$producerId/relations');

    try {
      final responses = await Future.wait([
        http.get(producerUrl),
        http.get(relationsUrl),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final producerData = json.decode(responses[0].body);
        final relationsData = json.decode(responses[1].body);

        // Combiner les données des deux requêtes
        return {
          ...producerData,
          ...relationsData,
        };
      } else {
        throw Exception('Erreur lors de la récupération des données.');
      }
    } catch (e) {
      print('Erreur réseau : $e');
      throw Exception('Impossible de charger les données du producteur.');
    }
  }

  /// Fonction pour récupérer les posts d'un producteur
  Future<List<dynamic>> _fetchProducerPosts(String producerId) async {
    final url = Uri.parse('${getBaseUrl()}/api/producers/$producerId');
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
          final postUrl = Uri.parse('${getBaseUrl()}/api/posts/$postId');
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

  Future<void> _markInterested(String targetId, Map<String, dynamic> post) async {
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/interested');
    final body = {'userId': widget.producerId, 'targetId': targetId};

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
  }

  Future<void> _markChoice(String targetId, Map<String, dynamic> post) async {
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/choice');
    final body = {'userId': widget.producerId, 'targetId': targetId};

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
  }

  Future<Map<String, dynamic>?> _fetchProfileById(String id) async {
    final userUrl = Uri.parse('${getBaseUrl()}/api/users/$id');
    final unifiedUrl = Uri.parse('${getBaseUrl()}/api/unified/$id');

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

  Widget _buildHeader(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.orange.shade50],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo de profil améliorée
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(
                    data['photo'] ?? 'https://via.placeholder.com/100',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Informations principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Nom non spécifié',
                      style: const TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Note avec étoiles
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${data['rating'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${data['reviews_count'] ?? 0} avis)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Boutons d'action améliorés
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.edit,
                label: 'Éditer',
                onTap: () {
                  // Navigation vers l'écran d'édition du profil
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fonctionnalité d\'édition en développement')),
                  );
                },
              ),
              
              _buildActionButton(
                icon: Icons.monetization_on_outlined,
                label: 'Premium',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionScreen(producerId: widget.producerId),
                    ),
                  );
                },
                isHighlighted: true,
              ),
              
              _buildActionButton(
                icon: Icons.analytics_outlined,
                label: 'Statistiques',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fonctionnalité de statistiques en développement')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
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

    final filteredTimes = popularTimes[_selectedDay]['data']?.cast<int>().sublist(8, 24) ?? [];

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
          const SizedBox(height: 16),
          
          // Filtre Bilan Carbone
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButton<String>(
              value: _selectedCarbon,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
              items: const [
                DropdownMenuItem(
                  value: "<3kg", 
                  child: Row(
                    children: [
                      Icon(Icons.eco, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text("Bilan Carbone : <3kg"),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: "<5kg", 
                  child: Row(
                    children: [
                      Icon(Icons.eco, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Text("Bilan Carbone : <5kg"),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCarbon = value!;
                });
              },
            ),
          ),
          
          // Filtre NutriScore
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButton<String>(
              value: _selectedNutriScore,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
              items: const [
                DropdownMenuItem(
                  value: "A-C", 
                  child: Row(
                    children: [
                      Icon(Icons.health_and_safety, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text("NutriScore : A-C"),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: "A-B", 
                  child: Row(
                    children: [
                      Icon(Icons.health_and_safety, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text("NutriScore : A-B"),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedNutriScore = value!;
                });
              },
            ),
          ),
          
          // Slider de calories
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Calories maximales: ${_selectedMaxCalories.toInt()} cal",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.red,
                  inactiveTrackColor: Colors.red.withOpacity(0.2),
                  thumbColor: Colors.red,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredItems(Map<String, dynamic> producer) {
    final items = producer['structured_data']['Items Indépendants'] ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('Aucun item disponible.'));
    }

    final filteredItems = <String, List<dynamic>>{};
    for (var category in items) {
      final categoryName = category['catégorie'] ?? 'Autres';
      for (var item in category['items'] ?? []) {
        final carbonFootprint = double.tryParse(item['carbon_footprint']?.toString() ?? '0') ?? 0;
        final nutriScore = item['nutri_score']?.toString() ?? 'N/A';
        final calories = double.tryParse(item['nutrition']?['calories']?.toString() ?? '0') ?? 0;

        if (carbonFootprint <= 3 && nutriScore.compareTo('C') <= 0 && calories <= _selectedMaxCalories) {
          if (!filteredItems.containsKey(categoryName)) {
            filteredItems[categoryName] = [];
          }
          filteredItems[categoryName]!.add(item);
        }
      }
    }

    if (filteredItems.isEmpty) {
      return const Center(child: Text('Aucun item ne correspond aux critères.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items Filtrés',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...filteredItems.entries.map((entry) {
            final categoryName = entry.key;
            final categoryItems = entry.value;
            return ExpansionTile(
              title: Text(
                categoryName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              children: categoryItems.map<Widget>((item) {
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      item['nom'] ?? 'Nom non spécifié',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${item['description'] ?? 'Description non spécifiée'}\nBilan Carbone : ${item['carbon_footprint']}kg\nNutriScore : ${item['nutri_score']}\nCalories : ${item['nutrition']?['calories']} cal',
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
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Carte du Menu'),
              Tab(text: 'Photos'),
              Tab(text: 'Posts'),
            ],
            labelColor: Colors.orangeAccent,
            indicatorColor: Colors.orangeAccent,
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                _buildMenuDetails(producer),
                _buildPhotosSection(producer['photos'] ?? []),
                _buildPostsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuDetails(Map<String, dynamic> producer) {
    final menus = producer['structured_data']['Menus Globaux'] ?? [];
    if (menus.isEmpty) {
      return const Center(child: Text('Aucun menu disponible.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menus Disponibles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...menus.map<Widget>((menu) {
            final inclus = menu['inclus'] ?? [];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ExpansionTile(
                title: Text(
                  '${menu['nom']} - ${menu['prix']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                children: inclus.map<Widget>((inclusItem) {
                  final items = inclusItem['items'] ?? [];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inclusItem['catégorie'] ?? 'Non spécifié',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        ...items.map<Widget>((item) {
                          return ListTile(
                            title: Text(item['nom'] ?? 'Nom non spécifié'),
                            subtitle: Text('${item['description'] ?? ''} - Note: ${item['note'] ?? 'N/A'}'),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(List<dynamic> photos) {
    if (photos.isEmpty) {
      return const Center(child: Text('Aucune photo disponible.'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return Image.network(photos[index], fit: BoxFit.cover);
      },
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
                        IconButton(
                          icon: Icon(
                            post['interested']?.contains(widget.producerId) ?? false
                                ? Icons.emoji_objects
                                : Icons.emoji_objects_outlined,
                            color: post['interested']?.contains(widget.producerId) ?? false
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          onPressed: () => _markInterested(producerId!, post), // Passez `post`
                        ),
                        Text('$interestedCount Interested'),
                      ],
                    ),

                  // Choice Button (✅)
                  if (isProducerPost)
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            post['choices']?.contains(widget.producerId) ?? false
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: post['choices']?.contains(widget.producerId) ?? false
                                ? Colors.green
                                : Colors.grey,
                          ),
                          onPressed: () => _markChoice(producerId!, post), // Passez `post` en second argument
                        ),
                        Text('$choicesCount Choices'),
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
      if (ids is! List) {
        print('❌ Les IDs ne sont pas une liste valide.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : Les IDs ne sont pas valides.')),
        );
        return;
      }

      final validIds = ids.cast<String>(); // Essaie de convertir en List<String>
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

  @override
  void initState() {
    super.initState();
    post = widget.post;
    interestedCount = post['interested']?.length ?? 0;
    choicesCount = post['choices']?.length ?? 0;
  }

  Future<void> _markInterested(String targetId) async {
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/interested');
    final body = {'userId': widget.producerId, 'targetId': targetId};

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
  }

  Future<void> _markChoice(String targetId) async {
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/choice');
    final body = {'producerId': widget.producerId, 'targetId': targetId};

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
                      IconButton(
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
                      Text('$interestedCount Interested'),
                    ],
                  ),

                  // Choice Button
                  Column(
                    children: [
                      IconButton(
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
                      Text('$choicesCount Choices'),
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
                final profile = profiles[index];

                // Récupération des données nécessaires
                final userId = profile['_id']; // ID utilisateur classique
                final producerId = profile['producerId']; // ID producer
                final producerData = profile['producerData']; // Data leisure producer
                final photoUrl = profile['photo'] ??
                    profile['photo_url'] ??
                    'https://via.placeholder.com/150'; // Fallback pour les photos
                final name = profile['name'] ?? 'Nom inconnu';
                final description = profile['description'] ?? 'Pas de description';

                // Détection du type de profil
                final isUser = userId != null && producerId == null && producerData == null;
                final isProducer = producerId != null;
                final isLeisureProducer = producerData != null;

                // Vérification des profils non valides
                if (!isUser && !isProducer && !isLeisureProducer) {
                  print('❌ Profil non valide à l\'index $index');
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
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      description,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () async {
                      // Logique pour tenter successivement chaque navigation
                      bool navigationSuccessful = false;

                      try {
                        if (isUser) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userId: userId),
                            ),
                          );
                          navigationSuccessful = true;
                          return; // Arrête ici si la navigation réussit
                        }
                      } catch (e) {
                        print('⚠️ Échec pour ProfileScreen : $e');
                      }

                      try {
                        if (isProducer && !navigationSuccessful) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProducerScreen(producerId: producerId!),
                            ),
                          );
                          navigationSuccessful = true;
                          return; // Arrête ici si la navigation réussit
                        }
                      } catch (e) {
                        print('⚠️ Échec pour ProducerScreen : $e');
                      }

                      try {
                        if (isLeisureProducer && !navigationSuccessful) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProducerLeisureScreen(producerData: producerData!),
                            ),
                          );
                          navigationSuccessful = true;
                          return; // Arrête ici si la navigation réussit
                        }
                      } catch (e) {
                        print('⚠️ Échec pour ProducerLeisureScreen : $e');
                      }

                      // Si aucune navigation ne réussit
                      if (!navigationSuccessful) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Impossible de naviguer vers un écran approprié.')),
                        );
                      }
                    },
                  ),
                );
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
      final url = Uri.parse('${getBaseUrl()}/api/posts');
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
      final url = Uri.parse('${getBaseUrl()}/api/unified/search?query=$query');
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
    final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}');
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
    final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/update-items');

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
    final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/items/${widget.item['_id']}');


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
        Navigator.pop(context); // Fermer l’écran après mise à jour
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

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isProcessing = false; // Pour afficher un loading

  @override
  void initState() {
    super.initState();
    print("📢 SubscriptionScreen chargé avec producerId: ${widget.producerId}");
  }


  void _subscribe(BuildContext context, String plan, int price) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      bool success = await PaymentService.processPayment(context, plan, widget.producerId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Abonnement réussi ! 🎉")),
        );
        Navigator.pop(context); // Retour au profil
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Erreur lors du paiement. Réessayez.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Erreur : $e")),
      );
    }

    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choisir un abonnement Premium")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator()) // Affiche un loader pendant le paiement
            : Column(
                children: [
                  _buildPlanCard("Bronze", 5, "Boost de visibilité", context),
                  _buildPlanCard("Silver", 10, "Boost + Accès complet", context),
                  _buildPlanCard("Gold", 15, "Boost + IA Analytics", context),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annuler"),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPlanCard(String title, int price, String benefits, BuildContext context) {
    return Card(
      child: ListTile(
        title: Text("$title - $price€/mois", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(benefits),
        trailing: ElevatedButton(
          onPressed: () => _subscribe(context, title.toLowerCase(), price), // bronze, silver, gold
          child: const Text("S'abonner"),
        ),
      ),
    );
  }
}