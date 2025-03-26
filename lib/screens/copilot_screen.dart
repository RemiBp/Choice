import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'utils.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Pour les images
import '../services/ai_service.dart'; // Import du service AI
import 'producer_screen.dart'; // Pour les détails des restaurants
import 'producerLeisure_screen.dart'; // Pour les producteurs de loisirs
import 'eventLeisure_screen.dart'; // Pour les détails des événements
import 'vibe_map_screen.dart'; // Pour la cartographie sensorielle

// Extension pour convertir les entiers en Duration (ms)
extension DurationExtension on int {
  Duration get ms => Duration(milliseconds: this);
}

// Extensions pour remplacer flutter_animate
extension AnimateExtension on Widget {
  Widget animate({Duration? delay}) {
    return AnimatedWidgetFix(
      child: this,
      delay: delay,
    );
  }
  
  Widget fadeIn({Duration? duration, Curve curve = Curves.easeOut}) {
    return FadeTransition(
      opacity: AlwaysStoppedAnimation(1.0),
      child: this,
    );
  }
  
  Widget slideY({double? begin, double? end, Duration? duration, Curve curve = Curves.easeOut}) {
    return SlideTransition(
      position: AlwaysStoppedAnimation(Offset(0, end ?? 0)),
      child: this,
    );
  }
  
  Widget slideX({double? begin, double? end, Duration? duration, Curve curve = Curves.easeOut}) {
    return SlideTransition(
      position: AlwaysStoppedAnimation(Offset(end ?? 0, 0)),
      child: this,
    );
  }
  
  Widget scale({
    dynamic begin, 
    dynamic end, 
    Duration? duration, 
    Curve curve = Curves.easeOut
  }) {
    double scaleValue = 1.0;
    if (end is double) {
      scaleValue = end;
    } else if (end is Offset) {
      // Utiliser la moyenne des valeurs x et y pour l'échelle
      scaleValue = (end.dx + end.dy) / 2.0;
    }
    
    return Transform.scale(
      scale: scaleValue,
      child: this,
    );
  }
  
  Widget move({Offset? begin, Offset? end, Duration? duration, Curve curve = Curves.easeOut}) {
    return SlideTransition(
      position: AlwaysStoppedAnimation(end ?? Offset.zero),
      child: this,
    );
  }
}

// Widget animé personnalisé pour remplacer le système d'animation de flutter_animate
class AnimatedWidgetFix extends StatefulWidget {
  final Widget child;
  final Duration? delay;

  const AnimatedWidgetFix({Key? key, required this.child, this.delay}) : super(key: key);

  @override
  State<AnimatedWidgetFix> createState() => _AnimatedWidgetFixState();
}

class _AnimatedWidgetFixState extends State<AnimatedWidgetFix> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    if (widget.delay != null) {
      Future.delayed(widget.delay!, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}

class CopilotScreen extends StatefulWidget {
  final String userId;

  const CopilotScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _CopilotScreenState createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = false;
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  
  final AIService _aiService = AIService(); // Instance du service AI
  List<ProfileData> _extractedProfiles = []; // Pour stocker les profils extraits

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _isTyping = true;
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
    
