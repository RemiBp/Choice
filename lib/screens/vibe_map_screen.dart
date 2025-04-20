import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/responsive.dart';
import '../widgets/custom_card.dart';
import '../utils/constants.dart' as constants;
import '../services/ai_service.dart';
import '../screens/eventLeisure_screen.dart';
import '../screens/producerLeisure_screen.dart';
import '../screens/producer_screen.dart';

class VibeMapScreen extends StatefulWidget {
  final String userId;

  const VibeMapScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _VibeMapScreenState createState() => _VibeMapScreenState();
}

class _VibeMapScreenState extends State<VibeMapScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _vibeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final AIService _aiService = AIService();
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic>? _vibeMapData;
  List<dynamic> _extractedProfiles = [];
  
  // Animation controller pour les effets visuels
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Liste de "vibes" prédéfinies pour suggestions rapides
  final List<Map<String, dynamic>> _suggestedVibes = [
    {
      'name': 'Chaleureux et convivial',
      'icon': Icons.local_fire_department,
      'color': Colors.orange,
    },
    {
      'name': 'Romantique et intime',
      'icon': Icons.favorite,
      'color': Colors.pink,
    },
    {
      'name': 'Calme et reposant',
      'icon': Icons.spa,
      'color': Colors.blue,
    },
    {
      'name': 'Énergique et animé',
      'icon': Icons.bolt,
      'color': Colors.purple,
    },
    {
      'name': 'Nostalgique et authentique',
      'icon': Icons.watch_later,
      'color': Colors.brown,
    },
    {
      'name': 'Artistique et créatif',
      'icon': Icons.brush,
      'color': Colors.indigo,
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _vibeController.dispose();
    _locationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateVibeMap() async {
    if (_vibeController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer une ambiance ou émotion';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _vibeMapData = null;
      _extractedProfiles = [];
    });

    try {
      // Appel à l'API de cartographie sensorielle
      final response = await _aiService.generateVibeMap(
        userId: widget.userId,
        vibe: _vibeController.text,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response != null) {
            _vibeMapData = response;
            _extractedProfiles = response['profiles'] ?? [];
            _animationController.reset();
            _animationController.forward();
          } else {
            _errorMessage = 'Erreur lors de la génération de la carte sensorielle';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de connexion: $error';
        });
      }
    }
  }

  void _navigateToEntityDetails(String id, String type) async {
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
            final url = Uri.parse('${constants.getBaseUrl()}/api/leisureProducers/$id');
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
            final url = Uri.parse('${constants.getBaseUrl()}/api/events/$id');
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
      appBar: AppBar(
        title: const Text('Cartographie Sensorielle',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Zone de recherche d'ambiance
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre explicatif
                const Text(
                  "Explorez par sensation & ambiance",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Champ d'ambiance
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _vibeController,
                    decoration: InputDecoration(
                      hintText: 'Une ambiance, une émotion... (ex: "chaleureux et convivial")',
                      prefixIcon: const Icon(Icons.emoji_emotions, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.grey),
                        onPressed: _generateVibeMap,
                      ),
                    ),
                    onSubmitted: (_) => _generateVibeMap(),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Champ de localisation facultatif
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      hintText: 'Lieu (facultatif, ex: "Paris 11")',
                      prefixIcon: Icon(Icons.location_on, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onSubmitted: (_) => _generateVibeMap(),
                  ),
                ),
              ],
            ),
          ),
          
          // Suggestions d'ambiances
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Suggestions d'ambiances",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _suggestedVibes.map((vibe) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: ActionChip(
                          avatar: Icon(
                            vibe['icon'] as IconData,
                            color: vibe['color'] as Color,
                            size: 18,
                          ),
                          label: Text(vibe['name']),
                          backgroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.grey.withOpacity(0.3),
                          onPressed: () {
                            setState(() {
                              _vibeController.text = vibe['name'];
                            });
                            _generateVibeMap();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Message d'erreur
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Indicateur de chargement
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      "Génération de votre carte sensorielle...",
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          
          // Résultats de la cartographie sensorielle
          if (!_isLoading && _vibeMapData != null)
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête avec l'ambiance demandée
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getGradientColorsForVibe(_vibeMapData!),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _vibeMapData!['vibe'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_vibeMapData!['location'] != null)
                                Text(
                                  _vibeMapData!['location'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              const SizedBox(height: 15),
                              if (_vibeMapData!['vibeData']?['keywords'] != null)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (_vibeMapData!['vibeData']['keywords'] as List<dynamic>).map((keyword) {
                                    return Chip(
                                      label: Text(
                                        keyword,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.white.withOpacity(0.3),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Réponse textuelle de l'IA
                        if (_vibeMapData!['response'] != null)
                          _buildRichTextResponse(_vibeMapData!['response']),
                        
                        const SizedBox(height: 20),
                        
                        // Grille de lieux/expériences
                        if (_extractedProfiles.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_extractedProfiles.length} lieux & expériences',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 15),
                              GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemCount: _extractedProfiles.length,
                                itemBuilder: (context, index) {
                                  final profile = _extractedProfiles[index];
                                  return _buildProfileCard(profile);
                                },
                              ),
                            ],
                          ),
                          
                        // Ambiances similaires
                        if (_vibeMapData!['vibeData']?['relatedVibes'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 25),
                              const Text(
                                'Ambiances similaires',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 15),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: (_vibeMapData!['vibeData']['relatedVibes'] as List<dynamic>).map((relatedVibe) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 10.0),
                                      child: ActionChip(
                                        label: Text(relatedVibe),
                                        backgroundColor: Colors.white,
                                        elevation: 2,
                                        shadowColor: Colors.grey.withOpacity(0.3),
                                        onPressed: () {
                                          setState(() {
                                            _vibeController.text = relatedVibe;
                                          });
                                          _generateVibeMap();
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRichTextResponse(String response) {
    // Traitement du texte riche avec liens
    final RegExp linkRegex = RegExp(r'\[([^\]]+)\]\(profile:([^:]+):([^)]+)\)');
    final List<InlineSpan> spans = [];
    int lastIndex = 0;
    
    // Rechercher les correspondances de lien
    for (Match match in linkRegex.allMatches(response)) {
      // Ajouter le texte avant le lien
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: response.substring(lastIndex, match.start),
          style: const TextStyle(fontSize: 16),
        ));
      }
      
      // Ajouter le lien
      final String linkText = match.group(1)!;
      final String linkType = match.group(2)!;
      final String linkId = match.group(3)!;
      
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _navigateToEntityDetails(linkId, linkType),
          child: Text(
            linkText,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ));
      
      lastIndex = match.end;
    }
    
    // Ajouter le reste du texte
    if (lastIndex < response.length) {
      spans.add(TextSpan(
        text: response.substring(lastIndex),
        style: const TextStyle(fontSize: 16),
      ));
    }
    
    return RichText(
      text: TextSpan(
        style: TextStyle(color: Colors.black),
        children: spans,
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final String type = profile['type'] ?? 'unknown';
    final String name = profile['name'] ?? 'Sans nom';
    final String address = type == 'event' 
        ? (profile['location'] ?? 'Lieu non précisé')
        : (profile['address'] ?? 'Adresse non précisée');
    final String imageUrl = profile['image'] ?? '';
    final dynamic rating = profile['rating'];
    
    Color cardColor;
    IconData typeIcon;
    String typeLabel;
    
    switch (type) {
      case 'restaurant':
        cardColor = Colors.orange;
        typeIcon = Icons.restaurant;
        typeLabel = 'Restaurant';
        break;
      case 'leisureProducer':
        cardColor = Colors.purple;
        typeIcon = Icons.local_activity;
        typeLabel = 'Loisir';
        break;
      case 'event':
        cardColor = Colors.green;
        typeIcon = Icons.event;
        typeLabel = 'Événement';
        break;
      default:
        cardColor = Colors.grey;
        typeIcon = Icons.place;
        typeLabel = type;
    }
    
    return GestureDetector(
      onTap: () => _navigateToEntityDetails(profile['id'], type),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image et badge de type
            Stack(
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: imageUrl.isNotEmpty 
                  ? Image.network(
                      imageUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 130,
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(typeIcon, color: Colors.grey[400], size: 40),
                        ),
                      ),
                    )
                  : Container(
                      height: 130,
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(typeIcon, color: Colors.grey[400], size: 40),
                      ),
                    ),
                ),
                
                // Badge de type
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Badge de note si disponible
                if (rating != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '$rating',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Informations textuelles
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Color> _getGradientColorsForVibe(Map<String, dynamic> vibeMapData) {
    // Utiliser le schéma de couleurs fourni par l'API si disponible
    if (vibeMapData['vibeData']?['colorScheme'] != null) {
      final List<dynamic> colors = vibeMapData['vibeData']['colorScheme'];
      if (colors.length >= 2) {
        return colors.map((c) => Color(int.parse('0xFF$c'))).toList();
      }
    }
    
    // Couleurs par défaut basées sur le type d'ambiance
    final String vibe = vibeMapData['vibe'].toLowerCase();
    
    if (vibe.contains('chaleureux') || vibe.contains('convivial')) {
      return [Colors.orange[300]!, Colors.orange[700]!];
    } else if (vibe.contains('romantique') || vibe.contains('intime')) {
      return [Colors.pink[300]!, Colors.pink[700]!];
    } else if (vibe.contains('calme') || vibe.contains('reposant')) {
      return [Colors.blue[300]!, Colors.blue[700]!];
    } else if (vibe.contains('énergique') || vibe.contains('animé')) {
      return [Colors.purple[300]!, Colors.purple[700]!];
    } else if (vibe.contains('nostalgique') || vibe.contains('authentique')) {
      return [Colors.brown[300]!, Colors.brown[700]!];
    } else if (vibe.contains('artistique') || vibe.contains('créatif')) {
      return [Colors.indigo[300]!, Colors.indigo[700]!];
    } else if (vibe.contains('mélancolique') || vibe.contains('poétique')) {
      return [Colors.blueGrey[300]!, Colors.blueGrey[700]!];
    } else {
      // Couleurs par défaut
      return [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)];
    }
  }
}