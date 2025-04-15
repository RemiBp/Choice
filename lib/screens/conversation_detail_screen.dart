import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/conversation_service.dart';
import '../services/upload_service.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../services/call_service.dart';
import 'package:choice_app/screens/profile_screen.dart';
import 'package:choice_app/screens/producer_screen.dart';
import 'package:choice_app/screens/producerLeisure_screen.dart';
import 'package:choice_app/screens/wellness_producer_profile_screen.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String conversationId;
  final String recipientName;
  final String recipientAvatar;
  final bool isProducer;
  final bool isGroup;
  final String userId;
  final List<dynamic>? participants;

  const ConversationDetailScreen({
    Key? key,
    required this.conversationId,
    required this.recipientName,
    required this.recipientAvatar,
    required this.userId,
    this.isProducer = false,
    this.isGroup = false,
    this.participants,
  }) : super(key: key);

  @override
  _ConversationDetailScreenState createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ConversationService _conversationService;
  final UploadService _uploadService = UploadService();
  final FocusNode _messageFocusNode = FocusNode();
  final CallService _callService = CallService();
  
  bool _isLoading = true;
  bool _isSending = false;
  bool _isAttachingMedia = false;
  bool _isTyping = false;
  
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _participantsInfo = {};
  List<String> _mediaToSend = [];
  
  // Timer pour détecter quand l'utilisateur arrête de taper
  Timer? _typingTimer;
  // Timer pour rafraîchir les messages périodiquement
  Timer? _refreshTimer;
  
  // Pour le thème WhatsApp-like avec des couleurs de Choice
  final Color _primaryColor = Color(0xFF5D3587); // Couleur principale de Choice

  final UserService _userService = UserService();
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _showMentionSuggestions = false;
  String _currentMentionQuery = '';
  List<Mention> _mentions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationService = ConversationService();
    
    _loadMessages();
    
    if (widget.isGroup) {
      _loadGroupDetails();
    }
    
    // Écouter les changements dans le champ de texte pour détecter la frappe
    _messageController.addListener(_onTypingChanged);
    
    // Configurer un timer pour rafraîchir les messages périodiquement
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (_) {
      if (mounted) {
        _loadMessages(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _refreshTimer?.cancel();
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // L'application est revenue au premier plan, rafraîchir les messages
      _loadMessages(silent: true);
    }
  }
  
  void _onTypingChanged() {
    // Si l'utilisateur est en train de taper mais que le flag n'est pas activé
    if (_messageController.text.isNotEmpty && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
      _notifyTypingStatus(true);
    }
    
    // Réinitialiser le timer à chaque frappe
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() {
          _isTyping = false;
        });
        _notifyTypingStatus(false);
      }
    });
    
    // Nouvelle logique pour détecter les @mentions
    final text = _messageController.text;
    final selection = _messageController.selection;
    
    if (selection.baseOffset > 0) {
      // Chercher en arrière depuis la position actuelle pour trouver le dernier @
      final currentWord = _findCurrentMention(text, selection.baseOffset);
      
      if (currentWord != null && currentWord.startsWith('@') && currentWord.length > 1) {
        // Il y a une mention potentielle, rechercher des utilisateurs
        final query = currentWord.substring(1); // Enlever le @
        _searchUsers(query);
      } else {
        // Pas de mention en cours
        setState(() {
          _showMentionSuggestions = false;
          _currentMentionQuery = '';
        });
      }
    }
  }

  Future<void> _notifyTypingStatus(bool isTyping) async {
    try {
      // Implémenter la notification du statut de frappe
      print('Utilisateur ${widget.userId} ${isTyping ? 'est en train d\'écrire' : 'a arrêté d\'écrire'} dans la conversation ${widget.conversationId}');
      // Ici vous pourriez implémenter un appel au serveur pour notifier les autres utilisateurs
    } catch (e) {
      print('Erreur lors de la notification du statut de frappe: $e');
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // Implémenter le chargement des messages depuis le serveur
      final response = await _conversationService.getConversationMessages(widget.conversationId, widget.userId);
      
      if (mounted) {
        setState(() {
          // Assurer que les messages sont bien convertis en List<Map<String, dynamic>>
          if (response['messages'] is List) {
            _messages = List<Map<String, dynamic>>.from(
              response['messages'].map((msg) => 
                msg is Map<String, dynamic> ? msg : Map<String, dynamic>.from(msg)
              )
            );
          } else {
            _messages = [];
          }
          _isLoading = false;
        });
      }
      
      // Faire défiler jusqu'au dernier message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des messages: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages = []; // Assurer que _messages est initialisé même en cas d'erreur
        });
      }
    }
  }

  Future<void> _loadGroupDetails() async {
    try {
      // Implémenter le chargement des détails du groupe
      final response = await _conversationService.getGroupDetails(widget.conversationId);
      
      if (mounted) {
        setState(() {
          _participantsInfo = response['participants'] ?? {};
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des détails du groupe: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _mediaToSend.isEmpty) {
      return;
    }

    final message = _messageController.text.trim();
    final List<String> mediaUrls = List.from(_mediaToSend);
    final List<Mention> mentions = _mentions != null ? List.from(_mentions) : [];
    
    setState(() {
      _isSending = true;
      _isTyping = false;
      _messageController.clear();
      _mediaToSend = [];
      _mentions = [];
      
      // Ajouter le message à la liste avec un ID temporaire pour affichage immédiat
      final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
      _messages.add({
        '_id': tempId,
        'id': tempId,
        'senderId': widget.userId,
        'content': message,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sending', // Nouveau champ pour suivre l'état d'envoi
        'media': mediaUrls,
        'mentions': mentions.isNotEmpty ? mentions.map((m) => m.toJson()).toList() : [],
      });
    });
    
    try {
      print('📨 Envoi du message: $message dans la conversation ${widget.conversationId}');
      print('📨 senderId: ${widget.userId}');
      
      // Préparer l'objet de message avec les mentions si nécessaire
      List<Map<String, dynamic>>? mentionsData = 
          mentions.isNotEmpty ? mentions.map((m) => m.toJson()).toList() : null;
      
      final response = await _conversationService.sendMessage(
        widget.conversationId,
        widget.userId,
        message,
        mediaUrls.isNotEmpty ? mediaUrls : null,
        mentionsData,
      );
      
      if (mounted) {
        setState(() {
          _isSending = false;
          
          // Mettre à jour le message temporaire avec les vraies données
          final tempIndex = _messages.indexWhere((m) => m['_id'].toString().startsWith('temp-'));
          if (tempIndex != -1) {
            if (response['message'] != null) {
              final messageData = response['message'];
              _messages[tempIndex] = {
                ..._messages[tempIndex],
                '_id': messageData['_id'] ?? messageData['id'] ?? _messages[tempIndex]['_id'],
                'id': messageData['_id'] ?? messageData['id'] ?? _messages[tempIndex]['id'],
                'status': 'sent',
                'timestamp': messageData['timestamp'] ?? DateTime.now().toIso8601String(),
              };
            } else {
              // Si la structure n'est pas celle attendue
              _messages[tempIndex] = {
                ..._messages[tempIndex],
                'status': 'sent',
              };
            }
          }
        });
      }
      
      // Faire défiler jusqu'au dernier message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du message: $e');
      
      if (mounted) {
        setState(() {
          _isSending = false;
          
          // Marquer le message comme en erreur
          final tempIndex = _messages.indexWhere((m) => m['_id'].toString().startsWith('temp-'));
          if (tempIndex != -1) {
            _messages[tempIndex] = {
              ..._messages[tempIndex],
              'status': 'error',
            };
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du message. Veuillez réessayer.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: () {
                _messageController.text = message;
                if (mediaUrls.isNotEmpty) {
                  setState(() {
                    _mediaToSend = List.from(mediaUrls);
                  });
                }
                // Supprimer le message en erreur
                setState(() {
                  _messages.removeWhere((m) => m['status'] == 'error');
                });
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: source);
      
      if (image != null) {
        // Implémenter le téléversement de l'image
        final imageUrl = await _uploadService.uploadImage(File(image.path));
        
        if (imageUrl != null && mounted) {
          setState(() {
            _mediaToSend.add(imageUrl);
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: Impossible de téléverser l\'image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Erreur lors de la sélection de l\'image: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: _primaryColor),
                title: Text('Galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: _primaryColor),
                title: Text('Appareil photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMessageTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      
      if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
        return DateFormat('HH:mm').format(dateTime);
      } else {
        return DateFormat('dd/MM HH:mm').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isCurrentUser) {
    final String content = message['content'] ?? '';
    final List<dynamic> media = message['media'] ?? [];
    final String status = message['status'] ?? 'sent';
    
    // Déterminer la couleur de la bulle selon l'expéditeur
    final Color bubbleColor = isCurrentUser 
        ? _primaryColor.withOpacity(0.9)
        : Colors.grey[300]!;
    
    // Couleur du texte (blanc sur bulle colorée, noir sur bulle grise)
    final Color textColor = isCurrentUser ? Colors.white : Colors.black87;
    
    // Icône d'état pour les messages envoyés par l'utilisateur courant
    Widget statusIcon = const SizedBox.shrink();
    if (isCurrentUser) {
      if (status == 'sending') {
        statusIcon = const Icon(Icons.access_time, size: 12, color: Colors.white70);
      } else if (status == 'sent') {
        statusIcon = const Icon(Icons.check, size: 12, color: Colors.white70);
      } else if (status == 'error') {
        statusIcon = const Icon(Icons.error_outline, size: 12, color: Colors.red);
      }
    }
    
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Affichage des médias si présents
            if (media.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: media.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          media[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(child: Icon(Icons.broken_image, color: Colors.grey[400]));
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Texte du message
            _renderMessageContent(content, message['mentions']),
            
            // Heure d'envoi et statut
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message['timestamp'] ?? ''),
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                statusIcon,
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get participant ID and Type for potential navigation
    final String? otherUserId = _otherParticipantId;
    final String otherUserType = _otherParticipantType;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Row(
          children: [
            GestureDetector(
              // Navigate on avatar tap ONLY for non-group chats
              onTap: (!widget.isGroup && otherUserId != null) 
                  ? () => _navigateToProfile(otherUserId, otherUserType) 
                  : null,
              child: CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(widget.recipientAvatar),
                backgroundColor: Colors.grey[200],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.isGroup)
                    Text(
                      '${_participantsInfo.length} participants',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    )
                  else
                    Text(
                      'En ligne',  // Statut par défaut, à remplacer par le vrai statut
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () => _initiateCall(true),
          ),
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () => _initiateCall(false),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              // Implémenter les actions du menu
              if (value == 'search') {
                // Rechercher dans les messages
              } else if (value == 'clear') {
                // Effacer la conversation
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text('Rechercher'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text('Effacer la conversation'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone d'affichage des messages
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun message',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Commencez à discuter !',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['senderId'] == widget.userId;
                          
                          return _buildMessageBubble(message, isMe);
                        },
                      ),
          ),
          
          // Affichage des médias sélectionnés
          if (_mediaToSend.isNotEmpty)
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mediaToSend.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: _mediaToSend[index].startsWith('http')
                                ? NetworkImage(_mediaToSend[index])
                                : FileImage(File(_mediaToSend[index])) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mediaToSend.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          
          // Add mention suggestion UI
          if (_showMentionSuggestions)
            Container(
              height: min(200, _suggestedUsers.length * 60.0),
              color: Colors.white,
              child: ListView.builder(
                itemCount: _suggestedUsers.length,
                itemBuilder: (context, index) {
                  final user = _suggestedUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                        user['avatar'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user['name'] ?? 'User')}',
                      ),
                    ),
                    title: Text(user['name'] ?? user['username'] ?? 'User'),
                    onTap: () => _insertMention(user),
                  );
                },
              ),
            ),
          
          // Zone de saisie du message
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isAttachingMedia ? Icons.close : Icons.attach_file, color: _primaryColor),
                  onPressed: _showMediaOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: _isSending
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                          strokeWidth: 2,
                        )
                      : IconButton(
                          icon: Icon(Icons.send, color: _primaryColor),
                          onPressed: _sendMessage,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _viewGroupDetails() {
    // Implémenter la navigation vers les détails du groupe
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Détails du groupe non implémentés')),
    );
  }

  // Trouver la mention en cours à la position du curseur
  String? _findCurrentMention(String text, int cursorPosition) {
    // Trouver l'espace ou @ précédent
    int start = cursorPosition - 1;
    while (start >= 0 && text[start] != ' ' && text[start] != '@') {
      start--;
    }
    
    // Si nous avons trouvé un @, c'est le début d'une mention
    if (start >= 0 && text[start] == '@') {
      return text.substring(start, cursorPosition);
    } else if (start < 0 && text[0] == '@') {
      // Cas du début du texte
      return text.substring(0, cursorPosition);
    }
    
    return null;
  }
  
  // Rechercher des utilisateurs pour les suggestions de mention
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showMentionSuggestions = false;
        _suggestedUsers = [];
      });
      return;
    }
    
    if (query != _currentMentionQuery) {
      _currentMentionQuery = query;
      
      try {
        final results = await _userService.searchUsers(query);
        
        setState(() {
          _suggestedUsers = results;
          _showMentionSuggestions = results.isNotEmpty;
        });
      } catch (e) {
        print('Erreur lors de la recherche d\'utilisateurs pour les mentions: $e');
        setState(() {
          _showMentionSuggestions = false;
        });
      }
    }
  }
  
  // Insérer une mention dans le texte
  void _insertMention(Map<String, dynamic> user) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    
    // Trouver le début de la mention
    int start = selection.baseOffset - 1;
    while (start >= 0 && text[start] != ' ' && text[start] != '@') {
      start--;
    }
    
    if (start >= 0 && text[start] == '@') {
      // Nous avons le début de la mention
      // Remplacer @query par @username
      final String beforeMention = text.substring(0, start);
      final String afterMention = text.substring(selection.baseOffset);
      final String username = user['name'] ?? user['username'] ?? 'user';
      final String userId = user['id'] ?? '';
      
      final String newText = '$beforeMention@$username $afterMention';
      
      // Ajouter la mention à la liste des mentions
      _mentions.add(Mention(
        userId: userId,
        username: username,
        startIndex: start,
        endIndex: start + username.length + 1, // +1 pour le @
      ));
      
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + username.length + 2), // +2 pour @ et espace
      );
    }
    
    setState(() {
      _showMentionSuggestions = false;
    });
  }

  // Render message with highlighted mentions
  Widget _renderMessageContent(String content, List<dynamic>? mentions) {
    if (mentions == null || mentions.isEmpty) {
      return Text(
        content,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      );
    }
    
    // Convert mentions to TextSpans
    List<TextSpan> textSpans = [];
    int lastIndex = 0;
    
    // Sort mentions by startIndex
    mentions.sort((a, b) => a['startIndex'].compareTo(b['startIndex']));
    
    for (var mention in mentions) {
      final int startIndex = mention['startIndex'] ?? 0;
      final int endIndex = mention['endIndex'] ?? 0;
      
      if (startIndex > lastIndex) {
        // Add non-mention text
        textSpans.add(TextSpan(
          text: content.substring(lastIndex, startIndex),
          style: TextStyle(color: Colors.white),
        ));
      }
      
      // Add mention with highlight
      if (endIndex <= content.length) {
        textSpans.add(TextSpan(
          text: content.substring(startIndex, endIndex),
          style: TextStyle(
            color: Colors.blue[300],
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _onMentionTap(mention['userId']);
            },
        ));
        
        lastIndex = endIndex;
      }
    }
    
    // Add remaining text
    if (lastIndex < content.length) {
      textSpans.add(TextSpan(
        text: content.substring(lastIndex),
        style: TextStyle(color: Colors.white),
      ));
    }
    
    return RichText(
      text: TextSpan(
        children: textSpans,
      ),
    );
  }
  
  void _onMentionTap(String userId) {
    // Navigate to user profile
    Navigator.of(context).pushNamed('/profile', arguments: userId);
  }

  Future<void> _initiateCall(bool isVideo) async {
    try {
      // Pour les groupes, afficher un message indiquant que la fonctionnalité n'est pas disponible
      if (widget.isGroup) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Les appels de groupe ne sont pas encore disponibles')),
        );
        return;
      }
      
      // Pour les appels en tête-à-tête, utiliser l'API d'appel
      String recipientId = '';
      
      // Trouver l'ID du destinataire (qui n'est pas l'utilisateur actuel)
      if (widget.participants != null) {
        for (var participant in widget.participants!) {
          String participantId = '';
          if (participant is String) {
            participantId = participant;
          } else if (participant is Map && participant['_id'] != null) {
            participantId = participant['_id'];
          } else if (participant is Map && participant['id'] != null) {
            participantId = participant['id'];
          }
          
          if (participantId.isNotEmpty && participantId != widget.userId) {
            recipientId = participantId;
            break;
          }
        }
      }
      
      if (recipientId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de trouver le destinataire de l\'appel')),
        );
        return;
      }
      
      // Afficher un dialogue de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(isVideo ? 'Appel vidéo' : 'Appel audio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              SizedBox(height: 16),
              Text('Initialisation de l\'appel...'),
            ],
          ),
        ),
      );
      
      // Initier l'appel
      final response = await _callService.startCall(
        widget.userId,     // callerId
        recipientId,       // recipientId
        isVideo            // isVideo
      );
      
      // Fermer le dialogue de chargement
      Navigator.of(context).pop();
      
      if (response['success'] == true) {
        final callId = response['callId'];
        final iceServers = response['iceServers'];
        
        // Naviguer vers l'écran d'appel
        Navigator.of(context).pushNamed(
          '/call',
          arguments: {
            'callId': callId,
            'recipientId': recipientId,
            'recipientName': widget.recipientName,
            'recipientAvatar': widget.recipientAvatar,
            'isVideo': isVideo,
            'isInitiator': true,
            'iceServers': iceServers,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'initialisation de l\'appel')),
        );
      }
    } catch (e) {
      // Fermer le dialogue de chargement s'il est ouvert
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ---- Navigation Logic (Copied/Adapted from MessagingScreen) ----
  Future<void> _navigateToProfile(String participantId, String participantType) async {
    if (participantId.isEmpty) return;

    // Determine the type based on isProducer or isGroup flags if participantType is not provided
    // This is a fallback, ideally the type comes from the conversation list item
    String resolvedType = participantType;
    if (resolvedType == 'user' && widget.isProducer) {
        // TODO: Determine the actual producer type (restaurant, leisure, etc.)
        print("⚠️ Cannot determine producer type for profile navigation in detail screen.");
        resolvedType = 'restaurant'; 
    } else if (resolvedType == 'user' && widget.isGroup) {
        _viewGroupDetails();
        return; 
    }

    // Show loading indicator
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Chargement du profil..."),
                ],
              ),
            ),
          );
        },
      );

    try {
      if (resolvedType == 'user') {
         Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: participantId,
              viewMode: 'public',
            ),
          ),
        );
      } else if (resolvedType == 'restaurant') {
         Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: participantId,
              userId: widget.userId, 
            ),
          ),
        );
      } else if (resolvedType == 'leisure') {
        // Fetch data first for Leisure producer
        final url = Uri.parse('${ApiConfig.baseUrl}/api/producers/leisure/$participantId'); // Adjust API endpoint if needed
        final response = await http.get(url);
        Navigator.pop(context); // Close loading dialog
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          Navigator.push(
           context,
           MaterialPageRoute(
             // Assuming ProducerLeisureScreen accepts producerData map
             builder: (context) => ProducerLeisureScreen(producerData: data),
           ),
         );
        } else {
           throw Exception("Failed to load leisure producer data (${response.statusCode})");
        }
      } else if (resolvedType == 'wellness' || resolvedType == 'beauty') {
        // Fetch data first for Wellness/Beauty producer
        final url = Uri.parse('${ApiConfig.baseUrl}/api/unified/$participantId'); 
        final response = await http.get(url);
        Navigator.pop(context); // Close loading dialog
        if (response.statusCode == 200) {
            final data = json.decode(response.body);
            // Pass the full data map to WellnessProducerProfileScreen
            Navigator.push(
                context,
                MaterialPageRoute(
                builder: (context) => WellnessProducerProfileScreen(producerData: data), // <-- Pass producerData
                ),
            );
        } else {
            throw Exception("Failed to load wellness/beauty producer data (${response.statusCode})");
        }
      } else {
        Navigator.pop(context); // Close loading dialog
        print("⚠️ Unknown participant type for profile navigation: $resolvedType");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Type de profil inconnu: $resolvedType"))
        );
      }
    } catch (e) {
        Navigator.pop(context); // Close loading dialog on error
        print("❌ Error navigating to profile: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur lors du chargement du profil: $e"))
        );
    }
  }

  // Method to get the ID of the other participant (for 1-on-1 chats)
  String? get _otherParticipantId {
      if (widget.isGroup || widget.participants == null || widget.participants!.length < 2) {
          return null; // Not applicable for groups or invalid participant list
      }
      // Find the participant who is NOT the current user
      return widget.participants!.firstWhere(
          (p) => p is Map && p['_id'] != widget.userId, 
          orElse: () => null
      )?['_id'] as String?;
  }

  // Method to get the type of the other participant (for 1-on-1 chats)
  String get _otherParticipantType {
      if (widget.isGroup) return 'group'; // Not applicable for groups
      if (widget.isProducer) {
          // TODO: Determine actual producer type based on passed data or API call
          return 'restaurant'; // Defaulting, needs refinement
      }
      return 'user';
  }
} 