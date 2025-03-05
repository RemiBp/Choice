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
      // Utiliser le service AI avec accès direct aux données MongoDB
      final aiResponse = await _aiService.producerQuery(widget.producerId, message);
      
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
      
      // Fallback sur l'ancienne méthode en cas d'erreur
      String botResponse = await fetchBotResponse(widget.producerId, message);
      
      final botMessage = types.TextMessage(
        author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: botResponse,
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
      return "Erreur lors de la communication avec l'assistant IA: $e";
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
  
  /// 🔹 Construit un message personnalisé avec des liens cliquables
  Widget _buildCustomMessage(types.CustomMessage message, {required int messageWidth}) {
    final text = message.metadata?['text'] as String? ?? 'Message sans texte';
    final hasProfiles = message.metadata?['hasProfiles'] as bool? ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Afficher l'auteur
          Text(
            message.author.firstName ?? 'Assistant',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          
          // Afficher le texte avec des liens cliquables
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
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

  /// 🔹 Construit une carte pour un profil extrait
  Widget _buildProfileCard(ProfileData profile) {
    return GestureDetector(
      onTap: () => _navigateToProfile(profile.type, profile.id),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du profil
              if (profile.image != null && profile.image!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: profile.image!,
                    height: 50,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 50,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                )
              else
                Container(
                  height: 50,
                  color: Colors.grey[300],
                  width: double.infinity,
                  child: Icon(
                    profile.type == 'restaurant' ? Icons.restaurant :
                    profile.type == 'leisureProducer' ? Icons.local_activity :
                    Icons.store,
                    color: Colors.grey[500],
                  ),
                ),
              
              const SizedBox(height: 5),
              
              // Nom du profil
              Text(
                profile.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Note et catégorie
              if (profile.rating != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(' ${profile.rating!.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              
              if (profile.category.isNotEmpty)
                Text(
                  profile.category.first,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesData {
  final String day;
  final int sales;
  _SalesData(this.day, this.sales);
}
