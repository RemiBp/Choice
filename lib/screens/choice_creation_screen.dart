import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'dart:math';
import '../utils/constants.dart' as constants;
import '../widgets/rating_slider.dart';
import '../widgets/emotion_selector.dart';
import '../widgets/location_search.dart';
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

// Classe pour dessiner le checkmark
class CheckmarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  
  CheckmarkPainter({
    required this.color,
    this.strokeWidth = 3.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width / 3, size.height)
      ..lineTo(size.width, 0);
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Classe pour dessiner le logo Choice
class ChoiceLogoPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ChoiceLogoPainter({
    this.progress = 1.0,
    this.color = const Color(0xFF2196F3),
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Configuration du pinceau pour le cercle avec un dégradé
    final gradient = LinearGradient(
      colors: [
        const Color(0xFF29B6F6), // Bleu clair
        const Color(0xFF0288D1), // Bleu foncé
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    
    // Créer le shader du dégradé
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width * 0.4,
    );
    final gradientShader = gradient.createShader(rect);
    
    final circlePaint = Paint()
      ..shader = gradientShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    
    // Centre du cercle
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    
    // Dessiner le cercle ouvert (C) avec une animation
    final startAngle = -0.1; // Légèrement décalé pour commencer en haut
    final sweepAngle = 5.5 * progress; // Cercle ouvert à environ 300 degrés
    canvas.drawArc(rect, startAngle, sweepAngle, false, circlePaint);
    
    // Dessiner le checkmark si progress > 0.6
    if (progress > 0.6) {
      final checkProgress = (progress - 0.6) / 0.4; // Normaliser entre 0 et 1
      final checkPaint = Paint()
        ..shader = gradientShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeCap = StrokeCap.round;
      
      final path = Path();
      
      // Ajuster points de départ/arrivée du checkmark pour mieux correspondre au logo
      // Point de départ du checkmark (légèrement décalé vers la gauche et le bas)
      path.moveTo(
        center.dx - radius * 0.28,
        center.dy + radius * 0.05
      );
      
      // Premier segment du checkmark (partie descendante)
      if (checkProgress > 0.5) {
        path.lineTo(
          center.dx - radius * 0.05, 
          center.dy + radius * 0.3
        );
      } else {
        // Animation du premier segment
        final firstSegmentProgress = checkProgress * 2.0; // 0-0.5 → 0-1.0
        path.lineTo(
          center.dx - radius * 0.28 + (radius * 0.23 * firstSegmentProgress),
          center.dy + radius * 0.05 + (radius * 0.25 * firstSegmentProgress)
        );
      }
      
      // Deuxième segment (la partie montante)
      if (checkProgress > 0.5) {
        final secondSegmentProgress = (checkProgress - 0.5) * 2.0; // 0.5-1.0 → 0-1.0
        path.lineTo(
          center.dx - radius * 0.05 + radius * 0.48 * secondSegmentProgress,
          center.dy + radius * 0.3 - (radius * 0.55 * secondSegmentProgress)
        );
      }
      
      canvas.drawPath(path, checkPaint);
    }
    
    // Dessiner l'étoile si progress > 0.9
    if (progress > 0.9) {
      final starProgress = (progress - 0.9) / 0.1; // Normaliser entre 0 et 1
      
      // Position ajustée en haut à droite - plus proche du vrai logo
      final starCenter = Offset(
        center.dx + radius * 0.50,
        center.dy - radius * 0.50
      );
      
      // Étoile plus réaliste avec un dégradé
      final starGradient = RadialGradient(
        colors: [
          Colors.white,
          const Color(0xFF29B6F6),
        ],
        center: Alignment.center,
        radius: 0.6,
      );
      
      // Faire pulser l'étoile légèrement
      final pulseValue = 1.0 + sin(starProgress * pi * 3) * 0.1;
      
      final starRect = Rect.fromCircle(
        center: starCenter,
        radius: radius * 0.15 * pulseValue, // Étoile légèrement plus grande
      );
      
      final starPaint = Paint()
        ..shader = starGradient.createShader(starRect)
        ..style = PaintingStyle.fill;
      
      // Ajouter un halo autour de l'étoile
      final glowPaint = Paint()
        ..color = const Color(0xFF29B6F6).withOpacity(0.3 * starProgress)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * starProgress);
      
      canvas.drawCircle(starCenter, radius * 0.2 * starProgress, glowPaint);
      
      // Dessiner une étoile à quatre branches plus proche du logo véritable
      final starPath = Path();
      const numPoints = 4;
      const innerRadius = 0.4; // Rendre l'étoile plus pointue
      
      for (int i = 0; i < numPoints * 2; i++) {
        final pointRadius = i.isEven 
          ? radius * 0.15 * pulseValue  // Branches principales plus longues
          : radius * 0.06 * pulseValue; // Points intermédiaires plus courts
          
        // Rotation de 45 degrés pour aligner avec le logo
        final angle = 2 * pi * i / (numPoints * 2) + (pi/4);
        
        final point = Offset(
          starCenter.dx + pointRadius * cos(angle),
          starCenter.dy + pointRadius * sin(angle)
        );
        
        if (i == 0) {
          starPath.moveTo(point.dx, point.dy);
        } else {
          starPath.lineTo(point.dx, point.dy);
        }
      }
      
      starPath.close();
      canvas.drawPath(starPath, starPaint);
      
      // Ajouter un effet de brillance
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.9 * starProgress)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
      
      final highlightPath = Path();
      highlightPath.addOval(
        Rect.fromCircle(
          center: Offset(
            starCenter.dx - radius * 0.04,
            starCenter.dy - radius * 0.04
          ),
          radius: radius * 0.05 * starProgress * pulseValue
        )
      );
      
      canvas.drawPath(highlightPath, highlightPaint);
      
      // Ajouter des rayons lumineux autour de l'étoile
      if (starProgress > 0.7) {
        final rayProgress = (starProgress - 0.7) / 0.3;
        final rayPaint = Paint()
          ..color = Colors.white.withOpacity(0.5 * rayProgress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        
        for (int i = 0; i < 8; i++) {
          final angle = 2 * pi * i / 8 + (pi/8); // Offset pour aligner avec branches
          final startPoint = Offset(
            starCenter.dx + radius * 0.16 * cos(angle),
            starCenter.dy + radius * 0.16 * sin(angle)
          );
          final endPoint = Offset(
            starCenter.dx + radius * (0.25 + 0.1 * rayProgress) * cos(angle),
            starCenter.dy + radius * (0.25 + 0.1 * rayProgress) * sin(angle)
          );
          
          canvas.drawLine(startPoint, endPoint, rayPaint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant ChoiceLogoPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// Widget pour animer avec un délai
class DelayedAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, Animation<double> animation, Widget? child) builder;

  const DelayedAnimation({
    Key? key,
    required this.child,
    required this.delay,
    required this.duration,
    required this.builder,
    this.curve = Curves.easeOut,
  }) : super(key: key);

  @override
  State<DelayedAnimation> createState() => _DelayedAnimationState();
}

class _DelayedAnimationState extends State<DelayedAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    
    // Création du Tween ici au lieu de l'avoir comme paramètre const
    final tween = Tween<double>(begin: 0.0, end: 1.0);
    
    _animation = tween.animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _visible = true;
        });
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => widget.builder(context, _animation, child),
      child: widget.child,
    );
  }
}

