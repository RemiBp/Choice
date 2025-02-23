import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les événements
import 'profile_screen.dart'; // Pour les utilisateurs

class ProducerSearchPage extends StatefulWidget {
  final String userId; // Ajout du champ userId

  const ProducerSearchPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProducerSearchPageState createState() => _ProducerSearchPageState();
}

class _ProducerSearchPageState extends State<ProducerSearchPage> {
  List<dynamic> _producerResults = [];
  List<dynamic> _userResults = [];
  String _query = "";
  bool _isLoading = false;
  String _errorMessage = "";

  List<types.Message> _messages = [];
  final _user = const types.User(id: 'user');
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  /// 🔹 Message d'accueil du Copilot
  void _addWelcomeMessage() {
    final message = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'Copilot AI'),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: "Posez-moi vos questions ou explorez les suggestions ci-dessous ! 🤖",
    );

    setState(() {
      _messages.insert(0, message);
    });
  }

  /// 🔹 Recherche des producteurs, événements et utilisateurs
  Future<void> _searchItems() async {
    if (_query.isEmpty) {
      setState(() {
        _producerResults = [];
        _userResults = [];
        _errorMessage = "Veuillez entrer un mot-clé pour la recherche.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final url = Uri.parse('${getBaseUrl()}/api/unified/search?query=$_query');
      print('🔍 Requête vers : $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        setState(() {
          _producerResults = results.where((item) => item['type'] != 'user').toList();
          _userResults = results.where((item) => item['type'] == 'user').toList();

          if (_producerResults.isEmpty && _userResults.isEmpty) {
            _errorMessage = "Aucun résultat trouvé pour cette recherche.";
          }
        });
      } else {
        setState(() {
          _errorMessage = "Erreur lors de la récupération des résultats : ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur réseau : $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 🔹 Envoi d'une requête au Copilot
  Future<void> _handleSendPressed(String message) async {
    if (message.isEmpty) return;

    final userMessage = types.TextMessage(
      author: _user,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message,
    );

    setState(() {
      _messages.insert(0, userMessage);
      _searchController.clear();
    });

    String botResponse = await fetchBotResponse(widget.userId, message);

    final botMessage = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'Copilot AI'),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: botResponse,
    );

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.insert(0, botMessage);
      });
    });
  }

  Future<void> _navigateToDetails(String id, String type) async {
    print('🔍 Navigation vers l\'ID : $id (Type : $type)');

    try {
      switch (type) {
        case 'restaurant':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProducerScreen(
                producerId: id,
                userId: widget.userId, // Passe l'userId ici
              ),
            ),
          );
          break;
        case 'leisureProducer':
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
          }
          break;
        case 'event':
          final url = Uri.parse('${getBaseUrl()}/api/events/$id');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventLeisureScreen(eventData: data),
              ),
            );
          }
          break;
        case 'user':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: id),
            ),
          );
          break;
        default:
          setState(() {
            _errorMessage = "Type non reconnu.";
          });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur réseau : $e";
      });
    }
  }

  /// 🔹 Requête API vers le backend
  Future<String> fetchBotResponse(String userId, String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse("${getBaseUrl()}/api/chat/user/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId, "userMessage": userMessage}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["reply"];
      } else {
        return "Erreur de connexion au Copilot.";
      }
    } catch (e) {
      return "Erreur réseau : $e";
    }
  }

Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Recherche & Copilot'),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 🔍 Barre de recherche
          TextField(
            decoration: const InputDecoration(
              labelText: 'Rechercher...',
              suffixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _query = value.trim();
              });
            },
            onSubmitted: (_) => _searchItems(),
          ),

          const SizedBox(height: 16),

          // 🔥 Suggestions rapides
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _buildQuickSearchButton("🍽️ Bons plans restaurants", "Quels sont les meilleurs restaurants en promo ?"),
                _buildQuickSearchButton("🎭 Spectacle comique ce soir", "Quels spectacles humoristiques voir ce soir ?"),
                _buildQuickSearchButton("🎶 Concerts gratuits", "Y a-t-il des concerts gratuits bientôt ?"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔄 Chargement / Erreur
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage.isNotEmpty)
            Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            )
          else if (_producerResults.isEmpty && _userResults.isEmpty)
            const Center(
              child: Text(
                "Aucun résultat pour l'instant. Lancez une recherche.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  if (_producerResults.isNotEmpty) ...[
                    const Divider(),
                    const Text(
                      'Producteurs et événements',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    ..._producerResults.map((item) {
                      final String type = item['type'] ?? 'unknown';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(item['image'] ?? item['photo'] ?? ''),
                        ),
                        title: Text(item['intitulé'] ?? item['name'] ?? 'Nom non spécifié'),
                        subtitle: Text(item['adresse'] ?? 'Adresse non spécifiée'),
                        onTap: () => _navigateToDetails(item['_id'], type),
                      );
                    }).toList(),
                  ],
                  if (_userResults.isNotEmpty) ...[
                    const Divider(),
                    const Text(
                      'Utilisateurs',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    ..._userResults.map((user) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(user['photo_url'] ?? ''),
                        ),
                        title: Text(user['name'] ?? 'Nom non spécifié'),
                        onTap: () => _navigateToDetails(user['_id'], 'user'),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 10),

          // 🤖 Copilot en bas de page
          Expanded(
            child: Chat(
              messages: _messages,
              onSendPressed: (partialText) => _handleSendPressed(partialText.text),
              user: _user,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 🔹 Bouton pour les recherches rapides
Widget _buildQuickSearchButton(String title, String query) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4.0),
    child: ElevatedButton(
      onPressed: () => _handleSendPressed(query),
      child: Text(title),
    ),
  );
}

}
