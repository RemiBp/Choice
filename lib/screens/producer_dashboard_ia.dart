import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';
import '../services/ai_service.dart'; // Import du nouveau service AI
import 'package:cached_network_image/cached_network_image.dart'; // Pour charger les images avec cache
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'package:scroll_to_index/scroll_to_index.dart'; // Pour le contrôleur de défilement

class ProducerDashboardIaPage extends StatefulWidget {
  final String producerId;

  // ✅ Transformation correcte de `userId` en `producerId`
  const ProducerDashboardIaPage({Key? key, required String userId})
      : producerId = userId, // Mapping de `userId` vers `producerId`
        super(key: key);

  @override
  _ProducerDashboardIaPageState createState() => _ProducerDashboardIaPageState();
}

class _ProducerDashboardIaPageState extends State<ProducerDashboardIaPage> {
  List<types.Message> _messages = [];
  final _user = const types.User(id: 'producer');
  final TextEditingController _searchController = TextEditingController();
  bool _isTyping = false;
  bool _chatFullScreen = false; // ✅ Variable pour activer/désactiver le mode plein écran
  List<ProfileData> _extractedProfiles = []; // Pour stocker les profils extraits par l'IA
  final AutoScrollController _chatScrollController = AutoScrollController(); // Contrôleur de défilement pour le chat

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final message = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: "Bienvenue ! Je suis votre assistant avec accès direct à toutes les données du marché. Posez-moi des questions comme \"quels sont les restaurants avec le meilleur saumon dans ma zone ?\" ou consultez votre tableau de bord. 📊",
    );

    setState(() {
      _messages.insert(0, message);
    });
    
    // Charger des insights au démarrage
    _loadBusinessInsights();
  }
  
  void _loadBusinessInsights() async {
    try {
      // Utiliser le service AI pour obtenir des insights commerciaux
      final insights = await _aiService.getProducerInsights(widget.producerId);
      
      if (!insights.hasError && insights.response.isNotEmpty) {
        final insightMessage = types.CustomMessage(
          author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          metadata: {
            'text': insights.response,
            'hasProfiles': insights.profiles.isNotEmpty,
          },
        );
        
        if (insights.profiles.isNotEmpty) {
          setState(() {
            _extractedProfiles = insights.profiles;
          });
        }

        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _messages.insert(0, insightMessage);
          });
        });
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des insights d'entreprise: $e");
    }
  }

  void _handleSendPressed(String message) async {
    if (message.isEmpty) return;

    // ✅ Passe en mode plein écran au premier message envoyé
    setState(() {
      _chatFullScreen = true;
    });

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

    try {
      print("🔍 Envoi de la requête au service AI: $message");
      
      // Appel principal au service AI avec plusieurs tentatives
      AIQueryResponse aiResponse;
      try {
        // Premier essai - route principale
        aiResponse = await _aiService.producerQuery(widget.producerId, message);
      } catch (primaryError) {
        print("⚠️ Premier essai échoué, tentative avec route secondaire: $primaryError");
        try {
          // Deuxième essai - route de requête simple (fallback)
          aiResponse = await _aiService.simpleQuery(message);
        } catch (secondaryError) {
          print("❌ Tous les essais ont échoué: $secondaryError");
          throw secondaryError; // Relance l'erreur pour être attrapée par le bloc catch externe
        }
      }
      
      // Traitement de la réponse réussie
      print("✅ Réponse AI reçue: ${aiResponse.profiles.length} profils");
      
      // Enregistrer les profils extraits
      if (aiResponse.profiles.isNotEmpty) {
        setState(() {
          _extractedProfiles = aiResponse.profiles;
        });
      }
      
      // Créer le message du bot avec la réponse de l'IA
      final botMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metadata: {
          'text': aiResponse.response,
          'hasProfiles': aiResponse.profiles.isNotEmpty,
        },
      );

      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _messages.insert(0, botMessage);
        });
      });
    } catch (e) {
      print("❌ Erreur lors de l'appel à l'IA: $e");
      
      // Message d'erreur simple en cas d'échec complet
      final botMessage = types.TextMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Désolé, je rencontre des difficultés à me connecter à la base de données. Veuillez réessayer plus tard ou contacter le support si le problème persiste.",
      );

      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _messages.insert(0, botMessage);
        });
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Espace Producer", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: _chatFullScreen
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _chatFullScreen = false;
                  });
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              '📊 Établissements analysés:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 10),
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
        
        Expanded(
          child: Chat(
            messages: _messages,
            onSendPressed: (partialText) => _handleSendPressed(partialText.text),
            user: _user,
            scrollController: _chatScrollController,
            customMessageBuilder: _buildCustomMessage,
            theme: const DefaultChatTheme(
              inputBackgroundColor: Colors.black, // Fond de la barre en noir
              inputTextColor: Colors.white, // Texte en blanc
              primaryColor: Colors.blueAccent,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardScreen() {
    return Column(
      children: [
        // 🔍 Barre de recherche
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (text) {
              setState(() {
                _isTyping = text.isNotEmpty;
              });
            },
            onSubmitted: _handleSendPressed,
            style: TextStyle(color: Colors.black), // Définir la couleur du texte
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              hintText: _isTyping ? "" : "Je vous écoute...",
              hintStyle: TextStyle(color: Colors.grey), // Couleur du texte de l'astuce
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              filled: true,
              fillColor: Colors.white, // Fond du champ de texte en blanc
            ),
          ),
        ),

        // 📊 Tableau de bord interactif
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInteractiveKpiCard("👀 Visibilité", "12K vues cette semaine", _fetchVisibilityStats),
                _buildInteractiveKpiCard("📈 Performance", "+15% interactions", _fetchPerformanceStats),
                _buildChart(),
                _buildRecommendations(),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildInteractiveKpiCard(String title, String value, VoidCallback onTap) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.trending_up, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        trailing: ElevatedButton(
          onPressed: onTap,
          child: const Text("🔍 Voir"),
        ),
      ),
    );
  }

  Widget _buildChart() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("📊 Évolution des ventes", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: _buildSalesChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    final List<_SalesData> data = [
      _SalesData('Lun', 35),
      _SalesData('Mar', 28),
      _SalesData('Mer', 34),
      _SalesData('Jeu', 32),
      _SalesData('Ven', 40),
      _SalesData('Sam', 50),
      _SalesData('Dim', 45),
    ];

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      series: <CartesianSeries<_SalesData, String>>[
        LineSeries<_SalesData, String>(
          dataSource: data,
          xValueMapper: (datum, _) => datum.day,
          yValueMapper: (datum, _) => datum.sales,
          markerSettings: const MarkerSettings(isVisible: true),
        )
      ],
    );
  }

  Widget _buildRecommendations() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.lightbulb, color: Colors.orange),
            title: Text("🔍 Actions recommandées", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _buildActionItem("📸 Ajoutez des photos HD pour +30% d’interactions."),
          _buildActionItem("📌 Testez une promo ciblée cette semaine."),
          _buildActionItem("🍽️ Ajoutez une option végétarienne au menu."),
        ],
      ),
    );
  }

  Widget _buildActionItem(String text) {
    return ListTile(
      leading: const Icon(Icons.check_circle, color: Colors.green),
      title: Text(text),
    );
  }
  
  Widget _buildCompetitiveAnalysisCard() {
    return GestureDetector(
      onTap: _fetchCompetitorInsights,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.compare_arrows, color: Colors.teal, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Analyse concurrentielle",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, size: 14, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text(
                        "Détails",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Découvrez comment vous vous positionnez par rapport à vos principaux concurrents et obtenez des recommandations personnalisées.",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _buildCompetitorsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitorsList() {
    return Column(
      children: [
        _buildCompetitorItem(
          name: "Le Bistrot Parisien",
          rating: 4.7,
          distance: "0.8 km",
          better: true,
        ),
        const Divider(height: 24),
        _buildCompetitorItem(
          name: "L'Atelier Gourmand",
          rating: 4.2,
          distance: "1.2 km",
          better: false,
        ),
        const Divider(height: 24),
        _buildCompetitorItem(
          name: "Saveurs du Monde",
          rating: 4.0,
          distance: "1.5 km",
          better: false,
        ),
      ],
    );
  }

  Widget _buildCompetitorItem({
    required String name,
    required double rating,
    required String distance,
    required bool better,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.restaurant, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  Text(
                    " $rating",
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.place, color: Colors.grey, size: 14),
                  Text(
                    " $distance",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: better ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            better ? "+10% mieux" : "-5% en retard",
            style: TextStyle(
              fontSize: 12,
              color: better ? Colors.green[700] : Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecommendationsCard(),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Recommandations IA",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Notre IA a analysé vos données et celles du marché pour vous proposer des actions à fort impact.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _buildRecommendationItem(
            icon: Icons.photo_camera,
            title: "Ajouter des photos de qualité",
            description: "Les établissements avec 5+ photos HD obtiennent +30% d'interactions",
            impact: "Élevé",
            effort: "Faible",
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            icon: Icons.local_offer,
            title: "Créer une promotion",
            description: "Les promotions créent un pic d'engagement de +45% en moyenne",
            impact: "Élevé",
            effort: "Moyen",
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            icon: Icons.restaurant_menu,
            title: "Mettre à jour votre menu",
            description: "Un menu à jour et complet améliore la visibilité dans les recherches",
            impact: "Moyen",
            effort: "Moyen",
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            icon: Icons.eco,
            title: "Ajouter options végétariennes",
            description: "Les options végétariennes attirent un nouveau segment de clientèle",
            impact: "Moyen",
            effort: "Faible",
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem({
    required IconData icon,
    required String title,
    required String description,
    required String impact,
    required String effort,
  }) {
    Color impactColor;
    Color effortColor;
    
    // Couleurs pour l'impact
    switch (impact) {
      case "Élevé":
        impactColor = Colors.green;
        break;
      case "Moyen":
        impactColor = Colors.orange;
        break;
      default:
        impactColor = Colors.blue;
    }
    
    // Couleurs pour l'effort
    switch (effort) {
      case "Faible":
        effortColor = Colors.green;
        break;
      case "Moyen":
        effortColor = Colors.orange;
        break;
      default:
        effortColor = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.blue[700], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: impactColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 12,
                      color: impactColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Impact: $impact",
                      style: TextStyle(
                        fontSize: 11,
                        color: impactColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: effortColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.build,
                      size: 12,
                      color: effortColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Effort: $effort",
                      style: TextStyle(
                        fontSize: 11,
                        color: effortColor,
                        fontWeight: FontWeight.bold,
                      ),
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

  /// 🔹 Construit un message personnalisé avec des liens cliquables - style amélioré
  Widget _buildCustomMessage(types.CustomMessage message, {required int messageWidth}) {
    final text = message.metadata?['text'] as String? ?? 'Message sans texte';
    final hasProfiles = message.metadata?['hasProfiles'] as bool? ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.author.id == 'assistant' 
            ? Colors.blue.withOpacity(0.1) 
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: message.author.id == 'assistant' 
              ? Colors.blue.withOpacity(0.2) 
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Afficher l'auteur avec icône
          Row(
            children: [
              Icon(
                message.author.id == 'assistant' ? Icons.smart_toy : Icons.business,
                size: 16,
                color: message.author.id == 'assistant' ? Colors.blue[700] : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                message.author.firstName ?? (message.author.id == 'assistant' ? 'Assistant' : 'Vous'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: message.author.id == 'assistant' ? Colors.blue[700] : Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Afficher le texte avec des liens cliquables
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.black87,
                fontSize: 15,
                height: 1.4, // Améliore l'espacement des lignes
              ),
              children: hasProfiles
                ? AIService.parseMessageWithLinks(
                    text,
                    (type, id) => _navigateToProfile(type, id),
                  )
                : [TextSpan(text: text)],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 🔹 Navigue vers un profil spécifique
  void _navigateToProfile(String type, String id) {
    print('📊 Navigation vers le profil de type $type avec ID: $id');
    
    try {
      switch (type) {
        case 'restaurant':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.producerId, // On utilise l'ID du producteur comme utilisateur
              ),
            ),
          );
          break;
        case 'leisureProducer':
          // Récupérer les données du producteur de loisirs
          _fetchAndNavigateToLeisureProducer(id);
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Type de profil non pris en charge: $type')),
          );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de navigation: $e')),
      );
    }
  }

  /// 🔹 Récupère les données d'un producteur de loisirs et navigue vers son profil
  Future<void> _fetchAndNavigateToLeisureProducer(String id) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerLeisureScreen(producerData: data),
          ),
        );
      } else {
        throw Exception('Impossible de récupérer les données du producteur de loisirs');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  /// 🔹 Construit une carte pour un profil extrait - design amélioré
  Widget _buildProfileCard(ProfileData profile) {
    return GestureDetector(
      onTap: () => _navigateToProfile(profile.type, profile.id),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du profil - plus grande et mieux gérée
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: profile.image != null && profile.image!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profile.image!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: const Center(
                          child: SizedBox(
                            width: 20, 
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            _getIconForType(profile.type),
                            color: Colors.blue[200],
                            size: 40,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      height: 100,
                      color: Colors.grey[200],
                      width: double.infinity,
                      child: Center(
                        child: Icon(
                          _getIconForType(profile.type),
                          color: Colors.blue[200],
                          size: 40,
                        ),
                      ),
                    ),
              ),
              
              const SizedBox(height: 8),
              
              // Nom du profil avec style amélioré
              Text(
                profile.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Adresse si disponible
              if (profile.address != null && profile.address!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    profile.address!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              
              // Note avec étoiles et niveau de prix
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    if (profile.rating != null) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      Text(' ${profile.rating!.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                    ],
                    
                    if (profile.priceLevel != null) ...[
                      Text(
                        '${_getPriceSymbol(profile.priceLevel!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Catégorie avec style amélioré
              if (profile.category.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    profile.category.first,
                    style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Fonctions helpers pour le style
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
        return Icons.business;
    }
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
}

class _SalesData {
  final String day;
  final int sales;
  _SalesData(this.day, this.sales);
}
