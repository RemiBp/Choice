import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
import 'producerLeisure_screen.dart';
import '../utils.dart';
import 'map_screen.dart';

class ProducerScreen extends StatefulWidget {
  final String producerId;
  final String? userId;

  const ProducerScreen({Key? key, required this.producerId, this.userId}) : super(key: key);

  @override
  State<ProducerScreen> createState() => _ProducerScreenState();
}

class _ProducerScreenState extends State<ProducerScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _producerFuture;
  int _selectedDay = 0;
  
  // Improved filtering options
  RangeValues _ratingRange = const RangeValues(3.0, 5.0);
  double _selectedMaxCalories = 500;
  bool _showLocalProducts = true;
  bool _showOrganicOnly = false;
  bool _showVegetarianOptions = false;
  
  // Values for carbon footprint filter
  String _selectedCarbon = "<3kg";
  String _selectedNutriScore = "A-C";
  
  // Animation controller for UI elements
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    print('🔍 Initialisation du test des API');
    _testApi();
    _producerFuture = _fetchProducerDetails(widget.producerId);
    
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
    _animationController.dispose();
    super.dispose();
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
    
    final baseUrl = getBaseUrl();
    
    for (String endpoint in endpointsToTest) {
      try {
        print('🔍 Test : appel à $endpoint');
        Uri url;
        
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          url = Uri.http(domain, endpoint);
        } else if (baseUrl.startsWith('https://')) {
          final domain = baseUrl.replaceFirst('https://', '');
          url = Uri.https(domain, endpoint);
        } else {
          url = Uri.parse('$baseUrl$endpoint');
        }
        
        final response = await http.get(url).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception("Délai d'attente dépassé"),
        );
        
        print('Réponse pour $endpoint : ${response.statusCode}');
        print('Body : ${response.body}');
        
        if (response.statusCode == 200) {
          print('✅ Requête $endpoint réussie');
        } else {
          print('❌ Échec de la requête $endpoint: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Erreur réseau pour $endpoint : $e');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchProducerDetails(String producerId) async {
    // Validation MongoDB ObjectID - plus robuste avec message d'erreur détaillé
    final bool isValidObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(producerId);
    if (!isValidObjectId) {
      print('⚠️ Warning: ID potentiellement invalide: $producerId');
      print('⚠️ Un ID MongoDB valide doit être une chaîne hexadécimale de 24 caractères');
      
      // Analyse supplémentaire pour un message d'erreur plus précis
      if (producerId.isEmpty) {
        print('❌ Erreur: ID vide');
      } else if (producerId.length != 24) {
        print('❌ Erreur: Longueur incorrecte (${producerId.length} caractères au lieu de 24)');
      } else if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(producerId)) {
        print('❌ Erreur: Contient des caractères non hexadécimaux');
      }
    }
    
    final baseUrl = getBaseUrl();
    
    // Liste améliorée d'endpoints à essayer
    final List<Map<String, String>> endpointsToTry = [
      {'type': 'producer', 'main': '/api/producers/$producerId', 'relations': '/api/producers/$producerId/relations'},
      {'type': 'unified', 'main': '/api/unified/$producerId', 'relations': '/api/unified/$producerId/relations'},
      {'type': 'leisure', 'main': '/api/leisureProducers/$producerId', 'relations': '/api/leisureProducers/$producerId/relations'},
      // Fallback supplémentaire pour plus de robustesse
      {'type': 'events', 'main': '/api/events/$producerId', 'relations': '/api/events/$producerId/relations'},
    ];
    
    List<String> failedEndpoints = [];
    List<String> errorMessages = [];
    
    // Essayer chaque combinaison d'endpoints jusqu'à ce qu'une fonctionne
    for (final endpointSet in endpointsToTry) {
      try {
        print('🔍 Tentative avec ${endpointSet['type']} endpoints');
        
        Uri mainUrl;
        Uri relationsUrl;
        
        if (baseUrl.startsWith('http://')) {
          final domain = baseUrl.replaceFirst('http://', '');
          mainUrl = Uri.http(domain, endpointSet['main']!);
          relationsUrl = Uri.http(domain, endpointSet['relations']!);
        } else if (baseUrl.startsWith('https://')) {
          final domain = baseUrl.replaceFirst('https://', '');
          mainUrl = Uri.https(domain, endpointSet['main']!);
          relationsUrl = Uri.https(domain, endpointSet['relations']!);
        } else {
          mainUrl = Uri.parse('$baseUrl${endpointSet['main']}');
          relationsUrl = Uri.parse('$baseUrl${endpointSet['relations']}');
        }

        print('🌐 URL: $mainUrl');
        
        final responses = await Future.wait([
          http.get(mainUrl).timeout(const Duration(seconds: 10)),
          http.get(relationsUrl).timeout(const Duration(seconds: 8)),
        ]);

        if (responses[0].statusCode == 200) {
          final producerData = json.decode(responses[0].body);
          
          // Vérifier si les données récupérées contiennent un champ d'ID
          if (producerData['_id'] == null && producerData['id'] == null) {
            print('⚠️ Avertissement: Les données récupérées ne contiennent pas d\'ID');
          }
          
          // Même si les relations échouent, nous pouvons renvoyer les données du producteur
          if (responses[1].statusCode == 200) {
            final relationsData = json.decode(responses[1].body);
            print('✅ Données récupérées avec succès via ${endpointSet['type']} endpoint');
            return {
              ...producerData,
              ...relationsData,
              '_dataSource': endpointSet['type'],
              '_requestSuccessful': true,
            };
          } else {
            print('⚠️ Données principales récupérées, mais relations échouées (${responses[1].statusCode})');
            return {
              ...producerData,
              '_dataSource': '${endpointSet['type']} (sans relations)',
              '_requestSuccessful': true,
              '_relationsError': 'Statut ${responses[1].statusCode}',
            };
          }
        } else {
          final statusCode = responses[0].statusCode;
          final errorMsg = '❌ Échec avec ${endpointSet['type']} endpoint: $statusCode';
          print(errorMsg);
          failedEndpoints.add(endpointSet['type']!);
          errorMessages.add('$statusCode pour ${endpointSet['type']}');
        }
      } catch (e) {
        final errorMsg = '❌ Erreur réseau pour ${endpointSet['type']} endpoint: $e';
        print(errorMsg);
        failedEndpoints.add(endpointSet['type']!);
        String errorType = 'timeout';
        if (e.toString().contains('timeout')) {
          errorType = 'timeout';
        } else if (e.toString().contains('network')) {
          errorType = 'réseau';
        }
        errorMessages.add('Erreur $errorType pour ${endpointSet['type']}');
      }
    }
    
    // Si tous les endpoints ont échoué, lancer une exception avec un message d'aide
    final String allEndpointsMsg = failedEndpoints.join(', ');
    final String errorDetailsMsg = errorMessages.join('; ');
    
    throw Exception(
      'Impossible de charger les données du producteur. ' +
      (isValidObjectId 
        ? 'Tous les endpoints ont échoué ($allEndpointsMsg). Détails: $errorDetailsMsg. Veuillez vérifier votre connexion ou réessayer plus tard.' 
        : 'L\'identifiant "$producerId" semble être invalide. Un ID MongoDB valide doit être une chaîne hexadécimale de 24 caractères.'
      )
    );
  }

  Future<List<dynamic>> _fetchProducerPosts(String producerId) async {
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/producers/$producerId');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/producers/$producerId');
    } else {
      url = Uri.parse('$baseUrl/api/producers/$producerId');
    }
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final producerData = json.decode(response.body);
        final postIds = producerData['posts'] as List<dynamic>? ?? [];

        if (postIds.isEmpty) {
          return [];
        }

        final List<dynamic> posts = [];
        for (final postId in postIds) {
          Uri postUrl;
          
          if (baseUrl.startsWith('http://')) {
            final domain = baseUrl.replaceFirst('http://', '');
            postUrl = Uri.http(domain, '/api/posts/$postId');
          } else if (baseUrl.startsWith('https://')) {
            final domain = baseUrl.replaceFirst('https://', '');
            postUrl = Uri.https(domain, '/api/posts/$postId');
          } else {
            postUrl = Uri.parse('$baseUrl/api/posts/$postId');
          }
          
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
    setState(() {
      post['isLoading'] = true;
    });

    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/choicexinterest/interested');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/choicexinterest/interested');
    } else {
      url = Uri.parse('$baseUrl/api/choicexinterest/interested');
    }
    
    final body = {
      'userId': widget.userId,
      'targetId': targetId,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final updatedInterested = responseData['interested'];
        setState(() {
          post['interested'] = updatedInterested;
          post['isLoading'] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedInterested ? 'Ajouté à vos intérêts' : 'Retiré de vos intérêts'),
            backgroundColor: updatedInterested ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        _updateUserProfile();
        
        print('✅ Interested mis à jour avec succès');
      } else {
        setState(() {
          post['isLoading'] = false;
        });
        print('❌ Erreur lors de la mise à jour d\'Interested : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        post['isLoading'] = false;
      });
      print('❌ Erreur réseau lors de la mise à jour d\'Interested : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markChoice(String targetId, Map<String, dynamic> post) async {
    setState(() {
      post['isLoading'] = true;
    });
    
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/choicexinterest/choice');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/choicexinterest/choice');
    } else {
      url = Uri.parse('$baseUrl/api/choicexinterest/choice');
    }
    
    final body = {
      'userId': widget.userId,
      'targetId': targetId,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final updatedChoice = responseData['choice'];
        setState(() {
          post['choices'] = updatedChoice;
          post['isLoading'] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedChoice ? 'Ajouté à vos choix' : 'Retiré de vos choix'),
            backgroundColor: updatedChoice ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        _updateUserProfile();
        
        print('✅ Choice mis à jour avec succès');
      } else {
        setState(() {
          post['isLoading'] = false;
        });
        print('❌ Erreur lors de la mise à jour de Choice : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        post['isLoading'] = false;
      });
      print('❌ Erreur réseau lors de la mise à jour de Choice : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateUserProfile() async {
    if (widget.userId == null) {
      print('⚠️ Impossible de mettre à jour le profil : userId est null');
      return;
    }
    
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/users/${widget.userId}');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/users/${widget.userId}');
    } else {
      url = Uri.parse('$baseUrl/api/users/${widget.userId}');
    }
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        print('✅ Profil utilisateur mis à jour avec succès');
        print('📋 Intérêts: ${userData['interests']?.length ?? 0}');
        print('📋 Choices: ${userData['choices']?.length ?? 0}');
      } else {
        print('❌ Erreur lors de la mise à jour du profil : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de la mise à jour du profil : $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchProfileById(String id) async {
    final baseUrl = getBaseUrl();
    Uri userUrl;
    Uri unifiedUrl;
    Uri producerUrl;
    Uri leisureProducerUrl;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      userUrl = Uri.http(domain, '/api/users/$id');
      unifiedUrl = Uri.http(domain, '/api/unified/$id');
      producerUrl = Uri.http(domain, '/api/producers/$id');
      leisureProducerUrl = Uri.http(domain, '/api/leisureProducers/$id');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      userUrl = Uri.https(domain, '/api/users/$id');
      unifiedUrl = Uri.https(domain, '/api/unified/$id');
      producerUrl = Uri.https(domain, '/api/producers/$id');
      leisureProducerUrl = Uri.https(domain, '/api/leisureProducers/$id');
    } else {
      userUrl = Uri.parse('$baseUrl/api/users/$id');
      unifiedUrl = Uri.parse('$baseUrl/api/unified/$id');
      producerUrl = Uri.parse('$baseUrl/api/producers/$id');
      leisureProducerUrl = Uri.parse('$baseUrl/api/leisureProducers/$id');
    }
    
    // Try multiple endpoints to find a valid profile
    List<Map<String, dynamic>> endpointsToTry = [
      {'name': '/api/users/', 'url': userUrl},
      {'name': '/api/unified/', 'url': unifiedUrl},
      {'name': '/api/producers/', 'url': producerUrl},
      {'name': '/api/leisureProducers/', 'url': leisureProducerUrl},
    ];
    
    for (final endpoint in endpointsToTry) {
      try {
        print('🔍 Tentative avec ${endpoint['name']}:id pour l\'ID : $id');
        final Uri url = endpoint['url'] as Uri;
        final response = await http.get(url);

        if (response.statusCode == 200) {
          print('✅ Profil trouvé via ${endpoint['name']}:id');
          try {
            final decodedData = json.decode(response.body);
            
            // Ensure we're working with a Map and not a List
            if (decodedData is Map<String, dynamic>) {
              return decodedData;
            } else if (decodedData is List) {
              // If it's a list, try to find the first item that matches the ID
              for (var item in decodedData) {
                if (item is Map<String, dynamic> && 
                    (item['_id'] == id || item['id'] == id)) {
                  return item;
                }
              }
              // If no matching item is found, create a wrapper map
              print('⚠️ La réponse est une liste sans correspondance. Création d\'un wrapper.');
              return {'data': decodedData, '_id': id, 'isList': true};
            } else {
              print('⚠️ Format de réponse inattendu: ${decodedData.runtimeType}');
              return {'data': decodedData.toString(), '_id': id, 'isUnexpectedType': true};
            }
          } catch (e) {
            print('❌ Erreur lors du décodage JSON: $e');
          }
        } else {
          print('❌ Échec avec ${endpoint['name']}:id : ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Erreur réseau pour ${endpoint['name']}:id : $e');
      }
    }

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

  void _navigateToPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProducerPostDetailScreen(
          post: post,
          userId: widget.userId,
        ),
      ),
    );
  }

  Widget _buildProfileActions(Map<String, dynamic> data) {
    // Safely handle followers data which could be a Map or a List
    int followersCount = 0;
    List<dynamic> followersList = [];
    if (data['followers'] is Map) {
      followersCount = int.tryParse(data['followers']?['count']?.toString() ?? '0') ?? 0;
      followersList = data['followers']?['users'] as List<dynamic>? ?? [];
    } else if (data['followers'] is List) {
      followersList = data['followers'] as List<dynamic>;
      followersCount = followersList.length;
    }
    
    // Safely handle following data which could be a Map or a List
    int followingCount = 0;
    List<dynamic> followingList = [];
    if (data['following'] is Map) {
      followingCount = int.tryParse(data['following']?['count']?.toString() ?? '0') ?? 0;
      followingList = data['following']?['users'] as List<dynamic>? ?? [];
    } else if (data['following'] is List) {
      followingList = data['following'] as List<dynamic>;
      followingCount = followingList.length;
    }
    
    // Safely handle interestedUsers data which could be a Map or a List
    int interestedCount = 0;
    List<dynamic> interestedList = [];
    if (data['interestedUsers'] is Map) {
      interestedCount = int.tryParse(data['interestedUsers']?['count']?.toString() ?? '0') ?? 0;
      interestedList = data['interestedUsers']?['users'] as List<dynamic>? ?? [];
    } else if (data['interestedUsers'] is List) {
      interestedList = data['interestedUsers'] as List<dynamic>;
      interestedCount = interestedList.length;
    }
    
    // Safely handle choiceUsers data which could be a Map or a List
    int choicesCount = 0;
    List<dynamic> choicesList = [];
    if (data['choiceUsers'] is Map) {
      choicesCount = int.tryParse(data['choiceUsers']?['count']?.toString() ?? '0') ?? 0;
      choicesList = data['choiceUsers']?['users'] as List<dynamic>? ?? [];
    } else if (data['choiceUsers'] is List) {
      choicesList = data['choiceUsers'] as List<dynamic>;
      choicesCount = choicesList.length;
    }
    
    return Material(
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatisticItem(
                title: 'Followers',
                count: followersCount,
                icon: Icons.people,
                color: Colors.blue,
                onTap: () {
                  try {
                    _navigateToRelationDetails('Followers', followersList);
                  } catch (e) {
                    print('❌ Erreur lors de la navigation vers Followers: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de l\'accès aux followers')),
                    );
                  }
                },
              ),
              _buildVerticalDivider(),
              _buildStatisticItem(
                title: 'Following',
                count: followingCount,
                icon: Icons.person_add,
                color: Colors.purple,
                onTap: () {
                  try {
                    _navigateToRelationDetails('Following', followingList);
                  } catch (e) {
                    print('❌ Erreur lors de la navigation vers Following: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de l\'accès aux following')),
                    );
                  }
                },
              ),
              _buildVerticalDivider(),
              _buildStatisticItem(
                title: 'Interested',
                count: interestedCount,
                icon: Icons.emoji_objects,
                color: Colors.orange,
                onTap: () {
                  try {
                    _navigateToRelationDetails('Interested', interestedList);
                  } catch (e) {
                    print('❌ Erreur lors de la navigation vers Interested: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de l\'accès aux intéressés')),
                    );
                  }
                },
              ),
              _buildVerticalDivider(),
              _buildStatisticItem(
                title: 'Choices',
                count: choicesCount,
                icon: Icons.check_circle,
                color: Colors.green,
                onTap: () {
                  try {
                    _navigateToRelationDetails('Choices', choicesList);
                  } catch (e) {
                    print('❌ Erreur lors de la navigation vers Choices: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de l\'accès aux choix')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticItem({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
    );
  }

  void _navigateToRelationDetails(String title, dynamic data) async {
    print('🔍 _navigateToRelationDetails appelé avec titre: $title et data de type: ${data.runtimeType}');
    
    // Detailed diagnostic of the data structure
    if (data is List) {
      print('📊 La donnée est une liste de longueur: ${data.length}');
      if (data.isNotEmpty) {
        print('📊 Premier élément est de type: ${data.first.runtimeType}');
        // If it's a list of maps, examine the first element's structure
        if (data.first is Map) {
          print('📊 Contenu du premier élément: ${data.first}');
        }
      }
    } else if (data is Map) {
      print('📊 La donnée est une Map avec clés: ${data.keys.toList()}');
      for (var key in data.keys) {
        var value = data[key];
        print('📊 Clé: $key, Type de valeur: ${value.runtimeType}');
        if (value is List) {
          print('📊   ↳ Liste de longueur: ${value.length}');
          if (value.isNotEmpty) {
            print('📊   ↳ Premier élément est de type: ${value.first.runtimeType}');
            if (value.first is Map) {
              print('📊   ↳ Contenu du premier élément: ${value.first}');
            }
          }
        } else if (value is Map) {
          print('📊   ↳ Map avec clés: ${value.keys.toList()}');
        }
      }
    } else {
      print('⚠️ Type de données inconnu: ${data.runtimeType}');
    }

    // Initialize an empty list for IDs
    List<String> validIds = [];
    
    try {
      // Enhanced type handling with stronger defensive programming
      if (data == null) {
        print('❌ Les données sont null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur : Aucune donnée disponible')),
        );
        return;
      }
      
      // Handle all possible data formats to extract user IDs
      if (data is List) {
        // Case 1: Direct list of user IDs
        if (data.isEmpty) {
          print('⚠️ Liste vide, aucun ID à extraire');
        } else if (data.first is String || data.first is int) {
          print('✅ Extraction depuis une liste d\'IDs directe');
          for (var item in data) {
            if (item != null) {
              validIds.add(item.toString());
            }
          }
        } 
        // Case 2: List of maps with userId field (format used by choiceUsers)
        else if (data.first is Map) {
          print('✅ Extraction depuis une liste de maps');
          for (var item in data) {
            if (item is Map) {
              // Try to find userId field in map
              if (item.containsKey('userId')) {
                var userId = item['userId'];
                if (userId != null) {
                  print('✅ UserId trouvé dans un objet: $userId');
                  validIds.add(userId.toString());
                }
              } else {
                // If no userId field, try to use any string/id-like values
                item.forEach((key, value) {
                  if ((value is String || value is int) && 
                      (key == 'id' || key == '_id' || key == 'userId' || key == 'user_id')) {
                    validIds.add(value.toString());
                  }
                });
              }
            } else if (item != null) {
              validIds.add(item.toString());
            }
          }
        }
      } else if (data is Map) {
        // Case 1: Standard API format with users array
        if (data.containsKey('users')) {
          print('✅ Structure avec champ "users" détectée');
          var users = data['users'];
          if (users is List) {
            print('✅ Le champ "users" est bien une liste');
            for (var userId in users) {
              if (userId != null) {
                validIds.add(userId.toString());
              }
            }
          } else {
            print('⚠️ Le champ "users" n\'est pas une liste: ${users.runtimeType}');
          }
        } 
        // Case 2: Look for any potential ID values in the map
        else {
          print('⚠️ Format de map sans champ "users", extraction générique');
          data.forEach((key, value) {
            if (value != null) {
              if (value is List) {
                print('✅ Valeur de type liste trouvée pour la clé "$key"');
                // If it's a list of maps with userId field (special case for choiceUsers)
                if (value.isNotEmpty && value.first is Map) {
                  for (var item in value) {
                    if (item is Map && item.containsKey('userId')) {
                      var userId = item['userId'];
                      if (userId != null) {
                        print('✅ UserId trouvé dans un objet: $userId');
                        validIds.add(userId.toString());
                      }
                    }
                  }
                } 
                // Regular list of IDs
                else {
                  for (var item in value) {
                    if (item != null) {
                      validIds.add(item.toString());
                    }
                  }
                }
              } 
              // Direct ID values
              else if (value is String || value is int) {
                validIds.add(value.toString());
              } 
              // Nested map with users array
              else if (value is Map) {
                if (value.containsKey('users')) {
                  var nestedUsers = value['users'];
                  if (nestedUsers is List) {
                    print('✅ Nested users array found for key: $key');
                    for (var userId in nestedUsers) {
                      if (userId != null) {
                        validIds.add(userId.toString());
                      }
                    }
                  }
                } 
                // Nested map with userId field (special case for choiceUsers)
                else if (value.containsKey('userId')) {
                  var userId = value['userId'];
                  if (userId != null) {
                    print('✅ UserId trouvé dans un objet imbriqué: $userId');
                    validIds.add(userId.toString());
                  }
                }
              }
            }
          });
        }
      } else if (data is String || data is int) {
        // Single ID as a scalar value
        print('✅ ID unique détecté de type ${data.runtimeType}');
        validIds.add(data.toString());
      } else {
        // Completely unknown type - last resort with toString()
        print('⚠️ Type inconnu: ${data.runtimeType}, tentative avec toString()');
        try {
          String dataStr = data.toString();
          if (dataStr.isNotEmpty && dataStr != "null") {
            validIds.add(dataStr);
          }
        } catch (e) {
          print('❌ Impossible de convertir en string: $e');
        }
      }
      
      if (validIds.isEmpty) {
        print('❌ Aucun ID valide extrait: ${data.runtimeType}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun identifiant trouvé dans les données')),
        );
        return;
      }
      
      print('✅ ${validIds.length} IDs valides extraits: $validIds');
    } catch (e) {
      print('❌ Erreur lors de l\'extraction des IDs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'extraction des IDs')),
      );
      return;
    }
    
    print('🔍 Validation des profils pour ${validIds.length} IDs');
    final validProfiles = await _validateProfiles(validIds);
    print('✅ ${validProfiles.length} profils valides trouvés');

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
      print('❌ Aucun profil valide trouvé pour les IDs: $validIds');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun profil valide trouvé.')),
      );
    }
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    final String photoUrl = data['photo'] ?? 'https://via.placeholder.com/100';
    final String name = data['name'] ?? 'Nom non spécifié';
    final String description = data['description'] ?? 'Description non spécifiée';
    final double rating = double.tryParse(data['rating']?.toString() ?? '0') ?? 0;
    final coordinates = data['gps_coordinates'];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(photoUrl),
              ),
              const SizedBox(width: 16),
              
              // Name, rating and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Rating badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Additional tags or badges
          if (data['tags'] != null || data['cuisine'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (data['cuisine'] != null)
                    _buildTag(data['cuisine'], Icons.restaurant, Colors.teal),
                  
                  // Extract and display tags if available
                  ..._extractTags(data).map((tag) => 
                    _buildTag(tag, Icons.local_offer, Colors.deepPurple)
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<String> _extractTags(Map<String, dynamic> data) {
    final tags = <String>[];
    
    // If 'tags' is directly available as a list
    if (data['tags'] is List) {
      for (var tag in data['tags']) {
        if (tag is String) {
          tags.add(tag);
        }
      }
    }
    
    // Add cuisine type if available and not already included
    if (data['cuisine'] is String && !tags.contains(data['cuisine'])) {
      tags.add(data['cuisine']);
    }
    
    // Add type if available and not already included
    if (data['type'] is String && !tags.contains(data['type'])) {
      tags.add(data['type']);
    }
    
    return tags;
  }

  Widget _buildTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsSection(Map<String, dynamic> producer) {
    final notes = producer['notes_globales'] ?? {};
    final service = (notes['service'] ?? 0.0).toDouble();
    final lieu = (notes['lieu'] ?? 0.0).toDouble();
    final portions = (notes['portions'] ?? 0.0).toDouble();
    final ambiance = (notes['ambiance'] ?? 0.0).toDouble();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: const Icon(Icons.star_rate, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Notes détaillées',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildRatingItem(
                    'Service',
                    service,
                    Icons.room_service,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRatingItem(
                    'Lieu',
                    lieu,
                    Icons.place,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRatingItem(
                    'Portions',
                    portions,
                    Icons.restaurant,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRatingItem(
                    'Ambiance',
                    ambiance,
                    Icons.mood,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingItem(String label, double rating, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyGraph(Map<String, dynamic> producer) {
    try {
      dynamic frequencyData = producer['frequency_data'];
      if (frequencyData == null) {
        // Try alternate key
        frequencyData = producer['popular_times'];
      }
      
      if (frequencyData == null) {
        print('❌ Données de fréquentation non disponibles');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Données de fréquentation non disponibles.',
        );
      }

      // Determine if frequencyData is a List or Map and handle accordingly
      if (!(frequencyData is List) && !(frequencyData is Map)) {
        print('❌ Données de fréquentation ni liste ni Map: ${frequencyData.runtimeType}');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Format de données de fréquentation non supporté.',
        );
      }

      // Check if data is empty
      if ((frequencyData is List && frequencyData.isEmpty) ||
          (frequencyData is Map && frequencyData.isEmpty)) {
        print('❌ Données de fréquentation vides');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Aucune donnée de fréquentation disponible.',
        );
      }

      // Determine size safely and ensure _selectedDay is an int
      int size = 0;
      int selectedDayIndex = 0;
      
      try {
        // Make sure _selectedDay is always an integer
        if (_selectedDay is int) {
          selectedDayIndex = _selectedDay;
        } else if (_selectedDay is String) {
          selectedDayIndex = int.tryParse(_selectedDay.toString()) ?? 0;
        } else {
          selectedDayIndex = 0;
        }
      } catch (e) {
        print('❌ Erreur lors de la conversion de _selectedDay: $e');
        selectedDayIndex = 0;
      }
      
      if (frequencyData is List) {
        size = frequencyData.length;
      } else if (frequencyData is Map) {
        size = frequencyData.keys.length;
      }

      // Ensure selected day is in bounds
      if (selectedDayIndex >= size || selectedDayIndex < 0) {
        print('❌ selectedDayIndex ($selectedDayIndex) hors limites, remise à 0');
        selectedDayIndex = 0;
      }

      // Get data for selected day with strong type checking
      dynamic selectedDayData;
      if (frequencyData is List) {
        if (frequencyData.isNotEmpty && selectedDayIndex < frequencyData.length) {
          selectedDayData = frequencyData[selectedDayIndex];
        }
      } else if (frequencyData is Map) {
        // Try different strategies to find the correct day data
        final selectedDayKey = selectedDayIndex.toString();
        
        // Strategy 1: Direct key lookup
        if (frequencyData.containsKey(selectedDayKey)) {
          selectedDayData = frequencyData[selectedDayKey];
        }
        // Strategy 2: Find a key that converts to the selected day index
        else if (frequencyData.containsKey(selectedDayIndex)) {
          selectedDayData = frequencyData[selectedDayIndex];
        }
        // Strategy 3: Look for day names as keys
        else {
          List<String> dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
          if (selectedDayIndex < dayNames.length && frequencyData.containsKey(dayNames[selectedDayIndex])) {
            selectedDayData = frequencyData[dayNames[selectedDayIndex]];
          } else {
            // Strategy 4: Look for a key in the map whose string representation matches
            final keysList = frequencyData.keys.toList();
            for (int i = 0; i < keysList.length; i++) {
              var key = keysList[i];
              if (key.toString() == selectedDayKey || 
                  (key is int && key == selectedDayIndex) ||
                  (key is String && key == selectedDayKey)) {
                selectedDayData = frequencyData[key];
                break;
              }
            }
            
            // If still not found, default to first item
            if (selectedDayData == null && frequencyData.isNotEmpty) {
              var firstKey = frequencyData.keys.first;
              selectedDayData = frequencyData[firstKey];
            }
          }
        }
      }

      // Handle case where no data was found
      if (selectedDayData == null) {
        print('❌ selectedDayData est null');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Données du jour sélectionné non disponibles.',
        );
      }
      
      // Extract actual data with better type checking
      dynamic data;
      if (selectedDayData is Map) {
        data = selectedDayData['data'] ?? selectedDayData;
      } else if (selectedDayData is List) {
        data = selectedDayData;
      } else if (selectedDayData is String) {
        // Try to parse as JSON if it's a string
        try {
          final decoded = json.decode(selectedDayData);
          if (decoded is Map) {
            data = decoded['data'] ?? decoded;
          } else {
            data = decoded;
          }
        } catch (e) {
          print('❌ Impossible de décoder selectedDayData: $e');
          data = null;
        }
      }
      
      if (data == null) {
        print('❌ data est null dans selectedDayData');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Données de fréquentation pour le jour sélectionné non disponibles.',
        );
      }

      // Convert data to List<int> safely
      List<int> filteredTimes = [];
      if (data is List) {
        try {
          // Convert all items to int safely
          for (var item in data) {
            int value = 0;
            if (item is int) {
              value = item;
            } else if (item is double) {
              value = item.toInt();
            } else if (item is String) {
              value = int.tryParse(item) ?? 0;
            } else if (item is Map && item.containsKey('value')) {
              // Handle case where data might be structured as objects
              var nestedValue = item['value'];
              if (nestedValue is int) {
                value = nestedValue;
              } else if (nestedValue is double) {
                value = nestedValue.toInt();
              } else if (nestedValue is String) {
                value = int.tryParse(nestedValue) ?? 0;
              }
            }
            filteredTimes.add(value);
          }
          
          // Extract relevant time range (8h-midnight)
          if (filteredTimes.length >= 24) {
            filteredTimes = filteredTimes.sublist(8, 24);
          } else if (filteredTimes.length > 16) {
            // Take the last 16 elements if we have more than 16 but less than 24
            filteredTimes = filteredTimes.sublist(filteredTimes.length - 16);
          } else if (filteredTimes.isEmpty) {
            // Default to zeros if empty
            filteredTimes = List.filled(16, 0);
          }
        } catch (e) {
          print('❌ Erreur lors de la conversion des données: $e');
          filteredTimes = List.filled(16, 0);
        }
      } else if (data is Map) {
        // Handle case where data is a map
        try {
          var values = <int>[];
          // Try different strategies to extract values
          if (data.containsKey('values') && data['values'] is List) {
            var valuesData = data['values'] as List;
            for (var val in valuesData) {
              if (val is int) {
                values.add(val);
              } else if (val is double) {
                values.add(val.toInt());
              } else if (val is String) {
                values.add(int.tryParse(val) ?? 0);
              }
            }
          } else {
            // Try to extract all numeric values from the map
            data.forEach((key, value) {
              if (value is int) {
                values.add(value);
              } else if (value is double) {
                values.add(value.toInt());
              } else if (value is String && int.tryParse(value) != null) {
                values.add(int.tryParse(value)!);
              }
            });
          }
          
          if (values.isNotEmpty) {
            filteredTimes = values;
            if (filteredTimes.length > 16) {
              filteredTimes = filteredTimes.sublist(0, 16);
            }
          } else {
            filteredTimes = List.filled(16, 0);
          }
        } catch (e) {
          print('❌ Erreur lors de l\'extraction des valeurs de la map: $e');
          filteredTimes = List.filled(16, 0);
        }
      } else {
        print('❌ data n\'est ni une liste ni une map: ${data.runtimeType}');
        filteredTimes = List.filled(16, 0);
      }

      // Get day labels
      List<String> dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      
      return Card(
        elevation: 1,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    child: const Icon(Icons.access_time, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Fréquentation (8h - Minuit)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  value: selectedDayIndex,
                  isExpanded: true,
                  hint: const Text('Sélectionnez un jour'),
                  underline: Container(), // Supprime la ligne par défaut
                  items: List.generate(
                    dayLabels.length < size ? size : dayLabels.length, 
                    (index) {
                      String dayName = index < dayLabels.length 
                          ? dayLabels[index] 
                          : 'Jour ${index + 1}';
                      
                      return DropdownMenuItem(
                        value: index,
                        child: Text(dayName),
                      );
                    }
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedDay = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: List.generate(filteredTimes.length, (index) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: filteredTimes[index].toDouble(),
                              width: 8,
                              color: Colors.blue.withOpacity(0.8),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 2,
                            getTitlesWidget: (value, _) {
                              int hour = value.toInt() + 8;
                              return Text(
                                '$hour h',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Erreur inattendue dans _buildFrequencyGraph: $e');
      return _buildInfoCard(
        'Tendances de fréquentation',
        Icons.trending_up,
        Colors.blue,
        'Erreur lors de l\'affichage des données de fréquentation.',
      );
    }
  }

  Widget _buildInfoCard(String title, IconData icon, Color color, String message) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  message,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black)),
        ],
      ),
      selected: selected,
      selectedColor: color,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? color : Colors.grey.withOpacity(0.3)),
      ),
      onSelected: onSelected,
    );
  }

  Widget _buildFilterOptions() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.filter_list, color: Colors.purple),
            ),
            const SizedBox(width: 12),
            const Text(
              'Filtres',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating and Calories in one row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Note: ${_ratingRange.start.toStringAsFixed(1)} - ${_ratingRange.end.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.amber,
                              inactiveTrackColor: Colors.amber.withOpacity(0.2),
                              thumbColor: Colors.amber,
                              overlayColor: Colors.amber.withOpacity(0.2),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              trackHeight: 3,
                            ),
                            child: RangeSlider(
                              values: _ratingRange,
                              min: 0.0,
                              max: 5.0,
                              divisions: 10,
                              onChanged: (RangeValues values) {
                                setState(() {
                                  _ratingRange = values;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Max: $_selectedMaxCalories cal',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.red,
                              inactiveTrackColor: Colors.red.withOpacity(0.2),
                              thumbColor: Colors.red,
                              overlayColor: Colors.red.withOpacity(0.2),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _selectedMaxCalories,
                              min: 100,
                              max: 1000,
                              divisions: 9,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMaxCalories = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 24),
                
                // Carbon and NutriScore in one row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.eco, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Bilan Carbone',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: ButtonTheme(
                                alignedDropdown: true,
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedCarbon,
                                  items: const [
                                    DropdownMenuItem(value: "<3kg", child: Text("<3kg")),
                                    DropdownMenuItem(value: "<5kg", child: Text("<5kg")),
                                    DropdownMenuItem(value: "<10kg", child: Text("<10kg")),
                                    DropdownMenuItem(value: "Tous", child: Text("Tous")),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCarbon = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.health_and_safety, color: Colors.teal, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Nutri-Score',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: ButtonTheme(
                                alignedDropdown: true,
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedNutriScore,
                                  items: const [
                                    DropdownMenuItem(value: "A", child: Text("A uniquement")),
                                    DropdownMenuItem(value: "A-B", child: Text("A-B")),
                                    DropdownMenuItem(value: "A-C", child: Text("A-C")),
                                    DropdownMenuItem(value: "Tous", child: Text("Tous")),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedNutriScore = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 24),
                
                // Toggle options in a wrap
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildFilterChip(
                      label: 'Produits locaux',
                      icon: Icons.location_on,
                      color: Colors.indigo,
                      selected: _showLocalProducts,
                      onSelected: (value) => setState(() => _showLocalProducts = value),
                    ),
                    _buildFilterChip(
                      label: 'Bio uniquement',
                      icon: Icons.eco_outlined,
                      color: Colors.green,
                      selected: _showOrganicOnly,
                      onSelected: (value) => setState(() => _showOrganicOnly = value),
                    ),
                    _buildFilterChip(
                      label: 'Végétarien',
                      icon: Icons.grass,
                      color: Colors.lightGreen,
                      selected: _showVegetarianOptions,
                      onSelected: (value) => setState(() => _showVegetarianOptions = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchOption(
    String title,
    IconData icon,
    Color color,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredItems(Map<String, dynamic> producer) {
    final items = producer['structured_data']?['Items Indépendants'] ?? [];
    if (items.isEmpty) {
      return _buildInfoCard(
        'Plats Recommandés',
        Icons.restaurant_menu,
        Colors.orange,
        'Aucun plat disponible pour ce restaurant.',
      );
    }

    final filteredItems = <String, List<dynamic>>{};
    for (var category in items) {
      final categoryName = category['catégorie'] ?? 'Autres';
      for (var item in category['items'] ?? []) {
        // Parse item properties with better error handling
        final carbonFootprint = double.tryParse(item['carbon_footprint']?.toString() ?? '0') ?? 0;
        final nutriScore = item['nutri_score']?.toString() ?? 'N/A';
        final calories = double.tryParse(item['nutrition']?['calories']?.toString() ?? '0') ?? 0;
        final rating = double.tryParse(item['note']?.toString() ?? '0') ?? 0;
        final isOrganic = item['bio'] == true || item['bio'] == 'true';
        final isVegetarian = item['vegetarian'] == true || item['vegetarian'] == 'true';
        final isLocal = item['local'] == true || item['local'] == 'true';

        // Apply filters
        bool passesFilters = true;
        
        // Rating filter
        if (rating < _ratingRange.start || rating > _ratingRange.end) {
          passesFilters = false;
        }
        
        // Carbon footprint filter
        if (_selectedCarbon != "Tous") {
          double maxCarbon = 10; // Default
          if (_selectedCarbon == "<3kg") maxCarbon = 3;
          if (_selectedCarbon == "<5kg") maxCarbon = 5;
          if (_selectedCarbon == "<10kg") maxCarbon = 10;
          
          if (carbonFootprint > maxCarbon) {
            passesFilters = false;
          }
        }
        
        // Nutri-score filter
        if (_selectedNutriScore != "Tous") {
          if (_selectedNutriScore == "A" && nutriScore != "A") {
            passesFilters = false;
          } else if (_selectedNutriScore == "A-B" && !(nutriScore == "A" || nutriScore == "B")) {
            passesFilters = false;
          } else if (_selectedNutriScore == "A-C" && !(nutriScore == "A" || nutriScore == "B" || nutriScore == "C")) {
            passesFilters = false;
          }
        }
        
        // Calories filter
        if (calories > _selectedMaxCalories) {
          passesFilters = false;
        }
        
        // Optional filters
        if (_showLocalProducts && !isLocal) {
          passesFilters = false;
        }
        
        if (_showOrganicOnly && !isOrganic) {
          passesFilters = false;
        }
        
        if (_showVegetarianOptions && !isVegetarian) {
          passesFilters = false;
        }

        // Add item to filtered items if it passes all filters
        if (passesFilters) {
          if (!filteredItems.containsKey(categoryName)) {
            filteredItems[categoryName] = [];
          }
          filteredItems[categoryName]!.add(item);
        }
      }
    }

    if (filteredItems.isEmpty) {
      return _buildInfoCard(
        'Plats Recommandés',
        Icons.restaurant_menu,
        Colors.orange,
        'Aucun plat ne correspond à vos critères de filtrage.',
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: const Icon(Icons.restaurant_menu, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Plats Recommandés',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Categories and items
            ...filteredItems.entries.map((entry) {
              final categoryName = entry.key;
              final categoryItems = entry.value;
              
              // Sort items by rating (highest first)
              categoryItems.sort((a, b) {
                final ratingA = double.tryParse(a['note']?.toString() ?? '0') ?? 0;
                final ratingB = double.tryParse(b['note']?.toString() ?? '0') ?? 0;
                return ratingB.compareTo(ratingA);
              });
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  ...categoryItems.map((item) => _buildDishCard(item)).toList(),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDishCard(Map<String, dynamic> item) {
    final String name = item['nom'] ?? 'Nom non spécifié';
    final String description = item['description'] ?? 'Description non spécifiée';
    final double rating = double.tryParse(item['note']?.toString() ?? '0') ?? 0;
    final String carbonFootprint = item['carbon_footprint']?.toString() ?? 'N/A';
    final String nutriScore = item['nutri_score']?.toString() ?? 'N/A';
    final String calories = item['nutrition']?['calories']?.toString() ?? 'N/A';
    final String price = item['prix']?.toString() ?? 'N/A';
    final List<dynamic> ingredients = item['ingredients'] ?? [];
    final String imageUrl = item['image'] ?? '';

    // Get nutri-score color
    Color nutriScoreColor;
    switch (nutriScore.toUpperCase()) {
      case 'A':
        nutriScoreColor = Colors.green;
        break;
      case 'B':
        nutriScoreColor = Colors.lightGreen;
        break;
      case 'C':
        nutriScoreColor = Colors.yellow;
        break;
      case 'D':
        nutriScoreColor = Colors.orange;
        break;
      case 'E':
        nutriScoreColor = Colors.red;
        break;
      default:
        nutriScoreColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildBadge(
                        nutriScore.toUpperCase(),
                        nutriScoreColor,
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(
                        "$carbonFootprint kg CO₂",
                        Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(
                        "$calories cal",
                        Colors.red,
                      ),
                      const Spacer(),
                      Text(
                        "$price €",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Ingrédients",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ingredients.map<Widget>((ingredient) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            ingredient.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMenuDetails(Map<String, dynamic> producer) {
    final menus = producer['structured_data']?['Menus Globaux'] ?? [];
    if (menus.isEmpty) {
      return _buildInfoCard(
        'Menus Disponibles',
        Icons.menu_book,
        Colors.indigo,
        'Aucun menu n\'est disponible pour ce restaurant.',
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Menus Disponibles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ...menus.map<Widget>((menu) {
              final String name = menu['nom'] ?? 'Menu sans nom';
              final String price = menu['prix']?.toString() ?? 'Prix non spécifié';
              final List<dynamic> included = menu['inclus'] ?? [];
              final String description = menu['description'] ?? '';
              
              // Calculate average rating for menu items
              double avgRating = 0;
              int ratedItemsCount = 0;
              
              for (var category in included) {
                for (var item in category['items'] ?? []) {
                  final double itemRating = double.tryParse(item['note']?.toString() ?? '0') ?? 0;
                  if (itemRating > 0) {
                    avgRating += itemRating;
                    ratedItemsCount++;
                  }
                }
              }
              
              if (ratedItemsCount > 0) {
                avgRating /= ratedItemsCount;
              }
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ExpansionTile(
                  initiallyExpanded: false,
                  childrenPadding: const EdgeInsets.all(16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (avgRating > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, color: Colors.white, size: 14),
                                        const SizedBox(width: 2),
                                        Text(
                                          avgRating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              '$price €',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  children: included.map<Widget>((category) {
                    final String categoryName = category['catégorie'] ?? 'Catégorie non spécifiée';
                    final List<dynamic> items = category['items'] ?? [];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        ...items.map<Widget>((item) {
                          final String itemName = item['nom'] ?? 'Nom non spécifié';
                          final String itemDescription = item['description'] ?? '';
                          final double itemRating = double.tryParse(item['note']?.toString() ?? '0') ?? 0;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.restaurant, size: 16, color: Colors.indigo),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              itemName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (itemRating > 0)
                                            Row(
                                              children: [
                                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                                const SizedBox(width: 2),
                                                Text(
                                                  itemRating.toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      if (itemDescription.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            itemDescription,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection(List<dynamic> photos) {
    if (photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Aucune photo disponible.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Colors.orangeAccent),
              ),
              const SizedBox(width: 12),
              const Text(
                'Galerie',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  // Ouvrir l'image en plein écran ou dans une galerie
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.black87,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 3.0,
                            child: Image.network(
                              photos[index],
                              fit: BoxFit.contain,
                              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 30),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.network(
                      photos[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchProducerPosts(widget.producerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.post_add, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun post disponible pour ce producteur.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
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
    final producerId = post['producer_id'];
    final isProducerPost = producerId != null;
    final interestedCount = post['interested']?.length ?? 0;
    final choicesCount = post['choices']?.length ?? 0;

    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(
                        post['user_photo'] ?? 'https://via.placeholder.com/150',
                      ),
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
                      Text(
                        formatDate(post['created_at'] ?? ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                post['title'] ?? 'Titre non spécifié',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Content
              Text(
                post['content'] ?? 'Contenu non disponible',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Media
              if (mediaUrls.isNotEmpty)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PageView(
                      children: mediaUrls.map((url) {
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.error, color: Colors.red),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Actions row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Like Button
                  _buildPostAction(
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    label: 'Like',
                    isActive: false,
                    color: Colors.red,
                    count: 0,
                    onPressed: () {
                      print('Like functionality not yet implemented');
                    },
                  ),

                  // Interested Button
                  if (isProducerPost)
                    _buildPostAction(
                      icon: Icons.emoji_objects_outlined,
                      activeIcon: Icons.emoji_objects,
                      label: 'Intéressé',
                      isActive: post['interested']?.contains(widget.userId) ?? false,
                      color: Colors.orange,
                      count: interestedCount,
                      onPressed: () => _markInterested(producerId!, post),
                    ),

                  // Choice Button
                  if (isProducerPost)
                    _buildPostAction(
                      icon: Icons.check_circle_outline,
                      activeIcon: Icons.check_circle,
                      label: 'Choix',
                      isActive: post['choices']?.contains(widget.userId) ?? false,
                      color: Colors.green,
                      count: choicesCount,
                      onPressed: () => _markChoice(producerId!, post),
                    ),

                  // Share Button
                  _buildPostAction(
                    icon: Icons.share,
                    activeIcon: Icons.share,
                    label: 'Partager',
                    isActive: false,
                    color: Colors.blue,
                    count: null,
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

  Widget _buildPostAction({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required Color color,
    required Function onPressed,
    int? count,
  }) {
    return GestureDetector(
      onTap: () => onPressed(),
      child: Column(
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? color : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            count != null ? '$label ($count)' : label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? color : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return 'il y a $years an${years > 1 ? 's' : ''}';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return 'il y a $months mois';
      } else if (difference.inDays > 0) {
        return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'à l\'instant';
      }
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildMap(Map<String, dynamic>? coordinates) {
    try {
      if (coordinates == null || coordinates['coordinates'] == null) {
        return _buildInfoCard(
          'Localisation',
          Icons.location_on,
          Colors.red,
          'Coordonnées GPS non disponibles.',
        );
      }
      
      final List? coords = coordinates['coordinates'];
      if (coords == null || coords.length < 2) {
        print('❌ Format de coordonnées invalide');
        return _buildInfoCard(
          'Localisation',
          Icons.location_on,
          Colors.red,
          'Format de coordonnées invalide.',
        );
      }
      
      if (coords[0] == null || coords[1] == null || 
          !(coords[0] is num) || !(coords[1] is num)) {
        print('❌ Coordonnées invalides: valeurs non numériques');
        return _buildInfoCard(
          'Localisation',
          Icons.location_on,
          Colors.red,
          'Coordonnées invalides: valeurs non numériques.',
        );
      }
      
      final double lon = coords[0].toDouble();
      final double lat = coords[1].toDouble();
      
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        print('❌ Coordonnées invalides: hors limites (lat: $lat, lon: $lon)');
        return _buildInfoCard(
          'Localisation',
          Icons.location_on,
          Colors.red,
          'Coordonnées invalides: hors limites.',
        );
      }

      final latLng = LatLng(lat, lon);

      return Card(
        elevation: 1,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Localisation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
                        markers: {
                          Marker(
                            markerId: const MarkerId('producer'),
                            position: latLng,
                            infoWindow: const InfoWindow(
                              title: 'Restaurant',
                              snippet: '',
                            ),
                          )
                        },
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: FloatingActionButton.small(
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.fullscreen, color: Colors.black87),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapScreen(
                                  initialPosition: LatLng(lat, lon),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Erreur lors du rendu de la carte: $e');
      return _buildInfoCard(
        'Localisation',
        Icons.location_on,
        Colors.red,
        'Erreur lors du chargement de la carte.',
      );
    }
  }

  Widget _buildContactDetails(Map<String, dynamic> producer) {
    final String? phoneNumber = producer['phone_number'];
    final String? website = producer['website'];
    final String? address = producer['address'];
    final Map<String, dynamic>? openingHours = producer['opening_hours'] as Map<String, dynamic>?;
    
    if (phoneNumber == null && website == null && address == null && openingHours == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informations Pratiques',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (address != null)
              _buildContactItem(
                Icons.place,
                'Adresse',
                address,
                Colors.red,
              ),
            
            if (phoneNumber != null)
              _buildContactItem(
                Icons.phone,
                'Téléphone',
                phoneNumber,
                Colors.blue,
              ),
            
            if (website != null)
              _buildContactItem(
                Icons.language,
                'Site Web',
                website,
                Colors.purple,
              ),
            
            if (openingHours != null && openingHours.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time, color: Colors.green, size: 18),
                ),
                title: const Text(
                  'Horaires d\'ouverture',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: openingHours.entries.map((entry) {
                  final day = entry.key;
                  final hours = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          hours.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(Map<String, dynamic> producer) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Colors.orangeAccent,
              labelColor: Colors.orangeAccent,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(
                  icon: Icon(Icons.restaurant_menu),
                  text: 'Carte',
                ),
                Tab(
                  icon: Icon(Icons.photo_library),
                  text: 'Photos',
                ),
                Tab(
                  icon: Icon(Icons.post_add),
                  text: 'Posts',
                ),
              ],
            ),
            SizedBox(
              height: 600,
              child: TabBarView(
                children: [
                  // Menu tab with integrated filters and menu items
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        // Filter section
                        Card(
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _buildFilterOptions(),
                        ),
                        // Menu items section
                        Card(
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildFilteredItems(producer),
                              const Divider(height: 1),
                              _buildMenuDetails(producer),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(child: _buildPhotosSection(producer['photos'] ?? [])),
                  SingleChildScrollView(child: _buildPostsSection()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail Producteur'),
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
        actions: [
          // Map button with better visibility and styling
          FutureBuilder<Map<String, dynamic>>(
            future: _producerFuture,
            builder: (context, snapshot) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Tooltip(
                  message: 'Voir sur la carte',
                  child: IconButton(
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () {
                      if (snapshot.hasData) {
                        final Map<String, dynamic> data = snapshot.data!;
                        final coordinates = data['gps_coordinates'];
                        if (coordinates != null && coordinates['coordinates'] is List) {
                          final List coords = coordinates['coordinates'];
                          if (coords.length >= 2) {
                            final double lat = coords[1].toDouble();
                            final double lon = coords[0].toDouble();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapScreen(
                                  initialPosition: LatLng(lat, lon),
                                ),
                              ),
                            );
                            return;
                          }
                        }
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapScreen(
                            initialPosition: const LatLng(48.8566, 2.3522),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Share button with tooltip
          Tooltip(
            message: 'Partager',
            child: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Partage du profil producteur')),
                );
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _producerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent)
            );
          } else if (snapshot.hasError) {
            // Analyse de l'erreur pour fournir des messages plus clairs
            String errorMessage = 'Une erreur est survenue';
            String errorDetails = '';
            bool isIdError = false;
            bool isNetworkError = false;
            
            // Déterminer le type d'erreur
            final error = snapshot.error.toString();
            if (error.contains('ID MongoDB valide')) {
              isIdError = true;
              errorMessage = 'Identifiant producteur invalide';
              errorDetails = 'L\'ID fourni ne correspond pas au format requis.';
            } else if (error.contains('Tous les endpoints ont échoué')) {
              isNetworkError = true;
              errorMessage = 'Impossible de se connecter aux APIs';
              errorDetails = 'Vérifiez votre connexion internet ou la disponibilité du serveur.';
            } else if (error.contains('timeout') || error.contains('délai')) {
              isNetworkError = true;
              errorMessage = 'Délai d\'attente dépassé';
              errorDetails = 'Le serveur met trop de temps à répondre. Réessayez plus tard.';
            }
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIdError ? Icons.error_outline : 
                    isNetworkError ? Icons.wifi_off : 
                    Icons.error_outline,
                    color: isIdError ? Colors.orange : Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      errorDetails.isEmpty ? '$error' : errorDetails,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Afficher des actions différentes selon le type d'erreur
                  if (isIdError)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _producerFuture = _fetchProducerDetails(widget.producerId);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                      ),
                    ),
                  if (isNetworkError) 
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: TextButton(
                        onPressed: () {
                          // Afficher un dialogue avec des détails techniques
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Détails de l\'erreur'),
                              content: SingleChildScrollView(
                                child: Text(error),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Fermer'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Voir les détails techniques'),
                      ),
                    ),
                ],
              ),
            );
          }

          final producer = snapshot.data!;
          
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _producerFuture = _fetchProducerDetails(widget.producerId);
              });
            },
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(producer),
                    _buildProfileActions(producer),
                    _buildFrequencyGraph(producer),
                    _buildRatingsSection(producer),
                    _buildMap(producer['gps_coordinates']),
                    _buildTabs(producer),
                    _buildContactDetails(producer),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Classe dédiée à l'écran de détail de post pour les producteurs
class ProducerPostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? userId;

  const ProducerPostDetailScreen({Key? key, required this.post, this.userId}) : super(key: key);

  @override
  _ProducerPostDetailScreenState createState() => _ProducerPostDetailScreenState();
}

class _ProducerPostDetailScreenState extends State<ProducerPostDetailScreen> {
  late Map<String, dynamic> post;
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
    setState(() {
      post['isLoading'] = true;
    });
    
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/choicexinterest/interested');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/choicexinterest/interested');
    } else {
      url = Uri.parse('$baseUrl/api/choicexinterest/interested');
    }
    
    final body = {'userId': widget.userId, 'targetId': targetId};

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final updatedInterested = responseData['interested'];
        setState(() {
          post['interested'] = updatedInterested;
          interestedCount = updatedInterested.length;
          post['isLoading'] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedInterested ? 'Ajouté à vos intérêts' : 'Retiré de vos intérêts'),
            backgroundColor: updatedInterested ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        print('✅ Interested ajouté avec succès');
      } else {
        setState(() {
          post['isLoading'] = false;
        });
        print('❌ Erreur lors de l\'ajout à Interested : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        post['isLoading'] = false;
      });
      print('❌ Erreur réseau lors de l\'ajout à Interested : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markChoice(String targetId) async {
    setState(() {
      post['isLoading'] = true;
    });
    
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/choicexinterest/choice');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/choicexinterest/choice');
    } else {
      url = Uri.parse('$baseUrl/api/choicexinterest/choice');
    }
    
    final body = {'userId': widget.userId, 'targetId': targetId};

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final updatedChoices = responseData['choice'];
        setState(() {
          post['choices'] = updatedChoices;
          choicesCount = updatedChoices.length;
          post['isLoading'] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedChoices ? 'Ajouté à vos choix' : 'Retiré de vos choix'),
            backgroundColor: updatedChoices ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        print('✅ Choice ajouté avec succès');
      } else {
        setState(() {
          post['isLoading'] = false;
        });
        print('❌ Erreur lors de l\'ajout à Choices : ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        post['isLoading'] = false;
      });
      print('❌ Erreur réseau lors de l\'ajout à Choices : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réseau : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _updateUserProfile() async {
    if (widget.userId == null) return;
    
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/users/${widget.userId}');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/users/${widget.userId}');
    } else {
      url = Uri.parse('$baseUrl/api/users/${widget.userId}');
    }
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        print('✅ Profil utilisateur mis à jour avec succès');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de la mise à jour du profil : $e');
    }
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return 'il y a $years an${years > 1 ? 's' : ''}';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return 'il y a $months mois';
      } else if (difference.inDays > 0) {
        return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'à l\'instant';
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrls = post['media'] as List<dynamic>? ?? [];
    final producerId = post['producer_id'];
    final title = post['title'] ?? 'Détails du Post';
    final content = post['content'] ?? 'Contenu non disponible';
    final authorName = post['author_name'] ?? 'Auteur inconnu';
    final userPhoto = post['user_photo'] ?? 'https://via.placeholder.com/150';
    final createdAt = post['created_at'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité de partage')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(userPhoto),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Images
              if (mediaUrls.isNotEmpty)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PageView.builder(
                      itemCount: mediaUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Afficher l'image en plein écran quand on clique dessus
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                insetPadding: EdgeInsets.zero,
                                backgroundColor: Colors.black87,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 3.0,
                                      child: Image.network(
                                        mediaUrls[index],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'post_image_$index',
                            child: Image.network(
                              mediaUrls[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.orangeAccent,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.error, color: Colors.red, size: 50),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Content
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Actions
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Interested Button
                      _buildActionButton(
                        label: 'Intéressé',
                        icon: Icons.emoji_objects_outlined,
                        activeIcon: Icons.emoji_objects,
                        isActive: post['interested']?.contains(widget.userId) ?? false,
                        isLoading: post['isLoading'] == true,
                        count: interestedCount,
                        color: Colors.orange,
                        onPressed: () {
                          if (producerId != null) {
                            _markInterested(producerId);
                            _updateUserProfile();
                          }
                        },
                      ),

                      // Divider
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),

                      // Choice Button
                      _buildActionButton(
                        label: 'Choix',
                        icon: Icons.check_circle_outline,
                        activeIcon: Icons.check_circle,
                        isActive: post['choices']?.contains(widget.userId) ?? false,
                        isLoading: post['isLoading'] == true,
                        count: choicesCount,
                        color: Colors.green,
                        onPressed: () {
                          if (producerId != null) {
                            _markChoice(producerId);
                            _updateUserProfile();
                          }
                        },
                      ),

                      // Divider
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),

                      // Share Button
                      _buildActionButton(
                        label: 'Partager',
                        icon: Icons.share,
                        activeIcon: Icons.share,
                        isActive: false,
                        isLoading: false,
                        count: null,
                        color: Colors.blue,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Fonctionnalité de partage')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required bool isLoading,
    required Color color,
    required Function onPressed,
    int? count,
  }) {
    return GestureDetector(
      onTap: () => onPressed(),
      child: Column(
        children: [
          isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? color : Colors.grey,
                  size: 24,
                ),
          const SizedBox(height: 8),
          Text(
            count != null ? '$label ($count)' : label,
            style: TextStyle(
              fontSize: 14,
              color: isActive ? color : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// Écran pour afficher les relations (followers, following, etc.)
class RelationDetailsScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> profiles;

  const RelationDetailsScreen({Key? key, required this.title, required this.profiles})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
      ),
      body: profiles.isNotEmpty
          ? ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];

                final userId = profile['_id'];
                final producerId = profile['producerId'];
                final producerData = profile['producerData'];
                final photoUrl = profile['photo'] ??
                    profile['photo_url'] ??
                    'https://via.placeholder.com/150';
                final name = profile['name'] ?? 'Nom inconnu';
                final description = profile['description'] ?? 'Pas de description';

                final isUser = userId != null && producerId == null && producerData == null;
                final isProducer = producerId != null;
                final isLeisureProducer = producerData != null;

                if (!isUser && !isProducer && !isLeisureProducer) {
                  print('❌ Profil non valide à l\'index $index');
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(photoUrl),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getProfileTypeColor(isUser, isProducer, isLeisureProducer).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getProfileTypeColor(isUser, isProducer, isLeisureProducer).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getProfileType(isUser, isProducer, isLeisureProducer),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getProfileTypeColor(isUser, isProducer, isLeisureProducer),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
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
                          return;
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
                          return;
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
                          return;
                        }
                      } catch (e) {
                        print('⚠️ Échec pour ProducerLeisureScreen : $e');
                      }

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun profil disponible.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
    );
  }

  String _getProfileType(bool isUser, bool isProducer, bool isLeisureProducer) {
    if (isUser) return 'Utilisateur';
    if (isProducer) return 'Restaurant';
    if (isLeisureProducer) return 'Loisir';
    return 'Inconnu';
  }

  Color _getProfileTypeColor(bool isUser, bool isProducer, bool isLeisureProducer) {
    if (isUser) return Colors.blue;
    if (isProducer) return Colors.orange;
    if (isLeisureProducer) return Colors.purple;
    return Colors.grey;
  }
}