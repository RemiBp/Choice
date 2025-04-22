import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';
import '../utils/constants.dart' as constants;
import '../widgets/rating_slider.dart';
import '../widgets/emotion_selector.dart';
import '../widgets/location_search.dart';
import 'dart:convert';
import 'package:flutter/rendering.dart';

class ChoiceCreationScreen extends StatefulWidget {
  final String userId;

  const ChoiceCreationScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChoiceCreationScreen> createState() => _ChoiceCreationScreenState();
}

class _ChoiceCreationScreenState extends State<ChoiceCreationScreen> {
  // Force à vide pour commencer par la sélection du type
  String _selectedType = '';
  Map<String, dynamic>? _selectedLocation;
  final Map<String, double> _ratings = {};
  final List<String> _selectedEmotions = [];
  final List<String> _menuItems = [];
  final TextEditingController _commentController = TextEditingController();
  bool _createPost = false;
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _isVerified = false;

  // Restaurant rating aspects
  final Map<String, String> _restaurantAspects = {
    'service': 'Service',
    'lieu': 'Lieu',
    'portions': 'Portions',
    'ambiance': 'Ambiance',
  };
  
  // Wellness rating aspects
  final Map<String, String> _wellnessAspects = {
    'ambiance': 'Ambiance',
    'service': 'Service',
    'proprete': 'Propreté',
    'expertise': 'Expertise',
  };

  // Event rating aspects based on category
  final Map<String, Map<String, List<String>>> _eventCategories = {
    'Théâtre': {
      'aspects': ['mise en scène', 'jeu des acteurs', 'texte', 'scénographie'],
      'emotions': ['intense', 'émouvant', 'captivant', 'enrichissant', 'profond'],
    },
    'Comédie': {
      'aspects': ['humour', 'jeu des acteurs', 'rythme', 'dialogue'],
      'emotions': ['drôle', 'amusant', 'divertissant', 'léger', 'enjoué'],
    },
    // Add other categories as needed
  };
  
  // Wellness emotions
  final List<String> _wellnessEmotions = [
    'relaxant', 'apaisant', 'énergisant', 'revitalisant', 'ressourçant', 'rajeunissant'
  ];

  @override
  void initState() {
    super.initState();
    _initializeRatings();
    
    // S'assurer que l'état est bien réinitialisé au démarrage
    _resetSelection();
  }
  
  // Fonction pour réinitialiser la sélection et revenir au choix du type
  void _resetSelection() {
    setState(() {
      _selectedType = '';
      _selectedLocation = null;
      _isVerified = false;
      _isVerifying = false;
      _createPost = false;
      _commentController.clear();
      _selectedEmotions.clear();
      _menuItems.clear();
      _initializeRatings(); // Réinitialiser les notes
    });
  }

  void _initializeRatings() {
    // Vider les anciennes notes
    _ratings.clear();
    
    // Initialize with default ratings
    _restaurantAspects.forEach((key, _) {
      _ratings[key] = 5.0;
    });
    
    _wellnessAspects.forEach((key, _) {
      _ratings[key] = 5.0;
    });
  }

