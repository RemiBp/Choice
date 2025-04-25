import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/ai_service.dart'; // Import du nouveau service AI
import 'package:cached_network_image/cached_network_image.dart'; // Pour charger les images avec cache
// import 'producer_screen.dart'; // Not directly used for navigation anymore
// import 'producerLeisure_screen.dart'; // Not directly used for navigation anymore
import 'package:scroll_to_index/scroll_to_index.dart'; // Pour le contrôleur de défilement
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sales_data.dart';
import '../models/kpi_data.dart';
import '../models/recommendation_data.dart';
import '../models/ai_query_response.dart';
import '../utils/constants.dart' as constants;
import 'package:uuid/uuid.dart';
// import 'package:go_router/go_router.dart';
import '../../models/profile_data.dart' as model_profile_data;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_message.dart';
import '../services/api_service.dart';
import '../utils.dart' show getImageProvider;
import '../services/auth_service.dart';

class ProducerDashboardIaPage extends StatefulWidget {
  final String producerId;

  // ✅ Transformation correcte de `userId` en `producerId`
  const ProducerDashboardIaPage({Key? key, required String userId})
      : producerId = userId, // Mapping de `userId` vers `producerId`
        super(key: key);

  @override
  _ProducerDashboardIaPageState createState() => _ProducerDashboardIaPageState();
}

class _ProducerDashboardIaPageState extends State<ProducerDashboardIaPage> with SingleTickerProviderStateMixin {
  List<types.Message> _messages = [];
  final _user = const types.User(id: 'producer');
  final TextEditingController _searchController = TextEditingController();
  bool _isTyping = false;
  bool _chatFullScreen = false; // ✅ Variable pour activer/désactiver le mode plein écran
  List<model_profile_data.ProfileData> _extractedProfiles = []; // Pour stocker les profils extraits par l'IA
  final AutoScrollController _chatScrollController = AutoScrollController(); // Contrôleur de défilement pour le chat
  
  // Animation controller pour les transitions
  late AnimationController _animationController;
  
  // Type de producteur
  String _producerType = 'restaurant'; // Valeur par défaut
  Map<String, dynamic>? _producerData;
  bool _isLoadingProducerData = true;
  bool _isLoadingProducerType = true; // Renamed loading state
  bool _isLoadingDashboard = true;

