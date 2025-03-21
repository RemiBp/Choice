import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'utils.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Pour les images
import '../services/ai_service.dart'; // Import du service AI
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les détails des événements
import 'vibe_map_screen.dart'; // Pour la cartographie sensorielle

class CopilotScreen extends StatefulWidget {
  final String userId;

  const CopilotScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _CopilotScreenState createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = false;
  final AIService _aiService = AIService(); // Instance du service AI
  List<ProfileData> _extractedProfiles = []; // Pour stocker les profils extraits

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _extractedProfiles = []; // Réinitialiser les profils extraits
      _conversations.add({
        'type': 'user',
        'content': question,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _questionController.clear();
    });

    // Scroll to bottom after adding user message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      // Utiliser le service AI pour obtenir une réponse enrichie
      AIQueryResponse aiResponse;
      try {
        // Premier essai - requête utilisateur standard
        aiResponse = await _aiService.userQuery(widget.userId, question);
      } catch (primaryError) {
        print("⚠️ Premier essai échoué, tentative avec requête simple: $primaryError");
        try {
          // Deuxième essai - requête simple (fallback)
          aiResponse = await _aiService.simpleQuery(question);
        } catch (secondaryError) {
          print("❌ Tous les essais ont échoué: $secondaryError");
          throw secondaryError; // Relance l'erreur pour être attrapée par le bloc catch externe
        }
      }
      
      // Enregistrer les profils extraits s'il y en a
      if (aiResponse.profiles.isNotEmpty) {
        setState(() {
          _extractedProfiles = aiResponse.profiles;
        });
      }

      setState(() {
        _conversations.add({
          'type': 'copilot',
          'content': aiResponse.response,
          'timestamp': DateTime.now().toIso8601String(),
          'hasProfiles': aiResponse.profiles.isNotEmpty,
          'intent': aiResponse.intent,
          'resultCount': aiResponse.resultCount,
        });
        _isLoading = false;
      });