    // Add typing indicator
    setState(() {
      _conversations.add({
        'type': 'typing',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    
    // Scroll to typing indicator
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
      
      // Supprimer l'indicateur de frappe
      setState(() {
        _conversations.removeWhere((msg) => msg['type'] == 'typing');
        _isTyping = false;
      });
      
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
      // Supprimer l'indicateur de frappe
      setState(() {
        _conversations.removeWhere((msg) => msg['type'] == 'typing');
        _isTyping = false;
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
            SnackBar(
              content: Text('Type de profil non pris en charge: $type'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade800,
            ),
          );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de navigation: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade800,
        ),
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
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement des informations...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails du lieu",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
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
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
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
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Chargement de l'événement...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Récupération des détails et informations",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
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
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Copilot',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(
            color: Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
        actions: [
          // Bouton de cartographie sensorielle
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.mood, color: Colors.deepPurple, size: 26),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: 'Cartographie sensorielle',
              onPressed: () => _navigateToVibeMap(),
            ),
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
            // Enhanced Profile section header with more visual impact
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.purple.withOpacity(0.1),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.place, color: Colors.purple.shade700, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggestions pour vous',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${_extractedProfiles.length} lieux correspondent à votre recherche',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Responsive card container that adapts to different screen sizes
            SafeArea(
              bottom: false,
              child: Container(
                height: 200, // Slightly taller for more content
                margin: const EdgeInsets.only(bottom: 16),
                child: MediaQuery.of(context).size.width < 380
                    // Smaller screens (most iPhones) - show one card at a time with pageView
                    ? PageView.builder(
                        itemCount: _extractedProfiles.length,
                        controller: PageController(viewportFraction: 0.9),
                        padEnds: true,
                        itemBuilder: (context, index) {
                          final profile = _extractedProfiles[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: _buildProfileCard(profile)
                              .animate(delay: (50 * index).ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
                          );
                        },
                      )
                    // Larger screens - regular horizontal list
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _extractedProfiles.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        physics: const BouncingScrollPhysics(), // More native iOS feel
                        itemBuilder: (context, index) {
                          final profile = _extractedProfiles[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: _buildProfileCard(profile)
                              .animate(delay: (80 * index).ms)
                              .fadeIn(duration: 300.ms)
                              .slideX(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                          );
                        },
                      ),
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
                if (message['type'] == 'typing') {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(message, index);
              },
            ),
          ),
          
          // Loading indicator
          if (_isLoading && !_isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                minHeight: 3,
              ),
            ),
          
          // Input area at the bottom
          _buildInputArea(),
        ],
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal,
              child: const Icon(
                Icons.emoji_objects,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: const Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildDot(0),
                  const SizedBox(width: 4),
                  _buildDot(150),
                  const SizedBox(width: 4),
                  _buildDot(300),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDot(int delay) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final delayedValue = (_typingAnimationController.value * 1000 - delay) / 500;
        final opacity = delayedValue.clamp(0.0, 1.0);
        final scale = 0.5 + (delayedValue.clamp(0.0, 0.5) * 1.0);
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  // Construire une carte pour un profil extrait avec design amélioré
  Widget _buildProfileCard(ProfileData profile) {
    final Color typeColor = _getColorForType(profile.type);
    final String typeLabel = _getTypeLabel(profile.type);
    final IconData typeIcon = _getIconForType(profile.type);
    
    // Utiliser un URI image par défaut si non fourni
    final String imageUrl = (profile.image != null && profile.image!.isNotEmpty) 
        ? profile.image!
        : 'https://via.placeholder.com/300x200/e0e0e0/9e9e9e?text=${Uri.encodeComponent(typeLabel)}';
    
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        onTap: () => _navigateToProfile(profile.type, profile.id),
        borderRadius: BorderRadius.circular(16),
        splashColor: typeColor.withOpacity(0.2),
        highlightColor: typeColor.withOpacity(0.1),
        child: Container(
          width: 180, // Plus large pour montrer plus d'information
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du profil avec effet de chargement amélioré
              Stack(
                children: [
                  // Container for fixed height before image loads
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  
                  // Image with loading and error handling
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24, 
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icon(typeIcon, color: Colors.grey[400], size: 24),
                          ],
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(typeIcon, color: typeColor.withOpacity(0.6), size: 40),
                            const SizedBox(height: 8),
                            Text(
                              typeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Gradient overlay for better text visibility
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Type badge with icon
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            typeLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Name overlay at bottom for enhanced visibility
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      profile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // Details section
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address with icon for better readability
                    if (profile.address != null && profile.address!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profile.address!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Bottom row with rating and categories
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rating with enhanced styling
                        if (profile.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  profile.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Category badges (if available)
                        if (profile.category.isNotEmpty)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: typeColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    profile.category.first,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: typeColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.category.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      "+${profile.category.length - 1}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
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
        return 'Évènement';
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
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade800,
            Colors.purple.shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec icône
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_objects,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bienvenue sur Copilot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Votre assistant personnel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Description
          Text(
            'Je suis là pour vous aider à découvrir des lieux et activités qui vous plairont. Posez-moi une question en langage naturel!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Titre des suggestions
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber.shade300,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Essayez par exemple :',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Suggestions
          _buildSuggestionChip('Recommande-moi un restaurant romantique')
            .animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          _buildSuggestionChip('Que faire ce weekend à Paris ?')
            .animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          _buildSuggestionChip('Je cherche une pièce de théâtre pour ce soir')
            .animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1.0, 1.0),
      duration: 600.ms,
      curve: Curves.easeOutBack,
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return GestureDetector(
      onTap: () => _sendQuestion(suggestion),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isUser = message['type'] == 'user';
    final hasError = message['error'] == true;
    final hasProfiles = message['hasProfiles'] == true;
    final isIOS = Platform.isIOS;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isIOS ? 6.0 : 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser),
          
          SizedBox(width: isIOS ? 8.0 : 10.0),
          
          // Message bubble with platform-specific styling for better visibility
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isIOS ? 14.0 : 16.0, 
                vertical: isIOS ? 12.0 : 14.0
              ),
              decoration: BoxDecoration(
                color: isUser 
                    ? Colors.deepPurple.shade600 
                    : (hasError ? Colors.red.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(isIOS ? 18.0 : 20.0).copyWith(
                  bottomLeft: isUser ? Radius.circular(isIOS ? 18.0 : 20.0) : const Radius.circular(4),
                  bottomRight: !isUser ? Radius.circular(isIOS ? 18.0 : 20.0) : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isIOS ? 0.1 : 0.08),
                    blurRadius: isIOS ? 4.0 : 6.0,
                    offset: isIOS ? const Offset(0, 1) : const Offset(0, 2),
                  ),
                ],
                // Enhanced border for better visibility on all platforms
                border: !isUser ? Border.all(
                  color: hasError 
                      ? Colors.red.withOpacity(0.2)
                      : (isIOS ? Colors.grey.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
                  width: isIOS ? 0.5 : 1.0,
                ) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message['content'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isIOS ? 15.0 : 16.0,
                        height: 1.4,
                        letterSpacing: isIOS ? -0.2 : 0,
                      ),
                    )
                  else
                    hasProfiles
                      // Message with clickable links - improved text wrapping and iOS styling
                      ? Container(
                          width: double.infinity, // Force full width for SelectableText.rich
                          child: SelectableText.rich(
                            TextSpan(
                              style: TextStyle(
                                color: hasError ? Colors.red.shade800 : Colors.black87,
                                fontSize: isIOS ? 15.0 : 16.0,
                                height: 1.4,
                                letterSpacing: isIOS ? -0.2 : 0,
                              ),
                              children: AIService.parseMessageWithLinks(
                                message['content'],
                                (type, id) => _navigateToProfile(type, id),
                              ),
                            ),
                            // Enable text selection with iOS-friendly settings
                            enableInteractiveSelection: true,
                            showCursor: true,
                            cursorWidth: 2.0,
                            cursorColor: Colors.deepPurple,
                          ),
                        )
                      // Simple message without links - enhanced for iOS
                      : Container(
                          width: double.infinity, // Force full width for SelectableText
                          child: SelectableText(
                            message['content'],
                            style: TextStyle(
                              color: hasError ? Colors.red.shade800 : Colors.black87,
                              fontSize: isIOS ? 15.0 : 16.0,
                              height: 1.4,
                              letterSpacing: isIOS ? -0.2 : 0,
                            ),
                            // Enable better selection for iOS
                            enableInteractiveSelection: true,
                            showCursor: true,
                            cursorWidth: 2.0,
                            cursorColor: Colors.deepPurple,
                          ),
                        ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(message['timestamp']),
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey,
                          fontSize: isIOS ? 11.0 : 12.0,
                        ),
                      ),
                      if (!isUser && message['resultCount'] != null && message['resultCount'] > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.deepPurple.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${message['resultCount']} résultats',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      
                      // Intent badge (if available and no error)
                      if (!isUser && !hasError && message['intent'] != null && message['intent'] != 'unknown') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.teal.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getIntentLabel(message['intent']),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.teal[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ).animate(delay: (50 * index).ms)
            .fadeIn(duration: 300.ms)
            .slideX(
              begin: isUser ? 0.2 : -0.2, 
              end: 0, 
              duration: 400.ms, 
              curve: Curves.easeOutCubic
            ),
          
          const SizedBox(width: 10),
          
          if (isUser) _buildAvatar(isUser),
        ],
      ),
    );
  }
  
  String _getIntentLabel(String intent) {
    // Retourner un label plus convivial pour chaque type d'intention
    switch (intent) {
      case 'restaurant_search':
        return 'Recherche resto';
      case 'event_search':
        return 'Recherche événement';
      case 'leisure_search':
        return 'Recherche loisir';
      case 'recommendation':
        return 'Recommandation';
      case 'information':
        return 'Information';
      default:
        return intent;
    }
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
    final isIOS = Platform.isIOS;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0, 
        vertical: isIOS ? 16.0 : 12.0
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isIOS ? 0.08 : 0.05),
            blurRadius: isIOS ? 8.0 : 10.0,
            offset: const Offset(0, -2),
          ),
        ],
        // Add a subtle top border for iOS
        border: isIOS ? const Border(
          top: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ) : null,
      ),
      child: Row(
        children: [
          // Input field with platform-specific styling
          Expanded(
            child: Container(
              // Add elevation effect for iOS
              decoration: isIOS ? BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ) : null,
              child: TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: 'Posez une question à Copilot...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: isIOS ? 15.0 : 16.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isIOS ? 25.0 : 30.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isIOS ? Colors.grey[50] : Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isIOS ? 16.0 : 20.0, 
                    vertical: isIOS ? 10.0 : 12.0
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isIOS ? CupertinoIcons.clear_circled_solid : Icons.clear,
                      color: Colors.grey,
                      size: isIOS ? 20.0 : 24.0,
                    ),
                    onPressed: () => _questionController.clear(),
                  ),
                  prefixIcon: IconButton(
                    icon: Icon(
                      isIOS ? CupertinoIcons.mic_fill : Icons.mic,
                      color: Colors.deepPurple.shade300,
                      size: isIOS ? 20.0 : 24.0,
                    ),
                    onPressed: () {
                      // Fonctionnalité de dictée vocale à venir
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Dictée vocale bientôt disponible'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: isIOS ? Colors.black.withOpacity(0.8) : null,
                          shape: isIOS ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ) : null,
                        ),
                      );
                    },
                  ),
                ),
                style: TextStyle(
                  fontSize: isIOS ? 15.0 : 16.0,
                  letterSpacing: isIOS ? -0.2 : 0,
                ),
                keyboardType: TextInputType.text,
                keyboardAppearance: isIOS ? Brightness.light : Brightness.dark,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) => _sendQuestion(value),
              ),
            ),
          ),
          
          // Send button with platform-specific styling
          Container(
            margin: EdgeInsets.only(left: isIOS ? 6.0 : 8.0),
            width: isIOS ? 44.0 : 48.0,
            height: isIOS ? 44.0 : 48.0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x55673AB7),
                  blurRadius: isIOS ? 6.0 : 8.0,
                  offset: isIOS ? const Offset(0, 1) : const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendQuestion(_questionController.text),
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Center(
                    child: Icon(
                      isIOS ? CupertinoIcons.paperplane_fill : Icons.send,
                      color: Colors.white,
                      size: isIOS ? 20.0 : 22.0,
                    ),
                  ),
                ),
              ),
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
              size: 28,
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À propos de Copilot',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Votre assistant intelligent',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
                ),
              ],
            ),
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
            const SizedBox(height: 12),
            _buildHelpItem(
              'Découverte',
              'Explorez de nouveaux lieux et activités dans votre région.',
              Icons.explore,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              'Cartographie sensorielle',
              'Visualisez des lieux selon vos émotions et ambiances recherchées.',
              Icons.mood,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              'Assistance',
              'Obtenez des réponses à vos questions sur l\'application.',
              Icons.help_outline,
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Exemples de questions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildExampleItem('Pièce de théâtre ce soir'),
            _buildExampleItem('Restaurant avec des frites'),
            _buildExampleItem('Activité romantique à Paris'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Compris !',
              style: TextStyle(
                color: Colors.deepPurple.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  Widget _buildExampleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.arrow_right, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.deepPurple.shade500,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}