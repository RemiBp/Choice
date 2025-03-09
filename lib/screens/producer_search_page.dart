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
import 'package:scroll_to_index/scroll_to_index.dart'; // Pour le contrôleur de défilement

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
  bool _isFullScreenChat = false; // Variable pour suivre le mode plein écran
  final AutoScrollController _chatScrollController = AutoScrollController(); // Contrôleur de défilement pour le chat

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

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("La requête a pris trop de temps. Veuillez réessayer.");
        },
      );

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
      _isFullScreenChat = true; // Activer automatiquement le mode plein écran lors de l'envoi d'un message
    });

    try {
      print("🔍 Envoi de la requête au service AI: $message");
      
      // Afficher un indicateur de chargement
      final loadingMessage = types.TextMessage(
        author: const types.User(id: 'assistant', firstName: 'Copilot AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Recherche en cours...",
      );
      
      setState(() {
        _messages.insert(0, loadingMessage);
      });
      
      // Appel principal au service AI avec plusieurs tentatives
      AIQueryResponse aiResponse;
      try {
        // Premier essai - route principale
        aiResponse = await _aiService.userQuery(widget.userId, message);
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
      
      // Supprimer le message de chargement
      setState(() {
        _messages.removeAt(0);
      });
      
      // Traitement de la réponse réussie
      print("✅ Réponse AI reçue: ${aiResponse.profiles.length} profils");
      
      // Enregistrer les profils extraits
      if (aiResponse.profiles.isNotEmpty) {
        setState(() {
          _extractedProfiles = aiResponse.profiles;
        });
      }
      
      // Si la recherche est une requête de type recherche, lancer également une recherche classique
      if (aiResponse.intent == "restaurant_search" || 
          aiResponse.intent == "event_search" || 
          aiResponse.intent == "leisure_search") {
        setState(() {
          _query = message; // Définir la requête avant d'appeler _searchItems()
        });
        _searchItems(); // Appel sans argument (utilisant _query)
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

      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _messages.insert(0, botMessage);
        });
      });
    } catch (e) {
      print("❌ Erreur lors de l'appel à l'IA: $e");
      
      // Supprimer le message de chargement s'il existe
      if (_messages.isNotEmpty && _messages[0].author.id == 'assistant') {
        setState(() {
          _messages.removeAt(0);
        });
      }
      
      // Message d'erreur simple en cas d'échec complet
      final botMessage = types.TextMessage(
        author: const types.User(id: 'assistant', firstName: 'Copilot AI'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Désolé, je rencontre des difficultés à me connecter à la base de données. Veuillez réessayer plus tard ou contacter le support si le problème persiste.",
      );

      setState(() {
        _messages.insert(0, botMessage);
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
          // Afficher un indicateur de chargement
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Dialog(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text("Chargement des informations..."),
                    ],
                  ),
                ),
              );
            },
          );
          
          try {
            final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
            final response = await http.get(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception("La requête a pris trop de temps. Veuillez réessayer.");
              },
            );
            
            // Fermer l'indicateur de chargement
            Navigator.of(context).pop();
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
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
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            
            // Afficher un message d'erreur
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Erreur lors du chargement: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        case 'event':
          // Afficher un indicateur de chargement
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Dialog(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text("Chargement de l'événement..."),
                    ],
                  ),
                ),
              );
            },
          );
          
          try {
            final url = Uri.parse('${getBaseUrl()}/api/events/$id');
            final response = await http.get(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception("La requête a pris trop de temps. Veuillez réessayer.");
              },
            );
            
            // Fermer l'indicateur de chargement
            Navigator.of(context).pop();
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
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
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            
            // Afficher un message d'erreur
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Erreur lors du chargement: $e"),
                backgroundColor: Colors.red,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Type non reconnu: $type"),
              backgroundColor: Colors.orange,
            ),
          );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur de navigation: $e"),
          backgroundColor: Colors.red,
        ),
      );
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
      
      // Message d'erreur clair sans fallback vers des routes obsolètes
      return "Désolé, je ne peux pas traiter votre demande pour le moment. Veuillez réessayer plus tard.";
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 120, // Ajusté pour éviter le débordement
                maxHeight: double.infinity, // Pas de limite de hauteur max
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔍 Barre de recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Rechercher...',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchItems(),
                        ),
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

                  // 🤖 Copilot en mode normal ou plein écran selon l'état
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(8),
                    height: _isFullScreenChat 
                      ? MediaQuery.of(context).size.height * 0.6 // 60% de la hauteur de l'écran en mode plein écran
                      : 220, // Taille normale légèrement agrandie
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // En-tête du copilot avec bouton de basculement plein écran
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.smart_toy, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text('Copilot AI', 
                                      style: TextStyle(
                                        color: Colors.white, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Bouton pour basculer le mode plein écran
                              IconButton(
                                icon: Icon(
                                  _isFullScreenChat ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isFullScreenChat = !_isFullScreenChat;
                                  });
                                },
                                tooltip: _isFullScreenChat ? 'Réduire le chat' : 'Agrandir le chat',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              const SizedBox(width: 8),
                              if (!_isFullScreenChat)
                                Flexible(
                                  child: Text(
                                    "Posez vos questions ici",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Zone de chat améliorée - s'adapte à la hauteur du conteneur
                        Expanded(
                          child: Chat(
                            messages: _messages,
                            onSendPressed: (partialText) => _handleSendPressed(partialText.text),
                            user: _user,
                            scrollController: _chatScrollController,
                            customMessageBuilder: _buildCustomMessage,
                            theme: const DefaultChatTheme(
                              inputBackgroundColor: Colors.white,
                              inputTextColor: Colors.black87,
                              inputTextCursorColor: Colors.blueAccent,
                              primaryColor: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 📍 Profils extraits par l'IA (s'il y en a et si le chat n'est pas en plein écran)
                  if (_extractedProfiles.isNotEmpty && !_isFullScreenChat) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Icon(Icons.search, color: Colors.blueAccent, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Suggestions par IA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16,
                                    color: Colors.blueAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 170,
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
                    ),
                  ],

                  // 🔄 Chargement / Erreur / Résultats (seulement si le chat n'est pas en plein écran)
                  if (!_isFullScreenChat)
                    _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage.isNotEmpty && _extractedProfiles.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : (_producerResults.isEmpty && _userResults.isEmpty && _extractedProfiles.isEmpty)
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Posez une question au Copilot AI\nou lancez une recherche classique",
                                      style: TextStyle(color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_producerResults.isNotEmpty) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: const Text(
                                      'Restaurants et lieux',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 18,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  ...(_producerResults.map((item) {
                                    final String type = item['type'] ?? 'unknown';
                                    return _buildResultCard(
                                      id: item['_id'],
                                      type: type,
                                      title: item['intitulé'] ?? item['name'] ?? 'Nom non spécifié',
                                      subtitle: item['adresse'] ?? item['address'] ?? 'Adresse non spécifiée',
                                      imageUrl: item['image'] ?? item['photo'] ?? item['photo_url'] ?? '',
                                      rating: item['rating'],
                                      price: item['price_level'],
                                      categories: item['category'],
                                    );
                                  }).toList()),
                                ],
                                if (_userResults.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: const Text(
                                      'Utilisateurs',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 18,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  ...(_userResults.map((user) {
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: user['photo_url'] != null && user['photo_url'].isNotEmpty 
                                          ? NetworkImage(user['photo_url'])
                                          : null,
                                        backgroundColor: Colors.grey[300],
                                        child: (user['photo_url'] == null || user['photo_url'] == '') 
                                          ? const Icon(Icons.person, color: Colors.grey)
                                          : null,
                                      ),
                                      title: Text(user['name'] ?? 'Nom non spécifié'),
                                      subtitle: Text(user['username'] ?? ''),
                                      onTap: () => _navigateToDetails(user['_id'], 'user'),
                                    );
                                  }).toList()),
                                ],
                              ],
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Bouton pour les recherches rapides avec style amélioré
  Widget _buildQuickSearchButton(String title, String query) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () => _handleSendPressed(query),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(title),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Afficher l'auteur avec icône
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.author.id == 'assistant' ? Icons.smart_toy : Icons.person,
                size: 16,
                color: message.author.id == 'assistant' ? Colors.blueAccent : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message.author.firstName ?? (message.author.id == 'assistant' ? 'Assistant' : 'Vous'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: message.author.id == 'assistant' ? Colors.blueAccent : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Afficher le texte avec des liens cliquables
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: messageWidth.toDouble()),
              child: RichText(
                overflow: TextOverflow.clip,
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
  
  /// 🔹 Construit une carte pour un profil extrait - design amélioré et corrigé
  Widget _buildProfileCard(ProfileData profile) {
    // Remplacer les URLs placeholder par des URLs fiables
    String imageUrl = profile.image ?? '';
    if (imageUrl.contains('placeholder.com') || imageUrl.isEmpty) {
      switch (profile.type) {
        case 'restaurant':
          imageUrl = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80';
          break;
        case 'event':
          imageUrl = 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80';
          break;
        case 'leisureProducer':
          imageUrl = 'https://images.unsplash.com/photo-1471967183320-ee018f6e114a?w=500&q=80';
          break;
        default:
          imageUrl = 'https://images.unsplash.com/photo-1471967183320-ee018f6e114a?w=500&q=80';
      }
    }
    
    return GestureDetector(
      onTap: () => _navigateToProfile(profile.type, profile.id),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Réduit marge verticale
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        child: SizedBox(
          width: 155, // Légèrement réduit pour éviter débordement
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 155, // Hauteur maximale contrainte
            ),
            child: Padding(
              padding: const EdgeInsets.all(6), // Padding réduit
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Utilise minimal space
                children: [
                  // Image du profil - hauteur réduite pour éviter débordement
                  SizedBox(
                    height: 75, // Hauteur réduite
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
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
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              _getIconForType(profile.type),
                              color: Colors.grey[400],
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 4), // Espacement réduit
                  
                  // Nom du profil avec style amélioré
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12, // Taille réduite
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Adresse si disponible
                  if (profile.address != null && profile.address!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1.0), // Padding réduit
                      child: Text(
                        profile.address!,
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]), // Taille réduite
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  
                  // Note avec étoiles et niveau de prix
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0), // Padding réduit
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (profile.rating != null) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 10), // Taille réduite
                          Text(' ${profile.rating!.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 10)), // Taille réduite
                          const SizedBox(width: 4), // Espacement réduit
                        ],
                        
                        if (profile.priceLevel != null)
                          Flexible(
                            child: Text(
                              _getPriceSymbol(profile.priceLevel!),
                              style: const TextStyle(fontSize: 10), // Taille réduite
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Catégorie - badge rendu plus compact
                  if (profile.category.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2), // Marge réduite
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Padding réduit
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile.category.first,
                        style: TextStyle(fontSize: 8, color: Colors.grey[700]), // Taille réduite
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 🔹 Construit une carte de résultat pour la liste principale avec corrections des débordements
  Widget _buildResultCard({
    required String id,
    required String type,
    required String title,
    required String subtitle,
    required String imageUrl,
    dynamic rating,
    dynamic price,
    dynamic categories,
  }) {
    // Utiliser une URL d'image plus fiable si l'URL actuelle contient placeholder.com
    if (imageUrl.contains('placeholder.com') || imageUrl.isEmpty) {
      // Utiliser une image de repli en fonction du type
      switch (type) {
        case 'restaurant':
          imageUrl = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80';
          break;
        case 'event':
          imageUrl = 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80';
          break;
        case 'leisureProducer':
          imageUrl = 'https://images.unsplash.com/photo-1471967183320-ee018f6e114a?w=500&q=80';
          break;
        default:
          imageUrl = 'https://images.unsplash.com/photo-1471967183320-ee018f6e114a?w=500&q=80';
      }
    }

    return GestureDetector(
      onTap: () => _navigateToDetails(id, type),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image avec taille fixe pour éviter les problèmes de layout
              SizedBox(
                width: 80,
                height: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
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
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              _getIconForType(type),
                              color: Colors.grey[400],
                              size: 30,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            _getIconForType(type),
                            color: Colors.grey[400],
                            size: 30,
                          ),
                        ),
                      ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Informations - utilisation d'Expanded pour éviter les débordements
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titre
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Adresse
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Évaluation et prix - réorganisés pour éviter les débordements
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          // Section gauche (notes et prix) avec Expanded
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (rating != null) ...[
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      rating is double 
                                          ? rating.toStringAsFixed(1)
                                          : rating.toString(),
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                
                                if (price != null && price is num && price > 0)
                                  Text(
                                    _getPriceSymbol(price),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Badge de type à droite - avec contraintes de taille
                          Container(
                            constraints: const BoxConstraints(maxWidth: 70),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getColorForType(type),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getLabelForType(type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Catégories avec scroll horizontal pour éviter les débordements
                    if (categories != null) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 22, // Hauteur fixe
                        child: _buildCategoriesChips(categories),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fonction helper optimisée pour afficher les catégories
  Widget _buildCategoriesChips(dynamic categories) {
    List<String> categoryList = [];
    
    if (categories is List) {
      categoryList = categories.map((c) => c.toString()).toList();
    } else if (categories is String) {
      categoryList = [categories];
    }
    
    if (categoryList.isEmpty) return const SizedBox.shrink();
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const AlwaysScrollableScrollPhysics(), // Permet toujours le défilement
      itemCount: categoryList.length > 3 ? 3 : categoryList.length,
      itemBuilder: (context, index) {
        final category = categoryList[index];
        return Container(
          margin: const EdgeInsets.only(right: 5),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(maxWidth: 80), // Limite la largeur max des puces
          child: Text(
            category,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      },
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
        return Icons.place;
    }
  }
  
  Color _getColorForType(String type) {
    switch (type) {
      case 'restaurant':
        return Colors.orange;
      case 'leisureProducer':
        return Colors.purple;
      case 'event':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
  
  String _getLabelForType(String type) {
    switch (type) {
      case 'restaurant':
        return 'Restaurant';
      case 'leisureProducer':
        return 'Loisir';
      case 'event':
        return 'Événement';
      default:
        return type.substring(0, 1).toUpperCase() + type.substring(1);
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