      // Scroll to bottom after adding copilot response
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _conversations.add({
          'type': 'copilot',
          'content': 'Une erreur s\'est produite. Veuillez vérifier votre connexion et réessayer.',
          'timestamp': DateTime.now().toIso8601String(),
          'error': true,
        });
        _isLoading = false;
      });
    }
  }

  // Navigue vers le profil d'un restaurant, loisir ou événement
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
                userId: widget.userId,
              ),
            ),
          );
          break;
        case 'leisureProducer':
          _fetchAndNavigateToLeisureProducer(id);
          break;
        case 'event':
          _fetchAndNavigateToEvent(id);
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

  // Récupère les données d'un producteur de loisirs et navigue vers son profil
  Future<void> _fetchAndNavigateToLeisureProducer(String id) async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            backgroundColor: Colors.white,
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
      
      final url = Uri.parse('${getBaseUrl()}/api/leisureProducers/$id');
      final response = await http.get(url);
      
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
  }

  // Récupère les données d'un événement et navigue vers sa page
  Future<void> _fetchAndNavigateToEvent(String id) async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            backgroundColor: Colors.white,
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
      
      final url = Uri.parse('${getBaseUrl()}/api/events/$id');
      final response = await http.get(url);
      
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Copilot', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 22
          )
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // Bouton de cartographie sensorielle
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.mood, color: Colors.deepPurple),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            tooltip: 'Cartographie sensorielle',
            onPressed: () => _navigateToVibeMap(),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome card at the top
          if (_conversations.isEmpty)
            _buildWelcomeCard(),
          
          // Profils extraits par l'IA (si présents)
          if (_extractedProfiles.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                '📍 Établissements et événements suggérés:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Container(
              height: 180,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _extractedProfiles.length,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemBuilder: (context, index) {
                  final profile = _extractedProfiles[index];
                  return _buildProfileCard(profile);
                },
              ),
            ),
          ],
          
          // Conversation history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final message = _conversations[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            ),
          
          // Input area at the bottom
          _buildInputArea(),
        ],
      ),
    );
  }

  // Construire une carte pour un profil extrait
  Widget _buildProfileCard(ProfileData profile) {
    return GestureDetector(
      onTap: () => _navigateToProfile(profile.type, profile.id),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du profil
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: profile.image != null && profile.image!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profile.image!,
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 90,
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
                        height: 90,
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            _getIconForType(profile.type),
                            color: Colors.grey[400],
                            size: 30,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      height: 90,
                      color: Colors.grey[200],
                      width: double.infinity,
                      child: Center(
                        child: Icon(
                          _getIconForType(profile.type),
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
                    ),
              ),
              
              const SizedBox(height: 8),
              
              // Nom du profil
              Text(
                profile.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              
              // Note et badge de type
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    if (profile.rating != null) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      Text(' ${profile.rating!.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    
                    // Badge type
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getColorForType(profile.type).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeLabel(profile.type),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getColorForType(profile.type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  // Obtenir l'icône correspondant au type
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
  
  // Obtenir la couleur correspondant au type
  Color _getColorForType(String type) {
    switch (type) {
      case 'restaurant':
        return Colors.orange;
      case 'leisureProducer':
        return Colors.purple;
      case 'event':
        return Colors.green;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  // Obtenir le libellé correspondant au type
  String _getTypeLabel(String type) {
    switch (type) {
      case 'restaurant':
        return 'Restaurant';
      case 'leisureProducer':
        return 'Loisir';
      case 'event':
        return 'Événement';
      case 'user':
        return 'Utilisateur';
      default:
        return type;
    }
  }

  // Navigation vers la cartographie sensorielle
  void _navigateToVibeMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VibeMapScreen(userId: widget.userId),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade800,
            Colors.deepPurple.shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_objects,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Bienvenue sur Copilot',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Je suis votre assistant personnel pour vous aider à découvrir des lieux et activités qui vous plairont.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Essayez par exemple :',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildSuggestionChip('Recommande-moi un restaurant romantique'),
          _buildSuggestionChip('Que faire ce weekend à Paris ?'),
          _buildSuggestionChip('Je cherche une activité pour enfants'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return GestureDetector(
      onTap: () => _sendQuestion(suggestion),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                suggestion,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';
    final hasError = message['error'] == true;
    final hasProfiles = message['hasProfiles'] == true;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser),
          
          const SizedBox(width: 8),
          
          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser 
                    ? Colors.deepPurple.shade500 
                    : (hasError ? Colors.red.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
                  bottomRight: !isUser ? const Radius.circular(20) : const Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message['content'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  else
                    hasProfiles
                      // Message avec des liens cliquables
                      ? RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: hasError ? Colors.red.shade800 : Colors.black87,
                              fontSize: 16,
                              height: 1.4,
                            ),
                            children: AIService.parseMessageWithLinks(
                              message['content'],
                              (type, id) => _navigateToProfile(type, id),
                            ),
                          ),
                        )
                      // Message simple sans liens
                      : Text(
                          message['content'],
                          style: TextStyle(
                            color: hasError ? Colors.red.shade800 : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(message['timestamp']),
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (!isUser && message['resultCount'] != null && message['resultCount'] > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${message['resultCount']} résultats',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          if (isUser) _buildAvatar(isUser),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? Colors.deepPurple.shade300 : Colors.teal,
      child: Icon(
        isUser ? Icons.person : Icons.emoji_objects,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Input field
          Expanded(
            child: TextField(
              controller: _questionController,
              decoration: InputDecoration(
                hintText: 'Posez une question à Copilot...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _questionController.clear(),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) => _sendQuestion(value),
            ),
          ),
          
          // Send button
          Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send),
              color: Colors.white,
              onPressed: () => _sendQuestion(_questionController.text),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // If message is from today, show time only
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Otherwise, show date and time
      return '${dateTime.day}/${dateTime.month} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.deepPurple.shade400,
            ),
            const SizedBox(width: 8),
            const Text('À propos de Copilot'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              'Recommandations',
              'Demandez des recommandations personnalisées basées sur vos préférences.',
              Icons.thumbs_up_down,
            ),
            const SizedBox(height: 8),
            _buildHelpItem(
              'Découverte',
              'Explorez de nouveaux lieux et activités dans votre région.',
              Icons.explore,
            ),
            const SizedBox(height: 8),
            _buildHelpItem(
              'Cartographie sensorielle',
              'Visualisez des lieux selon vos émotions et ambiances recherchées.',
              Icons.mood,
            ),
            const SizedBox(height: 8),
            _buildHelpItem(
              'Assistance',
              'Obtenez des réponses à vos questions sur l\'application.',
              Icons.help_outline,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris !'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.deepPurple.shade400,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}