import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils.dart' show getImageProvider;
import '../services/ai_service.dart'; // Import du nouveau service AI
import '../services/api_service.dart'; // Add this import
import 'package:cached_network_image/cached_network_image.dart'; // Pour charger les images avec cache
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'package:scroll_to_index/scroll_to_index.dart'; // Pour le contrôleur de défilement
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sales_data.dart';
import '../models/kpi_data.dart';
import '../models/recommendation_data.dart';
import '../models/ai_query_response.dart';
import '../utils/constants.dart' as constants;

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
  List<ProfileData> _extractedProfiles = []; // Pour stocker les profils extraits par l'IA
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
  List<ProfileData> _competitors = [];
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
      setState(() {
        _isLoadingProducerData = true;
      });
      
      // Utiliser le service AI pour détecter le type
      final aiService = AIService();
      final detectedType = await aiService.detectProducerType(widget.producerId);
      
      // Charger les données du producteur avec le bon endpoint
      final data = await _fetchProducerData(detectedType);
      
      setState(() {
        _producerType = detectedType;
        _producerData = data;
        _isLoadingProducerData = false;
      });
      
      // Ajouter un message de bienvenue adapté au type
      _addWelcomeMessage();
      
      // Charger des insights initiaux
      _loadBusinessInsights();
      
    } catch (e) {
      print("❌ Erreur lors de la détection du type de producteur: $e");
      setState(() {
        _isLoadingProducerData = false;
        // Utiliser 'restaurant' comme valeur par défaut en cas d'erreur
        _producerType = 'restaurant';
      });
    _addWelcomeMessage();
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
        endpoint = '/api/beauty_places/${widget.producerId}';
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
  
  // Charger les insights adaptés au type de producteur
  void _loadBusinessInsights() async {
    try {
      // Afficher un message de chargement
      final loadingMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: 'loading_insights_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'isLoading': true,
          'text': 'Chargement de vos insights commerciaux...',
        },
      );

      setState(() {
        _messages.insert(0, loadingMessage);
      });
      
      // Utiliser le service AI pour obtenir des insights adaptés au type
      final aiService = AIService();
      final insights = await aiService.getProducerInsights(widget.producerId);
      
      // Supprimer le message de chargement
      setState(() {
        _messages.removeWhere((msg) => msg.id == loadingMessage.id);
      });
      
      if (!insights.hasError && insights.response.isNotEmpty) {
        final insightMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': insights.response,
            'hasProfiles': insights.profiles.isNotEmpty,
            'isInsight': true,
          },
        );
        
        if (insights.profiles.isNotEmpty) {
          setState(() {
            _extractedProfiles = insights.profiles;
          });
        }

          setState(() {
            _messages.insert(0, insightMessage);
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des insights d'entreprise: $e");
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
      AIQueryResponse aiResponse = await aiService.producerQuery(
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
          _extractedProfiles = aiResponse.profiles;
        });
      }
      
      // Créer le message de réponse AI
      final botMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metadata: {
          'text': aiResponse.response,
          'hasProfiles': aiResponse.profiles.isNotEmpty,
          'timestamp': DateTime.now().toIso8601String(),
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
          'isError': true,
        },
      );

        setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }

  final AIService _aiService = AIService(); // Instance du service AI
  
  Future<String> fetchBotResponse(String producerId, String userMessage) async {
    try {
      // Utilisation du nouveau service AI avec accès direct aux données MongoDB
      final result = await _aiService.producerQuery(producerId, userMessage);
      
      // Retourner la réponse complète générée par l'IA
      return result.response;
    } catch (e) {
      print("❌ Erreur lors de l'appel au service AI: $e");
      // Message d'erreur clair sans fallback vers des routes obsolètes
      return "Désolé, je ne peux pas traiter votre demande pour le moment. Veuillez réessayer plus tard.";
    }
  }

  Future<void> _fetchVisibilityStats() async {
    try {
      // Utilisation de l'endpoint d'insights pour obtenir des statistiques détaillées
      final insights = await _aiService.getProducerInsights(widget.producerId);
      _handleSendPressed("Voici les statistiques de visibilité actuelles de votre établissement.");
      
      // L'IA a maintenant accès à toutes les données en temps réel
      // et peut fournir des analyses beaucoup plus détaillées
    } catch (e) {
      _handleSendPressed("Donne-moi le nombre de choices que j'ai reçus depuis la dernière fois.");
    }
  }

  Future<void> _fetchPerformanceStats() async {
    try {
      // Demande spécifique pour analyser les performances
      final result = await _aiService.producerQuery(
        widget.producerId, 
        "Analyse ma performance en comparaison avec les autres établissements similaires dans mon quartier"
      );
      
      // Ajouter la réponse complète au chat
      _handleSendPressed(result.response);
    } catch (e) {
      _handleSendPressed("Combien de fois suis-je apparu dans le feed récemment ?");
    }
  }
  
  Future<void> _fetchCompetitorInsights() async {
    try {
      // Demande spécifique pour analyser les concurrents
      final result = await _aiService.producerQuery(
        widget.producerId, 
        "Analyse mes concurrents directs et compare leurs performances avec la mienne"
      );
      
      // Ajouter la réponse complète au chat
      _handleSendPressed(result.response);
    } catch (e) {
      _handleSendPressed("Qui sont mes principaux concurrents et comment puis-je me démarquer ?");
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
                  "+15% interactions",
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

  Widget _buildInteractiveKpiCard(String title, String value, VoidCallback onTap) {
    // Ajuster l'icône et les métriques selon le type
    IconData icon;
    if (title.contains("Visibilité")) {
      icon = Icons.visibility;
    } else if (title.contains("Performance")) {
      switch (_producerType) {
        case 'leisureProducer':
          icon = Icons.people;
          break;
        case 'wellnessProducer':
        case 'beautyPlace':
          icon = Icons.calendar_today;
          break;
        default:
          icon = Icons.trending_up;
      }
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
                // Icône avec cercle
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getColorForType().withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: _getColorForType(),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Texte
                Expanded(
        child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
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
                // Bouton de détails
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
    // Exemple d'appel avec des données factices pour éviter l'erreur de compilation
    return Column(
      children: [
        _buildCompetitorItem(
          name: 'Exemple',
          rating: 4.2,
          distance: '1.2 km',
          priceLevel: 2,
          category: ['Italien', 'Pizza'],
        ),
      ],
    );
  }

  Widget _buildCompetitorItem({
    required String name,
    required double rating,
    required String distance,
    dynamic priceLevel,
    List<dynamic>? category,
  }) {
    final imageProvider = getImageProvider(name);
    final catList = category ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Logo/Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Container(
                      height: 100,
                      width: double.infinity,
                      color: _getColorForType().withOpacity(0.1),
                      child: imageProvider != null
                        ? Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Icon(
                              _getIconForProducerType(),
                              color: _getColorForType(),
                              size: 40,
                            ),
                          ),
                    ),
                    // Badge de type en haut à droite
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getBackgroundColorForType(),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIconForProducerType(),
                              color: _getColorForType(),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getLabelForProducerType(),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getColorForType(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Contenu
              Padding(
                padding: const EdgeInsets.all(12),
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
              
                    // Adresse
                    if (distance != null && distance.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                  child: Text(
                    distance,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    
                    // Note et prix
                    Row(
                  children: [
                    if (rating != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      const SizedBox(width: 8),
                    ],
                    
                    if (priceLevel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getPriceSymbol(priceLevel),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                      ),
                    ],
                  ],
              ),
              
                    const SizedBox(height: 8),
                    
                    // Catégories
              if (catList.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: catList.take(2).map((cat) {
                          return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
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
            ],
          ),
        ],
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
    print('📊 Navigation vers le profil de type $type avec ID: $id');
    
    // Utiliser un indicateur visuel de chargement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chargement du profil...'),
        duration: Duration(milliseconds: 800),
      ),
    );
    
    try {
      // Utiliser la navigation appropriée selon le type
      switch (type) {
        case 'restaurant':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.producerId,
              ),
            ),
          );
          break;
        case 'leisureProducer':
          _fetchAndNavigateToProducer(type, id);
          break;
        case 'wellnessProducer':
          _fetchAndNavigateToProducer(type, id);
          break;
        case 'beautyPlace':
          _fetchAndNavigateToProducer(type, id);
          break;
        default:
          _fetchGenericProfile(type, id);
      }
    } catch (e) {
      // Gérer l'erreur de manière élégante
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger le profil: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Récupère et navigue vers différents types de producteurs
  Future<void> _fetchAndNavigateToProducer(String type, String id) async {
    // Déterminer l'endpoint approprié
    String endpoint;
    switch (type) {
      case 'leisureProducer':
        endpoint = 'leisureProducers';
        break;
      case 'wellnessProducer':
        endpoint = 'wellness';
        break;
      case 'beautyPlace':
        endpoint = 'beauty_places';
        break;
      default:
        endpoint = 'producers';
    }
    
    try {
      final url = Uri.parse('${constants.getBaseUrlSync()}/api/$endpoint/$id');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Navigation selon le type
        switch (type) {
          case 'leisureProducer':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProducerLeisureScreen(producerData: data),
              ),
            );
            break;
          case 'wellnessProducer':
            Navigator.pushNamed(context, '/wellness/details', arguments: data);
            break;
          case 'beautyPlace':
            Navigator.pushNamed(context, '/beauty/details', arguments: data);
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Type non supporté: $type')),
            );
        }
      } else {
        throw Exception('Erreur ${response.statusCode} lors de la récupération des données');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Récupère et navigue vers d'autres types de profils
  Future<void> _fetchGenericProfile(String type, String id) async {
    try {
      String endpoint;
      
      switch (type) {
        case 'event':
          endpoint = 'events';
          break;
        case 'user':
          endpoint = 'users';
          break;
        default:
          endpoint = 'unified';
      }
      
      final url = Uri.parse('${constants.getBaseUrlSync()}/api/$endpoint/$id');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        switch (type) {
          case 'event':
            Navigator.pushNamed(context, '/events/details', arguments: data);
            break;
          case 'user':
            Navigator.pushNamed(context, '/users/profile', arguments: data);
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigation vers $type non implémentée')),
            );
        }
      } else {
        throw Exception('Erreur ${response.statusCode} lors de la récupération des données');
      }
    } catch (e) {
      rethrow;
    }
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

  Widget _buildProfileCard(ProfileData profile) {
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
    // TODO: Remplacer par le vrai rendu custom message IA
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message.metadata?['text']?.toString() ?? ''),
      ),
    );
  }
}
