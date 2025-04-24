import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'utils.dart';
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
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = false;
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  
  final AIService _aiService = AIService(); // Instance du service AI
  List<ProfileData> _topExtractedProfiles = []; // Profils affichés en haut

  // Attributs pour gérer différents types d'utilisateurs
  String _accountType = 'user'; // Par défaut: utilisateur standard
  bool _isProducer = false; // Flag pour identifier si c'est un producteur
  String? _producerId; // ID producteur si applicable
  bool _isLoadingAccountInfo = true; // Indicateur de chargement des infos de compte
  Map<String, dynamic> _userData = {}; // Données de l'utilisateur
  
  // Nouveaux attributs pour optimisation
  bool _topProfilesExpanded = false; // État d'expansion des profils du haut
  final int _initialTopProfilesCount = 3; // Nombre initial de profils à afficher en haut
  bool _hasMoreTopProfilesToLoad = false; // Indicateur pour "Voir plus" en haut

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
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

  // Application du lazy loading aux profils affichés en haut
  void _applyLazyLoadingToTopList(List<ProfileData> allProfiles) {
    if (allProfiles.isEmpty) {
      _topExtractedProfiles = [];
      _hasMoreTopProfilesToLoad = false;
      return;
    }
    
    // Si on a peu de profils, on les montre tous directement en haut
    if (allProfiles.length <= _initialTopProfilesCount) {
      _topExtractedProfiles = List.from(allProfiles);
      _hasMoreTopProfilesToLoad = false;
      return;
    }
    
    // Sinon on applique le lazy loading pour la liste du haut
    if (!_topProfilesExpanded) {
      _topExtractedProfiles = allProfiles.take(_initialTopProfilesCount).toList();
      _hasMoreTopProfilesToLoad = true;
    } else {
      _topExtractedProfiles = List.from(allProfiles);
      _hasMoreTopProfilesToLoad = false;
    }
  }
  
  // Charge plus de profils dans la liste du haut
  void _loadMoreTopProfiles() {
    // On doit se souvenir de tous les profils de la dernière réponse pour pouvoir tous les afficher
    // On suppose que la dernière réponse AI est celle qui a les profils complets
    final lastAiMessage = _conversations.lastWhere(
        (msg) => msg['type'] == 'copilot' && msg['profiles'] != null, 
        orElse: () => {'profiles': <ProfileData>[]} // Fallback
    );
    final allProfilesFromLastResponse = List<ProfileData>.from(lastAiMessage['profiles'] ?? []);

    if (allProfilesFromLastResponse.isNotEmpty) {
      setState(() {
        _topProfilesExpanded = true;
        _applyLazyLoadingToTopList(allProfilesFromLastResponse);
      });
    }
  }

  // Charge les informations du compte pour adapter l'interface
  Future<void> _loadAccountInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingAccountInfo = true;
    });
    
    try {
      // Récupérer les infos utilisateur pour déterminer le type de compte
      final url = Uri.parse('${getBaseUrl()}/api/users/${widget.userId}');
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
    if (_isProducer) {
      // Analyse automatique au démarrage pour les producteurs
      if (_producerId != null) {
        _runProducerAnalysis();
      }
    }
  }
  
  // Exécute une analyse pour les producteurs
  Future<void> _runProducerAnalysis() async {
    if (_producerId == null) return;
    
    try {
      final analysisResponse = await _aiService.producerAnalysis(_producerId!);
      
      if (!analysisResponse.hasError && mounted) {
        setState(() {
          _conversations.add({
            'type': 'copilot',
            'content': analysisResponse.response,
            'timestamp': DateTime.now().toIso8601String(),
            'hasProfiles': analysisResponse.profiles.isNotEmpty,
            'intent': 'producer_analysis',
            'resultCount': analysisResponse.resultCount,
          });
          
          if (analysisResponse.profiles.isNotEmpty) {
            _topExtractedProfiles = analysisResponse.profiles;
          }
        });
      }
    } catch (e) {
      print('Erreur lors de l\'analyse producteur: $e');
    }
  }

  // Modifier _sendQuestion pour corriger l'affichage de la réponse
  Future<void> _sendQuestion(String question) async {
    if (question.trim().isEmpty) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isTyping = true;
      _topExtractedProfiles = []; // Réinitialiser les profils du haut
      _topProfilesExpanded = false; // Réinitialiser l'état d'expansion
      _hasMoreTopProfilesToLoad = false;
      
      _conversations.add({
        'type': 'user',
        'content': question,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _questionController.clear();
    });

    // Scroll to bottom after adding user message
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    
    // Add typing indicator
    if (!mounted) return;
    setState(() {
      _conversations.add({
        'type': 'typing',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    
    // Scroll to typing indicator
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    try {
      // Utiliser le service AI pour obtenir une réponse enrichie en fonction du type de compte
      AIQueryResponse aiResponse;
      try {
        // Choisir le bon type de requête selon le type de compte
        if (_isProducer && _producerId != null) {
          // Requête producteur
          print('🔍 Envoi de requête producteur: "$question" (producerId: $_producerId)');
          aiResponse = await _aiService.producerQuery(_producerId!, question);
        } else {
          // Requête utilisateur complexe (plus robuste)
          print('🔍 Envoi de requête utilisateur complexe: "$question" (userId: ${widget.userId})');
          // *** CHANGED: Call complex query endpoint ***
          aiResponse = await _aiService.complexUserQuery(widget.userId, question); 
        }
        
        // Debug: afficher la réponse complète
        print('📊 Réponse reçue: ${aiResponse.response.length} caractères');
        print('📊 Contenu de la réponse: "${aiResponse.response}"');
        print('📊 Profils extraits: ${aiResponse.profiles.length}');
        if (aiResponse.profiles.isNotEmpty) {
          final profile = aiResponse.profiles.first;
          print('📊 Premier profil: ID=${profile.id}, Type=${profile.type}, Nom=${profile.name}');
        }
        
      } catch (primaryError) {
        print("⚠️ Premier essai échoué, tentative avec requête simple: $primaryError");
        try {
          // Deuxième essai - requête simple (fallback)
          print('🔄 Tentative avec requête simple: "$question"');
          aiResponse = await _aiService.simpleQuery(question);
        } catch (secondaryError) {
          print("❌ Tous les essais ont échoué: $secondaryError");
          throw secondaryError; // Relance l'erreur pour être attrapée par le bloc catch externe
        }
      }
      
      // Supprimer l'indicateur de frappe
      if (!mounted) return;
      setState(() {
        _conversations.removeWhere((msg) => msg['type'] == 'typing');
        _isTyping = false;
      });
      
      // Enregistrer les profils extraits s'il y en a
      if (aiResponse.profiles.isNotEmpty) {
          if (!mounted) return;
          setState(() {
          // Normaliser les types de profils pour une meilleure compatibilité
          for (var i = 0; i < aiResponse.profiles.length; i++) {
            var profile = aiResponse.profiles[i];
            // Si type générique ou inconnu, essayer de déterminer le type à partir des données
            if (profile.type == 'generic' || profile.type == 'unknown') {
              // Détecter le type en fonction du contenu des catégories ou des noms
              final String name = profile.name.toLowerCase();
              final List<String> categories = profile.category.map((c) => c.toLowerCase()).toList();
              
              // Debug pour le développement
              print('🔍 Normalisation du type pour: ${profile.name}');
              print('🔍 Catégories: ${profile.category.join(', ')}');
              
              // Restaurant
              if (categories.any((cat) => 
                  cat.contains('restaurant') || 
                  cat.contains('gastronomie') ||
                  cat.contains('cuisine') ||
                  cat.contains('food'))) {
                aiResponse.profiles[i] = profile.copyWith(type: 'restaurant');
                
              // Lieu de loisirs (dont les théâtres)
              } else if (categories.any((cat) => 
                  cat.contains('loisir') || 
                  cat.contains('thé') ||  // Couvre "théâtre"
                  cat.contains('culture') ||
                  cat.contains('spectacle') ||
                  cat.contains('salle') ||
                  cat.contains('musée')) || 
                  name.contains('théâtre') ||
                  name.contains('theatre') ||
                  name.contains('comédie') ||
                  name.contains('comedie')) {
                aiResponse.profiles[i] = profile.copyWith(type: 'leisureProducer');
              
              // Évènement
              } else if (categories.any((cat) => 
                  cat.contains('évènement') || 
                  cat.contains('evenement') ||
                  cat.contains('event'))) {
                aiResponse.profiles[i] = profile.copyWith(type: 'event');
              
              // Bien-être
              } else if (categories.any((cat) => 
                  cat.contains('bien-être') || 
                  cat.contains('bien être') ||
                  cat.contains('spa') ||
                  cat.contains('massage') ||
                  cat.contains('wellness'))) {
                aiResponse.profiles[i] = profile.copyWith(type: 'wellnessProducer');
              
              // Beauté
              } else if (categories.any((cat) => 
                  cat.contains('beauté') || 
                  cat.contains('beauty') ||
                  cat.contains('salon') ||
                  cat.contains('coiffure'))) {
                aiResponse.profiles[i] = profile.copyWith(type: 'beautyPlace');
              
              // Par défaut: considérer comme restaurant si aucun match
              } else {
                // Si nous ne pouvons pas déterminer, garder le type générique
                // pour permettre à l'API de détection de type de fonctionner
                print('⚠️ Type indéterminé pour: ${profile.name}, conservé comme ${profile.type}');
              }
              
              // Afficher le résultat de la normalisation
              print('✅ Type normalisé: ${profile.name} => ${aiResponse.profiles[i].type}');
            }
          }
          
          _topExtractedProfiles = aiResponse.profiles;
          _applyLazyLoadingToTopList(_topExtractedProfiles); // Appliquer le lazy loading
        });
      }

      if (!mounted) return;
      setState(() {
        // S'assurer que la réponse n'est pas vide
        String responseText = aiResponse.response.trim();
        if (responseText.isEmpty) {
          responseText = "Je n'ai pas bien compris votre demande. Pouvez-vous reformuler ?";
        } else if (responseText.isEmpty && _topExtractedProfiles.isNotEmpty) {
          responseText = "Voici quelques suggestions qui pourraient vous intéresser.";
        }
        
        _conversations.add({
          'type': 'copilot',
          'content': responseText,
          'timestamp': DateTime.now().toIso8601String(),
          'profiles': _topExtractedProfiles, // Store the processed profiles here
          'hasProfiles': _topExtractedProfiles.isNotEmpty, // Convenience flag
          'intent': aiResponse.intent,
          'resultCount': aiResponse.resultCount,
        });
        _isLoading = false;
      });

      // Scroll to bottom after adding copilot response
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      // Supprimer l'indicateur de frappe
      if (!mounted) return;
      setState(() {
        _conversations.removeWhere((msg) => msg['type'] == 'typing');
        _isTyping = false;
        _conversations.add({
          'type': 'copilot',
          'content': 'Une erreur s\'est produite. Veuillez vérifier votre connexion et réessayer.\nErreur: $e',
          'timestamp': DateTime.now().toIso8601String(),
          'error': true,
          'profiles': <ProfileData>[], // Ensure profiles field exists even on error
        });
        _isLoading = false;
        _topExtractedProfiles = []; // Clear top profiles on error
        _hasMoreTopProfilesToLoad = false;
      });
      _scrollToBottom(); // Scroll after error message
    }
  }

  // Helper to scroll to bottom
  void _scrollToBottom() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
  void _navigateToProfile(String type, String id) {
    print('📊 Navigation vers le profil de type $type avec ID: $id');
    
    try {
      // Si le type est générique, essayer de déterminer le type réel
      if (type == 'generic' || type == 'unknown') {
        // Format MongoDB ObjectId: 24 caractères hexadécimaux
        if (id.length == 24 && RegExp(r'^[0-9a-f]{24}$').hasMatch(id)) {
          // Tenter d'abord de charger en tant que restaurant (cas le plus fréquent)
          _attemptNavigationWithMultipleTypes(id);
          return;
        } else {
          // Format non reconnu
          _showNavigationError("Format d'ID non reconnu: $id");
          return;
        }
      }
      
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
          _fetchAndNavigateToLeisureProducer(id);
          break;
        case 'wellnessProducer':
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
          break;
        case 'beautyPlace':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId,
                isBeauty: true,
              ),
            ),
          );
          break;
        case 'event':
          _fetchAndNavigateToEvent(id);
          break;
        case 'user':
          _navigateToUserProfile(id);
          break;
        default:
          // Essayer une navigation plus générique pour les autres types
          _attemptNavigationWithMultipleTypes(id);
      }
    } catch (e) {
      _showNavigationError('Erreur de navigation: $e');
    }
  }
  
  // Essaie de naviguer vers différents types d'entités en fonction de l'ID
  void _attemptNavigationWithMultipleTypes(String id) {
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Détection du type de lieu...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Nous déterminons le type d'entité",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
    
    // Tentative de détection du type d'entité via l'API
    final url = Uri.parse('${getBaseUrl()}/api/ai/detect-producer-type/$id');
    http.get(url).then((response) {
      if (!mounted) return;
      
      // Fermer l'indicateur de chargement
      Navigator.of(context).pop();
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final detectedType = data['producerType'];
        
        // Naviguer en fonction du type détecté
        if (detectedType == 'restaurant') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId,
              ),
            ),
          );
        } else if (detectedType == 'leisureProducer') {
          _fetchAndNavigateToLeisureProducer(id);
        } else if (detectedType == 'wellnessProducer') {
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
        } else if (detectedType == 'beautyPlace') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId,
                isBeauty: true,
              ),
            ),
          );
        } else if (detectedType == 'event') {
          _fetchAndNavigateToEvent(id);
        } else if (detectedType == 'user') {
          _navigateToUserProfile(id);
      } else {
          // Type non reconnu, essayer une approche universelle avec l'endpoint unifié
          _fetchAndNavigateWithUnifiedApi(id);
        }
      } else {
        // Si la détection échoue, essayer l'API unifiée
        _fetchAndNavigateWithUnifiedApi(id);
      }
    }).catchError((e) {
      if (!mounted) return;
      
      // Fermer l'indicateur de chargement s'il est encore ouvert
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Tenter l'API unifiée en cas d'erreur
      _fetchAndNavigateWithUnifiedApi(id);
    });
  }
  
  // Affiche une erreur de navigation standardisée
  void _showNavigationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement des informations...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails du lieu",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
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
            builder: (context) => ProducerLeisureScreen(producerData: data),
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
  Future<void> _fetchAndNavigateToEvent(String id) async {
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement de l'événement...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails et informations",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${getBaseUrl()}/api/events/$id');
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
            builder: (context) => EventLeisureScreen(eventData: data),
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

  // Ajouter une nouvelle fonction pour naviguer vers un lieu de beauté
  Future<void> _fetchAndNavigateToBeautyPlace(String id) async {
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.pink),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement des informations...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails du lieu de beauté",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      final url = Uri.parse('${getBaseUrl()}/api/beauty_places/$id');
      final response = await http.get(url);
      
      // Fermer l'indicateur de chargement
      if (!mounted) return;
      Navigator.of(context).pop();
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        
        // Utiliser ProducerScreen avec le flag isBeauty
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: id,
              userId: widget.userId,
              isBeauty: true,
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

  // Ajouter une nouvelle fonction pour naviguer vers un profil utilisateur
  void _navigateToUserProfile(String userId) {
    if (!mounted) return;
    
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            userId: userId,
            viewMode: 'public',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la navigation vers le profil: $e"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Ajouter une nouvelle fonction pour utiliser l'API unifiée
  Future<void> _fetchAndNavigateWithUnifiedApi(String id) async {
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
                  "Chargement des informations...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Tentative avec l'API unifiée",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
    
    final url = Uri.parse('${getBaseUrl()}/api/unified/$id');
    final response = await http.get(url);
    
    // Fermer l'indicateur de chargement
    if (!mounted) return;
      Navigator.of(context).pop();

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (!mounted) return;
        
        final String dataType = data['type'] ?? 'unknown';
        
        // Naviguer en fonction du type détecté dans les données
        if (dataType == 'restaurant') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId,
              ),
            ),
          );
        } else if (dataType == 'leisureProducer') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerLeisureScreen(producerData: data),
            ),
          );
        } else if (dataType == 'wellnessProducer') {
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
        } else if (dataType == 'beautyPlace') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId,
                isBeauty: true,
              ),
            ),
          );
        } else if (dataType == 'event') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventLeisureScreen(eventData: data),
            ),
          );
        } else {
          // Fallback à ProducerScreen pour tout autre type
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId,
              ),
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            // Écouteur pour la reconnaissance vocale
            Consumer<VoiceRecognitionService>(
              builder: (context, voiceService, child) {
                // Animer le titre si la reconnaissance vocale est active
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: voiceService.isListening ? 12.0 : 0.0,
                  ),
                  decoration: BoxDecoration(
                    color: voiceService.isListening ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Copilot',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      if (voiceService.isListening) ...[
                        const SizedBox(width: 8),
                        _buildPulsingMicIndicator(),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (_isProducer) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(
            color: Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
        actions: [
          // Bouton de cartographie sensorielle
          if (!_isProducer) // Seulement pour les utilisateurs standards
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.mood, color: Colors.deepPurple, size: 26),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'Cartographie sensorielle',
                onPressed: () => _navigateToVibeMap(),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicateur de chargement des informations du compte
          if (_isLoadingAccountInfo)
            LinearProgressIndicator(
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(_isProducer ? Colors.blue : Colors.deepPurple),
              minHeight: 3,
            ),
          
          // Welcome card at the top
          if (_conversations.isEmpty && !_isLoadingAccountInfo)
            _buildWelcomeCard(),
          
          // Profils extraits affichés en haut (si présents)
          if (_topExtractedProfiles.isNotEmpty) ...[
            // Enhanced Profile section header with more visual impact
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.purple.withOpacity(0.1),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.place, color: Colors.purple.shade700, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggestions pour vous',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${_topExtractedProfiles.length} lieux correspondent à votre recherche',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_hasMoreTopProfilesToLoad)
                    TextButton(
                      onPressed: _loadMoreTopProfiles,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Voir tous',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.purple.shade700,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Responsive card container that adapts to different screen sizes
            SafeArea(
              bottom: false,
              child: Container(
                height: 200, // Slightly taller for more content
                margin: const EdgeInsets.only(bottom: 16),
                child: MediaQuery.of(context).size.width < 380
                    // Smaller screens (most iPhones) - show one card at a time with pageView
                    ? PageView.builder(
                        itemCount: _topExtractedProfiles.length,
                        controller: PageController(viewportFraction: 0.9),
                        padEnds: true,
                        itemBuilder: (context, index) {
                          final profile = _topExtractedProfiles[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: _buildProfileCard(profile)
                              .animate(delay: (50 * index).ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
                          );
                        },
                      )
                    // Larger screens - regular horizontal list
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _topExtractedProfiles.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        physics: const BouncingScrollPhysics(), // More native iOS feel
                        itemBuilder: (context, index) {
                          final profile = _topExtractedProfiles[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: _buildProfileCard(profile)
                              .animate(delay: (80 * index).ms)
                              .fadeIn(duration: 300.ms)
                              .slideX(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                          );
                        },
                      ),
              ),
            ),
          ],
          
          // Conversation history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _conversations.length,
              reverse: true, // Display messages from bottom to top
              itemBuilder: (context, index) {
                // Access messages in reverse order for display
                final message = _conversations[_conversations.length - 1 - index];
                if (message['type'] == 'typing') {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(message, index);
              },
            ),
          ),
          
          // Loading indicator
          if (_isLoading && !_isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              minHeight: 3,
              ),
            ),
          
          // Input area at the bottom
          _buildInputArea(),
        ],
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
     return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal,
              child: const Icon(
                Icons.emoji_objects,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: const Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildDot(0),
                  const SizedBox(width: 4),
                  _buildDot(150),
                  const SizedBox(width: 4),
                  _buildDot(300),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDot(int delay) {
     return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final delayedValue = (_typingAnimationController.value * 1000 - delay) / 500;
        final opacity = delayedValue.clamp(0.0, 1.0);
        final scale = 0.5 + (delayedValue.clamp(0.0, 0.5) * 1.0);
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  // Modifier le widget _buildProfileCard pour améliorer l'affichage des images et la gestion des types
  Widget _buildProfileCard(ProfileData profile) {
    final Color typeColor = _getColorForType(profile.type);
    final String typeLabel = _getTypeLabel(profile.type);
    final IconData typeIcon = _getIconForType(profile.type);
    
    // Déterminer l'URL de l'image avec une logique améliorée
    String imageUrl = '';
    
    // Tenter de récupérer l'URL de l'image du profil dans cet ordre:
    if (profile.image != null && profile.image!.isNotEmpty) {
      // URL directe depuis le profile
      imageUrl = profile.image!;
      print('🖼️ Image trouvée dans profile.image: $imageUrl');
    } else if (profile.structuredData != null) {
      // Chercher dans structuredData
      if (profile.structuredData!['photos'] != null) {
        if (profile.structuredData!['photos'] is List && profile.structuredData!['photos'].isNotEmpty) {
          print('📸 PHOTOS (liste): ${profile.structuredData!['photos'].length} photos');
          print('   - Première photo: ${profile.structuredData!['photos'][0].toString()}');
          imageUrl = profile.structuredData!['photos'][0].toString();
        } else if (profile.structuredData!['photos'] is String && profile.structuredData!['photos'].toString().isNotEmpty) {
          imageUrl = profile.structuredData!['photos'].toString();
        }
      } else if (profile.structuredData!['photo'] != null) {
        imageUrl = profile.structuredData!['photo'].toString();
        print('🖼️ PHOTO: $imageUrl');
      } else if (profile.structuredData!['image'] != null) {
        imageUrl = profile.structuredData!['image'].toString();
      }
      
      print('-----------------------------------');
    } else if (profile.businessData != null) {
      // Chercher dans businessData
      if (profile.businessData!['photos'] != null) {
        if (profile.businessData!['photos'] is List && profile.businessData!['photos'].isNotEmpty) {
          imageUrl = profile.businessData!['photos'][0].toString();
        } else if (profile.businessData!['photos'] is String && profile.businessData!['photos'].toString().isNotEmpty) {
          imageUrl = profile.businessData!['photos'].toString();
        }
      } else if (profile.businessData!['photo'] != null) {
        imageUrl = profile.businessData!['photo'].toString();
      } else if (profile.businessData!['image'] != null) {
        imageUrl = profile.businessData!['image'].toString();
      }
    }
    
    // Traitement spécifique des URL d'images
    if (imageUrl.isNotEmpty) {
      // Traitement des URLs de base64
      if (imageUrl.startsWith('data:image')) {
        // Pour les images base64, on les utilise directement
        print('🍽️ Image de restaurant trouvée (base64): ${imageUrl.substring(0, 50)}...');
      } 
      // Traitement des URLs Google Maps Photos
      else if (imageUrl.contains('maps.googleapis.com/maps/api/place/photo')) {
        // Les URLs Google Maps Photo sont déjà correctes
        print('🍽️ Image de restaurant trouvée (Google Maps): $imageUrl');
      }
      // Traitement des URLs relatives
      else if (!imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
        if (imageUrl.startsWith('/')) {
          imageUrl = '${getBaseUrl()}$imageUrl';
        } else {
          imageUrl = '${getBaseUrl()}/$imageUrl';
        }
        print('🍽️ Image de restaurant avec URL convertie: $imageUrl');
      }
      // Si c'est une URL normale mais sans http ou https
      else if (!imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
        imageUrl = 'https://' + imageUrl.replaceAll('//', '');
        print('🍽️ Image de restaurant avec préfixe ajouté: $imageUrl');
      } 
      // Si c'est une URL normale mais avec des doubles slashes
      else if (imageUrl.contains('//') && !imageUrl.startsWith('http')) {
        imageUrl = 'https:' + imageUrl;
        print('🍽️ Image de restaurant avec préfixe ajouté: $imageUrl');
      }
      else {
        // Afficher directement l'URL
        print('🍽️ Image de restaurant trouvée (photos[0]): $imageUrl');
      }
      
      // Nettoyer l'URL pour éviter les problèmes
      imageUrl = imageUrl.trim();
    } else {
      // Aucune image trouvée
      print('⚠️ Aucune image trouvée pour le restaurant: ${profile.name}');
    }
    
    // Image par défaut si aucune image trouvée
    if (imageUrl.isEmpty) {
      imageUrl = 'https://via.placeholder.com/300x200/e0e0e0/9e9e9e?text=${Uri.encodeComponent(typeLabel)}';
    }
    
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        onTap: () => _navigateToProfile(profile.type, profile.id),
        borderRadius: BorderRadius.circular(16),
        splashColor: typeColor.withOpacity(0.2),
        highlightColor: typeColor.withOpacity(0.1),
        child: Container(
          width: 180, // Plus large pour montrer plus d'information
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du profil avec effet de chargement amélioré
              Stack(
                children: [
                  // Container for fixed height before image loads
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  
                  // Image with loading and error handling
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24, 
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icon(typeIcon, color: Colors.grey[400], size: 24),
                          ],
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(typeIcon, color: typeColor.withOpacity(0.6), size: 40),
                            const SizedBox(height: 8),
                            Text(
                              typeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Gradient overlay for better text visibility
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Type badge with icon
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            typeLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Name overlay at bottom for enhanced visibility
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      profile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // Details section
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address with icon for better readability
                    if (profile.address != null && profile.address!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profile.address!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Bottom row with rating and categories
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rating with enhanced styling
                        if (profile.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  profile.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Category badges (if available)
                        if (profile.category.isNotEmpty)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: typeColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    profile.category.first,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: typeColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.category.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      "+${profile.category.length - 1}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  // Obtenir l'icône correspondant au type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'restaurant': return Icons.restaurant;
      case 'leisureProducer': return Icons.local_activity;
      case 'event': return Icons.event;
      case 'wellnessProducer': return Icons.spa; // Added
      case 'beautyPlace': return Icons.face_retouching_natural; // Added
      case 'user': return Icons.person;
      default: return Icons.place;
    }
  }
  
  // Obtenir la couleur correspondant au type
  Color _getColorForType(String type) {
     switch (type) {
      case 'restaurant': return Colors.orange;
      case 'leisureProducer': return Colors.purple;
      case 'event': return Colors.green;
      case 'wellnessProducer': return Colors.teal; // Added
      case 'beautyPlace': return Colors.pink; // Added
      case 'user': return Colors.blue;
      default: return Colors.grey;
    }
  }
  
  // Obtenir le libellé correspondant au type
  String _getTypeLabel(String type) {
    switch (type) {
      case 'restaurant': return 'Restaurant';
      case 'leisureProducer': return 'Loisir';
      case 'event': return 'Évènement';
      case 'wellnessProducer': return 'Bien-être'; // Added
      case 'beautyPlace': return 'Beauté'; // Added
      case 'user': return 'Utilisateur';
      default: return type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : 'Lieu'; // Default label
    }
  }

  // Navigation vers la cartographie sensorielle
  void _navigateToVibeMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VibeMapScreen(userId: widget.userId),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    // Personnaliser le contenu selon le type d'utilisateur
    final bool isProducer = _isProducer;
    final String welcomeTitle = isProducer ? 'Bienvenue sur Copilot Pro' : 'Bienvenue sur Copilot';
    final String welcomeSubtitle = isProducer ? 'Votre assistant professionnel' : 'Votre assistant personnel';
    final String welcomeDescription = isProducer
        ? 'Je suis là pour vous aider à optimiser votre activité, analyser vos données et comprendre votre clientèle. Posez-moi une question en langage naturel!'
        : 'Je suis là pour vous aider à découvrir des lieux et activités qui vous plairont. Posez-moi une question en langage naturel!';
    
    // Adapter les couleurs selon le type
    final List<Color> gradientColors = isProducer
        ? [Colors.blue.shade800, Colors.blue.shade500]
        : [Colors.deepPurple.shade800, Colors.purple.shade500];
    
    final Color shadowColor = isProducer ? Colors.blue : Colors.deepPurple;
    final Color iconBgColor = isProducer ? Colors.blue.shade900 : Colors.deepPurple.shade900;
    
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec icône
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isProducer ? Icons.analytics : Icons.emoji_objects,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    welcomeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    welcomeSubtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Description
          Text(
            welcomeDescription,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Titre des suggestions
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber.shade300,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Essayez par exemple :',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Adapter les suggestions en fonction du type d'utilisateur
          if (isProducer) ...[
            // Suggestions pour les producteurs
            _buildSuggestionChip('Analyse de ma performance du mois dernier')
              .animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
            _buildSuggestionChip('Comment me démarquer de la concurrence ?')
              .animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
            _buildSuggestionChip('Quelles sont les tendances actuelles dans mon secteur ?')
              .animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          ] else ...[
            // Suggestions pour les utilisateurs standards
            _buildSuggestionChip('Recommande-moi un restaurant romantique')
              .animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
            _buildSuggestionChip('Que faire ce weekend à Paris ?')
              .animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
            _buildSuggestionChip('Je cherche une pièce de théâtre pour ce soir')
              .animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1.0, 1.0),
      duration: 600.ms,
      curve: Curves.easeOutBack,
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return GestureDetector(
      onTap: () => _sendQuestion(suggestion),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                suggestion,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isUser = message['type'] == 'user';
    final hasError = message['error'] == true;
    // Check for profiles directly in the message map
    final List<ProfileData> profilesInMessage = List<ProfileData>.from(message['profiles'] ?? []);
    final hasProfiles = profilesInMessage.isNotEmpty;
    
    final isIOS = Platform.isIOS;
    
    // Animation properties
    final delay = (50 * index).ms; // Delay based on original index (before reverse)
    final slideBegin = isUser ? 0.2 : -0.2;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isIOS ? 6.0 : 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser),
          
          SizedBox(width: isIOS ? 8.0 : 10.0),
          
          // Message bubble with platform-specific styling for better visibility
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isIOS ? 14.0 : 16.0, 
                vertical: isIOS ? 12.0 : 14.0
              ),
              decoration: BoxDecoration(
                color: isUser 
                    ? Colors.deepPurple.shade600 
                    : (hasError ? Colors.red.shade50 : Colors.white),
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
                // Enhanced border for better visibility on all platforms
                border: !isUser ? Border.all(
                  color: hasError 
                      ? Colors.red.withOpacity(0.2)
                      : (isIOS ? Colors.grey.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
                  width: isIOS ? 0.5 : 1.0,
                ) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Display Text Content ---
                  _buildTextMessageContent(message, isUser, hasError, isIOS),

                  // --- Display Integrated Profiles (if any) ---
                  if (!isUser && hasProfiles) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 150, // Fixed height for integrated list
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: profilesInMessage.length,
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        itemBuilder: (context, profileIndex) {
                          final profile = profilesInMessage[profileIndex];
                          return Padding(
                             padding: const EdgeInsets.only(right: 10.0),
                             // Use a more compact card for integrated view
                             child: _buildCompactProfileCard(profile), 
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4), // Small space after profiles
                  ],
                  
                  // --- Display Timestamp and Metadata ---
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(message['timestamp']),
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey,
                          fontSize: isIOS ? 11.0 : 12.0,
                        ),
                      ),
                      if (!isUser && message['resultCount'] != null && message['resultCount'] > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.deepPurple.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${message['resultCount']} résultats',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      
                      // Intent badge (if available and no error)
                      if (!isUser && !hasError && message['intent'] != null && message['intent'] != 'unknown') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.teal.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getIntentLabel(message['intent']),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.teal[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ).animate(delay: delay) // Apply animation
            .fadeIn(duration: 300.ms)
            .slideX(
              begin: slideBegin,
              end: 0, 
              duration: 400.ms, 
              curve: Curves.easeOutCubic
            ),
          
          const SizedBox(width: 10),
          
          if (isUser) _buildAvatar(isUser),
        ],
      ),
    );
  }

  String _getIntentLabel(String intent) {
    // Retourner un label plus convivial pour chaque type d'intention
    switch (intent) {
      case 'restaurant_search':
        return 'Recherche resto';
      case 'event_search':
        return 'Recherche événement';
      case 'leisure_search':
        return 'Recherche loisir';
      case 'recommendation':
        return 'Recommandation';
      case 'information':
        return 'Information';
      default:
        return intent;
    }
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? Colors.deepPurple.shade300 : Colors.teal,
      child: Icon(
        isUser ? Icons.person : Icons.emoji_objects,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildInputArea() {
    final isIOS = Platform.isIOS;
    
        return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0, 
        vertical: isIOS ? 16.0 : 12.0
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isIOS ? 0.08 : 0.05),
            blurRadius: isIOS ? 8.0 : 10.0,
            offset: const Offset(0, -2),
          ),
        ],
        // Add a subtle top border for iOS
        border: isIOS ? const Border(
          top: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ) : null,
      ),
      child: Row(
        children: [
          // Input field with platform-specific styling
          Expanded(
            child: Container(
              // Add elevation effect for iOS
              decoration: isIOS ? BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ) : null,
              child: TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: 'Posez une question à Copilot...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: isIOS ? 15.0 : 16.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isIOS ? 25.0 : 30.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isIOS ? Colors.grey[50] : Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isIOS ? 16.0 : 20.0, 
                    vertical: isIOS ? 10.0 : 12.0
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isIOS ? CupertinoIcons.clear_circled_solid : Icons.clear,
                      color: Colors.grey,
                      size: isIOS ? 20.0 : 24.0,
                    ),
                    onPressed: () => _questionController.clear(),
                  ),
                  prefixIcon: VoiceSearchButton(
                    onResult: (text) {
                      setState(() {
                        _questionController.text = text;
                      });
                      _handleSearch();
                    },
                    tooltip: 'Recherche vocale pour Copilot',
                  ),
                ),
              style: TextStyle(
                fontSize: isIOS ? 15.0 : 16.0,
                  letterSpacing: isIOS ? -0.2 : 0,
                ),
                keyboardType: TextInputType.text,
                keyboardAppearance: isIOS ? Brightness.light : Brightness.dark,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) => _sendQuestion(value),
              ),
            ),
          ),
          
          // Send button with platform-specific styling
          Container(
            margin: EdgeInsets.only(left: isIOS ? 6.0 : 8.0),
            width: isIOS ? 44.0 : 48.0,
            height: isIOS ? 44.0 : 48.0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x55673AB7),
                  blurRadius: isIOS ? 6.0 : 8.0,
                  offset: isIOS ? const Offset(0, 1) : const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendQuestion(_questionController.text),
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Center(
                    child: Icon(
                      isIOS ? CupertinoIcons.paperplane_fill : Icons.send,
                      color: Colors.white,
                      size: isIOS ? 20.0 : 22.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // If message is from today, show time only
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Otherwise, show date and time
      return '${dateTime.day}/${dateTime.month} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showHelpDialog(BuildContext context) {
    // Adapter le contenu selon le type d'utilisateur
    final bool isProducer = _isProducer;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isProducer ? Icons.analytics : Icons.info_outline,
              color: isProducer ? Colors.blue.shade400 : Colors.deepPurple.shade400,
              size: 28,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProducer ? 'À propos de Copilot Pro' : 'À propos de Copilot',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  isProducer ? 'Votre assistant professionnel' : 'Votre assistant intelligent',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isProducer 
              ? _buildProducerHelpContent() 
              : _buildStandardHelpContent(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Compris !',
              style: TextStyle(
                color: isProducer ? Colors.blue.shade600 : Colors.deepPurple.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  // Contenu d'aide pour les utilisateurs standard
  List<Widget> _buildStandardHelpContent() {
    return [
      _buildHelpItem(
        'Recommandations',
        'Demandez des recommandations personnalisées basées sur vos préférences.',
        Icons.thumbs_up_down,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Découverte',
        'Explorez de nouveaux lieux et activités dans votre région.',
        Icons.explore,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Reconnaissance vocale',
        'Posez vos questions à l\'oral en appuyant sur l\'icône de microphone.',
        Icons.mic,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Cartographie sensorielle',
        'Visualisez des lieux selon vos émotions et ambiances recherchées.',
        Icons.mood,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Assistance',
        'Obtenez des réponses à vos questions sur l\'application.',
        Icons.help_outline,
      ),
      
      const SizedBox(height: 24),
      const Text(
        'Exemples de questions:',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _buildExampleItem('Pièce de théâtre ce soir'),
      _buildExampleItem('Restaurant avec des frites'),
      _buildExampleItem('Activité romantique à Paris'),
    ];
  }
  
  // Contenu d'aide pour les producteurs
  List<Widget> _buildProducerHelpContent() {
    return [
      _buildHelpItem(
        'Analyse de performance',
        'Obtenez des insights sur vos performances et votre clientèle.',
        Icons.bar_chart,
        color: Colors.blue,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Analyse concurrentielle',
        'Comprenez votre positionnement par rapport à la concurrence.',
        Icons.compare_arrows,
        color: Colors.blue,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Reconnaissance vocale',
        'Posez vos questions à l\'oral en appuyant sur l\'icône de microphone.',
        Icons.mic,
        color: Colors.blue,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Tendances du marché',
        'Découvrez les tendances actuelles dans votre secteur d\'activité.',
        Icons.trending_up,
        color: Colors.blue,
      ),
      const SizedBox(height: 12),
      _buildHelpItem(
        'Optimisation',
        'Identifiez des opportunités d\'amélioration pour votre business.',
        Icons.lightbulb_outline,
        color: Colors.blue,
      ),
      
      const SizedBox(height: 24),
      const Text(
        'Exemples de questions:',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _buildExampleItem('Analyse de mon taux d\'occupation'),
      _buildExampleItem('Quels plats sont les plus populaires ?'),
      _buildExampleItem('Comment améliorer mes avis clients ?'),
      _buildExampleItem('Tendances actuelles dans la restauration'),
    ];
  }

  Widget _buildExampleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.arrow_right, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon, {Color? color}) {
    final itemColor = color ?? Colors.deepPurple;
    
    return Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Container(
          padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
            color: itemColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: itemColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                                ),
                              const SizedBox(height: 4),
                                     Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
                                ),
                           ],
                        ),
                     ),
                   ],
    );
  }

  // Widget qui affiche une animation d'écoute lorsque la reconnaissance vocale est active
  Widget _buildPulsingMicIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 24,
          width: 24,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.2 * value),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.mic,
              color: Colors.deepPurple,
              size: 12 + 4 * value,
            ),
          ),
        );
      },
      onEnd: () {
        setState(() {
          // Re-exécuter l'animation à la fin
          _buildPulsingMicIndicator();
        });
      },
    );
  }

  void _handleSearch() {
    if (_questionController.text.isNotEmpty) {
      _sendQuestion(_questionController.text);
    }
  }

  // Fonction utilitaire pour extraire les coordonnées GPS d'un producteur
  Map<String, double>? extractGpsCoordinates(Map<String, dynamic>? gpsCoordinates) {
    if (gpsCoordinates == null) return null;
    
    try {
      // Format {type: Point, coordinates: [longitude, latitude]}
      if (gpsCoordinates.containsKey('type') && gpsCoordinates.containsKey('coordinates')) {
        final coordinates = gpsCoordinates['coordinates'];
        if (coordinates is List && coordinates.length >= 2) {
          // Vérifier et convertir les valeurs en double
          double lat, lng;
          try {
            // Les coordonnées GeoJSON sont en [longitude, latitude]
            lng = double.parse(coordinates[0].toString().replaceAll(',', '.'));
            lat = double.parse(coordinates[1].toString().replaceAll(',', '.'));
            return {
              'latitude': lat,
              'longitude': lng,
            };
          } catch (e) {
            print('Erreur de conversion des valeurs de coordonnées: $e');
            // Essai alternatif si les valeurs ne peuvent pas être converties directement
            return null;
          }
        }
      }
      
      // Format {latitude: X, longitude: Y}
      if (gpsCoordinates.containsKey('latitude') && gpsCoordinates.containsKey('longitude')) {
        try {
          double lat = double.parse(gpsCoordinates['latitude'].toString().replaceAll(',', '.'));
          double lng = double.parse(gpsCoordinates['longitude'].toString().replaceAll(',', '.'));
          return {
            'latitude': lat,
            'longitude': lng,
          };
        } catch (e) {
          print('Erreur de conversion lat/lng direct: $e');
          return null;
        }
      }
      
      // Format geometry.location de Google
      if (gpsCoordinates.containsKey('lat') && gpsCoordinates.containsKey('lng')) {
        try {
          double lat = double.parse(gpsCoordinates['lat'].toString().replaceAll(',', '.'));
          double lng = double.parse(gpsCoordinates['lng'].toString().replaceAll(',', '.'));
          return {
            'latitude': lat,
            'longitude': lng,
          };
        } catch (e) {
          print('Erreur de conversion format Google: $e');
          return null;
        }
      }
    } catch (e) {
      print('Erreur de conversion des coordonnées GPS: $gpsCoordinates - $e');
      return null;
    }
    
    // Aucun format reconnu
    print('Erreur de conversion des coordonnées GPS: $gpsCoordinates');
    return null;
  }

  // Helper to build text part of the message bubble
  Widget _buildTextMessageContent(Map<String, dynamic> message, bool isUser, bool hasError, bool isIOS) {
    final textContent = message['content']?.toString() ?? '';
    
    if (isUser) {
       return Text(
         textContent,
         style: TextStyle(color: Colors.white, fontSize: isIOS ? 15.0 : 16.0, height: 1.4),
       );
    } else {
       // Copilot message - use SelectableText.rich for link parsing
       return Container(
         width: double.infinity, 
         child: SelectableText.rich(
           TextSpan(
             style: TextStyle(
               color: hasError ? Colors.red.shade800 : Colors.black87,
               fontSize: isIOS ? 15.0 : 16.0,
               height: 1.4,
             ),
             children: AIService.parseMessageWithLinks( // Reuse existing parser
               textContent,
               (type, id) => _navigateToProfile(type, id),
             ),
           ),
           enableInteractiveSelection: true,
           showCursor: true,
           cursorWidth: 2.0,
           cursorColor: Colors.deepPurple,
         ),
       );
    }
  }

  // New: Build a more compact card for the integrated view inside the bubble
  Widget _buildCompactProfileCard(ProfileData profile) {
    final Color typeColor = _getColorForType(profile.type);
    final IconData typeIcon = _getIconForType(profile.type);
    String imageUrl = profile.image ?? '';
    // Simplified image URL logic for compact view
    if (imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
        imageUrl = '${getBaseUrl()}$imageUrl'; 
      }
    } else {
      imageUrl = ''; // No placeholder in compact view, just icon
    }

    return Material(
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
           onTap: () => _navigateToProfile(profile.type, profile.id),
           borderRadius: BorderRadius.circular(12),
           child: Container(
              width: 140, // Smaller width
              decoration: BoxDecoration(
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
              ),
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    // Image or Icon
                    Container(
                       height: 80, // Smaller height
                       width: double.infinity,
                       decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                             topLeft: Radius.circular(12),
                             topRight: Radius.circular(12),
                          ),
                       ),
                       child: imageUrl.isNotEmpty 
                           ? ClipRRect(
                               borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                               ),
                               child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.5), size: 24)),
                                  errorWidget: (context, url, error) => Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.6), size: 30)),
                               ),
                             )
                           : Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.7), size: 30)),
                    ),
                    // Details
                    Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                                profile.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                             ),
                             const SizedBox(height: 2),
                             if (profile.address != null && profile.address!.isNotEmpty)
                               Text(
                                  profile.address!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                               ),
                             const SizedBox(height: 4),
                              // Rating
                             if (profile.rating != null && profile.rating! > 0)
                               Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 14),
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
}
