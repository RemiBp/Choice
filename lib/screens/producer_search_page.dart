import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'utils.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'profile_screen.dart'; // Pour les utilisateurs

class ProducerSearchPage extends StatefulWidget {
  final String userId;

  const ProducerSearchPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProducerSearchPageState createState() => _ProducerSearchPageState();
}

class _ProducerSearchPageState extends State<ProducerSearchPage> {
  List<dynamic> _searchResults = [];
  String _query = "";
  bool _isLoading = false;
  String _errorMessage = "";
  final TextEditingController _searchController = TextEditingController();

  // Ces listes seraient normalement remplies par des appels backend
  // Pour l'instant on utilise des données statiques pour l'affichage
  final List<Map<String, dynamic>> _trendingNow = [
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
    {
      'id': '3',
      'type': 'leisureProducer',
      'name': 'Escape Game "Mystery Room"',
      'image': 'https://images.unsplash.com/photo-1517263904808-5dc91e3e7044?w=500&q=80',
      'rating': 4.7,
      'category': 'Divertissement'
    },
  ];
  
  final List<Map<String, dynamic>> _popularNearby = [
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
    {
      'id': '6',
      'type': 'event',
      'name': 'Exposition Picasso',
      'image': 'https://images.unsplash.com/photo-1531058020387-3be344556be6?w=500&q=80',
      'rating': 4.9,
      'category': 'Art'
    },
  ];
  
  final List<Map<String, dynamic>> _bestFriendsExperiences = [
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
  ];
  
  final List<Map<String, dynamic>> _innovative = [
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
  
  final List<Map<String, dynamic>> _surprise = [
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

  /// Recherche des producteurs, événements et utilisateurs
  Future<void> _searchItems() async {
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
      final url = Uri.parse('${getBaseUrl()}/api/unified/search?query=$_query');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("La requête a pris trop de temps. Veuillez réessayer.");
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        setState(() {
          _searchResults = results;
          if (_searchResults.isEmpty) {
            _errorMessage = "Aucun résultat trouvé pour cette recherche.";
          }
        });
      } else {
        setState(() {
          _errorMessage = "Erreur lors de la récupération des résultats : ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur réseau : $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToDetails(String id, String type) async {
    try {
      switch (type) {
        case 'restaurant':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId,
              ),
            ),
          );
          break;
        case 'leisureProducer':
          // Afficher un indicateur de chargement
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
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
          
          try {
            final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
            final response = await http.get(url);
            
            // Fermer l'indicateur de chargement
            Navigator.of(context).pop();
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProducerLeisureScreen(producerData: data),
                ),
              );
            } else {
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            // Fermer l'indicateur de chargement s'il est encore ouvert
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            
            // Afficher un message d'erreur
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Erreur lors du chargement: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        case 'event':
          // Afficher un indicateur de chargement
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
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
          
          try {
            final url = Uri.parse('${getBaseUrl()}/api/events/$id');
            final response = await http.get(url);
            
            // Fermer l'indicateur de chargement
            Navigator.of(context).pop();
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventLeisureScreen(eventData: data),
                ),
              );
            } else {
              throw Exception("Erreur ${response.statusCode}: ${response.body}");
            }
          } catch (e) {
            // Fermer l'indicateur de chargement s'il est encore ouvert
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            
            // Afficher un message d'erreur
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Erreur lors du chargement: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        case 'user':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: id),
            ),
          );
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Type non reconnu: $type"),
              backgroundColor: Colors.orange,
            ),
          );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur de navigation: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Barre de recherche stylisée
            Padding(
              padding: const EdgeInsets.all(16.0),
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
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher restaurants, activités...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
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
                    : _buildTrendingSections(),
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
          id: item['_id'],
          type: type,
          title: item['intitulé'] ?? item['name'] ?? 'Nom non spécifié',
          subtitle: item['adresse'] ?? item['address'] ?? item['lieu'] ?? 'Adresse non spécifiée',
          imageUrl: item['image'] ?? item['photo'] ?? item['photo_url'] ?? '',
          rating: item['rating'] ?? item['note'],
          category: item['catégorie'] ?? item['category'],
        );
      },
    );
  }

  Widget _buildTrendingSections() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tendances du moment
          _buildTrendingSection(
            'Tendances du moment', 
            _trendingNow, 
            Colors.purple.shade800,
            Icons.trending_up,
          ),
          
          // Le plus populaire autour de vous
          _buildTrendingSection(
            'Le plus populaire autour de vous', 
            _popularNearby, 
            Colors.blue.shade700,
            Icons.place,
          ),
          
          // Les meilleures expériences de vos proches
          _buildTrendingSection(
            'Les meilleures expériences de vos proches', 
            _bestFriendsExperiences, 
            Colors.teal.shade700,
            Icons.people,
          ),
          
          // Tenter quelque chose d'improbable, novateur
          _buildTrendingSection(
            'Tenter quelque chose d\'improbable, novateur', 
            _innovative, 
            Colors.amber.shade800,
            Icons.lightbulb,
          ),
          
          // Laissez-vous surprendre
          _buildTrendingSection(
            'Laissez-vous surprendre', 
            _surprise, 
            Colors.pink.shade700,
            Icons.auto_awesome,
          ),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(String title, List<Map<String, dynamic>> items, Color accentColor, IconData icon) {
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
        
        // Grille horizontale
        SizedBox(
          height: 190,
          child: ListView.builder(
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
                rating: item['rating'],
                category: item['category'],
                accentColor: accentColor,
              );
            },
          ),
        ),
      ],
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
                  child: const Center(child: CircularProgressIndicator()),
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
                  
                  // Note et type
                  Row(
                    children: [
                      // Note avec étoile
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              rating.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Badge type
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTypeLabel(type),
                          style: TextStyle(
                            fontSize: 10,
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
                  : 'https://via.placeholder.com/100',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  width: 100,
                  height: 100,
                  child: const Center(child: CircularProgressIndicator()),
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
                        if (rating != null) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating is double 
                              ? rating.toStringAsFixed(1) 
                              : rating.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        
                        // Catégorie si disponible
                        if (category != null && category.toString().isNotEmpty)
                          Flexible(
                            child: Text(
                              category.toString(),
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
}