class ChoiceCreationScreen extends StatefulWidget {
  final String userId;

  const ChoiceCreationScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChoiceCreationScreen> createState() => _ChoiceCreationScreenState();
}

class ConsumedItem {
  final String id;
  final String name;
  final String type;
  final String? category;
  double? rating;

  ConsumedItem({
    required this.id,
    required this.name,
    required this.type,
    this.category,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
    'itemId': id,
    'name': name,
    'type': type,
    if (category != null) 'category': category,
    if (rating != null) 'rating': rating,
  };
}

class _ChoiceCreationScreenState extends State<ChoiceCreationScreen> with SingleTickerProviderStateMixin {
  String _selectedType = '';
  Map<String, dynamic>? _selectedLocation;
  final Map<String, double> _ratings = {};
  final List<String> _selectedEmotions = [];
  final TextEditingController _commentController = TextEditingController();
  bool _createPost = false;
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _isVerified = false;
  bool _showSuccessAnimation = false;
  late AnimationController _animationController;

  bool _loadingMenuItems = false;
  List<dynamic> _fetchedMenus = [];
  Map<String, List<Map<String, dynamic>>> _fetchedCategorizedItems = {};
  final List<ConsumedItem> _selectedConsumedItems = [];

  Map<String, dynamic> _fetchedCriteriaRatings = {};
  List<String> _dynamicWellnessCriteriaKeys = [];
  bool _loadingCriteria = false;