  Future<void> _verifyLocation() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isVerifying = true;
      _isVerified = false;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/choices/verify');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'locationId': _selectedLocation!['_id'],
          'locationType': _selectedType,
          // Add additional location data to help with verification
          'location': _selectedLocation!['gps_coordinates'],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isVerified = data['verified'] ?? false;
          _isVerifying = false;
        });

        if (!_isVerified) {
          _showVerificationError(data['message'] ?? 'Vérification échouée');
        }
      } else {
        throw Exception('Verification failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error verifying location: $e');
      setState(() {
        _isVerifying = false;
        _isVerified = false;
      });
      _showVerificationError('Erreur lors de la vérification: $e');
    }
  }

  void _showVerificationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _submitChoice() async {
    if (!_isVerified || _selectedLocation == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/choices');
      final Map<String, dynamic> choiceData = {
        'userId': widget.userId,
        'locationId': _selectedLocation!['_id'],
        'locationType': _selectedType,
        'ratings': _ratings,
        'createPost': _createPost,
      };

      if (_selectedType == 'restaurant') {
        choiceData['menuItems'] = _menuItems;
      } else if (_selectedType == 'event') {
        choiceData['emotions'] = _selectedEmotions;
      } else if (_selectedType == 'wellness') {
        choiceData['emotions'] = _selectedEmotions;
      }

      if (_commentController.text.isNotEmpty) {
        choiceData['comment'] = _commentController.text;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(choiceData),
      );

      if (response.statusCode == 201) {
        // If post creation was requested and we have a comment, make sure it was created
        if (_createPost && _commentController.text.isNotEmpty) {
          // Optionally check post creation status here if needed
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Choice créé avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create choice');
      }
    } catch (e) {
      print('Error creating choice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Choice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedType.isNotEmpty && _selectedLocation == null) {
              // Si un type est sélectionné mais pas de lieu, revenir à la sélection du type
              _resetSelection();
            } else {
              // Sinon, fermer l'écran
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_selectedType.isNotEmpty && _selectedLocation != null && !_isVerified)
            TextButton.icon(
              icon: const Icon(Icons.restore, color: Colors.white),
              label: const Text(
                'CHANGER TYPE',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _resetSelection,
            ),
          if (_isVerified && !_isLoading)
            TextButton.icon(
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'VALIDER',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _submitChoice,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selection
            if (_selectedType.isEmpty) ...[
              const Text(
                'Que souhaitez-vous partager ?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildTypeSelectionCards(),
            ] else ...[
              // Location search
              if (_selectedLocation == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedType == 'restaurant'
                          ? 'Restaurant'
                          : _selectedType == 'event'
                              ? 'Événement'
                              : 'Bien-être',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('CHANGER'),
                      onPressed: _resetSelection,
                    ),
                  ],
                ),
                const Divider(),
                _buildLocationSearch(),
              ] else ...[
                // Location verification
                if (!_isVerified) ...[
                  _buildVerificationSection(),
                ] else ...[
                  // Rating section
                  _buildRatingSection(),
                  
                  // Post creation option
                  _buildPostCreationSection(),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelectionCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                'restaurant',
                'Restaurant',
                Icons.restaurant,
                Colors.amber,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTypeCard(
                'event',
                'Événement',
                Icons.event,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                'wellness',
                'Bien-être',
                Icons.spa,
                Colors.purple,
              ),
            ),
            const Expanded(child: SizedBox()), // Espace vide pour équilibrer
          ],
        ),
      ],
    );
  }

  Widget _buildTypeCard(
    String type,
    String title,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedType == 'restaurant'
              ? 'Rechercher un restaurant'
              : _selectedType == 'event'
                  ? 'Rechercher un événement'
                  : 'Rechercher un établissement de bien-être',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LocationSearch(
          type: _selectedType,
          onLocationSelected: (location) {
            setState(() {
              _selectedLocation = location;
            });
            _verifyLocation();
          },
        ),
      ],
    );
  }

  Widget _buildVerificationSection() {
    Color themeColor = _selectedType == 'restaurant'
        ? Colors.amber
        : _selectedType == 'event'
            ? Colors.green
            : Colors.purple;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeColor.withOpacity(0.2),
            themeColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: _isVerifying 
            ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
            : ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: themeColor.withOpacity(0.8),
                      child: Icon(
                        _selectedType == 'restaurant'
                            ? Icons.restaurant
                            : _selectedType == 'event'
                                ? Icons.event
                                : Icons.spa,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLocation!['name'] ?? 'Lieu sélectionné',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedLocation!['address'] != null) 
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                _selectedLocation!['address'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_isVerifying)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Vérification de votre visite...'),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: const Text('VÉRIFIER MA VISITE', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _verifyLocation,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: themeColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: themeColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'Comment ça marche ?',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nous vérifions que vous avez passé au moins 30 minutes sur place dans les 7 derniers jours.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const Divider(height: 16),
                            Text(
                              'Mode démo : vérification automatique activée',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Votre ressenti',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedType == 'restaurant')
          _buildRestaurantRatings()
        else if (_selectedType == 'event')
          _buildEventRatings()
        else if (_selectedType == 'wellness')
          _buildWellnessRatings(),
      ],
    );
  }

  Widget _buildRestaurantRatings() {
    return Column(
      children: [
        // Rating sliders
        ..._restaurantAspects.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RatingSlider(
              label: entry.value,
              value: _ratings[entry.key] ?? 5.0,
              onChanged: (value) {
                setState(() {
                  _ratings[entry.key] = value;
                });
              },
            ),
          );
        }),

        // Menu items
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_menu, color: Colors.amber),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Plats consommés',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Fetch and display menu items from producer
                FutureBuilder<List<String>>(
                  future: _getRestaurantMenuItems(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Text(
                        'Erreur de chargement des plats',
                        style: TextStyle(color: Colors.red[300]),
                      );
                    }
                    
                    final availableItems = snapshot.data ?? [];
                    
                    if (availableItems.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.no_food, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text(
                              'Aucun plat disponible',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomItemInputField(
                                    onItemAdded: (item) {
                                      setState(() {
                                        _menuItems.add(item);
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
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sélectionnez les plats que vous avez goûtés :',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableItems.map((item) {
                            final isSelected = _menuItems.contains(item);
                            return FilterChip(
                              label: Text(item),
                              selected: isSelected,
                              selectedColor: Colors.amber.withOpacity(0.2),
                              checkmarkColor: Colors.amber,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _menuItems.add(item);
                                  } else {
                                    _menuItems.remove(item);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Ajouter un plat non listé :',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomItemInputField(
                          onItemAdded: (item) {
                            setState(() {
                              _menuItems.add(item);
                            });
                          },
                        ),
                        if (_menuItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Plats sélectionnés :',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _menuItems.map((item) {
                              return Chip(
                                label: Text(item),
                                onDeleted: () {
                                  setState(() {
                                    _menuItems.remove(item);
                                  });
                                },
                                backgroundColor: Colors.amber.withOpacity(0.1),
                                deleteIconColor: Colors.amber,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWellnessRatings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating sliders
        ..._wellnessAspects.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RatingSlider(
              label: entry.value,
              value: _ratings[entry.key] ?? 5.0,
              onChanged: (value) {
                setState(() {
                  _ratings[entry.key] = value;
                });
              },
            ),
          );
        }),

        // Emotion selection
        const SizedBox(height: 20),
        const Text(
          'Sensations ressenties',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        EmotionSelector(
          emotions: _wellnessEmotions,
          selectedEmotions: _selectedEmotions,
          onEmotionToggled: (emotion) {
            setState(() {
              if (_selectedEmotions.contains(emotion)) {
                _selectedEmotions.remove(emotion);
              } else {
                _selectedEmotions.add(emotion);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildEventRatings() {
    final category = _selectedLocation?['category'] ?? 'Default';
    final aspects = _eventCategories[category]?['aspects'] ??
        ['qualité générale', 'intérêt', 'originalité'];
    final emotions = _eventCategories[category]?['emotions'] ??
        ['agréable', 'intéressant', 'divertissant', 'satisfaisant'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating sliders
        ...aspects.map((aspect) {
          final formattedAspect = aspect
              .split(' ')
              .map((word) => word[0].toUpperCase() + word.substring(1))
              .join(' ');

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RatingSlider(
              label: formattedAspect,
              value: _ratings[aspect] ?? 5.0,
              onChanged: (value) {
                setState(() {
                  _ratings[aspect] = value;
                });
              },
            ),
          );
        }),

        // Emotion selection
        const SizedBox(height: 20),
        const Text(
          'Émotions ressenties',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        EmotionSelector(
          emotions: emotions,
          selectedEmotions: _selectedEmotions,
          onEmotionToggled: (emotion) {
            setState(() {
              if (_selectedEmotions.contains(emotion)) {
                _selectedEmotions.remove(emotion);
              } else {
                _selectedEmotions.add(emotion);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildPostCreationSection() {
    Color themeColor = _selectedType == 'restaurant'
        ? Colors.amber
        : _selectedType == 'event'
            ? Colors.green
            : Colors.purple;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.post_add, color: themeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Partager votre expérience',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Switch(
                  value: _createPost,
                  onChanged: (value) {
                    setState(() {
                      _createPost = value;
                    });
                  },
                  activeColor: themeColor,
                ),
              ],
            ),
            if (_createPost) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Partagez votre expérience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeColor.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Ce post sera visible sur votre profil et dans le fil d\'actualité',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Activez cette option pour partager votre avis avec vos abonnés',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('VALIDER MON CHOICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _submitChoice,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _getRestaurantMenuItems() async {
    if (_selectedLocation == null || _selectedType != 'restaurant') {
      return [];
    }

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${_selectedLocation!['_id']}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> menuItems = [];

        // Extrait les plats de la structure de données
        if (data['structured_data'] != null) {
          // Extraire des items indépendants
          if (data['structured_data']['Items Indépendants'] != null) {
            final items = data['structured_data']['Items Indépendants'];
            if (items is List) {
              for (var category in items) {
                if (category is Map && category['items'] is List) {
                  for (var item in category['items']) {
                    if (item is Map && item['nom'] != null) {
                      menuItems.add(item['nom']);
                    }
                  }
                }
              }
            }
          }

          // Extraire des menus globaux
          if (data['structured_data']['Menus Globaux'] != null) {
            final menus = data['structured_data']['Menus Globaux'];
            if (menus is List) {
              for (var menu in menus) {
                if (menu is Map && menu['inclus'] is List) {
                  for (var category in menu['inclus']) {
                    if (category is Map && category['items'] is List) {
                      for (var item in category['items']) {
                        if (item is Map && item['nom'] != null) {
                          menuItems.add(item['nom']);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Enlever les doublons
        return menuItems.toSet().toList();
      }
    } catch (e) {
      print('Erreur lors de la récupération des plats: $e');
    }

    return [];
  }
}

// Widget pour la saisie personnalisée de plats
class CustomItemInputField extends StatefulWidget {
  final Function(String) onItemAdded;

  const CustomItemInputField({
    Key? key,
    required this.onItemAdded,
  }) : super(key: key);

  @override
  State<CustomItemInputField> createState() => _CustomItemInputFieldState();
}

class _CustomItemInputFieldState extends State<CustomItemInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onItemAdded(text);
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Ajouter un plat non listé...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.amber, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _addItem();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _addItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}
