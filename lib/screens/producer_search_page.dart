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

    try {
      print("🔍 Envoi de la requête au service AI: $message");
      
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

      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _messages.insert(0, botMessage);
        });
      });
    } catch (e) {
      print("❌ Erreur lors de l'appel à l'IA: $e");
      
      // Message d'erreur simple en cas d'échec complet
      final botMessage = types.TextMessage(
        author: const types.User(id: 'assistant', firstName: 'Copilot AI'),
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

            // 🤖 Copilot en haut - plus visible et accessible
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête du copilot
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
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
                        Text(
                          "Posez vos questions ici",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Zone de chat améliorée - priorité plus haute
                  SizedBox(
                    height: 200, // Taille fixe pour assurer la visibilité
                    child: Chat(
                      messages: _messages,
                      onSendPressed: (partialText) => _handleSendPressed(partialText.text),
                      user: _user,
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

            // 📍 Profils extraits par l'IA (s'il y en a)
            if (_extractedProfiles.isNotEmpty) ...[
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
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.search, color: Colors.blueAccent, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Suggestions par IA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
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

            // 🔄 Chargement / Erreur / Résultats
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty && _extractedProfiles.isEmpty
                  ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : (_producerResults.isEmpty && _userResults.isEmpty && _extractedProfiles.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      )
                    : ListView(
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
                                  backgroundImage: NetworkImage(user['photo_url'] ?? ''),
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
            ),
          ],
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
        children: [
          // Afficher l'auteur avec icône
          Row(
            children: [
              Icon(
                message.author.id == 'assistant' ? Icons.smart_toy : Icons.person,
                size: 16,
                color: message.author.id == 'assistant' ? Colors.blueAccent : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                message.author.firstName ?? (message.author.id == 'assistant' ? 'Assistant' : 'Vous'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: message.author.id == 'assistant' ? Colors.blueAccent : Colors.grey[700],
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
    print('🔍 Navigation vers le profil de type $type avec ID: $id');
    _navigateToDetails(id, type);
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
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
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
                            color: Colors.grey[400],
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
                          color: Colors.grey[400],
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
                    
                    if (profile.price_level != null) ...[
                      Text(
                        '${_getPriceSymbol(profile.price_level!)}',
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
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    profile.category.first,
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
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
  
  /// 🔹 Construit une carte de résultat pour la liste principale
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
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
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
                        width: 80,
                        height: 80,
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
                      width: 80,
                      height: 80,
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
              
              const SizedBox(width: 12),
              
              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    
                    // Évaluation et prix
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          // Note avec étoiles
                          if (rating != null) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            Text(' ${rating is double ? rating.toStringAsFixed(1) : rating}',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 12),
                          ],
                          
                          // Niveau de prix
                          if (price != null && price is num && price > 0) ...[
                            Text(
                              _getPriceSymbol(price),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          
                          const Spacer(),
                          
                          // Type d'établissement
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getColorForType(type),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getLabelForType(type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Catégories si disponibles
                    if (categories != null) ...[
                      const SizedBox(height: 6),
                      _buildCategoriesChips(categories),
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

  // Fonction helper pour afficher les catégories
  Widget _buildCategoriesChips(dynamic categories) {
    List<String> categoryList = [];
    
    if (categories is List) {
      categoryList = categories.map((c) => c.toString()).toList();
    } else if (categories is String) {
      categoryList = [categories];
    }
    
    if (categoryList.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 22,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categoryList.length > 3 ? 3 : categoryList.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              categoryList[index],
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            ),
          );
        },
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
