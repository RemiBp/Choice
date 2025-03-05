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
import '../services/ai_service.dart'; // Import du nouveau service AI
import 'package:cached_network_image/cached_network_image.dart'; // Pour charger les images avec cache

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
  List<ProfileData> _extractedProfiles = []; // Pour stocker les profils extraits par l'IA

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  /// 🔹 Message d'accueil du Copilot
  final AIService _aiService = AIService(); // Instance du service AI
  
  void _addWelcomeMessage() {
    final message = types.TextMessage(
      author: const types.User(id: 'assistant', firstName: 'Copilot AI'),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: "Posez-moi vos questions ou explorez les suggestions ci-dessous ! 🤖\nJe peux maintenant accéder directement à toutes les données pour vous proposer les meilleures recommandations personnalisées.",
    );

    setState(() {
      _messages.insert(0, message);
    });
    
    // Charger des suggestions personnalisées au démarrage
    _loadPersonalizedSuggestions();
  }
  
  void _loadPersonalizedSuggestions() async {
    try {
      // Utiliser le service AI pour obtenir des insights personnalisés
      final insights = await _aiService.getUserInsights(widget.userId);
      // Les insights peuvent être utilisés plus tard pour améliorer l'expérience utilisateur
    } catch (e) {
      print("❌ Erreur lors du chargement des suggestions personnalisées: $e");
    }
  }

  /// 🔹 Recherche des producteurs, événements et utilisateurs
  Future<void> _searchItems([String? queryOverride]) async {
    String searchQuery = queryOverride ?? _query;
    if (searchQuery.isEmpty) {
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

  /// 🔹 Envoi d'une requête au Copilot avec accès MongoDB en temps réel
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
      _extractedProfiles = []; // Réinitialiser les profils extraits
    });

    // Utiliser le service AI avec accès direct aux données MongoDB
    try {
      final aiResponse = await _aiService.userQuery(widget.userId, message);
      
      // Enregistrer les profils extraits
      if (aiResponse.profiles.isNotEmpty) {
        setState(() {
          _extractedProfiles = aiResponse.profiles;
        });
      }
      
      // Créer le message du bot avec la réponse de l'IA
      final botMessage = types.CustomMessage(
        author: const types.User(id: 'assistant', firstName: 'Copilot AI'),
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

  /// 🔹 Requête API vers le backend avec le service AI avancé
  Future<String> fetchBotResponse(String userId, String userMessage) async {
    try {
      // Utilisation du service AI avec accès direct aux données MongoDB
      final result = await _aiService.userQuery(userId, userMessage);
      
      // Si la recherche est une requête de type recherche, lancer également une recherche classique
      if (result.intent == "restaurant_search" || 
          result.intent == "event_search" || 
          result.intent == "leisure_search") {
        setState(() {
          _query = userMessage; // Définir la requête avant d'appeler _searchItems()
        });
        _searchItems(); // Appel sans argument (utilisant _query)
      }
      
      // Retourner la réponse complète générée par l'IA
      return result.response;
    } catch (e) {
      print("❌ Erreur lors de l'appel au service AI: $e");
      
      // Fallback sur l'ancienne implémentation
      try {
        final response = await http.post(
          Uri.parse("${getBaseUrl()}/api/chat/user/chat"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"userId": userId, "userMessage": userMessage}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data["reply"];
        }
      } catch (_) {}
      
      return "Erreur lors de la communication avec l'assistant IA: $e";
    }
  }

  @override
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher...',
                  suffixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value.trim();
                  });
                },
                onSubmitted: (_) => _searchItems(),
              ),
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

            // 🔄 Chargement / Erreur / Résultats
            Expanded(
              flex: 1,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty 
                  ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : (_producerResults.isEmpty && _userResults.isEmpty)
                    ? const Center(
                        child: Text(
                          "Aucun résultat pour l'instant. Lancez une recherche.",
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
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
            
            // 📍 Profils extraits par l'IA (s'il y en a)
            if (_extractedProfiles.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '🔍 Lieux correspondants trouvés:',
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

            // 🤖 Copilot en bas de page
            Expanded(
              flex: 1,
              child: Chat(
                messages: _messages,
                onSendPressed: (partialText) => _handleSendPressed(partialText.text),
                user: _user,
                customMessageBuilder: _buildCustomMessage,
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
  
  /// 🔹 Construit un message personnalisé avec des liens cliquables
  Widget _buildCustomMessage(types.CustomMessage message, {required int messageWidth}) {
    final text = message.metadata?['text'] as String? ?? 'Message sans texte';
    final hasProfiles = message.metadata?['hasProfiles'] as bool? ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
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
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 4),
          
          // Afficher le texte avec des liens cliquables
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.black,
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
    print('🔍 Navigation vers le profil de type $type avec ID: $id');
    _navigateToDetails(id, type);
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
                    profile.type == 'event' ? Icons.event : Icons.place,
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
