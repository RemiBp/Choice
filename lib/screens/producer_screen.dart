import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // Pour les graphiques
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
import 'producerLeisure_screen.dart';
import 'utils.dart';

class ProducerScreen extends StatefulWidget {
  final String producerId;
  final String? userId; // Rendez ce champ optionnel (nullable)

  const ProducerScreen({Key? key, required this.producerId, this.userId}) : super(key: key);

  @override
  State<ProducerScreen> createState() => _ProducerScreenState();
}

class _ProducerScreenState extends State<ProducerScreen> {
  late Future<Map<String, dynamic>> _producerFuture;
  int _selectedDay = 0; // Pour les horaires populaires
  String _selectedCarbon = "<3kg";
  String _selectedNutriScore = "A-C";
  double _selectedMaxCalories = 500;

  @override
  void initState() {
    super.initState();
    print('🔍 Initialisation du test des API');
    _testApi(); // Appel à la méthode de test
    _producerFuture = _fetchProducerDetails(widget.producerId);
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
    // Afficher l'indicateur de chargement
    setState(() {
      post['isLoading'] = true;
    });

    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/interested');
    
    // Format de données attendu par le backend - simplifié pour correspondre à l'API
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
        
        // Feedback à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedInterested ? 'Ajouté à vos intérêts' : 'Retiré de vos intérêts'),
            backgroundColor: updatedInterested ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Mettre à jour le profil utilisateur pour refléter le changement
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
    // Afficher l'indicateur de chargement
    setState(() {
      post['isLoading'] = true;
    });
    
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/choice');
    
    // Format de données attendu par le backend - simplifié pour correspondre à l'API
    final body = {
      'userId': widget.userId,
      'targetId': targetId,
      // Optionnel: ajout d'un commentaire si nécessaire
      // 'comment': 'Ajouté depuis la page producteur'
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
        
        // Feedback à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedChoice ? 'Ajouté à vos choix' : 'Retiré de vos choix'),
            backgroundColor: updatedChoice ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Mettre à jour le profil utilisateur pour refléter le changement
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

  /// Mettre à jour le profil utilisateur après un changement d'interest/choice
  Future<void> _updateUserProfile() async {
    if (widget.userId == null) {
      print('⚠️ Impossible de mettre à jour le profil : userId est null');
      return;
    }
    
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users/${widget.userId}');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        print('✅ Profil utilisateur mis à jour avec succès');
        print('📋 Intérêts: ${userData['interests']?.length ?? 0}');
        print('📋 Choices: ${userData['choices']?.length ?? 0}');
        
        // On pourrait stocker ces données dans un état global si nécessaire
      } else {
        print('❌ Erreur lors de la mise à jour du profil : ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de la mise à jour du profil : $e');
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

  void _navigateToPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProducerPostDetailScreen(
          post: post, // Passez les données du post directement
          userId: widget.userId, // Utilisez le userId pour les actions
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

      // Convertir manuellement chaque ID en String au lieu d'utiliser cast<String>()
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              final users = data['followers']?['users'] as List<dynamic>? ?? [];
              _navigateToRelationDetails('Followers', users);
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
              _navigateToRelationDetails('Following', users);
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
              _navigateToRelationDetails('Interested', users);
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
              _navigateToRelationDetails('Choices', users);
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

  Widget _buildHeader(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(
              data['photo'] ?? 'https://via.placeholder.com/100',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Nom non spécifié',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  'Note moyenne : ${data['rating'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  data['description'] ?? 'Description non spécifiée',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyGraph(Map<String, dynamic> producer) {
    try {
      // Vérification de l'existence des données de fréquentation
      final popularTimes = producer['popular_times'];
      if (popularTimes == null) {
        print('❌ popular_times est null dans les données du producteur');
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Données de fréquentation non disponibles.'),
        );
      }

      // Vérification du type de popular_times
      if (!(popularTimes is List) && !(popularTimes is Map)) {
        print('❌ popular_times n\'est ni une liste ni un Map: ${popularTimes.runtimeType}');
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Format de données de fréquentation non supporté.'),
        );
      }

      // Si la liste est vide
      if ((popularTimes is List && popularTimes.isEmpty) ||
          (popularTimes is Map && popularTimes.isEmpty)) {
        print('❌ popular_times est vide');
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Aucune donnée de fréquentation disponible.'),
        );
      }

      // Déterminer la taille
      int size = popularTimes is List 
          ? popularTimes.length 
          : popularTimes.keys.length;

      // Sécurité pour l'index sélectionné
      if (_selectedDay >= size) {
        print('❌ _selectedDay ($_selectedDay) hors limites, remise à 0');
        _selectedDay = 0;
      }

      // Extraire les données du jour sélectionné
      var selectedDayData;
      if (popularTimes is List && popularTimes.isNotEmpty) {
        if (_selectedDay < popularTimes.length) {
          selectedDayData = popularTimes[_selectedDay];
        }
      } else if (popularTimes is Map && popularTimes.isNotEmpty) {
        // Chercher par clé string
        String selectedDayKey = _selectedDay.toString();
        if (popularTimes.containsKey(selectedDayKey)) {
          selectedDayData = popularTimes[selectedDayKey];
        } else {
          // Essayer de trouver une clé contenant la valeur comme chaîne
          var matchingKey = popularTimes.keys.firstWhere(
            (key) => key.toString() == _selectedDay.toString(),
            orElse: () => popularTimes.keys.first.toString()
          );
          selectedDayData = popularTimes[matchingKey];
        }
      }

      // Vérification des données du jour
      if (selectedDayData == null) {
        print('❌ selectedDayData est null');
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Données du jour sélectionné non disponibles.'),
        );
      }
      
      // Extraction des données de fréquentation
      var data = selectedDayData['data'];
      if (data == null) {
        print('❌ data est null dans selectedDayData');
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Données de fréquentation pour le jour sélectionné non disponibles.'),
        );
      }

      // Conversion et filtrage des données
      List<int> filteredTimes = [];
      if (data is List) {
        try {
          // Essayer de convertir en List<int>
          filteredTimes = data.map<int>((item) {
            if (item is int) return item;
            if (item is String) return int.tryParse(item) ?? 0;
            if (item is double) return item.toInt();
            return 0; // Valeur par défaut
          }).toList();
          
          // Sous-ensemble des données pour les heures 8h-minuit
          if (filteredTimes.length >= 24) {
            filteredTimes = filteredTimes.sublist(8, 24);
          }
        } catch (e) {
          print('❌ Erreur lors de la conversion des données: $e');
          filteredTimes = List.filled(16, 0); // 16 heures de données vides
        }
      } else {
        print('❌ data n\'est pas une liste: ${data.runtimeType}');
        filteredTimes = List.filled(16, 0); // 16 heures de données vides
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Fréquentation (8h - Minuit)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<int>(
              value: _selectedDay,
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
                        // Fallback
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
                          width: 12,
                          color: Colors.orange,
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
                          return Text('$hour h');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      print('❌ Erreur inattendue dans _buildFrequencyGraph: $e');
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Erreur lors de l\'affichage des données de fréquentation: $e'),
      );
    }
  }

  Widget _buildFilterOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtres',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedCarbon,
            items: const [
              DropdownMenuItem(value: "<3kg", child: Text("Bilan Carbone : <3kg")),
              DropdownMenuItem(value: "<5kg", child: Text("Bilan Carbone : <5kg")),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCarbon = value!;
              });
            },
          ),
          DropdownButton<String>(
            value: _selectedNutriScore,
            items: const [
              DropdownMenuItem(value: "A-C", child: Text("NutriScore : A-C")),
              DropdownMenuItem(value: "A-B", child: Text("NutriScore : A-B")),
            ],
            onChanged: (value) {
              setState(() {
                _selectedNutriScore = value!;
              });
            },
          ),
          Slider(
            value: _selectedMaxCalories,
            min: 100,
            max: 1000,
            divisions: 9,
            label: "Calories: $_selectedMaxCalories",
            onChanged: (value) {
              setState(() {
                _selectedMaxCalories = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredItems(Map<String, dynamic> producer) {
    final items = producer['structured_data']?['Items Indépendants'] ?? [];
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

  Widget _buildMenuDetails(Map<String, dynamic> producer) {
    final menus = producer['structured_data']?['Menus Globaux'] ?? [];
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
      future: _fetchProducerPosts(widget.producerId),
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
                            post['interested']?.contains(widget.userId) ?? false
                                ? Icons.emoji_objects
                                : Icons.emoji_objects_outlined,
                            color: post['interested']?.contains(widget.userId) ?? false
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
                            post['choices']?.contains(widget.userId) ?? false
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: post['choices']?.contains(widget.userId) ?? false
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

  Widget _buildMap(Map<String, dynamic>? coordinates) {
    if (coordinates == null || coordinates['coordinates'] == null) {
      return const Text('Coordonnées GPS non disponibles.');
    }

    final latLng = LatLng(
      coordinates['coordinates'][1],
      coordinates['coordinates'][0],
    );

    return SizedBox(
      height: 200,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
        markers: {Marker(markerId: MarkerId('producer'), position: latLng)},
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail Producteur'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Désactiver le clavier si nécessaire
        child: FutureBuilder<Map<String, dynamic>>(
          future: _producerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }

            final producer = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
    // Afficher un indicateur de chargement
    setState(() {
      post['isLoading'] = true;
    });
    
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/interested');
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
          interestedCount = updatedInterested.length; // Mise à jour du compteur
          post['isLoading'] = false;
        });
        
        // Feedback utilisateur
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
    // Afficher un indicateur de chargement
    setState(() {
      post['isLoading'] = true;
    });
    
    final url = Uri.parse('${getBaseUrl()}/api/choicexinterest/choice');
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
          choicesCount = updatedChoices.length; // Mise à jour du compteur
          post['isLoading'] = false;
        });
        
        // Feedback utilisateur
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
  
  // Mettre à jour le profil utilisateur
  Future<void> _updateUserProfile() async {
    if (widget.userId == null) return;
    
    try {
      final url = Uri.parse('${getBaseUrl()}/api/users/${widget.userId}');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        print('✅ Profil utilisateur mis à jour avec succès');
      }
    } catch (e) {
      print('❌ Erreur réseau lors de la mise à jour du profil : $e');
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

              // Boutons d'actions avec indicateurs de chargement
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Interested Button
                  Column(
                    children: [
                      post['isLoading'] == true
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            post['interested']?.contains(widget.userId) ?? false
                                ? Icons.emoji_objects
                                : Icons.emoji_objects_outlined,
                            color: post['interested']?.contains(widget.userId) ?? false
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          onPressed: () {
                            if (producerId != null) {
                              _markInterested(producerId);
                              // Appeler updateUserProfile pour synchroniser les données
                              _updateUserProfile();
                            }
                          },
                        ),
                      Text('$interestedCount Intéressé${interestedCount > 1 ? 's' : ''}'),
                    ],
                  ),

                  // Choice Button
                  Column(
                    children: [
                      post['isLoading'] == true
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            post['choices']?.contains(widget.userId) ?? false
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: post['choices']?.contains(widget.userId) ?? false
                                ? Colors.green
                                : Colors.grey,
                          ),
                          onPressed: () {
                            if (producerId != null) {
                              _markChoice(producerId);
                              // Appeler updateUserProfile pour synchroniser les données
                              _updateUserProfile();
                            }
                          },
                        ),
                      Text('$choicesCount Choix'),
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

// Écran pour afficher les relations (followers, following, etc.)
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