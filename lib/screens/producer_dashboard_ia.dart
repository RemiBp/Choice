import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final message = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'Assistant AI'),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: "Bienvenue ! Posez-moi vos questions ou consultez votre tableau de bord. 📊",
    );

    setState(() {
      _messages.insert(0, message);
    });
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
    });

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

  Future<String> fetchBotResponse(String producerId, String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:5000/api/chat/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"producerId": producerId, "userMessage": userMessage}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["reply"];
      } else {
        return "Erreur de connexion au chatbot.";
      }
    } catch (e) {
      return "Erreur réseau : $e";
    }
  }

  Future<void> _fetchVisibilityStats() async {
    _handleSendPressed("Donne-moi le nombre de choices que j'ai reçus depuis la dernière fois.");
  }

  Future<void> _fetchPerformanceStats() async {
    _handleSendPressed("Combien de fois suis-je apparu dans le feed récemment ?");
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
        Expanded(
          child: Chat(
            messages: _messages,
            onSendPressed: (partialText) => _handleSendPressed(partialText.text),
            user: _user,
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
}

class _SalesData {
  final String day;
  final int sales;
  _SalesData(this.day, this.sales);
}
