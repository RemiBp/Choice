import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart'; // Pour les utilisateurs
import 'producer_screen.dart'; // Pour les producteurs
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs

class MessagingScreen extends StatefulWidget {
  final String userId;

  const MessagingScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  List<Map<String, dynamic>> conversations = [];
  bool isLoading = true;
  String searchQuery = '';
  List<Map<String, dynamic>> filteredConversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    filteredConversations = conversations; // Initialiser avec toutes les conversations
  }

  void _navigateToDetails(String id, bool isProducer) {
    if (isProducer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerScreen(producerId: id),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: id),
        ),
      );
    }
  }

  void _filterConversations(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredConversations = conversations;
      } else {
        filteredConversations = conversations
            .where((conversation) =>
                (conversation['name'] ?? '').toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }
  

  Future<Map<String, dynamic>?> _fetchProfileDetails(String id, String type) async {
    try {
      String endpoint = '';
      switch (type) {
        case 'user':
          endpoint = 'http://10.0.2.2:5000/api/users/$id';
          break;
        case 'producer':
          endpoint = 'http://10.0.2.2:5000/api/producers/$id';
          break;
        case 'leisureProducer':
          endpoint = 'http://10.0.2.2:5000/api/leisureProducers/$id';
          break;
      }

      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching profile details: $e');
    }
    return null;
  }

  Future<void> _fetchConversations() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/conversations/${widget.userId}/conversations'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Conversations reçues: $data');

        List<Map<String, dynamic>> enrichedConversations = [];

        for (var conversation in data) {
          final participants = conversation['participants'] ?? [];
          final messages = conversation['messages'] ?? [];

          if (participants.isEmpty) {
            print('⚠️ Pas de participants pour la conversation ${conversation['_id']}');
            continue;
          }

          // Trouver l'autre participant
          final otherParticipantId = participants.firstWhere(
            (id) => id != widget.userId,
            orElse: () => null,
          );

          if (otherParticipantId != null) {
            final participantDetails =
                await _fetchParticipantDetails(otherParticipantId);

            if (participantDetails != null) {
              enrichedConversations.add({
                'id': conversation['_id'] ?? '',
                'name': participantDetails['name'] ?? 'Inconnu',
                'image': participantDetails['photo_url'] ?? '',
                'lastMessage': messages.isNotEmpty
                    ? messages.last['content'] ?? 'Pas encore de message'
                    : 'Pas encore de message',
                'profileId': otherParticipantId,
                'type': participantDetails['type'] ?? 'user',
              });
            } else {
              print('⚠️ Aucun détail trouvé pour le participant $otherParticipantId');
            }
          }
        }

        setState(() {
          conversations = enrichedConversations;
          filteredConversations = enrichedConversations; // Synchroniser les deux listes
          isLoading = false;
        });
      } else {
        print('❌ Échec de récupération des conversations: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur : $e');
    }
  }




  Future<Map<String, dynamic>?> _fetchParticipantDetails(String id) async {
    final List<String> endpoints = [
      'http://10.0.2.2:5000/api/users/$id',
      'http://10.0.2.2:5000/api/producers/$id',
      'http://10.0.2.2:5000/api/leisureProducers/$id',
    ];

    for (var endpoint in endpoints) {
      try {
        final response = await http.get(Uri.parse(endpoint));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (endpoint.contains('users')) {
            return {
              'name': data['name'],
              'photo_url': data['photo_url'],
              'type': 'user',
            };
          } else if (endpoint.contains('producers')) {
            return {
              'name': data['name'],
              'photo_url': data['photo'],
              'type': 'producer',
            };
          } else if (endpoint.contains('leisureProducers')) {
            return {
              'name': data['lieu'],
              'photo_url': '',
              'type': 'leisureProducer',
            };
          }
        } else {
          print('❌ Requête échouée vers $endpoint avec statut ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Erreur réseau pour le participant $id via $endpoint: $e');
      }
    }

    return null; // Si aucune requête n'a fonctionné
  }

  Future<void> _searchAndNavigate(String query) async {
    if (query.isEmpty) return;

    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/unified/search?query=$query'));
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        if (results.isEmpty) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Aucun résultat trouvé'),
              content: const Text('Aucun utilisateur ou producteur correspondant à votre recherche.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        // Afficher les résultats
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Résultats de recherche'),
              content: SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    final String name = item['name'] ?? 'Nom non spécifié';
                    final String id = item['_id'] ?? '';
                    final String type = item['type'] ?? 'user';

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('Type: $type'),
                      onTap: () async {
                        Navigator.pop(context);

                        // Vérifier si une conversation existe déjà
                        final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/conversations/${widget.userId}/check/$id'));
                        if (response.statusCode == 200) {
                          final data = json.decode(response.body);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                userId: widget.userId,
                                conversationId: data['conversationId'], // Conversation existante ou nouvelle
                                name: name,
                                image: item['photo_url'] ?? '',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      print('Erreur lors de la recherche: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _filterConversations,
              decoration: InputDecoration(
                hintText: 'Rechercher une conversation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          // Liste des conversations
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = filteredConversations[index];
                      return _buildConversationTile(conversation);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final String name = conversation['name'] ?? 'Inconnu';
    final String lastMessage = conversation['lastMessage'] ?? 'Pas encore de message';
    final String image = conversation['image'] ?? '';
    final String id = conversation['id'] ?? '';
    final String profileId = conversation['profileId'] ?? '';
    final String type = conversation['type'] ?? 'user';

    return ListTile(
      leading: CircleAvatar(
        radius: 30,
        backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
        child: image.isEmpty ? const Icon(Icons.person, size: 30) : null,
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey),
      ),
      onTap: () {
        if (type == 'user') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                userId: widget.userId,
                conversationId: id,
                name: name,
                image: image,
              ),
            ),
          );
        } else {
          _navigateToDetails(profileId, type == 'producer');
        }
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String userId;
  final String conversationId;
  final String name;
  final String image;

  const ChatScreen({
    Key? key,
    required this.userId,
    required this.conversationId,
    required this.name,
    required this.image,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/conversations/${widget.conversationId}/messages'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          messages = data.map((message) {
            return {
              'content': message['content'] ?? '',
              'senderId': message['senderId'] ?? '',
            };
          }).toList();
          isLoading = false;
        });
      } else {
        print('Erreur lors de la récupération des messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur: $e');
    }
  }




  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        final newMessage = {
          'senderId': widget.userId,
          'content': _messageController.text,
        };

        final endpoint = 'http://10.0.2.2:5000/api/conversations/${widget.conversationId}/message';
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newMessage),
        );

        if (response.statusCode == 201) {
          setState(() {
            messages.add({'content': _messageController.text, 'type': 'sent'});
            _messageController.clear();
          });

          // Scroller vers le bas
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          print('Erreur d\'envoi de message: ${response.body}');
        }
      } catch (e) {
        print('Erreur: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.image.isNotEmpty
                  ? NetworkImage(widget.image)
                  : null,
              child: widget.image.isEmpty
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : messages.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun message pour le moment.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: false, // Affiche les messages dans l'ordre chronologique
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    // Vérifie si le message a été envoyé par l'utilisateur connecté
                    final bool isSent = message['senderId'].toString() == widget.userId.toString(); // Alignement à droite si c'est l'utilisateur connecté
                    print('senderId: ${message['senderId']}, userId: ${widget.userId}');
                    return Align(
                      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft, // Message aligné à droite ou à gauche
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSent ? Colors.blue : Colors.grey[300], // Message bleu si envoyé par l'utilisateur
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: isSent ? const Radius.circular(15) : Radius.zero,
                            bottomRight: isSent ? Radius.zero : const Radius.circular(15),
                          ),
                        ),
                        child: Text(
                          message['content'] ?? '',
                          style: TextStyle(
                            color: isSent ? Colors.white : Colors.black, // Texte blanc si le message est envoyé par l'utilisateur
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Créer une conversation'),
              content: const Text('Utilisez cette interface pour commencer une nouvelle conversation.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }



  /// Méthode pour naviguer vers le profil d'un utilisateur ou d'un producteur
  void _navigateToProfile(String id, String type) {
    if (id.isNotEmpty) {
      if (type == 'producer') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(producerId: id),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: id),
          ),
        );
      }
    } else {
      print('❌ Aucun ID de profil pour naviguer.');
    }
  }
}