  // State variables for dashboard data (using imported models)
  KpiData? _visibilityKpi;
  KpiData? _performanceKpi;
  List<SalesData> _trendData = [];
  List<model_profile_data.ProfileData> _competitors = [];
  List<RecommendationData> _recommendations = [];
  String _chartPeriod = 'Semaine'; // Default chart period

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _detectProducerTypeAndLoadData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Détecte le type de producteur et charge les données appropriées
  Future<void> _detectProducerTypeAndLoadData() async {
    try {
      // Check if mounted before setting loading state
      if (mounted) {
        setState(() {
          _isLoadingProducerData = true;
        });
      }
      
      // Utiliser le service AI pour détecter le type
      final aiService = AIService();
      final detectedType = await aiService.detectProducerType(widget.producerId);
      
      // Charger les données du producteur avec le bon endpoint
      final data = await _fetchProducerData(detectedType);
      
      // Check if the widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _producerType = detectedType;
          _producerData = data;
          _isLoadingProducerData = false;
        });
        _addWelcomeMessage();
        _loadBusinessInsights();
      }
      
    } catch (e) {
      print("❌ Erreur lors de la détection du type de producteur: $e");
      // Check if the widget is still mounted before calling setState in catch block
      if (mounted) {
        setState(() {
          _isLoadingProducerData = false;
          // Utiliser 'restaurant' comme valeur par défaut en cas d'erreur
          _producerType = 'restaurant';
        });
        _addWelcomeMessage();
      }
    }
  }
  
  /// Récupère les données du producteur selon son type
  Future<Map<String, dynamic>> _fetchProducerData(String type) async {
    String endpoint;
    
    switch (type) {
      case 'leisureProducer':
        endpoint = '/api/leisureProducers/${widget.producerId}';
        break;
      case 'wellnessProducer':
        endpoint = '/api/wellness/${widget.producerId}';
        break;
      case 'beautyPlace':
        endpoint = '/api/wellness/${widget.producerId}';
        break;
      case 'restaurant':
      default:
        endpoint = '/api/producers/${widget.producerId}';
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrlSync()}$endpoint');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode} lors de la récupération des données');
      }
    } catch (e) {
      print("❌ Erreur lors de la récupération des données: $e");
      return {};
    }
  }

  void _addWelcomeMessage() {
    // Adapter le message selon le type
    String welcomeText;
    
    switch (_producerType) {
      case 'leisureProducer':
        welcomeText = "Bienvenue dans votre espace producteur de loisirs ! Je suis votre assistant avec accès à toutes les données pertinentes. Posez-moi des questions sur votre activité, vos réservations, ou consultez votre tableau de bord. 🎮";
        break;
      case 'wellnessProducer':
        welcomeText = "Bienvenue dans votre espace bien-être ! Je suis votre assistant avec accès à toutes les données du marché. Posez-moi des questions sur vos prestations, vos clients, ou consultez votre tableau de bord. 💆";
        break;
      case 'beautyPlace':
        welcomeText = "Bienvenue dans votre espace beauté ! Je suis votre assistant avec accès à toutes les données du marché. Posez-moi des questions sur vos prestations, vos clients, ou consultez votre tableau de bord. 💅";
        break;
      case 'restaurant':
      default:
        welcomeText = "Bienvenue ! Je suis votre assistant avec accès direct à toutes les données du marché. Posez-moi des questions comme \"quels sont les restaurants avec le meilleur saumon dans ma zone ?\" ou consultez votre tableau de bord. 📊";
    }

    final message = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: welcomeText,
    );

    setState(() {
      _messages.insert(0, message);
    });
  }
  
  /// Méthode pour construire un élément de statistique
  Widget _buildStatItem(String label, String value, String change, bool isPositive) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPositive ? Colors.green[600] : Colors.red[600],
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              change,
              style: TextStyle(
                fontSize: 12,
                color: isPositive ? Colors.green[600] : Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// Charge les insights métier pour le tableau de bord
  Future<void> _loadBusinessInsights() async {
    try {
      // Check if mounted before setting loading state
      if (mounted) {
        setState(() => _isLoadingDashboard = true);
      }
      
      // Déterminer l'endpoint en fonction du type de producteur
      String endpoint;
      switch (_producerType) {
        case 'leisureProducer':
          endpoint = '/api/ai/leisure-insights/${widget.producerId}';
          break;
        case 'wellnessProducer':
          endpoint = '/api/ai/wellness-insights/${widget.producerId}';
          break;
        case 'beautyPlace':
          endpoint = '/api/ai/wellness-insights/${widget.producerId}'; // Utiliser le même endpoint que wellnessProducer
          break;
        case 'restaurant':
        default:
          endpoint = '/api/ai/producer-insights/${widget.producerId}';
      }
      
      final url = Uri.parse('${constants.getBaseUrlSync()}$endpoint');
      
      // Récupérer le token d'authentification
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      
      if (token == null) {
        throw Exception('Token non trouvé, impossible de charger les insights.');
      }
      
      // Ajouter l'en-tête d'authentification
      final response = await http.get(
        url, 
        headers: { 
          'Authorization': 'Bearer $token', 
          'Content-Type': 'application/json' 
        }
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // ... le reste de la méthode reste inchangé
      } else {
        throw Exception('Erreur ${response.statusCode} lors de la récupération des insights');
      }
    } catch (e) {
      print("❌ Erreur lors de la récupération des insights: $e");
      // Check if mounted before setting loading state
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
        });
      }
    }
  }

  void _handleSendPressed(String message) async {
    if (message.isEmpty) return;

    // Passe en mode plein écran au premier message envoyé
    setState(() {
      _chatFullScreen = true;
      _animationController.forward();
    });

    // Créer un message utilisateur
    final userMessage = types.TextMessage(
      author: _user,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message,
    );

    setState(() {
      _messages.insert(0, userMessage);
      _searchController.clear();
      _isTyping = false;
      _extractedProfiles = []; // Réinitialiser les profils extraits
    });

    // Afficher un indicateur de chargement
    final loadingMessage = types.CustomMessage(
      author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'isLoading': true,
        'text': 'Analyse en cours...',
      },
    );

    setState(() {
      _messages.insert(0, loadingMessage);
    });

    try {
      // Utiliser le service AI avec le type de producteur
      final aiService = AIService();
      
      // Passer explicitement le type de producteur pour s'assurer que le bon endpoint est utilisé
      final AIQueryResponse aiResponse = await aiService.producerQuery(
        widget.producerId, 
        message,
        producerType: _producerType, // Assurons-nous de passer le type de producteur
      );
      
      // Supprimer le message de chargement
      setState(() {
        _messages.removeWhere((msg) => msg.id == loadingMessage.id);
      });
      
      // Traitement de la réponse réussie
      if (aiResponse.profiles.isNotEmpty) {
        setState(() {
          _extractedProfiles = aiResponse.profiles.map((aiProfile) => 
            _convertToProfileData(aiProfile)
          ).toList();
        });
      }
      
      // Créer le message de réponse AI
      final botMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metadata: {
          'text': aiResponse.response,
          'profiles': aiResponse.profiles,
          'analysisResults': aiResponse.analysisResults,
          'type': 'ai_response',
        },
      );

        setState(() {
          _messages.insert(0, botMessage);
        });
      
    } catch (e) {
      print("❌ Erreur lors de l'appel à l'IA: $e");
      
      // Supprimer le message de chargement
      setState(() {
        _messages.removeWhere((msg) => msg.id == loadingMessage.id);
      });
      
      // Message d'erreur
      final errorMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metadata: {
          'text': "Désolé, je rencontre des difficultés à me connecter au serveur. Veuillez réessayer dans quelques instants ou reformuler votre question.",
          'type': 'error',
        },
      );

        setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }

  Future<void> _fetchVisibilityStats() async {
    try {
      // Afficher un message de chargement
      final loadingMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: 'loading_stats_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'isLoading': true,
          'text': 'Analyse de la visibilité...',
          'type': 'loading',
        },
      );

      setState(() {
        _messages.insert(0, loadingMessage);
      });
      
      // Utilisation de l'endpoint d'insights pour obtenir des statistiques détaillées
      final aiService = AIService();
      final insights = await aiService.getProducerInsights(widget.producerId);
      
      // Supprimer le message de chargement
      setState(() {
        _messages.removeWhere((msg) => msg.id == loadingMessage.id);
      });
      
      if (!insights.hasError && insights.response.isNotEmpty) {
        final statMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': insights.response,
            'profiles': insights.profiles,
            'analysisResults': insights.analysisResults,
            'type': 'insight',
          },
        );
        
        if (insights.profiles.isNotEmpty) {
          setState(() {
            _extractedProfiles = insights.profiles.map((aiProfile) => 
              _convertToProfileData(aiProfile)
            ).toList();
          });
        }

        setState(() {
          _messages.insert(0, statMessage);
        });
      } else {
        // Si l'API renvoie une erreur, afficher un message explicatif
        final errorMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': "Je ne peux pas récupérer les statistiques de visibilité pour le moment. Il est possible que votre établissement n'ait pas encore suffisamment de données pour une analyse complète.",
            'type': 'error',
          },
        );

        setState(() {
          _messages.insert(0, errorMessage);
        });
      }
    } catch (e) {
      print("❌ Erreur lors de la récupération des statistiques de visibilité: $e");
      
      // Supprimer tout message de chargement qui pourrait être affiché
      setState(() {
        _messages.removeWhere((msg) => 
          msg.metadata != null && 
          msg.metadata!['isLoading'] == true && 
          (msg.id?.startsWith('loading_stats_') ?? false)
        );
      });
      
      // Message de secours
      final errorMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metadata: {
          'text': "Désolé, je ne peux pas accéder aux statistiques de visibilité pour le moment. Voici quelques conseils généraux pour améliorer votre visibilité : enrichissez vos données (images, menu), encouragez les avis et interactions, et maintenez vos informations à jour.",
          'type': 'error',
        },
      );

      setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }

  Future<void> _fetchPerformanceStats() async {
    try {
      // Afficher un message de chargement
      final loadingMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: 'loading_performance_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'isLoading': true,
          'text': 'Analyse des performances...',
          'type': 'loading',
        },
      );

      setState(() {
        _messages.insert(0, loadingMessage);
      });
      
      // Demande spécifique pour analyser les performances
      final result = await AIService().producerQuery(
        widget.producerId, 
        "Analyse ma performance en comparaison avec les autres établissements similaires dans mon quartier"
      );
      
      // Supprimer le message de chargement
      setState(() {
        _messages.removeWhere((msg) => msg.id == loadingMessage.id);
      });
      
      if (!result.hasError && result.response.isNotEmpty) {
        final performanceMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': result.response,
            'profiles': result.profiles,
            'analysisResults': result.analysisResults,
            'type': 'performance',
          },
        );
        
        if (result.profiles.isNotEmpty) {
          setState(() {
            _extractedProfiles = result.profiles.map((aiProfile) => 
              _convertToProfileData(aiProfile)
            ).toList();
          });
        }

        setState(() {
          _messages.insert(0, performanceMessage);
        });
      } else {
        // Si l'API renvoie une erreur, afficher un message explicatif
        final errorMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': "Je ne peux pas analyser vos performances pour le moment. Il est possible qu'il n'y ait pas assez de données comparatives disponibles.",
            'type': 'error',
          },
        );

        setState(() {
          _messages.insert(0, errorMessage);
        });
      }
    } catch (e) {
      print("❌ Erreur lors de l'analyse des performances: $e");
      
      // Supprimer tout message de chargement qui pourrait être affiché
      setState(() {
        _messages.removeWhere((msg) => 
          msg.metadata != null && 
          msg.metadata!['isLoading'] == true && 
          (msg.id?.startsWith('loading_performance_') ?? false)
        );
      });
      
      // Message de secours avec conseils généraux sur les performances
      final errorMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metadata: {
          'text': "Désolé, je ne peux pas accéder aux données de performance pour le moment. Voici quelques conseils généraux pour améliorer votre performance : analysez vos heures d'affluence, diversifiez votre offre, et soyez attentif aux avis clients pour identifier les points d'amélioration.",
          'type': 'error',
        },
      );

      setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }
  
  Future<void> _fetchCompetitorInsights() async {
    try {
      // Afficher un message de chargement
      final loadingMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: 'loading_competitors_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'isLoading': true,
          'text': 'Analyse des concurrents...',
          'type': 'loading',
        },
      );

      setState(() {
        _messages.insert(0, loadingMessage);
      });
      
      // Demande spécifique pour analyser les concurrents
      final result = await AIService().producerQuery(
        widget.producerId, 
        "Analyse mes concurrents directs et compare leurs performances avec la mienne"
      );
      
      // Supprimer le message de chargement
      setState(() {
        _messages.removeWhere((msg) => msg.id == loadingMessage.id);
      });
      
      if (!result.hasError && result.response.isNotEmpty) {
        final competitorMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': result.response,
            'profiles': result.profiles,
            'analysisResults': result.analysisResults,
            'type': 'competitor',
          },
        );
        
        if (result.profiles.isNotEmpty) {
          setState(() {
            _extractedProfiles = result.profiles.map((aiProfile) => 
              _convertToProfileData(aiProfile)
            ).toList();
          });
        }

        setState(() {
          _messages.insert(0, competitorMessage);
        });
      } else {
        // Si l'API renvoie une erreur, afficher un message explicatif
        final errorMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': "Je ne peux pas analyser vos concurrents pour le moment. Il est possible qu'il n'y ait pas assez d'établissements similaires dans votre zone pour une comparaison pertinente.",
            'type': 'error',
          },
        );

        setState(() {
          _messages.insert(0, errorMessage);
        });
      }
    } catch (e) {
      print("❌ Erreur lors de l'analyse des concurrents: $e");
      
      // Supprimer tout message de chargement qui pourrait être affiché
      setState(() {
        _messages.removeWhere((msg) => 
          msg.metadata != null && 
          msg.metadata!['isLoading'] == true && 
          (msg.id?.startsWith('loading_competitors_') ?? false)
        );
      });
      
      // Message de secours avec conseils généraux sur la concurrence
      final errorMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metadata: {
          'text': "Désolé, je ne peux pas accéder aux données de vos concurrents pour le moment. Pour vous démarquer, concentrez-vous sur ce qui vous rend unique, étudiez les établissements similaires de votre quartier, et identifiez des opportunités de différenciation dans votre offre ou votre service client.",
          'type': 'error',
        },
      );

      setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProducerData) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Chargement...", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _chatFullScreen ? "Copilot IA" : _getProducerTypeTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _chatFullScreen ? _getColorForType() : Colors.white,
        foregroundColor: _chatFullScreen ? Colors.white : Colors.black87,
        actions: [
          IconButton(
            icon: Icon(_chatFullScreen ? Icons.dashboard : Icons.help_outline),
            onPressed: () {
              setState(() {
                _chatFullScreen = !_chatFullScreen;
              });
              // Animer la transition
              if (_chatFullScreen) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            },
            tooltip: _chatFullScreen ? 'Tableau de bord' : 'Aide',
          ),
        ],
        leading: _chatFullScreen
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _chatFullScreen = false;
                  });
                  _animationController.reverse();
                },
              )
            : null,
      ),
      body: _chatFullScreen ? _buildChatScreen() : _buildDashboardScreen(),
    );
  }

  Widget _buildChatScreen() {
    return Column(
      children: [
        // Profils concurrents extraits par l'IA (s'il y en a)
        if (_extractedProfiles.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              border: Border(
                bottom: BorderSide(
                  color: Colors.blue.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Établissements analysés',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _extractedProfiles.length,
              itemBuilder: (context, index) {
                final profile = _extractedProfiles[index];
                return _buildProfileCard(profile);
              },
            ),
          ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: -0.2, end: 0),
        ],
        
        Expanded(
          child: Chat(
            messages: _messages,
            onSendPressed: (partialText) => _handleSendPressed(partialText.text),
            user: _user,
            scrollController: _chatScrollController,
            customMessageBuilder: _buildCustomMessage,
            theme: DefaultChatTheme(
              inputBackgroundColor: Colors.blue.shade50,
              inputTextColor: Colors.blue.shade900,
              primaryColor: Colors.blue,
              backgroundColor: Colors.grey[50]!,
              sentMessageBodyTextStyle: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.4,
              ),
              receivedMessageBodyTextStyle: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.4,
              ),
              inputTextStyle: TextStyle(
                fontSize: 16,
                color: Colors.blue.shade900,
              ),
              inputBorderRadius: BorderRadius.circular(24),
              inputMargin: const EdgeInsets.all(16),
              inputPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              sendButtonIcon: Icon(
                Icons.send_rounded,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardScreen() {
    return Column(
      children: [
        // Barre de recherche améliorée
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (text) {
              setState(() {
                _isTyping = text.isNotEmpty;
              });
            },
            onSubmitted: _handleSendPressed,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search,
                color: Colors.blue.shade700,
              ),
              suffixIcon: _isTyping
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _isTyping = false;
                        });
                      },
                    )
                  : null,
              hintText: _isTyping ? "" : "Posez une question à votre copilot...",
              hintStyle: TextStyle(color: Colors.grey[400]),
              fillColor: Colors.grey[100],
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),

        // Tableau de bord interactif
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Text(
                  "Tableau de bord",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ).animate().fadeIn(duration: 300.ms),
                
                const SizedBox(height: 8),
                
                Text(
                  "Votre assistant IA vous aide à prendre des décisions stratégiques",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
                
                const SizedBox(height: 24),
                
                // Section KPI
                _buildInteractiveKpiCard(
                  "👀 Visibilité",
                  "12K vues cette semaine",
                  _fetchVisibilityStats,
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(begin: -0.1, end: 0),
                
                _buildInteractiveKpiCard(
                  "📈 Performance",
                  _getPerformanceMetricValue(),
                  _fetchPerformanceStats,
                ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideX(begin: -0.1, end: 0),
                
                _buildChart().animate().fadeIn(duration: 300.ms, delay: 400.ms),
                
                _buildCompetitiveAnalysisCard().animate().fadeIn(duration: 300.ms, delay: 500.ms),
                
                const SizedBox(height: 16),
                
                _buildRecommendationsTab().animate().fadeIn(duration: 300.ms, delay: 600.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveKpiCard(String title, String valueText, VoidCallback onTap) {
    IconData icon;
    Color color = _getColorForType(); // Utiliser la couleur du type

    if (title.contains("Visibilité")) {
      icon = Icons.visibility;
    } else if (title.contains("Performance")) {
      icon = _getIconForProducerType(); // Utiliser l'icône du type
    } else {
      icon = Icons.trending_up;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: color, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(valueText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: color)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: Colors.green[600],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "+8.2% vs la semaine dernière",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    // Adapter les titres et données selon le type de producteur
    String chartTitle;
    String primaryMetric;
    
    switch (_producerType) {
      case 'leisureProducer':
        chartTitle = "Évolution des réservations";
        primaryMetric = "Réservations";
        break;
      case 'wellnessProducer':
        chartTitle = "Évolution des prestations";
        primaryMetric = "Prestations";
        break;
      case 'beautyPlace':
        chartTitle = "Évolution des rendez-vous";
        primaryMetric = "Rendez-vous";
        break;
      case 'restaurant':
      default:
        chartTitle = "Évolution des ventes";
        primaryMetric = "Ventes";
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getColorForType().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bar_chart, color: _getColorForType()),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    chartTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: "Semaine",
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: "Jour", child: Text("Jour")),
                  DropdownMenuItem(value: "Semaine", child: Text("Semaine")),
                  DropdownMenuItem(value: "Mois", child: Text("Mois")),
                ],
                onChanged: (value) {
                  // Changer la période
                },
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                ),
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Légende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getColorForType(),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text("Cette semaine", style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text("Semaine dernière", style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Graphique adapté
          SizedBox(
            height: 220,
            child: _buildCustomChart(),
          ),
          
          const SizedBox(height: 16),
          
          // Statistiques résumées adaptées
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(primaryMetric, _getValueForMetric(primaryMetric), "+12%", true),
              _buildStatItem(_getSecondaryMetric(), _getValueForMetric(_getSecondaryMetric()), "+8%", true),
              _buildStatItem(_getTertiaryMetric(), _getValueForMetric(_getTertiaryMetric()), "+2%", true),
            ],
          ),
        ],
      ),
    );
  }

  // Obtenir les métriques adaptées selon le type
  String _getSecondaryMetric() {
    switch (_producerType) {
      case 'leisureProducer':
        return "Participants";
      case 'wellnessProducer':
      case 'beautyPlace':
        return "Clients";
      case 'restaurant':
      default:
        return "Paniers";
    }
  }
  
  String _getTertiaryMetric() {
    switch (_producerType) {
      case 'leisureProducer':
        return "Durée moy.";
      case 'wellnessProducer':
      case 'beautyPlace':
        return "Panier moy.";
      case 'restaurant':
      default:
        return "Tickets";
    }
  }
  
  String _getValueForMetric(String metric) {
    switch (metric) {
      case "Ventes":
        return "€3,450";
      case "Paniers":
        return "482";
      case "Tickets":
        return "€38.50";
      case "Réservations":
        return "342";
      case "Participants":
        return "684";
      case "Durée moy.":
        return "1h45";
      case "Prestations":
        return "156";
      case "Clients":
        return "122";
      case "Panier moy.":
        return "€65.80";
      case "Rendez-vous":
        return "218";
      default:
        return "N/A";
    }
  }
  
  Widget _buildCustomChart() {
    // Données adaptées au type de producteur
    final List<SalesData> currentData = [
      SalesData(day: 'Lun', sales: 35, lastWeek: 28),
      SalesData(day: 'Mar', sales: 28, lastWeek: 25),
      SalesData(day: 'Mer', sales: 34, lastWeek: 30),
      SalesData(day: 'Jeu', sales: 32, lastWeek: 28),
      SalesData(day: 'Ven', sales: 40, lastWeek: 34),
      SalesData(day: 'Sam', sales: 50, lastWeek: 42),
      SalesData(day: 'Dim', sales: 45, lastWeek: 38),
    ];

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: 60,
        interval: 10,
        majorGridLines: MajorGridLines(width: 1, color: Colors.grey[200]),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      legend: Legend(isVisible: false),
      series: <CartesianSeries<SalesData, String>>[
        // Série pour la semaine précédente (gris)
        ColumnSeries<SalesData, String>(
          dataSource: currentData,
          xValueMapper: (datum, _) => datum.day,
          yValueMapper: (datum, _) => datum.lastWeek,
          color: Colors.grey[300],
          width: 0.3,
          spacing: 0.2,
          borderRadius: BorderRadius.circular(4),
        ),
        // Série pour la semaine actuelle (colorée selon le type)
        ColumnSeries<SalesData, String>(
          dataSource: currentData,
          xValueMapper: (datum, _) => datum.day,
          yValueMapper: (datum, _) => datum.sales,
          color: _getColorForType(),
          width: 0.3,
          spacing: 0.2,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
  
  Widget _buildCompetitiveAnalysisCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _fetchCompetitorInsights,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                      padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                  ),
                      child: const Icon(Icons.compare_arrows, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Analyse concurrentielle",
                  style: TextStyle(
                        fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                          const Icon(Icons.refresh, size: 14, color: Colors.teal),
                          const SizedBox(width: 6),
                      Text(
                            "Mise à jour il y a 2h",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal[700],
                              fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
                const SizedBox(height: 20),
            const Text(
                  "Votre positionnement par rapport à vos concurrents directs",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                    color: Colors.grey,
              ),
            ),
                const SizedBox(height: 20),
            _buildCompetitorsList(),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.teal.withOpacity(0.1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insights, size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          "Analyser en détail",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.teal[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompetitorsList() {
    if (_extractedProfiles.isEmpty) {
      // Afficher un message si aucun concurrent n'a été extrait
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            "Cliquez sur 'Analyser en détail' pour voir les concurrents.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Afficher la liste des concurrents extraits
    return Column(
      children: _extractedProfiles.map<Widget>((model_profile_data.ProfileData profile) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildCompetitorItem(
            profile: profile
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompetitorItem({
    required model_profile_data.ProfileData profile,
  }) {
    // Access fields safely from the profile object
    final String name = profile.name ?? 'Nom inconnu';
    final double rating = profile.rating ?? 0.0;
    final String address = profile.address ?? '';
    final dynamic priceLevel = profile.priceLevel;
    final List<dynamic> catList = profile.category ?? [];
    final String? imageUrl = profile.image;

    // Image provider logic remains similar, now using imageUrl from profile
    final imageProvider = imageUrl != null && imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null; 
    
    // Structure du Widget Card pour chaque concurrent
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero, // Enlever la marge par défaut de Card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Implémenter la navigation vers le profil du concurrent si nécessaire
          print("Tapped on competitor: $name");
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Container(
                width: 100,
                height: 130, // Hauteur fixe pour l'image
                color: _getColorForType().withOpacity(0.1),
                child: imageProvider != null
                  ? Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      height: 130,
                      width: 100,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          _getIconForProducerType(), // Icône par défaut basée sur le type
                          color: _getColorForType(),
                          size: 30, // Adjusted size
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        _getIconForProducerType(), // Icône par défaut basée sur le type
                        color: _getColorForType(),
                        size: 30, // Adjusted size
                      ),
                    ),
              ),
            ),

            // Contenu
            Expanded( // Utiliser Expanded pour que le contenu prenne la place restante
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0), // Padding à gauche de l'image
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Adresse/Distance
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address, // Afficher l'adresse
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              maxLines: 1, // Limiter à une ligne
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Note et Prix
                    Row(
                      children: [
                        if (rating > 0) ...[ // Afficher seulement si la note est > 0
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        if (priceLevel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getPriceSymbol(priceLevel),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Catégories
                    if (catList.isNotEmpty)
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: catList.take(2).map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cat.toString(),
                              style: TextStyle(fontSize: 10, color: Colors.grey[800]),
                            ),
                          );
                        }).toList(),
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

  // Fonctions helpers pour le style des cartes de profil
  IconData _getIconForProducerType() {
    switch (_producerType) {
      case 'leisureProducer':
        return Icons.sports_esports;
      case 'wellnessProducer':
        return Icons.spa;
      case 'beautyPlace':
        return Icons.face;
      case 'restaurant':
      default:
        return Icons.restaurant;
    }
  }
  
  String _getLabelForProducerType() {
    switch (_producerType) {
      case 'leisureProducer':
        return 'Loisir';
      case 'wellnessProducer':
        return 'Bien-être';
      case 'beautyPlace':
        return 'Beauté';
      case 'restaurant':
      default:
        return 'Restaurant';
    }
  }
  
  Color _getColorForType() {
    switch (_producerType) {
      case 'leisureProducer':
        return Colors.purple;
      case 'wellnessProducer':
        return Colors.teal;
      case 'beautyPlace':
        return Colors.pink;
      case 'restaurant':
      default:
        return Colors.blue;
    }
  }
  
  Color _getBackgroundColorForType() {
    return _getColorForType().withOpacity(0.1);
  }
  
  String _getPriceSymbol(dynamic price) {
    if (price is! num) return '';
    
    int priceLevel = price.toInt();
    switch (priceLevel) {
      case 1:
        return '€';
      case 2:
        return '€€';
      case 3:
        return '€€€';
      case 4:
        return '€€€€';
      default:
        return '';
    }
  }

  /// 🔹 Navigue vers un profil spécifique
  void _navigateToProfile(String type, String id) {
    if (id.isEmpty) return;

    String routeName;
    switch (type.toLowerCase()) {
        case 'restaurant':
        routeName = '/restaurants/';
          break;
      case 'leisureproducer':
        routeName = '/leisures/';
          break;
      case 'event':
        routeName = '/events/';
          break;
      case 'wellnessproducer':
        routeName = '/wellness/'; // Assuming route exists
          break;
      case 'beautyplace':
        routeName = '/beauty/'; // Assuming route exists
          break;
        case 'user':
         routeName = '/users/'; // Assuming route exists
          break;
        default:
        print("⚠️ Unknown profile type for navigation: $type");
        return; // Don't navigate if type is unknown
    }

    Navigator.of(context).pushNamed(routeName + id);
  }

  /// Obtient le titre adapté au type de producteur
  String _getProducerTypeTitle() {
    switch (_producerType) {
      case 'leisureProducer':
        return "Espace Loisirs";
      case 'wellnessProducer':
        return "Espace Bien-être";
      case 'beautyPlace':
        return "Espace Beauté";
      case 'restaurant':
      default:
        return "Espace Restaurant";
    }
  }

  // Helper function to map icon name string to IconData
  IconData getIconDataFromName(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'photocamera':
        return Icons.photo_camera;
      case 'localoffer':
        return Icons.local_offer;
      case 'restaurantmenu':
        return Icons.restaurant_menu;
      case 'event':
        return Icons.event;
      case 'trendingup':
        return Icons.trending_up;
      case 'campaign':
        return Icons.campaign;
      // Add more mappings as needed based on backend icon names
      default:
        return Icons.lightbulb_outline; // Default icon
    }
  }

  Widget _buildProfileCard(model_profile_data.ProfileData profile) {
    final provider = getImageProvider(profile.image!);
    if (provider != null)
      return Image(image: provider, width: 40, height: 40, fit: BoxFit.cover);
    else
      return Icon(Icons.person);
  }

  Widget _buildRecommendationsTab() {
    // TODO: Remplacer par le vrai rendu des recommandations IA
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text('Aucune recommandation disponible.'),
    );
  }

  Widget _buildCustomMessage(types.CustomMessage message, {required int messageWidth}) {
    final metadata = message.metadata ?? {};
    final String type = metadata['type'] as String? ?? 'unknown';
    final String text = metadata['text'] as String? ?? '';
    final List<model_profile_data.ProfileData> profiles = List<model_profile_data.ProfileData>.from(metadata['profiles'] ?? []);
    final analysis = metadata['analysisResults']; // Peut être null

    // Déterminer la couleur de fond et le contenu basé sur le type
    switch (type) {
      case 'loading':
        return _buildLoadingMessage(text);
      case 'error':
        return _buildErrorMessage(text);
      case 'insight':
      case 'performance':
      case 'competitor':
      case 'ai_response':
        return _buildAiResponseMessage(text, profiles, analysis);
      default:
        // Message texte standard de l'assistant (si on en ajoute)
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
             boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: Offset(0, 2)) ],
          ),
          child: Text(text, style: TextStyle(color: Colors.grey[800]))
        );
    }
  }

  // --- Fonctions de rendu pour les types de messages personnalisés ---

  Widget _buildLoadingMessage(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!)),
          ),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String text) {
     return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100)
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Colors.red.shade900, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildAiResponseMessage(String text, List<model_profile_data.ProfileData> profiles, dynamic analysis) {
     return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: Offset(0, 2)) ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Afficher le texte principal de l'IA
          SelectableText(text, style: TextStyle(color: Colors.grey[850], fontSize: 15, height: 1.45)),
          
          // Afficher les profils (concurrents, etc.) si présents
          if (profiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("Établissements pertinents:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
            const SizedBox(height: 8),
            SizedBox(
              height: 140, // Hauteur fixe pour la liste horizontale
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                   return Padding(
                     padding: const EdgeInsets.only(right: 10.0),
                     // Utiliser une carte compacte pour l'intégration
                     child: _buildCompactProfileCard(profiles[index]), 
                   );
                },
              ),
            ),
          ],
          
          // TODO: Afficher les données d'analyse (analysisResults) si présentes
          // if (analysis != null) ... [
          //   const SizedBox(height: 16),
          //   Text("Analyse détaillée:", style: TextStyle(fontWeight: FontWeight.bold)),
          //   _buildAnalysisDetails(analysis), // Nouvelle fonction à créer
          // ],
        ],
      ),
    );
  }

  // Nouvelle fonction pour la carte compacte (similaire à celle de CopilotScreen)
  Widget _buildCompactProfileCard(model_profile_data.ProfileData profile) {
       final Color typeColor = _getColorForType(); // Utiliser la couleur du producteur actuel
       final IconData typeIcon = _getIconForProducerType(); // Utiliser l'icône du producteur actuel
       String imageUrl = profile.image ?? '';
       // Simplified image URL logic
        if (imageUrl.isNotEmpty) {
           if (!imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
              imageUrl = '${constants.getBaseUrlSync()}$imageUrl'; 
           }
        } else {
            imageUrl = '';
        }

       return Material(
           borderRadius: BorderRadius.circular(12),
           elevation: 1,
           shadowColor: Colors.black.withOpacity(0.1),
           child: InkWell(
              onTap: () => _navigateToProfile(profile.type ?? _producerType, profile.id ?? ''),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                 width: 130,
                 decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
                 ),
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                         height: 70,
                         width: double.infinity,
                         decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.08),
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                         ),
                         child: imageUrl.isNotEmpty 
                             ? ClipRRect(
                                 borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                 child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.4), size: 20)),
                                    errorWidget: (context, url, error) => Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.5), size: 24)),
                                 ),
                               )
                             : Center(child: Icon(typeIcon, color: typeColor.withOpacity(0.6), size: 24)),
                      ),
                      Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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

  // Add this helper method to convert between ProfileData types
  model_profile_data.ProfileData _convertToProfileData(dynamic aiProfileData) {
    // Create model ProfileData from AI ProfileData
    return model_profile_data.ProfileData(
      id: aiProfileData.id ?? '',
      name: aiProfileData.name ?? '',
      type: aiProfileData.type ?? 'unknown',
      image: aiProfileData.avatar ?? aiProfileData.image ?? '',
      // Use empty list for required category field
      category: List<String>.from(aiProfileData.interests ?? []),
      // Add other fields as needed based on your ProfileData model
      description: aiProfileData.bio ?? '',
    );
  }

  // Fonction pour obtenir la valeur de la métrique de performance
  String _getPerformanceMetricValue() {
    switch (_producerType) {
      case 'leisureProducer': return "342 réservations"; // Exemple
      case 'wellnessProducer':
      case 'beautyPlace': return "156 prestations"; // Exemple
      case 'restaurant':
      default: return "+15% interactions"; // Exemple
    }
  }
}
