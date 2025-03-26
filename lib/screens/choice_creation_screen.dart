import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils.dart';
import '../widgets/rating_slider.dart';
import '../widgets/emotion_selector.dart';
import '../widgets/location_search.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeRatings();
  }

  void _initializeRatings() {
    // Initialize with default ratings
    _restaurantAspects.forEach((key, _) {
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
      final url = Uri.parse('${getBaseUrl()}/api/choices/verify');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'locationId': _selectedLocation!['_id'],
          'locationType': _selectedType,
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
        throw Exception('Verification failed');
      }
    } catch (e) {
      print('Error verifying location: $e');
      setState(() {
        _isVerifying = false;
        _isVerified = false;
      });
      _showVerificationError('Erreur lors de la vérification');
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
      final url = Uri.parse('${getBaseUrl()}/api/choices');
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
      }

      if (_createPost && _commentController.text.isNotEmpty) {
        choiceData['comment'] = _commentController.text;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(choiceData),
      );

      if (response.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to create choice');
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
        actions: [
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
    return Row(
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
              : 'Rechercher un événement',
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _selectedType == 'restaurant'
                      ? Icons.restaurant
                      : Icons.event,
                  color: _selectedType == 'restaurant'
                      ? Colors.amber
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLocation!['name'] ?? 'Lieu sélectionné',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('VÉRIFIER MA VISITE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _verifyLocation,
              ),
            const SizedBox(height: 8),
            Text(
              'Nous vérifions que vous avez passé au moins 30 minutes sur place.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
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
        else
          _buildEventRatings(),
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
        const Text(
          'Plats consommés',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItemInput(),
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

  Widget _buildMenuItemInput() {
    return Column(
      children: [
        // Display selected items
        if (_menuItems.isNotEmpty)
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
              );
            }).toList(),
          ),

        // Add item input
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Ajouter un plat...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _menuItems.add(value);
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // Add menu item logic
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostCreationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Créer un post',
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
              activeColor: Theme.of(context).primaryColor,
            ),
          ],
        ),
        if (_createPost) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: 'Ajouter un commentaire...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ],
    );
  }
}