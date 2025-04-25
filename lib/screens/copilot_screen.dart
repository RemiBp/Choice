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
            _topExtractedProfiles = analysisResponse.profiles;
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

  // Pour envoyer une question
  void _sendQuestion(String question) {
    if (question.isEmpty) return;

    final userMessage = {
      'type': 'user',
      'content': question,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final loadingMessage = {
      'type': 'copilot',
      'content': 'Analyse en cours...',
      'isLoading': true,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isLoading = true;
      _conversations.insert(0, loadingMessage);
      _conversations.insert(0, userMessage);
      _questionController.clear();
      _isTyping = false;
    });

    _scrollToBottom();

    // Appeler directement le service AI au lieu de l'analyse locale
    _callAiService(question);
  }

  // Renommer et modifier _handleGeneralQuery pour appeler l'API AI
  Future<void> _callAiService(String query) async {
      if (!mounted) return;
      
    // Vérifier que userId n'est pas null ou vide avant d'appeler l'API
    if (widget.userId == null || widget.userId.isEmpty) {
      setState(() {
        _conversations.removeWhere((msg) => msg['isLoading'] == true);
        _conversations.insert(0, {
          'type': 'copilot',
          'content': "Erreur: Identifiant utilisateur non disponible. Veuillez vous reconnecter.",
          'isError': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }
    
    try {
      // Utiliser le service AI pour traiter la requête utilisateur
      // Passer la requête utilisateur et l'ID utilisateur
      final AIQueryResponse aiResponse = await _aiService.complexUserQuery(
        widget.userId,
        query,
      );

      // Supprimer le message de chargement
      if (mounted) {
        setState(() {
          _conversations.removeWhere((msg) => msg['isLoading'] == true);
        });
      }

      // Traiter la réponse de l'IA
      if (mounted) {
        _processApiResponse(aiResponse);
      }

    } catch (e) {
      print("❌ Erreur lors de l'appel à l'IA: $e");
      if (mounted) {
        setState(() {
          _conversations.removeWhere((msg) => msg['isLoading'] == true);
          _conversations.insert(0, {
            'type': 'copilot',
            'content': "Désolé, une erreur est survenue. $e",
            'isError': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          _fetchAndNavigateWithUnifiedApi(endpoint: 'unified/entity', id: id, buildScreen: (data, userId) => ProducerLeisureScreen(
            producerId: data['producerId'],
            userId: userId,
          ));
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
        } else if (detectedType == 'event') {
          _fetchAndNavigateWithUnifiedApi(endpoint: 'unified/entity', id: id, buildScreen: (data, userId) => EventLeisureScreen(
            id: data['producerId'],
            eventData: null,
          ));
        } else if (detectedType == 'user') {
          _navigateToUserProfile(id);
        } else {
          // Type non reconnu, essayer une approche universelle avec l'endpoint unifié
          _fetchAndNavigateWithUnifiedApi(endpoint: 'unified/entity', id: id, buildScreen: (data, userId) => ProducerScreen(
            producerId: data['producerId'],
            userId: userId,
            isWellness: data['entityType'] == 'wellnessProducer',
          ));
        }
      } else {
        // Si la détection échoue, essayer l'API unifiée
        _fetchAndNavigateWithUnifiedApi(endpoint: 'unified/entity', id: id, buildScreen: (data, userId) => ProducerScreen(
          producerId: data['producerId'],
          userId: userId,
          isWellness: data['entityType'] == 'wellnessProducer',
        ));
      }
    }).catchError((e) {
      if (!mounted) return;
      
      // Fermer l'indicateur de chargement s'il est encore ouvert
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Tenter l'API unifiée en cas d'erreur
      _fetchAndNavigateWithUnifiedApi(endpoint: 'unified/entity', id: id, buildScreen: (data, userId) => ProducerScreen(
        producerId: data['producerId'],
        userId: userId,
        isWellness: data['entityType'] == 'wellnessProducer',
      ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // En-tête avec recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _analyzeAndNavigate(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  VoiceSearchButton(
                    onResult: (text) {
                      _searchController.text = text;
                      if (text.isNotEmpty) {
                        _analyzeAndNavigate(text);
                      }
                    },
                  ),
                ],
              ),
            ),
            
            // Conteneur principal
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section "Comment puis-je vous aider aujourd'hui?"
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "Comment puis-je vous aider aujourd'hui?",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          
                          // Widgets pour suggestions rapides
                          _buildQuickSuggestions(),
                          
                          // Vos recommandations personalisées
                          if (_recommendations.isNotEmpty) _buildRecommendations(),
                          
                          // Historique des conversations (si applicable)
                          if (_conversations.isNotEmpty) _buildConversationHistory(),
                          
                          const SizedBox(height: 70), // Espace pour le champ de texte en bas
                        ],
                      ),
                    ),
            ),
            
            // Barre de saisie en bas
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _questionController,
                        decoration: InputDecoration(
                          hintText: 'Posez votre question...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _sendQuestion(value);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      if (_questionController.text.isNotEmpty) {
                        _sendQuestion(_questionController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final List<Map<String, String>> suggestions = [
      {'icon': 'assets/icons/restaurant.png', 'text': 'Restaurants près de moi'},
      {'icon': 'assets/icons/activities.png', 'text': 'Activités à faire ce week-end'},
      {'icon': 'assets/icons/wellness.png', 'text': 'Lieux de bien-être'},
      {'icon': 'assets/icons/events.png', 'text': 'Événements du jour'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: suggestions.map((suggestion) {
              return GestureDetector(
                onTap: () {
                  _sendQuestion(suggestion['text'] ?? '');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        suggestion['icon'] ?? '',
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image_not_supported, size: 24);
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        suggestion['text'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Vos recommandations personnalisées",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                final recommendation = _recommendations[index];
                return GestureDetector(
                  onTap: () {
                    if (recommendation.containsKey('id')) {
                      _analyzeAndNavigate('Afficher ${recommendation['name']}');
                    }
                  },
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: recommendation['image'] ?? '',
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              height: 100,
                              width: double.infinity,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              height: 100,
                              width: double.infinity,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recommendation['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                recommendation['category'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 14,
                                  ),
                                  Text(
                                    " ${recommendation['rating'] ?? '4.0'}",
                                    style: const TextStyle(fontSize: 12),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationHistory() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Conversations récentes",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _conversations.length,
            itemBuilder: (context, index) {
              final conversation = _conversations[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.blue,
                            radius: 16,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Vous",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(conversation['question'] ?? ''),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 16,
                            child: Icon(
                              Icons.assistant,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Assistant",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(conversation['answer'] ?? ''),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Pour analyser le texte de la requête et naviger au bon screen
  void _analyzeAndNavigate(String text) {
    // Pour le moment, on redirige vers la méthode _sendQuestion existante
    // pour conserver la fonctionnalité actuelle
    _sendQuestion(text);
  }
  
  // Vérifier si le texte contient au moins un des mots clés
  bool _containsKeywords(String text, List<String> keywords) {
    for (var keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
  
  // Traitement de la réponse de l'API
  void _processApiResponse(AIQueryResponse aiResponse) {
    // Afficher la réponse textuelle de l'IA
    setState(() {
      // Trouver et supprimer le message de chargement s'il existe encore
      _conversations.removeWhere((msg) => msg['isLoading'] == true);
      
      // Ajouter la réponse de l'IA
      _conversations.insert(0, {
        'type': 'copilot',
        'content': aiResponse.response,
        'timestamp': DateTime.now().toIso8601String(),
        'hasProfiles': aiResponse.profiles.isNotEmpty,
        'intent': aiResponse.intent,
        'resultCount': aiResponse.resultCount,
        // Potentiellement ajouter 'analysisResults': aiResponse.analysisResults
      });
      
      // Mettre à jour la liste des profils principaux
      if (aiResponse.profiles.isNotEmpty) {
        // Normaliser les types avant d'appliquer le lazy loading
        final normalizedProfiles = _normalizeProfileTypes(aiResponse.profiles);
        _applyLazyLoadingToTopList(normalizedProfiles);
    } else {
        _topExtractedProfiles = [];
        _hasMoreTopProfilesToLoad = false;
      }
      
        _isLoading = false;
      });

    _scrollToBottom();

    // Logique de navigation basée sur l'intention (si nécessaire)
    // Exemple: Si l'intention est une recherche géo, peut-être afficher la carte?
    // if (aiResponse.intent == 'geo_search') { ... }
    // Pour l'instant, on affiche juste la réponse et les profils.
  }

  // Navigue vers le profil utilisateur
  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: userId,
        ),
      ),
    );
  }
}