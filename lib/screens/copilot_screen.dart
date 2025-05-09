import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'utils.dart';
import '../utils/constants.dart' as constants; // Ajouter cet import
import 'package:cached_network_image/cached_network_image.dart'; // Pour les images
import '../services/ai_service.dart'; // Import du service AI
import '../widgets/voice_search_button.dart'; // Import du widget de recherche vocale
import '../services/voice_recognition_service.dart'; // Import du service de reconnaissance vocale
import 'package:provider/provider.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les détails des événements
import 'vibe_map_screen.dart'; // Pour la cartographie sensorielle
import 'profile_screen.dart'; // Import du screen de profil
import 'package:go_router/go_router.dart';

// Extension pour convertir les entiers en Duration (ms)
extension DurationExtension on int {
  Duration get ms => Duration(milliseconds: this);
}

// Extensions pour remplacer flutter_animate
extension AnimateExtension on Widget {
  Widget animate({Duration? delay}) {
    return AnimatedWidgetFix(
      child: this,
      delay: delay,
    );
  }
  
  Widget fadeIn({Duration? duration, Curve curve = Curves.easeOut}) {
    return FadeTransition(
      opacity: AlwaysStoppedAnimation(1.0),
      child: this,
    );
  }
  
  Widget slideY({double? begin, double? end, Duration? duration, Curve curve = Curves.easeOut}) {
    return SlideTransition(
      position: AlwaysStoppedAnimation(Offset(0, end ?? 0)),
        child: this,
    );
  }
  
  Widget slideX({double? begin, double? end, Duration? duration, Curve curve = Curves.easeOut}) {
    return SlideTransition(
      position: AlwaysStoppedAnimation(Offset(end ?? 0, 0)),
        child: this,
    );
  }
  
  Widget scale({
    dynamic begin, 
    dynamic end, 
    Duration? duration, 
    Curve curve = Curves.easeOut
  }) {
    double scaleValue = 1.0;
    if (end is double) {
      scaleValue = end;
    } else if (end is Offset) {
      // Utiliser la moyenne des valeurs x et y pour l'échelle
      scaleValue = (end.dx + end.dy) / 2.0;
    }
    
    return Transform.scale(
      scale: scaleValue,
      child: this,
    );
  }
  
  Widget move({Offset? begin, Offset? end, Duration? duration, Curve curve = Curves.easeOut}) {
    return SlideTransition(
      position: AlwaysStoppedAnimation(end ?? Offset.zero),
        child: this,
    );
  }
}

// Widget animé personnalisé pour remplacer le système d'animation de flutter_animate
class AnimatedWidgetFix extends StatefulWidget {
  final Widget child;
  final Duration? delay;

  const AnimatedWidgetFix({Key? key, required this.child, this.delay}) : super(key: key);

  @override
  State<AnimatedWidgetFix> createState() => _AnimatedWidgetFixState();
}

class _AnimatedWidgetFixState extends State<AnimatedWidgetFix> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    if (widget.delay != null) {
      Future.delayed(widget.delay!, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}

class CopilotScreen extends StatefulWidget {
  final String userId;

  const CopilotScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _CopilotScreenState createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _conversations = [];
  final List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  
  final AIService _aiService = AIService(); // Instance du service AI

