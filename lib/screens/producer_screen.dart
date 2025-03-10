import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
import 'producerLeisure_screen.dart';
import 'utils.dart';

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

    try {
      print('🔍 Test : appel à /producers/$producerId');
      final baseUrl = getBaseUrl();
      Uri producerUrl;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        producerUrl = Uri.http(domain, '/api/producers/$producerId');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        producerUrl = Uri.https(domain, '/api/producers/$producerId');
      } else {
        producerUrl = Uri.parse('$baseUrl/api/producers/$producerId');
      }
      
      final producerResponse = await http.get(producerUrl);
      print('Réponse pour /producers : ${producerResponse.statusCode}');
      print('Body : ${producerResponse.body}');

      print('🔍 Test : appel à /producers/$producerId/relations');
      Uri relationsUrl;
      
      if (baseUrl.startsWith('http://')) {
        final domain = baseUrl.replaceFirst('http://', '');
        relationsUrl = Uri.http(domain, '/api/producers/$producerId/relations');
      } else if (baseUrl.startsWith('https://')) {
        final domain = baseUrl.replaceFirst('https://', '');
        relationsUrl = Uri.https(domain, '/api/producers/$producerId/relations');
      } else {
        relationsUrl = Uri.parse('$baseUrl/api/producers/$producerId/relations');
      }
      
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
    final baseUrl = getBaseUrl();
    Uri producerUrl;
    Uri relationsUrl;
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      producerUrl = Uri.http(domain, '/api/producers/$producerId');
      relationsUrl = Uri.http(domain, '/api/producers/$producerId/relations');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      producerUrl = Uri.https(domain, '/api/producers/$producerId');
      relationsUrl = Uri.https(domain, '/api/producers/$producerId/relations');
    } else {
      producerUrl = Uri.parse('$baseUrl/api/producers/$producerId');
      relationsUrl = Uri.parse('$baseUrl/api/producers/$producerId/relations');
    }

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
    
    if (baseUrl.startsWith('http://')) {
      final domain = baseUrl.replaceFirst('http://', '');
      userUrl = Uri.http(domain, '/api/users/$id');
      unifiedUrl = Uri.http(domain, '/api/unified/$id');
    } else if (baseUrl.startsWith('https://')) {
      final domain = baseUrl.replaceFirst('https://', '');
      userUrl = Uri.https(domain, '/api/users/$id');
      unifiedUrl = Uri.https(domain, '/api/unified/$id');
    } else {
      userUrl = Uri.parse('$baseUrl/api/users/$id');
      unifiedUrl = Uri.parse('$baseUrl/api/unified/$id');
    }
    
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
    final followersCount = (data['followers'] is Map && data['followers']?['count'] != null) 
        ? int.tryParse(data['followers']?['count']?.toString() ?? '0') ?? 0 
        : 0;
    final followingCount = (data['following'] is Map && data['following']?['count'] != null)
        ? int.tryParse(data['following']?['count']?.toString() ?? '0') ?? 0
        : 0;
    final interestedCount = (data['interestedUsers'] is Map && data['interestedUsers']?['count'] != null)
        ? int.tryParse(data['interestedUsers']?['count']?.toString() ?? '0') ?? 0
        : 0;
    final choicesCount = (data['choiceUsers'] is Map && data['choiceUsers']?['count'] != null)
        ? int.tryParse(data['choiceUsers']?['count']?.toString() ?? '0') ?? 0
        : 0;

    void _navigateToRelationDetails(String title, dynamic ids) async {
      if (ids is! List) {
        print('❌ Les IDs ne sont pas une liste valide.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : Les IDs ne sont pas valides.')),
        );
        return;
      }

      final List<String> validIds = [];
      for (var id in ids) {
        if (id != null) {
          validIds.add(id.toString());
        }
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
    
    return Card(
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
                final users = data['followers']?['users'] as List<dynamic>? ?? [];
                _navigateToRelationDetails('Followers', users);
              },
            ),
            _buildVerticalDivider(),
            _buildStatisticItem(
              title: 'Following',
              count: followingCount,
              icon: Icons.person_add,
              color: Colors.purple,
              onTap: () {
                final users = data['following']?['users'] as List<dynamic>? ?? [];
                _navigateToRelationDetails('Following', users);
              },
            ),
            _buildVerticalDivider(),
            _buildStatisticItem(
              title: 'Interested',
              count: interestedCount,
              icon: Icons.emoji_objects,
              color: Colors.orange,
              onTap: () {
                final users = data['interestedUsers']?['users'] as List<dynamic>? ?? [];
                _navigateToRelationDetails('Interested', users);
              },
            ),
            _buildVerticalDivider(),
            _buildStatisticItem(
              title: 'Choices',
              count: choicesCount,
              icon: Icons.check_circle,
              color: Colors.green,
              onTap: () {
                final users = data['choiceUsers']?['users'] as List<dynamic>? ?? [];
                _navigateToRelationDetails('Choices', users);
              },
            ),
          ],
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
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

  Widget _buildHeader(Map<String, dynamic> data) {
    final String photoUrl = data['photo'] ?? 'https://via.placeholder.com/100';
    final String name = data['name'] ?? 'Nom non spécifié';
    final String description = data['description'] ?? 'Description non spécifiée';
    final double rating = double.tryParse(data['rating']?.toString() ?? '0') ?? 0;

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

  Widget _buildFrequencyGraph(Map<String, dynamic> producer) {
    try {
      final popularTimes = producer['popular_times'];
      if (popularTimes == null) {
        print('❌ popular_times est null dans les données du producteur');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Données de fréquentation non disponibles.',
        );
      }

      if (!(popularTimes is List) && !(popularTimes is Map)) {
        print('❌ popular_times n\'est ni une liste ni un Map: ${popularTimes.runtimeType}');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Format de données de fréquentation non supporté.',
        );
      }

      if ((popularTimes is List && popularTimes.isEmpty) ||
          (popularTimes is Map && popularTimes.isEmpty)) {
        print('❌ popular_times est vide');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Aucune donnée de fréquentation disponible.',
        );
      }

      int size = popularTimes is List 
          ? popularTimes.length 
          : popularTimes.keys.length;

      if (_selectedDay >= size) {
        print('❌ _selectedDay ($_selectedDay) hors limites, remise à 0');
        _selectedDay = 0;
      }

      var selectedDayData;
      if (popularTimes is List && popularTimes.isNotEmpty) {
        if (_selectedDay < popularTimes.length) {
          selectedDayData = popularTimes[_selectedDay];
        }
      } else if (popularTimes is Map && popularTimes.isNotEmpty) {
        String selectedDayKey = _selectedDay.toString();
        if (popularTimes.containsKey(selectedDayKey)) {
          selectedDayData = popularTimes[selectedDayKey];
        } else {
          var matchingKey = popularTimes.keys.firstWhere(
            (key) => key.toString() == _selectedDay.toString(),
            orElse: () => popularTimes.keys.first.toString()
          );
          selectedDayData = popularTimes[matchingKey];
        }
      }

      if (selectedDayData == null) {
        print('❌ selectedDayData est null');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Données du jour sélectionné non disponibles.',
        );
      }
      
      var data = selectedDayData['data'];
      if (data == null) {
        print('❌ data est null dans selectedDayData');
        return _buildInfoCard(
          'Tendances de fréquentation',
          Icons.trending_up,
          Colors.blue,
          'Données de fréquentation pour le jour sélectionné non disponibles.',
        );
      }

      List<int> filteredTimes = [];
      if (data is List) {
        try {
          filteredTimes = data.map<int>((item) {
            if (item is int) return item;
            if (item is String) return int.tryParse(item) ?? 0;
            if (item is double) return item.toInt();
            return 0;
          }).toList();
          
          if (filteredTimes.length >= 24) {
            filteredTimes = filteredTimes.sublist(8, 24);
          }
        } catch (e) {
          print('❌ Erreur lors de la conversion des données: $e');
          filteredTimes = List.filled(16, 0);
        }
      } else {
        print('❌ data n\'est pas une liste: ${data.runtimeType}');
        filteredTimes = List.filled(16, 0);
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
                  value: _selectedDay,
                  isExpanded: true,
                  hint: const Text('Sélectionnez un jour'),
                  underline: Container(), // Supprime la ligne par défaut
                  items: List.generate(
                    size, 
                    (index) {
                    var dayData;
                    try {
                      if (popularTimes is List) {
                        dayData = popularTimes[index];
                      } else if (popularTimes is Map) {
                        final key = index.toString();
                        if (popularTimes.containsKey(key)) {
                          dayData = popularTimes[key];
                        } else {
                          var keys = popularTimes.keys.toList();
                          if (index < keys.length) {
                            dayData = popularTimes[keys[index]];
                          }
                        }
                      }
                    } catch (e) {
                      print('❌ Erreur lors de l\'accès à l\'élément $index: $e');
                      dayData = null;
                    }
                    
                    String dayName = 'Jour ${index + 1}';
                    if (dayData != null && dayData['name'] != null) {
                      dayName = dayData['name'].toString();
                    }
                    
                    return DropdownMenuItem(
                      value: index,
                      child: Text(dayName),
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

  Widget _buildFilterOptions() {
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
                  child: const Icon(Icons.filter_list, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filtres Avancés',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Rating filter with range slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Évaluation: ${_ratingRange.start.toStringAsFixed(1)} - ${_ratingRange.end.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    trackHeight: 4,
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
            
            const Divider(height: 24),
            
            // Calories filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Calories max: $_selectedMaxCalories',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    trackHeight: 4,
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
            
            const Divider(height: 24),
            
            // Carbon footprint filter
            Row(
              children: [
                const Icon(Icons.eco, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Bilan Carbone:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCarbon,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Nutri-score filter
            Row(
              children: [
                const Icon(Icons.health_and_safety, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Nutri-Score:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedNutriScore,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Additional toggle filters
            Column(
              children: [
                _buildSwitchOption(
                  'Produits locaux uniquement',
                  Icons.location_on,
                  Colors.indigo,
                  _showLocalProducts,
                  (value) => setState(() => _showLocalProducts = value),
                ),
                _buildSwitchOption(
                  'Produits Bio uniquement',
                  Icons.eco_outlined,
                  Colors.green,
                  _showOrganicOnly,
                  (value) => setState(() => _showOrganicOnly = value),
                ),
                _buildSwitchOption(
                  'Options végétariennes',
                  Icons.grass,
                  Colors.lightGreen,
                  _showVegetarianOptions,
                  (value) => setState(() => _showVegetarianOptions = value),
                ),
              ],
            ),
          ],
        ),
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
                  child: GoogleMap(
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
              height: 600, // Taille fixe pour éviter les problèmes de défilement
              child: TabBarView(
                children: [
                  SingleChildScrollView(child: _buildMenuDetails(producer)),
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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Fonctionnalité de partage
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partage du profil producteur')),
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
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur : ${snapshot.error}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _producerFuture = _fetchProducerDetails(widget.producerId);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                    ),
                    child: const Text('Réessayer'),
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
                    _buildFilterOptions(),
                    _buildFilteredItems(producer),
                    _buildTabs(producer),
                    _buildMap(producer['gps_coordinates']),
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