  final Map<String, String> _restaurantAspects = {
    'service': 'Service',
    'lieu': 'Lieu',
    'ambiance': 'Ambiance',
  };
  
  final Map<String, String> _wellnessAspects = {
    'Qualité des soins': 'Qualité des soins', 
    'Propreté': 'Propreté', 
    'Accueil': 'Accueil', 
    'Rapport qualité/prix': 'Rapport Qualité/Prix',
    'Ambiance': 'Ambiance', 
    'Expertise du personnel': 'Expertise du Personnel'
  };

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
    
    // Initialize animation controller avec une durée plus longue
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500), // Augmenter la durée pour profiter de l'animation
    );
    
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showSuccessAnimation = false;
        });
        _animationController.reset();
        Navigator.pop(context, true);
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      _ratings.clear();
      _fetchedCriteriaRatings.clear();
      _dynamicWellnessCriteriaKeys.clear();
      _loadingCriteria = false;
      _loadingMenuItems = false;
      _fetchedMenus = [];
      _fetchedCategorizedItems = {};
      _selectedConsumedItems.clear();
      _initializeStaticRatings();
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

  void _initializeStaticRatings() {
    _ratings.clear();
    _restaurantAspects.forEach((key, _) {
      if (!_ratings.containsKey(key)) {
         _ratings[key] = 3.0;
      }
    });
  }

  void _initializeWellnessRatings() {
     _ratings.clear();
     for (String key in _dynamicWellnessCriteriaKeys) {
       dynamic fetchedValue = _fetchedCriteriaRatings[key];
       double initialValue = 3.0; 
       if (fetchedValue is num) {
         initialValue = fetchedValue.toDouble().clamp(0.0, 5.0);
       }
       _ratings[key] = initialValue;
       print("Initializing wellness rating for '$key' to $initialValue");
     }
  }

  Future<void> _verifyLocation() async {
    if (_selectedLocation == null) return;

    if (mounted) {
      setState(() {
        _isVerifying = true;
        _isVerified = false;
        _fetchedCriteriaRatings.clear();
        _dynamicWellnessCriteriaKeys.clear();
        _loadingCriteria = false;
        _loadingMenuItems = false;
        _fetchedMenus = [];
        _fetchedCategorizedItems = {};
        _selectedConsumedItems.clear();
      });
    }

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/choices/verify');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'locationId': _selectedLocation!['_id'],
          'locationType': _selectedType,
          'location': _selectedLocation!['location'],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _isVerified = data['verified'] ?? false;
            _isVerifying = false;
          });
        }

        if (_isVerified) {
          if (_selectedType == 'wellness') {
            await _fetchWellnessCriteria();
          } else if (_selectedType == 'restaurant') {
            await _fetchRestaurantMenuData();
            _initializeStaticRatings();
          } else {
             _initializeStaticRatings(); 
          }
        } else {
          _showVerificationError(data['message'] ?? 'Vérification échouée');
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          setState(() { _isVerifying = false; });
        }
        _showVerificationError('Erreur ${response.statusCode}: ${errorData['message'] ?? 'Erreur serveur'}');
      }
    } catch (e) {
      print('Error verifying location: $e');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isVerified = false;
        });
      }
      _showVerificationError('Erreur lors de la vérification: $e');
    }
  }

  Future<void> _fetchWellnessCriteria() async {
    if (_selectedLocation == null || _selectedLocation!['_id'] == null) return;

    setState(() {
      _loadingCriteria = true;
      _dynamicWellnessCriteriaKeys.clear();
      _fetchedCriteriaRatings.clear();
    });

    try {
      final placeId = _selectedLocation!['_id'];
      final url = Uri.parse('${constants.getBaseUrl()}/api/wellness/$placeId');
      print('Fetching wellness criteria from: $url');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final producerData = data;
        
        // --- DEBUG LOGGING START ---
        print('Raw producer data received for $placeId:');
        try {
          print(json.encode(producerData)); // Print the whole structure
        } catch (e) {
          print('Could not encode producerData: $e');
          print(producerData.toString()); // Fallback to toString
        }
        // --- DEBUG LOGGING END ---

        if (producerData != null && producerData['criteria_ratings'] is Map) {
           print('Received criteria data (using criteria_ratings): ${producerData['criteria_ratings']}');

           _fetchedCriteriaRatings = Map<String, dynamic>.from(producerData['criteria_ratings']);

           _dynamicWellnessCriteriaKeys = _fetchedCriteriaRatings.keys
               .where((key) => key != 'average_score')
               .toList();

            print('Dynamic criteria keys loaded: $_dynamicWellnessCriteriaKeys');
            
           _initializeWellnessRatings();

        } else {
          print('Criteria data not found or invalid format in response for $placeId');
          _showVerificationError('Critères d\'évaluation non trouvés pour ce lieu.');
        }
      } else {
         final errorData = json.decode(response.body);
         _showVerificationError('Erreur chargement critères ${response.statusCode}: ${errorData['message'] ?? 'Erreur serveur'}');
         print('Failed to load criteria: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching wellness criteria: $e');
      _showVerificationError('Erreur réseau lors du chargement des critères.');
    } finally {
      if (mounted) {
         setState(() {
            _loadingCriteria = false;
         });
      }
    }
  }

  Future<void> _fetchRestaurantMenuData() async {
    if (_selectedLocation == null || _selectedLocation!['_id'] == null) return;

    setState(() {
      _loadingMenuItems = true;
      _fetchedMenus = [];
      _fetchedCategorizedItems = {};
      _selectedConsumedItems.clear();
    });

    try {
      final placeId = _selectedLocation!['_id'];
      final url = Uri.parse('${constants.getBaseUrl()}/api/producers/$placeId'); 
      print('Fetching restaurant menu data from: $url');
      final response = await http.get(
         url,
         headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final producerData = data;

        if (producerData != null && producerData['structured_data'] is Map) {
          final structuredData = producerData['structured_data'] as Map<String, dynamic>;
          List<dynamic> globalMenus = [];
          Map<String, List<Map<String, dynamic>>> groupedItems = {};

          if (structuredData['Menus Globaux'] is List) {
            globalMenus = List<dynamic>.from(structuredData['Menus Globaux']);
             print('🍽️ Fetched ${globalMenus.length} global menus.');
          }

          if (structuredData['Items Indépendants'] is List) {
            final categoriesData = structuredData['Items Indépendants'] as List;
            for (var categoryData in categoriesData) {
              if (categoryData is Map<String, dynamic>) {
                final categoryName = categoryData['catégorie']?.toString().trim() ?? 'Autres';
                final itemsList = categoryData['items'];
                if (itemsList is List) {
                  final List<Map<String, dynamic>> validItems = itemsList.whereType<Map<String, dynamic>>().toList();
                  if (validItems.isNotEmpty) {
                    groupedItems.putIfAbsent(categoryName, () => []).addAll(validItems);
                  }
                }
              }
            }
             print('🛒 Fetched ${groupedItems.values.map((list) => list.length).fold(0, (a, b) => a + b)} independent items across ${groupedItems.keys.length} categories.');
          }

          if (mounted) {
             setState(() {
               _fetchedMenus = globalMenus;
               _fetchedCategorizedItems = groupedItems;
             });
          }
        } else {
          print('Menu data (structured_data) not found or invalid format for $placeId');
           _showVerificationError('Données du menu non trouvées pour ce restaurant.');
        }
      } else {
        final errorData = json.decode(response.body);
         _showVerificationError('Erreur chargement menu ${response.statusCode}: ${errorData['message'] ?? 'Erreur serveur'}');
         print('Failed to load menu data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching restaurant menu data: $e');
      _showVerificationError('Erreur réseau lors du chargement du menu.');
    } finally {
      if (mounted) {
          setState(() {
            _loadingMenuItems = false;
          });
      }
    }
  }

  void _showVerificationError(String message) {
    // Check mounted status first
    if (!mounted) return;

    // Capture ScaffoldMessengerState safely
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Now show the SnackBar using the captured state
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _submitChoice() async {
    if (!_isVerified || _selectedLocation == null) {
       _showVerificationError("Veuillez sélectionner et vérifier un lieu.");
       return;
    }
    
    if ((_selectedType == 'restaurant' || _selectedType == 'wellness') && _ratings.isEmpty) {
        _showVerificationError("Veuillez attribuer des notes aux critères principaux.");
        return;
    }
    
    if (_selectedType == 'restaurant' && _selectedConsumedItems.isEmpty && (_fetchedMenus.isNotEmpty || _fetchedCategorizedItems.isNotEmpty)) {
        _showVerificationError("Veuillez sélectionner au moins un plat ou menu consommé.");
        return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/choices');
      Map<String, double> ratingsToSubmit = {};
      if (_selectedType == 'restaurant') {
          _restaurantAspects.keys.forEach((key) { 
              if (_ratings.containsKey(key)) ratingsToSubmit[key] = _ratings[key]!; 
          });
      } else if (_selectedType == 'wellness') {
          _dynamicWellnessCriteriaKeys.forEach((key) { 
              if (_ratings.containsKey(key)) ratingsToSubmit[key] = _ratings[key]!; 
          });
      }

      List<Map<String, dynamic>> consumedItemsToSubmit = _selectedConsumedItems.map((item) => item.toJson()).toList();

      final Map<String, dynamic> choiceData = {
        'userId': widget.userId,
        'locationId': _selectedLocation!['_id'],
        'locationType': _selectedType,
        'ratings': ratingsToSubmit,
        'createPost': _createPost,
        'consumedItems': consumedItemsToSubmit,
      };

      if ((_selectedType == 'event' || _selectedType == 'wellness') && _selectedEmotions.isNotEmpty) {
        choiceData['emotions'] = _selectedEmotions;
      }

      if (_commentController.text.trim().isNotEmpty) {
        choiceData['comment'] = _commentController.text.trim();
      }

      print("Submitting Choice Data: ${json.encode(choiceData)}");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(choiceData),
      );

      if (response.statusCode == 201) {
         if (mounted) {
            setState(() {
              _isLoading = false;
              _showSuccessAnimation = true;
            });
            
            // Add haptic feedback for success
            HapticFeedback.mediumImpact();
            
            _animationController.forward();
         }
      } else {
        final errorData = json.decode(response.body);
        print("Choice creation failed: ${response.statusCode} - ${response.body}");
        throw Exception(errorData['message'] ?? 'Failed to create choice');
      }
    } catch (e) {
      print('Error creating choice: $e');
       if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Nouveau Choice'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (_isVerified) {
                   setState(() {
                     _isVerified = false;
                     _selectedLocation = null;
                     _ratings.clear();
                     _dynamicWellnessCriteriaKeys.clear();
                     _fetchedCriteriaRatings.clear();
                     _selectedConsumedItems.clear();
                     _fetchedMenus = [];
                     _fetchedCategorizedItems = {};
                   });
                } else if (_selectedLocation != null) {
                   setState(() {
                      _selectedLocation = null;
                   });
                } else if (_selectedType.isNotEmpty) {
                   _resetSelection();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            actions: [
              if (_selectedLocation != null && !_isVerified && !_isVerifying)
                TextButton(
                  child: const Text('CHANGER', style: TextStyle(color: Colors.white)),
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
              if (_isLoading || _isVerifying)
                 const Padding(
                   padding: EdgeInsets.only(right: 16.0),
                   child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
                 ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Changer Type'),
                            onPressed: _resetSelection,
                          ),
                        ],
                      ),
                      const Divider(),
                    _buildLocationSearch(),
                  ] else ...[
                    if (!_isVerified) ...[
                      _buildVerificationSection(),
                    ] else ...[
                      _buildSelectedLocationHeader(),
                      const SizedBox(height: 16),
                      _buildRatingSection(),
                      const SizedBox(height: 24),
                      _buildPostCreationSection(),
                       const SizedBox(height: 24),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
        if (_showSuccessAnimation)
          _buildSuccessAnimation(),
      ],
    );
  }

  Widget _buildSelectedLocationHeader() {
     Color themeColor = _selectedType == 'restaurant'
        ? Colors.amber
        : _selectedType == 'event'
            ? Colors.green
            : Colors.purple;
    return Container(
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: themeColor.withOpacity(0.1),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: themeColor.withOpacity(0.3))
       ),
       child: Row(
          children: [
            CircleAvatar(
              backgroundColor: themeColor,
              radius: 20,
              child: Icon(
                _selectedType == 'restaurant'
                    ? Icons.restaurant
                    : _selectedType == 'event'
                        ? Icons.event
                        : Icons.spa,
                color: Colors.white,
                size: 20,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_selectedLocation!['address'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        _selectedLocation!['address'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                         overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
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
            const Expanded(child: SizedBox()),
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
            _initializeStaticRatings();
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
                textAlign: TextAlign.center,
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _selectedType == 'restaurant'
                ? 'Quel restaurant avez-vous visité ?'
                : _selectedType == 'event'
                    ? 'À quel événement avez-vous assisté ?'
                    : 'Quel établissement avez-vous fréquenté ?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ),
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
                _buildSelectedLocationHeader(),
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
                          foregroundColor: Colors.white,
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
                           crossAxisAlignment: CrossAxisAlignment.start,
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
                              'Nous vérifions que vous avez passé au moins 30 minutes sur place dans les 7 derniers jours via votre historique de localisation.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const Divider(height: 16),
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
          'Votre expérience',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedType == 'restaurant')
          _buildRestaurantExperienceSection()
        else if (_selectedType == 'event')
          _buildEventRatings()
        else if (_selectedType == 'wellness')
          _buildWellnessRatings(),
      ],
    );
  }

  Widget _buildRestaurantExperienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'Note globale du restaurant', 
                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                 ),
                 const SizedBox(height: 16),
                 ..._restaurantAspects.entries.map((entry) {
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: RatingSlider(
                       label: entry.value,
                       value: _ratings[entry.key] ?? 3.0,
                       onChanged: (value) {
                         setState(() {
                           _ratings[entry.key] = value;
                         });
                       },
                     ),
                   );
                 }),
               ],
             ),
           ),
         ),
         const SizedBox(height: 24),

        _buildConsumedItemsSection(),
      ],
    );
  }

  Widget _buildConsumedItemsSection() {
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
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_menu, color: Colors.amber),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Plats & Menus Consommés',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_loadingMenuItems)
                   const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                else if (_fetchedMenus.isEmpty && _fetchedCategorizedItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('Menu non disponible pour ce restaurant.', style: TextStyle(color: Colors.grey))), 
                    )
                else ...[
                   if (_fetchedMenus.isNotEmpty) ...[
                      const Text('Menus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._fetchedMenus.map((menuData) => _buildSelectableMenuItemCard(menuData, 'menu')).toList(),
                      const SizedBox(height: 16),
                   ],
                   if (_fetchedCategorizedItems.isNotEmpty) ...[
                      ..._fetchedCategorizedItems.entries.map((entry) {
                          return Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...entry.value.map((itemData) => _buildSelectableMenuItemCard(itemData, 'item', category: entry.key)).toList(),
                                const SizedBox(height: 16),
                             ],
                          );
                      }).toList(),
                   ],
                ],

                 if (_selectedConsumedItems.isNotEmpty) ...[
                   const Divider(height: 24),
                   const Text(
                      'Notez les plats sélectionnés :', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                   ),
                   const SizedBox(height: 12),
                   ..._selectedConsumedItems.map((consumedItem) => _buildSelectedItemRatingCard(consumedItem)).toList(),
                 ],
              ],
            ),
          ),
        );
  }

  Widget _buildSelectableMenuItemCard(Map<String, dynamic> itemData, String type, {String? category}) {
    final String itemId = itemData['_id']?.toString() ?? 'temp_${itemData['name'] ?? UniqueKey().toString()}';
    final String name = itemData['name'] ?? itemData['nom'] ?? 'Inconnu';
    final dynamic price = itemData['price'] ?? itemData['prix'];
    final String formattedPrice = price != null ? '${price.toStringAsFixed(2)} €' : '';
    final bool isSelected = _selectedConsumedItems.any((item) => item.id == itemId);

    return Card(
       margin: const EdgeInsets.only(bottom: 12),
       elevation: isSelected ? 0 : 1,
       color: isSelected ? Colors.amber.withOpacity(0.1) : Colors.white,
       shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSelected ? Colors.amber : Colors.grey[200]!)
       ),
       child: InkWell(
          onTap: () {
             setState(() {
                if (isSelected) {
                   _selectedConsumedItems.removeWhere((item) => item.id == itemId);
                } else {
                   _selectedConsumedItems.add(ConsumedItem(
                     id: itemId,
                     name: name,
                     type: type,
                     category: category,
                   ));
                }
             });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
             child: Row(
                children: [
                   Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.amber : Colors.grey,
                      size: 24,
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                        name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                     ),
                   ),
                   if (formattedPrice.isNotEmpty)
                     Text(
                       formattedPrice,
                       style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                     ),
                ],
             ),
          ),
       ),
    );
  }

  Widget _buildSelectedItemRatingCard(ConsumedItem consumedItem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(10),
         border: Border.all(color: Colors.grey[300]!),
         boxShadow: [
           BoxShadow(
             color: Colors.grey.withOpacity(0.1),
             spreadRadius: 1,
             blurRadius: 3,
             offset: const Offset(0, 1), 
           ),
         ],
      ),
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Expanded(
                 child: Text(
                   consumedItem.name,
                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                 ),
               ),
               IconButton(
                  icon: Icon(Icons.close, size: 20, color: Colors.red[300]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Désélectionner',
                  onPressed: () {
                     setState(() {
                        _selectedConsumedItems.removeWhere((item) => item.id == consumedItem.id);
                     });
                  },
               )
             ],
           ),
           const SizedBox(height: 8),
           Text(
             'Votre note pour ce plat :' ?? '',
             style: TextStyle(fontSize: 14, color: Colors.grey[700]),
           ),
           const SizedBox(height: 8),
           RatingBar.builder(
             initialRating: consumedItem.rating ?? 0,
             minRating: 0,
             direction: Axis.horizontal,
             allowHalfRating: true,
             itemCount: 5,
             itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
             itemBuilder: (context, _) => const Icon(
               Icons.star,
               color: Colors.amber,
             ),
             itemSize: 30.0,
             onRatingUpdate: (rating) {
               setState(() {
                  int index = _selectedConsumedItems.indexWhere((item) => item.id == consumedItem.id);
                  if (index != -1) {
                     _selectedConsumedItems[index].rating = (rating == 0) ? null : rating;
                  }
               });
             },
           ),
         ],
      ),
    );
  }

  Widget _buildWellnessRatings() {
    if (_loadingCriteria) {
      return const Center(
         child: Padding(
           padding: EdgeInsets.symmetric(vertical: 32.0),
           child: Column(
             children: [
               CircularProgressIndicator(color: Colors.purple),
               SizedBox(height: 16),
               Text("Chargement des critères d'évaluation...")
             ],
           ),
         )
      );
    }

    if (_dynamicWellnessCriteriaKeys.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
             "Impossible de charger les critères d'évaluation pour ce lieu.",
             textAlign: TextAlign.center,
             style: TextStyle(color: Colors.red)
          )
        )
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  const Text(
                    'Note globale de l\'établissement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 16),
                  ..._dynamicWellnessCriteriaKeys.map((criterionKey) {
                    String displayLabel = criterionKey.replaceAll('_', ' ');
                    displayLabel = displayLabel[0].toUpperCase() + displayLabel.substring(1);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RatingSlider(
                        label: displayLabel,
                        value: _ratings[criterionKey] ?? 3.0,
                        onChanged: (value) {
                          setState(() {
                            _ratings[criterionKey] = value;
                          });
                        },
                      ),
                    );
                  }),
               ],
             ),
           ),
         ),
         const SizedBox(height: 24),

        Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
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
             ),
           ),
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

    for (var aspect in aspects) {
        if (!_ratings.containsKey(aspect)) {
            _ratings[aspect] = 3.0;
        }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'Note globale de l\'événement', 
                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                 ),
                 const SizedBox(height: 16),
                 ...aspects.map((aspect) {
                   String displayLabel = aspect
                       .split(' ')
                       .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
                       .join(' ');
         
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: RatingSlider(
                       label: displayLabel,
                       value: _ratings[aspect] ?? 3.0,
                       onChanged: (value) {
                         setState(() {
                           _ratings[aspect] = value;
                         });
                       },
                     ),
                   );
                 }),
               ],
             ),
           ),
         ),
         const SizedBox(height: 24),

        Card(
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
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
             ),
           ),
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
      margin: const EdgeInsets.only(top: 16),
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
                  hintText: 'Partagez votre expérience... (optionnel)',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 4,
                minLines: 2,
                 textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Ce post sera visible sur votre profil et dans le fil d'actualité.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Padding(
                 padding: const EdgeInsets.only(left: 52),
                 child: Text(
                    'Activez pour partager votre avis avec vos abonnés.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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
                   foregroundColor: Colors.white,
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

  Widget _buildSuccessAnimation() {
    // Couleur principale du logo Choice (Bleu)
    const Color choiceLogoColor = Color(0xFF00B0FF);
    
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Stack(
          children: [
            // Confetti animation in the background
            Positioned.fill(
              child: Lottie.network(
                'https://assets1.lottiefiles.com/packages/lf20_vwcwjxgx.json', // Confetti animation
                fit: BoxFit.cover,
              ),
            ),
            // Main success card in the center
            Center(
              child: DelayedAnimation(
                delay: Duration.zero,
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, animation, child) {
                  return Transform.scale(
                    scale: animation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: choiceLogoColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Choice avec animation progressive
                      DelayedAnimation(
                        delay: Duration.zero,
                        duration: const Duration(milliseconds: 2500), // Animation plus longue pour le logo
                        curve: Curves.easeOutCubic,
                        builder: (context, animation, child) {
                          // Déclencher l'animation de sortie après la fin de l'animation du logo
                          if (animation.status == AnimationStatus.completed && 
                              mounted && _showSuccessAnimation) {
                            Future.delayed(const Duration(milliseconds: 1000), () {
                              if (mounted && _showSuccessAnimation) {
                                _animationController.forward();
                              }
                            });
                          }
                          
                          return Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: choiceLogoColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(120, 120),
                                painter: ChoiceLogoPainter(
                                  progress: animation.value,
                                  color: choiceLogoColor,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const SizedBox(), // Placeholder
                      ),
                      const SizedBox(height: 24),
                      // Nom du logo "Choice"
                      DelayedAnimation(
                        delay: const Duration(milliseconds: 800),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, animation, child) {
                          return Opacity(
                            opacity: animation.value,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - animation.value)),
                              child: Text(
                                "Choice",
                                style: TextStyle(
                                  color: choiceLogoColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const SizedBox(), // Placeholder
                      ),
                      const SizedBox(height: 16),
                      // Text with typing animation
                      DelayedAnimation(
                        delay: const Duration(milliseconds: 1200),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, animation, child) {
                          final String text = 'Choice créé avec succès!';
                          final int charactersToShow = (text.length * animation.value).round();
                          return Text(
                            text.substring(0, charactersToShow),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: choiceLogoColor,
                            ),
                          );
                        },
                        child: const SizedBox(), // Placeholder
                      ),
                      const SizedBox(height: 12),
                      DelayedAnimation(
                        delay: const Duration(milliseconds: 1400),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, animation, child) {
                          return Opacity(
                            opacity: animation.value,
                            child: child,
                          );
                        },
                        child: Text(
                          _selectedLocation?['name'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 24),
                      DelayedAnimation(
                        delay: const Duration(milliseconds: 1600),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, animation, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - animation.value)),
                            child: Opacity(
                              opacity: animation.value,
                              child: child,
                            ),
                          );
                        },
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showSuccessAnimation = false;
                            });
                            _animationController.reset();
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: choiceLogoColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: const Text(
                            'CONTINUER',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