  // Attributs pour gérer différents types d'utilisateurs
  String _accountType = 'user'; // Par défaut: utilisateur standard
  bool _isProducer = false; // Flag pour identifier si c'est un producteur
  String? _producerId; // ID producteur si applicable
  bool _isLoadingAccountInfo = true; // Indicateur de chargement des infos de compte
  Map<String, dynamic> _userData = {}; // Données de l'utilisateur
  
  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Charger les informations du compte
    _loadAccountInfo();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  // Charge les informations du compte pour adapter l'interface
  Future<void> _loadAccountInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingAccountInfo = true;
    });
    
    try {
      // Récupérer les infos utilisateur pour déterminer le type de compte
      // Utiliser la méthode recommandée pour obtenir baseUrl
      final baseUrl = constants.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/users/${widget.userId}');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (!mounted) return;
        
        setState(() {
          _userData = userData;
          
          // Déterminer le type de compte (user/RestaurantProducer/LeisureProducer/WellnessProducer)
          if (userData['accountType'] != null) {
            _accountType = userData['accountType'];
            _isProducer = _accountType.contains('Producer');
            
            // Si producteur, récupérer l'ID du producteur
            if (_isProducer && userData['producerId'] != null) {
              _producerId = userData['producerId'];
            }
          }
          
          _isLoadingAccountInfo = false;
        });
        
        // Précharger des suggestions adaptées au type de compte
        _loadDefaultSuggestions();
      } else {
        throw Exception('Erreur lors de la récupération des données utilisateur');
      }
    } catch (error) {
      print('Erreur lors du chargement des infos compte: $error');
      if (!mounted) return;
      
      setState(() {
        _isLoadingAccountInfo = false;
      });
    }
  }
  
  // Charge des suggestions par défaut selon le type de compte
  void _loadDefaultSuggestions() {
    // Un producteur utilisant l'interface utilisateur (copilot) devrait toujours
    // être traité comme un utilisateur normal
    // Supprimer la logique spécifique aux producteurs ici, car ils ont leur propre interface
    // dans producer_dashboard_ia.dart
    
    // Charger des suggestions génériques pour tous les utilisateurs
    _loadGenericSuggestions();
  }
  
  // Charge des suggestions génériques pour tous les utilisateurs
  void _loadGenericSuggestions() {
    // Ici on pourrait charger des suggestions génériques basées sur les préférences de l'utilisateur
    // ou les tendances actuelles, indépendamment du type de compte
    
    // Cette fonction sera implémentée ultérieurement
    // Pour l'instant, on ne fait rien
  }
  
  // Exécute une analyse pour les producteurs
  Future<void> _runProducerAnalysis() async {
    if (_producerId == null || _producerId!.isEmpty) {
      print('❌ Impossible de lancer l\'analyse : ID producteur non disponible');
      return;
    }
    
    setState(() {
      _isLoading = true;
      // Ajouter un message de chargement
      _conversations.add({
        'type': 'copilot',
        'content': 'Analyse de votre établissement en cours...',
        'isLoading': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    
    try {
      final analysisResponse = await _aiService.producerAnalysis(_producerId!);
      
      if (!mounted) return;
      
        setState(() {
        // Supprimer le message de chargement
        _conversations.removeWhere((msg) => msg['isLoading'] == true);
        
        if (!analysisResponse.hasError) {
          _conversations.add({
            'type': 'copilot',
            'content': analysisResponse.response,
            'timestamp': DateTime.now().toIso8601String(),
            'hasProfiles': analysisResponse.profiles.isNotEmpty,
            'intent': 'producer_analysis',
            'resultCount': analysisResponse.resultCount,
          });
          
          if (analysisResponse.profiles.isNotEmpty) {
            // Profiles are handled within the message now
          }
        } else {
          // Ajouter un message d'erreur
          _conversations.add({
            'type': 'copilot',
            'content': analysisResponse.response.isNotEmpty 
                       ? "Erreur lors de l'analyse : ${analysisResponse.response}" 
                       : "Une erreur inconnue est survenue lors de l'analyse.",
            'isError': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      print('❌ Erreur lors de l\'analyse producteur: $e');
      
      if (!mounted) return;
      
      setState(() {
        _conversations.removeWhere((msg) => msg['isLoading'] == true);
        _conversations.add({
          'type': 'copilot',
          'content': "Erreur lors de l'analyse : $e",
          'isError': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isLoading = false;
      });
      
      _scrollToBottom();
    }
  }

  // --- Sending Questions and Processing Responses ---
  Future<void> _sendQuestion(String question) async {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) return;
    if (!mounted) return;

    print("--- CopilotScreen: _sendQuestion START ---"); // <-- PRINT 1

    final userMessage = {
      'type': 'user',
      'content': trimmedQuestion,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final loadingMessage = {
      'type': 'copilot',
      'content': 'Analyse en cours...',
      'isLoading': true,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      print("--- CopilotScreen: Adding user and loading messages to state ---"); // <-- PRINT 2
      _conversations.add(userMessage);
      _conversations.add(loadingMessage); // Add loading indicator
      _questionController.clear();
      _isLoading = true; // Set loading state for potential global indicator
    });

    _scrollToBottom(); // Scroll after adding messages

    try {
       // Vérifier que userId n'est pas null ou vide avant d'appeler l'API
       if (widget.userId.isEmpty) {
         throw Exception("Identifiant utilisateur non disponible.");
       }

       print("--- CopilotScreen: Calling _aiService.complexUserQuery... ---"); // <-- PRINT 3
       // Appel au service AI
      final AIQueryResponse aiResponse = await _aiService.complexUserQuery(
        widget.userId,
        trimmedQuestion,
      );
      print("--- CopilotScreen: _aiService.complexUserQuery SUCCESS ---"); // <-- PRINT 4

      if (mounted) {
         print("--- CopilotScreen: Calling _processApiResponse... ---"); // <-- PRINT 5
        _processApiResponse(aiResponse);
      }

    } catch (e) {
      print("--- CopilotScreen: ERROR during AI call: $e ---"); // <-- PRINT 6 (Error)
      if (mounted) {
        _processApiResponse(AIQueryResponse( // Create an error response
          response: "Désolé, une erreur est survenue lors de la communication avec l'assistant. $e",
          profiles: [],
          intent: 'error',
          resultCount: 0,
          hasError: true,
        ));
      }
    } finally {
       print("--- CopilotScreen: _sendQuestion FINALLY block ---"); // <-- PRINT 7
       if (mounted) {
          // Ensure loading indicator is removed even if processApiResponse wasn't called due to unmount
          setState(() {
             print("--- CopilotScreen: Removing loading indicator in finally ---"); // <-- PRINT 8
             _conversations.removeWhere((msg) => msg['metadata']?['type'] == 'loading');
             _isLoading = false;
          });
          _scrollToBottom(); // Scroll again after potential removal/addition
       }
    }
     print("--- CopilotScreen: _sendQuestion END ---"); // <-- PRINT 9
  }

  // Process the response from the AI service
  void _processApiResponse(AIQueryResponse aiResponse) {
    if (!mounted) return;
    print("--- CopilotScreen: _processApiResponse START (hasError: ${aiResponse.hasError}) ---"); // <-- PRINT 10

    // Normalize profiles first
    List<ProfileData> normalizedProfiles = [];
    if (aiResponse.profiles.isNotEmpty) {
      normalizedProfiles = _normalizeProfileTypes(aiResponse.profiles);
    }

    // S'assurer que la réponse n'est pas vide
    String responseText = aiResponse.response.trim();
    if (responseText.isEmpty && normalizedProfiles.isEmpty) {
       responseText = "Je n'ai pas trouvé d'informations pertinentes pour votre demande.";
    } else if (responseText.isEmpty && normalizedProfiles.isNotEmpty) {
       // Keep text minimal if only profiles are returned
       responseText = "Voici quelques suggestions qui pourraient correspondre :";
    }

    if (!mounted) return;
    setState(() {
      print("--- CopilotScreen: Updating state in _processApiResponse ---"); // <-- PRINT 11
      // Remove loading indicator FIRST
      _conversations.removeWhere((msg) => msg['metadata']?['type'] == 'loading');
      // Add the actual response
      _conversations.add({
        'type': 'copilot',
        'timestamp': DateTime.now().toIso8601String(),
        // Store data needed for rendering directly in the message map
        'metadata': {
          'text': responseText, // Just the text part
          'profiles': normalizedProfiles, // Store normalized profiles here
          'intent': aiResponse.intent,
          'resultCount': aiResponse.resultCount ?? normalizedProfiles.length,
          'type': aiResponse.hasError ? 'error' : 'ai_response', // Mark as error if needed
          'isLoading': false, // Ensure loading is false
        },
        // Keep 'content' for compatibility or user messages, but AI text is in metadata['text']
        'content': responseText,
        // Keep 'error' flag for simplicity in footer or other logic if needed
        'error': aiResponse.hasError,
      });
      _isLoading = false; // Update global loading state
    });

    _scrollToBottom(); // Scroll after adding the final message
    print("--- CopilotScreen: _processApiResponse END ---"); // <-- PRINT 12
  }

  // Normalize profile types (copied logic)
  List<ProfileData> _normalizeProfileTypes(List<ProfileData> profiles) {
    List<ProfileData> normalized = [];
    for (var profile in profiles) {
      var currentProfile = profile; // Start with the original profile
      if (profile.type == 'generic' || profile.type == 'unknown') {
        final String name = profile.name.toLowerCase();
        final List<String> categories = profile.category.map((c) => c.toLowerCase()).toList();
        
        print('🔍 Normalisation du type pour: ${profile.name} (Catégories: ${profile.category.join(', ')})');
        
        if (categories.any((cat) => cat.contains('restaurant') || cat.contains('gastronomie') || cat.contains('cuisine') || cat.contains('food'))) {
          currentProfile = profile.copyWith(type: 'restaurant');
        } else if (categories.any((cat) => cat.contains('loisir') || cat.contains('thé') || cat.contains('culture') || cat.contains('spectacle') || cat.contains('salle') || cat.contains('musée')) || name.contains('théâtre') || name.contains('theatre') || name.contains('comédie') || name.contains('comedie')) {
          currentProfile = profile.copyWith(type: 'leisureProducer');
        } else if (categories.any((cat) => cat.contains('évènement') || cat.contains('evenement') || cat.contains('event'))) {
          currentProfile = profile.copyWith(type: 'event');
        } else if (categories.any((cat) => cat.contains('bien-être') || cat.contains('bien être') || cat.contains('spa') || cat.contains('massage') || cat.contains('wellness'))) {
          currentProfile = profile.copyWith(type: 'wellnessProducer');
        } else if (categories.any((cat) => cat.contains('beauté') || cat.contains('beauty') || cat.contains('salon') || cat.contains('coiffure'))) {
          currentProfile = profile.copyWith(type: 'beautyPlace');
        } else {
          print('⚠️ Type indéterminé pour: ${profile.name}, conservé comme ${profile.type}');
        }
        print('✅ Type normalisé: ${profile.name} => ${currentProfile.type}');
      }
      normalized.add(currentProfile);
    }
    return normalized;
  }

  // Navigue vers le profil d'un restaurant, loisir ou événement
  void _navigateToEntity(String entityType, String id) {
    if (entityType == 'leisure') {
      // Naviguer vers l'écran de loisirs (ProducerLeisureScreen)
      _fetchAndNavigateWithUnifiedApi(
        endpoint: 'unified/entity', 
        id: id, 
        buildScreen: (data, userId) => ProducerLeisureScreen(
          producerId: data['_id'] ?? id,
          userId: userId,
        ),
      );
    } else if (entityType == 'event') {
      // Naviguer vers l'écran d'événement (EventLeisureScreen)
      _fetchAndNavigateWithUnifiedApi(
        endpoint: 'unified/entity', 
        id: id, 
        buildScreen: (data, userId) => EventLeisureScreen(
          id: data['_id'] ?? id,
          eventData: data,
        ),
      );
    } else if (entityType == 'user') {
      // Naviguer vers le profil utilisateur
      _navigateToUserProfile(id);
    } else if (entityType == 'producer') {
      // Naviguer vers l'écran du producteur (ProducerScreen)
      _fetchAndNavigateWithUnifiedApi(
        endpoint: 'unified/entity', 
        id: id, 
        buildScreen: (data, userId) => ProducerScreen(
          producerId: data['_id'] ?? id,
          userId: userId,
          isWellness: data['isWellness'] ?? false,
        ),
      );
    } else {
      // Type d'entité non reconnu - envoyer un toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Type d'entité non reconnu: $entityType"),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  // Essaie de naviguer vers différents types d'entités en fonction de l'ID
  void _attemptNavigationWithMultipleTypes(String id) {
    // Try to navigate using a general approach or show a selection dialog
    _showNavigationError("Navigation vers un profil de type inconnu non implémentée.");
    // Alternatively, you could implement a more sophisticated approach:
    // - First try to fetch the entity type from an API
    // - Then navigate to the appropriate route
    // - Or show a selection dialog if multiple types are possible
  }
  
  // Affiche une erreur de navigation standardisée
  void _showNavigationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Récupère les données d'un producteur de loisirs et navigue vers son profil
  Future<void> _fetchAndNavigateToLeisureProducer(String id) async {
    if (!mounted) return;
    
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement des informations...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails du lieu de loisir",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${getBaseUrl()}/api/leisure/$id');
      final response = await http.get(url);
      
      // Fermer l'indicateur de chargement
      if (!mounted) return;
      Navigator.of(context).pop();
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(
              producerId: id,
              userId: widget.userId,
            ),
          ),
        );
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      // Fermer l'indicateur de chargement s'il est encore ouvert
      if (!mounted) return;
      
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Récupère les données d'un événement et navigue vers sa page
  void _fetchAndNavigateToEvent(String id) async {
    if (!mounted) return;

    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement de l'événement...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );

      final url = Uri.parse('${getBaseUrl()}/api/events/$id');
      
      try {
        final response = await http.get(url);
        
        // Fermer l'indicateur de chargement
        if (!mounted) return;
        Navigator.of(context).pop();
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (!mounted) return;
          
          // Naviguer vers l'écran d'événement
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventLeisureScreen(
                id: id,
                eventData: data,
              ),
            ),
          );
        } else {
          throw Exception("Erreur ${response.statusCode}: ${response.body}");
        }
      } catch (e) {
        // En cas d'erreur de requête
        if (!mounted) return;
        
        // Fermer l'indicateur de chargement s'il est encore ouvert
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        // Afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors du chargement: $e"),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Gérer les exceptions
      if (!mounted) return;
      
      // Fermer le dialogue si ouvert
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Ajouter une nouvelle fonction pour naviguer vers un producteur de bien-être
  Future<void> _fetchAndNavigateToWellnessProducer(String id) async {
    if (!mounted) return;
    
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement des informations...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails du bien-être",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${getBaseUrl()}/api/wellness/$id');
      final response = await http.get(url);
      
      // Fermer l'indicateur de chargement
      if (!mounted) return;
      Navigator.of(context).pop();
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        
        // Importer WellnessScreen à ajouter si pas déjà fait
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: id,
              userId: widget.userId,
              isWellness: true,
            ),
          ),
        );
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      // Fermer l'indicateur de chargement s'il est encore ouvert
      if (!mounted) return;
      
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Méthode générique pour récupérer des données et naviguer
  Future<void> _fetchAndNavigateWithUnifiedApi({
    required String endpoint,
    required String id,
    required Widget Function(Map<String, dynamic>, String) buildScreen,
  }) async {
    if (!mounted) return;

    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement en cours...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des informations",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );

      final url = Uri.parse('${getBaseUrl()}/api/$endpoint/$id');
      
      final response = await http.get(url);
      
      // Fermer l'indicateur de chargement
      if (!mounted) return;
      Navigator.of(context).pop();
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (!mounted) return;
        
        // Naviguer vers l'écran approprié
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => buildScreen(data, widget.userId),
          ),
        );
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      // Fermer l'indicateur de chargement s'il est encore ouvert
      if (!mounted) return;
      
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Method to scroll to the bottom of the conversation
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Navigate to the vibemap with a specific profile highlighted
  void _navigateToVibeMap(ProfileData profile) {
    // Try to extract location from structuredData
    final location = profile.structuredData != null ? profile.structuredData!['location'] : null;
    final lat = location != null ? location['latitude'] : null;
    final lng = location != null ? location['longitude'] : null;
    if (lat == null || lng == null) {
      _showNavigationError("Coordonnées manquantes pour la navigation vers la carte.");
      return;
    }
    try {
      context.push('/vibe-map?highlightId=${profile.id}&lat=$lat&lng=$lng');
    } catch (e) {
      _showNavigationError('Erreur de navigation vers la carte: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS; // Platform check
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        // ... (Existing AppBar code) ...
      ),
      body: Column(
        children: [
          // ... (Existing loading indicators, welcome card, etc.) ...

          // Conversation history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              // Calculate item count considering potential profile lists
              itemCount: _calculateListItemCount(),
              itemBuilder: (context, index) {
                // Determine what item to build at this index
                final item = _getItemForIndex(index);

                if (item['type'] == 'message') {
                  final message = item['data'] as Map<String, dynamic>;
                  if (message['type'] == 'typing') {
                    return _buildTypingIndicator();
                  }
                  return _buildMessageBubble(message, index); // Pass index for animation
                } else if (item['type'] == 'profile_list') {
                  final profiles = item['data'] as List<ProfileData>;
                  final messageIndex = item['message_index'] as int; // Get original message index for animation delay
                  return _buildHorizontalProfileList(profiles, messageIndex)
                      .animate(delay: (100 + 50 * messageIndex).ms) // Delay after message animation
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad);
                }
                return const SizedBox.shrink(); // Should not happen
              },
            ),
          ),

          // ... (Existing loading indicator and input area) ...
        ],
      ),
    );
  }

  // Helper to determine the total number of items in the list (messages + profile lists)
  int _calculateListItemCount() {
    int count = 0;
    for (final message in _conversations) {
      count++; // Increment for the message itself
      final metadata = message['metadata'] as Map<String, dynamic>? ?? {};
      final profiles = (metadata['profiles'] as List<dynamic>? ?? [])
          .whereType<ProfileData>()
          .toList();
      if (message['type'] == 'copilot' && profiles.isNotEmpty) {
        count++; // Increment for the profile list associated with this message
      }
    }
    return count;
  }

  // Helper to get the correct item (message or profile list) for a given ListView index
  Map<String, dynamic> _getItemForIndex(int index) {
    int currentItemIndex = 0;
    int messageIndex = 0; // Keep track of the original message index
    for (final message in _conversations) {
      // Check if the current item is the message itself
      if (currentItemIndex == index) {
        return {'type': 'message', 'data': message};
      }
      currentItemIndex++;
      messageIndex++; // Increment message index after processing the message itself

      // Check if this message has an associated profile list
      final metadata = message['metadata'] as Map<String, dynamic>? ?? {};
      final profiles = (metadata['profiles'] as List<dynamic>? ?? [])
          .whereType<ProfileData>()
          .toList();
      if (message['type'] == 'copilot' && profiles.isNotEmpty) {
        // Check if the current item is the profile list
        if (currentItemIndex == index) {
          return {'type': 'profile_list', 'data': profiles, 'message_index': messageIndex -1}; // Return profile list and original message index
        }
        currentItemIndex++;
      }
    }
    // Should not be reached if _calculateListItemCount is correct
    throw Exception("Index out of bounds in _getItemForIndex");
  }

  // --- Updated _buildMessageBubble ---
  Widget _buildMessageBubble(Map<String, dynamic> message, int listIndex) {
    final isUser = message['type'] == 'user';
    final metadata = message['metadata'] as Map<String, dynamic>? ?? {};
    final bool isError = metadata['type'] == 'error';
    final bool isLoading = metadata['isLoading'] == true; // Check if it's a loading placeholder
    // Get text from metadata if available, otherwise from content (for user messages or older formats)
    final String text = metadata['text'] as String? ?? message['content'] as String? ?? '';
    final isIOS = Platform.isIOS;

    // Handle loading message bubble separately
    if (isLoading) {
      return _buildLoadingMessage(text);
    }

    // Regular message bubble rendering
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isIOS ? 6.0 : 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser),
          SizedBox(width: isIOS ? 8.0 : 10.0),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isIOS ? 14.0 : 16.0,
                vertical: isIOS ? 10.0 : 12.0,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.deepPurple.shade600
                    : (isError ? Colors.red.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(isIOS ? 18.0 : 20.0).copyWith(
                  bottomLeft: isUser ? Radius.circular(isIOS ? 18.0 : 20.0) : const Radius.circular(4),
                  bottomRight: !isUser ? Radius.circular(isIOS ? 18.0 : 20.0) : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isIOS ? 0.1 : 0.08),
                    blurRadius: isIOS ? 4.0 : 6.0,
                    offset: isIOS ? const Offset(0, 1) : const Offset(0, 2),
                  ),
                ],
                border: !isUser ? Border.all(
                  color: isError
                      ? Colors.red.withOpacity(0.2)
                      : (isIOS ? Colors.grey.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
                  width: isIOS ? 0.5 : 1.0,
                ) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Message Content Section (Text Only) ---
                  if (isUser)
                    SelectableText(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isIOS ? 15.0 : 16.0,
                        height: 1.4,
                        letterSpacing: isIOS ? -0.2 : 0,
                      ),
                    )
                  else // Copilot message rendering (Handles links within text)
                    SelectableText.rich(
                      TextSpan(
                        style: TextStyle(
                          color: isError ? Colors.red.shade800 : Colors.black87,
                          fontSize: isIOS ? 15.0 : 16.0,
                          height: 1.4,
                          letterSpacing: isIOS ? -0.2 : 0,
                        ),
                        // Use the existing parser for links within the text
                        children: AIService.parseMessageWithLinks(
                          text,
                          (type, id) => _navigateToProfile(type, id),
                        ),
                      ),
                      enableInteractiveSelection: true,
                      showCursor: true,
                      cursorWidth: 2.0,
                      cursorColor: Colors.deepPurple,
                    ),
                  // --- End Message Content Section ---

                  // --- Message Footer Section ---
                  // Pass the original message map to the footer builder
                  _buildMessageFooter(message),
                  // --- End Message Footer Section ---
                ],
              ),
            ),
          ).animate(delay: (50 * listIndex).ms) // Animate based on list index
            .fadeIn(duration: 300.ms)
            .slideX(
              begin: isUser ? 0.2 : -0.2,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic
            ),
          SizedBox(width: isIOS ? 8.0 : 10.0),
          if (isUser) _buildAvatar(isUser),
        ],
      ),
    );
  }
  // --- End Updated _buildMessageBubble ---


  // --- New Helper Function for Horizontal Profile List ---
  Widget _buildHorizontalProfileList(List<ProfileData> profiles, int messageIndex) {
    if (profiles.isEmpty) {
      return const SizedBox.shrink(); // Don't render if no profiles
    }

    final isIOS = Platform.isIOS;

    return Container(
      height: 160, // Adjusted height for compact cards + padding
      margin: const EdgeInsets.only(top: 4.0, bottom: 8.0), // Add some margin
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        // Add padding for the list itself
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        physics: const BouncingScrollPhysics(), // Nice scroll physics
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return Padding(
            // Padding between cards
            padding: EdgeInsets.only(
              right: index < profiles.length - 1 ? 12.0 : 0, // No padding after last card
            ),
            // Use the existing compact card builder
            child: _buildCompactProfileCard(profile)
                // Add subtle animation per card, delayed further
                .animate(delay: (150 + 50 * messageIndex + 30 * index).ms)
                .fadeIn(duration: 250.ms)
                .move(begin: const Offset(0, 10), end: Offset.zero, curve: Curves.easeOut),
          );
        },
      ),
    );
  }
  // --- End New Helper Function ---


  // ... (Existing helper functions: _formatTimestamp, _buildAvatar, _buildMessageFooter, _getIntentLabel, _buildCompactProfileCard, _getIconForType, _getColorForType, _navigateToVibeMap, _buildLoadingMessage, etc.) ...

  // Builds the compact profile card (ensure implementation matches your needs)
  Widget _buildCompactProfileCard(ProfileData profile) {
    final Color typeColor = _getColorForType(profile.type ?? 'unknown');
    final IconData typeIcon = _getIconForType(profile.type ?? 'unknown');
    String imageUrl = profile.image ?? '';
    final baseUrl = constants.getBaseUrlSync(); // Or use await getBaseUrl() if async needed

    if (imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
        imageUrl = imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';
      }
    } else {
      imageUrl = ''; // Default placeholder handled by CachedNetworkImage
    }

    return Material(
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () => _navigateToProfile(profile.type, profile.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 130, // Compact width
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              Container(
                height: 70,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.4), size: 20)),
                    errorWidget: (context, url, error) => Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.5), size: 24)),
                  ),
                ),
              ),
              // Text section
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text(
                        profile.name ?? 'Inconnu',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                     ),
                     const SizedBox(height: 3),
                     if (profile.rating != null && profile.rating! > 0)
                       Row(
                          children: [
                            Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 14),
                            const SizedBox(width: 3),
                            Text(
                               profile.rating!.toStringAsFixed(1),
                               style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                       ),
                   ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the loading indicator message bubble
  Widget _buildLoadingMessage(String text) {
    final isIOS = Platform.isIOS;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isIOS ? 6.0 : 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(false), // Copilot avatar
          SizedBox(width: isIOS ? 8.0 : 10.0),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isIOS ? 14.0 : 16.0,
                vertical: isIOS ? 10.0 : 12.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isIOS ? 18.0 : 20.0).copyWith(bottomLeft: const Radius.circular(4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isIOS ? 0.1 : 0.08),
                    blurRadius: isIOS ? 4.0 : 6.0,
                    offset: isIOS ? const Offset(0, 1) : const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isIOS ? Colors.grey.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                  width: isIOS ? 0.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(radius: isIOS ? 10.0 : 12.0),
                  const SizedBox(width: 12),
                  Flexible( // Allow text to wrap if long
                    child: Text(
                      text.isNotEmpty ? text : "Traitement...", // Shorter default text
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: isIOS ? 15.0 : 16.0,
                      ),
                      overflow: TextOverflow.ellipsis, // Prevent overflow
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the typing indicator (dots animation)
  Widget _buildTypingIndicator() {
    // Similar structure to loading message but with dots
    final isIOS = Platform.isIOS;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isIOS ? 6.0 : 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(false),
          SizedBox(width: isIOS ? 8.0 : 10.0),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isIOS ? 14.0 : 16.0,
                vertical: isIOS ? 12.0 : 14.0, // Slightly more vertical padding for dots
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isIOS ? 18.0 : 20.0).copyWith(bottomLeft: const Radius.circular(4)),
                // Add shadows and borders if needed, like in _buildLoadingMessage
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isIOS ? 0.1 : 0.08),
                    blurRadius: isIOS ? 4.0 : 6.0,
                    offset: isIOS ? const Offset(0, 1) : const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isIOS ? Colors.grey.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                  width: isIOS ? 0.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDot(0),
                  const SizedBox(width: 4),
                  _buildDot(150),
                  const SizedBox(width: 4),
                  _buildDot(300),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for typing indicator dots
  Widget _buildDot(int delay) {
    // Ensure _typingAnimationController is initialized and disposed properly
    // Use FadeTransition or similar for animation
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _typingAnimationController, // Make sure this controller is active
        curve: Interval((delay / 600.0).clamp(0.0, 1.0), 1.0, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // Builds the avatar for user or copilot
  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? Colors.deepPurple.shade300 : Colors.teal,
      child: Icon(
        isUser ? Icons.person_outline : Icons.emoji_objects_outlined, // Use outlined icons
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // Builds the footer for a message bubble
  Widget _buildMessageFooter(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';
    final metadata = message['metadata'] as Map<String, dynamic>? ?? {};
    final isError = metadata['type'] == 'error';
    final String? intent = metadata['intent'] as String?;
    final int? resultCount = metadata['resultCount'] as int?;
    // Ensure timestamp exists and is a string before parsing
    final timestampString = message['timestamp'] as String?;
    final timestamp = timestampString != null
        ? _formatTimestamp(timestampString) // Format if valid
        : ''; // Provide empty string or default if invalid/missing
    final isIOS = Platform.isIOS;

    // Don't show footer for loading messages
    if (metadata['type'] == 'loading') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Align to start
        mainAxisSize: MainAxisSize.min, // Take minimum space
        children: [
          Text(
            timestamp, // Use formatted timestamp
            style: TextStyle(
              color: isUser ? Colors.white70 : Colors.grey[600],
              fontSize: isIOS ? 11.0 : 12.0,
            ),
          ),
          // Result count badge (if available and not error/user)
          if (!isUser && !isError && resultCount != null && resultCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$resultCount résultat${resultCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.deepPurple[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          // Intent badge (if available and not error/user/unknown)
          if (!isUser && !isError && intent != null && intent != 'unknown' && intent != 'error' && intent != 'welcome') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getIntentLabel(intent), // Use helper for friendly label
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.teal[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Formats the timestamp string
  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp).toLocal(); // Convert to local time
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      // Consider using the intl package for more robust formatting
      // import 'package:intl/intl.dart';
      if (messageDate == today) {
        // return DateFormat('HH:mm').format(dateTime); // Example with intl
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

      } else {
        // return DateFormat('dd/MM HH:mm').format(dateTime); // Example with intl
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print("Error formatting timestamp '$timestamp': $e");
      return "--:--"; // Fallback for invalid format
    }
  }

  // Gets a user-friendly label for an intent
  String _getIntentLabel(String intent) {
    switch (intent.toLowerCase()) {
      case 'restaurant_search': return 'Restaurant';
      case 'leisure_search': return 'Loisir';
      case 'event_search': return 'Événement';
      case 'wellness_search': return 'Bien-être';
      case 'beauty_search': return 'Beauté';
      case 'recommendation': return 'Suggestion';
      case 'information': return 'Info';
      case 'producer_analysis': return 'Analyse Pro';
      // Add more mappings as needed
      default:
        // Capitalize first letter as a simple default formatting
        if (intent.isEmpty) return 'Inconnu';
        return intent[0].toUpperCase() + intent.substring(1);
    }
  }

  // Gets the icon for a profile type
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant': return Icons.restaurant_menu_outlined;
      case 'leisureproducer': return Icons.local_activity_outlined;
      case 'wellnessproducer': return Icons.spa_outlined;
      case 'beautyplace': return Icons.face_retouching_natural_outlined;
      case 'event': return Icons.event_outlined;
      case 'user': return Icons.person_outline;
      default: return Icons.place_outlined;
    }
  }

  // Gets the color for a profile type
  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant': return Colors.orange.shade600;
      case 'leisureproducer': return Colors.purple.shade600;
      case 'wellnessproducer': return Colors.teal.shade600;
      case 'beautyplace': return Colors.pink.shade400;
      case 'event': return Colors.green.shade600;
      case 'user': return Colors.blue.shade600;
      default: return Colors.grey.shade600;
    }
  }

  // Added missing _navigateToUserProfile
  void _navigateToUserProfile(String userId) {
    if (userId.isEmpty) {
      _showNavigationError("ID utilisateur manquant.");
      return;
    }
    // Use GoRouter if configured, otherwise use Navigator
    try {
      context.push('/profile/$userId');
    } catch (e) {
      print("GoRouter navigation to profile failed: $e");
      // Fallback or show specific error
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
      );
    }
  }

  // --- Navigation ---
  void _navigateToProfile(String type, String id) {
    print('📊 Navigation vers le profil de type $type avec ID: $id');
    if (id.isEmpty) {
      _showNavigationError("ID manquant pour la navigation.");
      return;
    }
    try {
      switch (type.toLowerCase()) {
        case 'restaurant':
          context.push('/producers/$id');
          break;
        case 'leisureproducer':
          context.push('/leisureProducers/$id');
          break;
        case 'wellnessproducer':
          context.push('/wellness/$id?isWellness=true');
          break;
        case 'beautyplace':
          context.push('/wellness/$id?isBeauty=true');
          break;
        case 'event':
          context.push('/events/$id');
          break;
        case 'user':
          _navigateToUserProfile(id);
          break;
        case 'generic':
        case 'unknown':
          _attemptNavigationWithMultipleTypes(id);
          break;
        default:
          _showNavigationError("Type de profil non reconnu: $type");
      }
    } catch (e) {
      _showNavigationError('Erreur de navigation GoRouter: $e');
    }
  }
}