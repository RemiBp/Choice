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
import 'package:socket_io_client/socket_io_client.dart' as IO; // Import socket_io_client
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
import '../utils/constants.dart' as constants; // Import constants for base URL
import 'group_details_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../utils.dart' show getImageProvider;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../widgets/tenor_gif_picker.dart';

class Mention {
  final String userId;
  final String username;
  final String entityType;
  final int startIndex;
  final int endIndex;

  Mention({
    required this.userId,
    required this.username,
    required this.entityType,
    required this.startIndex,
    required this.endIndex,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'entityId': userId,
        'username': username,
        'entityType': entityType,
        'startIndex': startIndex,
        'endIndex': endIndex,
      };

  factory Mention.fromJson(Map<String, dynamic> json) {
    return Mention(
      userId: json['userId'] ?? json['entityId'] ?? '',
      username: json['username'] ?? 'Mention',
      entityType: json['entityType'] ?? 'unknown',
      startIndex: json['startIndex'] ?? 0,
      endIndex: json['endIndex'] ?? 0,
    );
  }
}

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

  // --- WebSocket State ---
  IO.Socket? _socket;
  Map<String, dynamic> _messageReadStatus = {};
  Map<String, dynamic> _conversationUpdates = {};
  // --- End WebSocket State ---

  // Toggle pour l'affichage du picker d'émojis
  bool _isEmojiVisible = false;

  bool _isDarkMode = false;

  Map<String, dynamic>? _replyingMessage;

  bool _isPinned = false;
  bool _isMuted = false;

  String _recipientName = '';
  String _recipientAvatar = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationService = ConversationService();
    
    _loadMessages();
    _initWebSocket(); // Initialize WebSocket connection
    _markAsReadOnOpen();
    
    if (widget.isGroup) {
      _loadGroupDetails();
    }
    
    _messageController.addListener(_onTypingChanged);
    
    // Keep the refresh timer for now as a fallback, but WebSocket is primary
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (_) { // Increased interval
      if (mounted && (_socket == null || !_socket!.connected)) {
         print("WebSocket not connected, refreshing via timer...");
        _loadMessages(silent: true);
      }
    });
    // Charger l'état pin/mute initial si possible
    _fetchPinMuteStatus();
    _scrollController.addListener(_onScrollForReadReceipt);

    _recipientName = widget.recipientName;
    _recipientAvatar = widget.recipientAvatar;
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _refreshTimer?.cancel();
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _socket?.disconnect(); // Disconnect socket
    _socket?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMessages(silent: true);
       // Reconnect WebSocket if necessary when app resumes
      if (_socket != null && !_socket!.connected) {
         print("🔌 App resumed, attempting to reconnect WebSocket...");
         _socket!.connect();
      }
    } else if (state == AppLifecycleState.paused) {
       // Optionally disconnect or reduce activity when paused
       // _socket?.disconnect(); 
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = MediaQuery.of(context).platformBrightness;
    setState(() {
      _isDarkMode = brightness == Brightness.dark;
    });
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
    
    if (selection.isValid && selection.baseOffset > 0) {
      // Use the helper function to find the potential mention at the cursor
      final currentMention = _findCurrentMention(text, selection.baseOffset);

      if (currentMention != null && currentMention.length > 1) {
        // Potential mention detected, extract the query (text after @)
        final query = currentMention.substring(1);
         if (query != _currentMentionQuery) { // Search only if query changed
             _searchUsers(query);
             setState(() {
                 _currentMentionQuery = query; // Update current query
             });
         }
         // Ensure suggestions are shown if a potential mention is being typed
         if (!_showMentionSuggestions) {
            setState(() {
                _showMentionSuggestions = true;
            });
         }

      } else {
        // No valid mention pattern at cursor, hide suggestions
        if (_showMentionSuggestions) {
            setState(() {
                _showMentionSuggestions = false;
                _currentMentionQuery = '';
            });
        }
      }
    } else {
       // Invalid selection or cursor at start, hide suggestions
       if (_showMentionSuggestions) {
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
    final List<Mention> messageMentions = List.from(_mentions);
    final String tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final replyToId = _replyingMessage?['_id'] ?? _replyingMessage?['id'];

    setState(() {
      _isSending = true;
      _isTyping = false;
      _messageController.clear();
      _mediaToSend = [];
      _mentions = [];
      _showMentionSuggestions = false;
      _currentMentionQuery = '';
      _replyingMessage = null;
      _messages.add({
        '_id': tempId,
        'id': tempId,
        'senderId': widget.userId,
        'content': message,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sending',
        'media': mediaUrls,
        'mentions': messageMentions.isNotEmpty ? messageMentions.map((m) => m.toJson()).toList() : [],
        'replyTo': _replyingMessage != null
            ? {
                '_id': _replyingMessage!['_id'] ?? _replyingMessage!['id'],
                'content': _replyingMessage!['content'] ?? ''
              }
            : null,
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      List<Map<String, dynamic>>? mentionsData =
          messageMentions.isNotEmpty ? messageMentions.map((m) => m.toJson()).toList() : null;
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
          final tempIndex = _messages.indexWhere((m) => m['_id'].toString() == tempId);
          if (tempIndex != -1) {
             final Map<String, dynamic> messageData = response['message'] is Map ? Map<String, dynamic>.from(response['message']) : {};
             final String messageId = messageData['_id']?.toString() ?? messageData['id']?.toString() ?? tempId;
             final String messageTimestamp = messageData['timestamp']?.toString() ?? DateTime.now().toIso8601String();
             // --- Fix replyTo: if backend only returns id, fill in content from _messages ---
             dynamic replyTo = messageData['replyTo'];
             if (replyTo != null && (replyTo is String || replyTo is int)) {
               // Find the message in _messages
               final refMsg = _messages.firstWhere(
                 (m) => m['_id'].toString() == replyTo.toString() || m['id'].toString() == replyTo.toString(),
                 orElse: () => <String, dynamic>{},
               );
               if (refMsg != null) {
                 replyTo = {
                   '_id': refMsg['_id'] ?? refMsg['id'],
                   'content': refMsg['content'] ?? ''
                 };
               } else {
                 replyTo = null;
               }
             }
             // If backend returns full object, keep as is
             _messages[tempIndex] = {
               ..._messages[tempIndex],
               '_id': messageId,
               'id': messageId,
               'status': 'sent',
               'timestamp': messageTimestamp,
               'mentions': messageMentions.isNotEmpty ? messageMentions.map((m) => m.toJson()).toList() : [],
               'replyTo': replyTo,
             };
          }
        });
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du message: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
          final tempIndex = _messages.indexWhere((m) => m['_id'].toString() == tempId);
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
                 setState(() {
                     _messages.removeWhere((m) => m['_id'].toString() == tempId);
                     _messageController.text = message;
                     _mediaToSend = List.from(mediaUrls);
                     _mentions = List.from(messageMentions);
                     _replyingMessage = _replyingMessage;
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
    String status = message['status'] ?? 'sent';
    final List<dynamic>? mentionsData = message['mentions'] as List<dynamic>?;
    final Map<String, dynamic>? replyTo = message['replyTo'] as Map<String, dynamic>?;
    String? replySenderName;
    if (replyTo != null && replyTo['_id'] != null) {
      if (message['senderId'] == widget.userId) {
        replySenderName = 'Vous';
      } else if (widget.isGroup && _participantsInfo.isNotEmpty) {
        final p = _participantsInfo[message['senderId']];
        replySenderName = p != null ? (p['name'] ?? p['username'] ?? 'Utilisateur') : 'Utilisateur';
      } else if (!widget.isGroup) {
        replySenderName = widget.recipientName;
      } else {
        replySenderName = 'Utilisateur';
      }
    }

    final Color bubbleColor = isCurrentUser
        ? _primaryColor.withOpacity(0.9)
        : Colors.grey[300]!;
    final Color textColor = isCurrentUser ? Colors.white : Colors.black87;

    Widget statusIcon = const SizedBox.shrink();
    if (isCurrentUser) {
      if (status == 'sending') {
        statusIcon = const Icon(Icons.access_time, size: 12, color: Colors.white70);
      } else if (status == 'sent') {
        statusIcon = const Icon(Icons.check, size: 12, color: Colors.white70);
      } else if (status == 'delivered') {
        statusIcon = const Icon(Icons.done_all, size: 12, color: Colors.white70);
      } else if (status == 'read') {
        statusIcon = const Icon(Icons.done_all, size: 12, color: Colors.blueAccent);
      } else if (status == 'error') {
        statusIcon = const Icon(Icons.error_outline, size: 12, color: Colors.redAccent);
      }
    }

    // Bloc 2: read receipts - if current user is sender, check if all others have read
    if (isCurrentUser && message['id'] != null && _messageReadStatus.isNotEmpty) {
      final readStatus = _messageReadStatus[message['id']] ?? _messageReadStatus[message['_id']];
      if (readStatus == true || readStatus == 'read' || readStatus == 1) {
        status = 'read';
      }
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            setState(() => _replyingMessage = message);
          }
        },
        onDoubleTap: () {
          setState(() => _replyingMessage = message);
        },
        onLongPress: () => _showMessageMenu(context, message, isCurrentUser),
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
              if (replyTo != null && replyTo['content'] != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? Colors.white24 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (replySenderName != null)
                              Text(
                                replySenderName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurple),
                              ),
                            Text(
                              replyTo['content'],
                              style: TextStyle(fontStyle: FontStyle.italic, color: isCurrentUser ? Colors.white70 : Colors.black54, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                          child: message['image_url'] != null
                            ? Builder(
                                builder: (context) {
                                  final imageUrl = message['image_url'];
                                  final imageProvider = getImageProvider(imageUrl);
                                  
                                  return imageProvider != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            print("❌ Error loading message image: $error");
                                            return Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey[600]));
                                          },
                                        ),
                                      )
                                    : Center(child: Icon(Icons.image, size: 30, color: Colors.grey[600]));
                                }
                              )
                            : Container(),
                        ),
                      );
                    },
                  ),
                ),
              if (content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: _renderMessageContent(content, mentionsData),
                ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get participant ID and Type for potential navigation
    String? otherUserId;
    if (widget.participants != null) {
      for (final p in widget.participants!) {
        final idStr = p.toString();
        if (idStr != widget.userId) {
          otherUserId = idStr;
          break;
        }
      }
    }
    final String otherUserType = widget.isProducer ? 'restaurant' : 'user'; // Simplified type guessing

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Row(
          children: [
            GestureDetector(
              // Navigate on avatar tap ONLY for non-group chats
              onTap: (!widget.isGroup && otherUserId != null)
                  ? () => _navigateToProfile(otherUserId ?? '', otherUserType)
                  : null,
              child: CircleAvatar(
                radius: 20,
                backgroundImage: getImageProvider(widget.recipientAvatar) ?? const AssetImage('assets/images/default_avatar.png'),
                child: getImageProvider(widget.recipientAvatar) == null ? Icon(Icons.person, color: Colors.grey[400]) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), // Ensure text color is white
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.isGroup)
                    Text(
                      // Use actual participant count if available, otherwise fallback
                      '${widget.participants?.length ?? '...'} participants',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    )
                  else
                    Text(
                      'En ligne', // Statut par défaut, à remplacer par le vrai statut
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white), // Set icon color to white
        actionsIconTheme: IconThemeData(color: Colors.white), // Set actions icon color to white
        actions: [
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () => _initiateCall(true),
          ),
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () => _initiateCall(false),
          ),
          if (widget.isGroup)
            IconButton(
              icon: Icon(Icons.info_outline),
              tooltip: 'Détails du groupe',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupDetailsScreen(
                      conversationId: widget.conversationId,
                      currentUserId: widget.userId,
                      groupName: widget.recipientName,
                      groupAvatar: widget.recipientAvatar,
                      participants: (widget.participants ?? []).map((p) {
                        if (p is Map<String, dynamic>) return p;
                        if (p is String) return {'id': p, 'name': '', 'avatar': ''};
                        return <String, dynamic>{};
                      }).toList().cast<Map<String, dynamic>>(),
                    ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    if (result['groupName'] != null) _recipientName = result['groupName'];
                    if (result['groupAvatar'] != null) _recipientAvatar = result['groupAvatar'];
                  });
                }
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'search') {
                // Rechercher dans les messages
              } else if (value == 'clear') {
                // Effacer la conversation
              } else if (value == 'add_participant' && widget.isGroup) {
                  // TODO: Add participant logic
              } else if (value == 'group_info' && widget.isGroup) {
                  // TODO: Show group info screen
              } else if (value == 'pin') {
                await _togglePin();
              } else if (value == 'mute') {
                await _toggleMute();
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
                value: 'pin',
                child: Row(
                  children: [
                    Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(_isPinned ? 'Désépingler' : 'Épingler'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(_isMuted ? 'Activer notifications' : 'Mettre en sourdine'),
                  ],
                ),
              ),
              if (widget.isGroup)
                PopupMenuItem<String>(
                  value: 'add_participant',
                  child: Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text('Ajouter participant'),
                    ],
                  ),
                ),
                if (widget.isGroup)
                 PopupMenuItem<String>(
                   value: 'group_info',
                   child: Row(
                     children: [
                       Icon(Icons.info_outline, color: Colors.grey[700]),
                       const SizedBox(width: 8),
                       Text('Infos du groupe'),
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
          // --- Mention Suggestions List ---
           if (_showMentionSuggestions && _suggestedUsers.isNotEmpty)
             Container(
               height: min(180, _suggestedUsers.length * 60.0), // Limit height
               decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
               ),
               child: ListView.builder(
                 itemCount: _suggestedUsers.length,
                 itemBuilder: (context, index) {
                   final user = _suggestedUsers[index];
                   return ListTile(
                     leading: CircleAvatar(
                       radius: 18,
                       backgroundImage: CachedNetworkImageProvider(
                         user['avatar'] ?? 'https://via.placeholder.com/150',
                       ),
                       backgroundColor: Colors.grey[200],
                     ),
                     title: Text(user['name'] ?? 'Utilisateur', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                     onTap: () {
                       _onMentionSelected(user);
                     },
                     dense: true, // Make items smaller
                   );
                 },
               ),
             ),
           // --- End Mention Suggestions ---

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
                    : AnimationLimiter(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message['senderId'] == widget.userId;
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 300),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: _buildMessageBubble(message, isMe),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          
          // Afficher le sélecteur d'émojis si demandé
          if (_isEmojiVisible)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: _messageController,
                onEmojiSelected: (Category? category, Emoji emoji) {
                  // Insert emoji at the current cursor position
                  final text = _messageController.text;
                  final selection = _messageController.selection;
                  final newText = text.replaceRange(
                    selection.start,
                    selection.end,
                    emoji.emoji,
                  );
                  final emojiLength = emoji.emoji.length;
                  _messageController.value = _messageController.value.copyWith(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: (selection.start + emojiLength).toInt(),
                    ),
                  );
                },
                onBackspacePressed: () {
                  final text = _messageController.text;
                  final selection = _messageController.selection;
                  if (selection.start > 0) {
                    final newText = text.replaceRange(
                      selection.start - 1,
                      selection.start,
                      '',
                    );
                    _messageController.value = _messageController.value.copyWith(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: (selection.start - 1).toInt(),
                      ),
                    );
                  }
                },
                config: Config(
                  height: 250,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 32 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero,
                    recentsLimit: 28,
                    replaceEmojiOnLimitExceed: false,
                    noRecents: const Text(
                      'No Recents',
                      style: TextStyle(fontSize: 20, color: Colors.black26),
                      textAlign: TextAlign.center,
                    ),
                    loadingIndicator: const SizedBox.shrink(),
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    initCategory: Category.RECENT,
                    backgroundColor: const Color(0xFFF2F2F2),
                    indicatorColor: _primaryColor,
                    iconColor: Colors.grey,
                    iconColorSelected: _primaryColor,
                    backspaceColor: _primaryColor,
                    recentTabBehavior: RecentTabBehavior.RECENT,
                    tabIndicatorAnimDuration: kTabScrollDuration,
                  ),
                  skinToneConfig: SkinToneConfig(
                    enabled: true,
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: Colors.grey,
                  ),
                ),
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
                            image: getImageProvider(_mediaToSend[index]) ?? const AssetImage('assets/images/default_image.png'),
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
          
          // Zone de saisie du message
          _buildInputArea(),
        ],
      ),
    );
  }
  
  Widget _buildInputArea() {
    String? replySenderName;
    if (_replyingMessage != null) {
      if (_replyingMessage!['senderId'] == widget.userId) {
        replySenderName = 'Vous';
      } else if (widget.isGroup && _participantsInfo.isNotEmpty) {
        // Try to get name from group participants info
        final p = _participantsInfo[_replyingMessage!['senderId']];
        replySenderName = p != null ? (p['name'] ?? p['username'] ?? 'Utilisateur') : 'Utilisateur';
      } else if (!widget.isGroup) {
        replySenderName = widget.recipientName;
      } else {
        replySenderName = 'Utilisateur';
      }
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replySenderName != null)
                            Text(
                              replySenderName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple),
                            ),
                          Text(
                            _replyingMessage?['content'] ?? '',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _replyingMessage = null),
                    ),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                // Bouton "+" pour pièces jointes (ouvertures galerie/caméra)
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: _primaryColor),
                  onPressed: _showMediaOptions,
                ),
                IconButton(
                  icon: Icon(Icons.emoji_emotions_outlined, color: _primaryColor),
                  onPressed: _showEmojiPicker,
                ),
                IconButton(
                  icon: Icon(Icons.gif_box, color: _primaryColor),
                  onPressed: _showGifPicker,
                ),
                // Champ de texte
                Expanded(
                  child: Container(
                     padding: EdgeInsets.symmetric(horizontal: 14.0),
                     decoration: BoxDecoration(
                       color: Colors.grey[100], // Slightly different background for text field
                       borderRadius: BorderRadius.circular(25.0),
                     ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Taper un message...',
                        border: InputBorder.none,
                        isDense: true, // Reduces padding inside TextField
                      ),
                       textCapitalization: TextCapitalization.sentences,
                       keyboardType: TextInputType.multiline,
                       maxLines: null, // Allows multiple lines
                       onSubmitted: (_) => _sendMessage(), // Send on keyboard submit
                    ),
                  ),
                ),
                // Bouton d'envoi
                IconButton(
                  icon: Icon(Icons.send, color: _primaryColor),
                  onPressed: _isSending ? null : _sendMessage, // Désactiver pendant l'envoi
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _viewGroupDetails() {
    // Implémenter la navigation vers les détails du groupe
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Détails du groupe non implémentés')),
    );
  }

  // Helper to find the word starting with @ under the cursor
  String? _findCurrentMention(String text, int cursorPosition) {
    if (cursorPosition <= 0) return null;

    int start = cursorPosition - 1;
    // Find the start of the word (space or beginning of text)
    while (start >= 0 && text[start] != ' ' && text[start] != '@') {
      start--;
    }

    // Check if the word starts with @
    if (start >= 0 && text[start] == '@') {
      // Extract the word from @ up to the cursor position
      // Allow alphanumeric and underscore characters in usernames
      final potentialMention = text.substring(start, cursorPosition);
      final mentionRegex = RegExp(r"^@[\w]+$"); // Simple regex: @ followed by alphanumeric/underscore

      if (mentionRegex.hasMatch(potentialMention)) {
         return potentialMention;
      }
    }
    return null;
  }
  
  // Rechercher des utilisateurs pour les suggestions de mention
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestedUsers = [];
          // Garder _showMentionSuggestions = true si une requête vient d'être effacée
        });
      }
      return;
    }

    setState(() {
      _isLoading = true; // Afficher un indicateur pendant la recherche
    });

    try {
      // Appel à l'API de recherche unifiée
      final results = await _conversationService.searchAll(query);
      
      if (mounted) {
        setState(() {
          // Les résultats de searchAll sont déjà au format List<Map<String, dynamic>>
          // avec les clés attendues ('id', 'name', 'avatar', 'type')
          _suggestedUsers = results;
          _showMentionSuggestions = true; // Afficher tant qu'une requête est active
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur lors de la recherche unifiée pour mention: $e");
      if (mounted) {
        setState(() {
          _suggestedUsers = [];
          _showMentionSuggestions = false; // Cacher en cas d'erreur
          _isLoading = false;
        });
      }
    }
  }
  
  // Adapte l'insertion de mention pour inclure le type
  void _onMentionSelected(Map<String, dynamic> user) {
    final String username = user['name'] ?? 'Mention';
    final String entityId = user['id'] ?? '';
    final String entityType = user['type'] ?? 'unknown'; // Récupère le type

    if (entityId.isEmpty) return; // Impossible de mentionner sans ID

    final currentText = _messageController.text;
    final selection = _messageController.selection;

    // Trouver le début de la requête de mention (@...)
    int queryStart = selection.baseOffset - _currentMentionQuery.length - 1;
    if (queryStart < 0 || currentText[queryStart] != '@') {
      queryStart = currentText.substring(0, selection.baseOffset).lastIndexOf('@');
      if (queryStart < 0) return; // Impossible de continuer
    }

    final textBefore = currentText.substring(0, queryStart);
    final textAfterCursor = currentText.substring(selection.baseOffset);

    final mentionText = '@$username '; // Texte à insérer
    final newText = textBefore + mentionText + textAfterCursor;

    // Calculer les indices dans le *nouveau* texte
    final startIndex = queryStart;
    final endIndex = startIndex + mentionText.length; // endIndex est exclusif

    // Ajouter la mention avec son type
    _mentions.add(Mention(
      userId: entityId, // Stocke l'ID de l'entité
      username: username,
      entityType: entityType, // Stocke le type
      startIndex: startIndex,
      endIndex: endIndex, // Ajusté pour être exclusif si nécessaire ou correspondre à la logique d'affichage
    ));

    // Mettre à jour le champ de texte
    _messageController.text = newText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: startIndex + mentionText.length),
    );

    // Cacher les suggestions
    setState(() {
      _showMentionSuggestions = false;
      _suggestedUsers = [];
      _currentMentionQuery = '';
    });
  }

  // Modifie le rendu pour gérer différents types et la navigation
  Widget _renderMessageContent(String content, List<dynamic>? mentionsData) {
    if (mentionsData == null || mentionsData.isEmpty) {
      return Text(
        content,
        style: TextStyle(
          color: _isDarkMode ? Colors.white : Colors.black87, // Ajuster couleur texte pour les bulles claires
          fontSize: 16,
        ),
      );
    }

    List<TextSpan> textSpans = [];
    int lastIndex = 0;

    // Convertir les données JSON en objets Mention
    List<Mention> mentions = mentionsData.map((data) {
      if (data is Map<String, dynamic>) {
        return Mention.fromJson(data);
      } else if (data is Mention) {
        return data; // Si c'est déjà un objet Mention (cas de l'affichage optimiste)
      }
      // Retourner un objet par défaut ou lever une erreur si le format est inattendu
      return Mention(userId: '', username: 'error', entityType: 'unknown', startIndex: 0, endIndex: 0);
    }).toList();

    // Trier les mentions par startIndex pour un traitement correct
    mentions.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    for (var mention in mentions) {
      // Ajouter le texte normal avant la mention
      if (mention.startIndex > lastIndex) {
        textSpans.add(TextSpan(
          text: content.substring(lastIndex, mention.startIndex),
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        ));
      }

      // Ajouter la mention cliquable
      if (mention.endIndex <= content.length && mention.startIndex < mention.endIndex) {
        textSpans.add(TextSpan(
          text: content.substring(mention.startIndex, mention.endIndex),
          style: TextStyle(
            color: Colors.blue[300],
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              print("Mention cliquée: ${mention.username} (ID: ${mention.userId}, Type: ${mention.entityType})");
              // Naviguer vers le bon écran basé sur entityType
              _navigateToEntity(mention.userId, mention.entityType);
            },
        ));
        lastIndex = mention.endIndex;
      } else {
         print("Mention invalide ou hors limites: ${mention.toJson()}");
         // Ajouter le texte comme normal si les indices sont invalides
         if(mention.startIndex >= lastIndex && mention.startIndex < content.length) {
            textSpans.add(TextSpan(
             text: content.substring(lastIndex, mention.startIndex),
             style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
           ));
         }
         // Il se peut qu'il faille ajuster lastIndex ici
      }
    }

    // Ajouter le texte restant après la dernière mention
    if (lastIndex < content.length) {
      textSpans.add(TextSpan(
        text: content.substring(lastIndex),
        style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
      ));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
           fontSize: 16, 
           color: _isDarkMode ? Colors.white : Colors.black87 // Style par défaut pour le RichText
        ),
        children: textSpans,
      ),
    );
  }

  // Fonction de navigation basée sur l'ID et le type de l'entité
  Future<void> _navigateToEntity(String entityId, String entityType) async {
    if (entityId.isEmpty) return;

    print("Navigating vers entité: ID=$entityId, Type=$entityType");
    final currentContext = context; // Capturer le context

    // Afficher un indicateur de chargement (optionnel)
    showDialog(
      context: currentContext,
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
                Text("Chargement..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      Widget? destinationScreen;

      // Déterminer l'écran de destination en fonction du type
      switch (entityType) {
        case 'user':
          destinationScreen = ProfileScreen(userId: entityId, viewMode: 'public');
          break;
        case 'restaurant':
          // Assurez-vous que ProducerScreen attend bien producerId et userId
          destinationScreen = ProducerScreen(producerId: entityId, userId: widget.userId);
          break;
        case 'leisureProducer':
          // Pour les loisirs, il faut peut-être récupérer les données avant
          // ou adapter ProducerLeisureScreen pour prendre un ID
          final data = await _fetchEntityDetails(entityId, entityType);
          if (data != null) {
             destinationScreen = ProducerLeisureScreen(producerData: data);
          }
          break;
        case 'wellnessPlace':
        case 'beautyPlace':
         final data = await _fetchEntityDetails(entityId, entityType);
          if (data != null) {
             destinationScreen = WellnessProducerProfileScreen(producerData: data);
          }
          break;
        case 'event':
          // Assurez-vous qu'un écran pour les événements existe et prend un ID
          // destinationScreen = EventDetailScreen(eventId: entityId);
          print("Navigation vers écran événement (ID: $entityId) non implémentée.");
          ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(content: Text('Détails de l\'événement non disponibles.')));
          break;
        default:
          print("⚠️ Type d'entité inconnu pour la navigation: $entityType");
          ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(content: Text('Type de profil inconnu: $entityType')));
      }

      // Fermer le dialogue de chargement
      if (Navigator.of(currentContext).canPop()) {
         Navigator.pop(currentContext);
      }

      // Naviguer si une destination a été trouvée
      if (destinationScreen != null && currentContext.mounted) {
        Navigator.push(
          currentContext,
          MaterialPageRoute(builder: (context) => destinationScreen!),
        );
      } 
    } catch (e) {
      print("❌ Erreur lors de la navigation vers l'entité: $e");
      // Fermer le dialogue de chargement en cas d'erreur
      if (Navigator.of(currentContext).canPop()) {
         Navigator.pop(currentContext);
      }
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text("Erreur lors du chargement des détails: $e")),
        );
      }
    }
  }

  // Helper pour récupérer les détails d'une entité via l'API unifiée
  Future<Map<String, dynamic>?> _fetchEntityDetails(String entityId, String entityType) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/unified/$entityId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Vérifier si le type retourné correspond au type attendu
        if (data['type'] == entityType) {
          return data;
        } else {
          print("Type mismatch: expected $entityType, got ${data['type']}");
          return null;
        }
      } else {
        print("Failed to fetch details for $entityType $entityId: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching entity details: $e");
      return null;
    }
  }

  Future<void> _initiateCall(bool isVideoCall) async {
    if (widget.isGroup) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Appels de groupe non implémentés'))
       );
       return; // Fine in async void/Future<void>
     }

   final String? recipientId = _otherParticipantId;
   if (recipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Impossible de déterminer le destinataire'))
       );
      return; // Fine in async void/Future<void>
    }

    // Show loading indicator
    // Use a local variable for context that might become invalid
    final currentContext = context;
     showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(width: 20),
                  Text("Lancement de l'appel..."),
                ],
              ),
            ),
          );
        },
      );

    try {
       // Corrected call to use positional arguments
       await _callService.startCall( 
         widget.userId,
         recipientId!, // Pass recipientId directly (with null check)
         isVideoCall, // Pass isVideoCall directly
       );
       // Dialog is popped automatically by startCall or in finally/catchError
     } catch (error) {
       print("Error initiating call: $error");
       // Close dialog if still visible and context is valid
       if (Navigator.of(currentContext).canPop()) {
         Navigator.of(currentContext).pop();
       }
       if (currentContext.mounted) { // Check context validity before showing SnackBar
           ScaffoldMessenger.of(currentContext).showSnackBar(
             SnackBar(content: Text('Erreur lancement appel: $error'))
           );
       }
    }
  }

  // Helper to get the other participant ID for profile navigation (Rewritten)
  String? get _otherParticipantId {
    if (widget.isGroup || widget.participants == null || widget.participants!.isEmpty) {
      return null;
    }
    // Iterate manually to find the first participant ID that is not the current user
    for (final participant in widget.participants!) {
       if (participant is String && participant != widget.userId) {
         return participant; // Return the first match found
       }
       // Handle cases where participants might be Maps (though the list seems to be String based on usage)
       else if (participant is Map) {
          final String? idFromMap = participant['_id']?.toString() ?? participant['id']?.toString();
          if (idFromMap != null && idFromMap != widget.userId) {
             return idFromMap;
          }
       }
    }
    return null; // Return null if no other participant ID is found
  }

  // Helper to guess the other participant type (simplified)
   String get _otherParticipantType {
     if (widget.isProducer) {
         // You might need more specific logic if there are multiple producer types
         return 'restaurant'; // Assume restaurant if isProducer is true for now
     }
     return 'user'; // Assume user otherwise
   }

  // --- Profile Navigation Logic ---
   Future<void> _navigateToProfile(String participantId, String participantType) async {
     if (participantId.isEmpty) return;

     print("Navigating to profile: ID=$participantId, Type=$participantType");

     // Show loading indicator (optional but good UX)
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
                   CircularProgressIndicator(color: _primaryColor),
                   SizedBox(width: 20),
                   Text("Chargement..."),
                 ],
               ),
             ),
           );
         },
       );

     try {
       // Close loading indicator before pushing new screen
       Navigator.pop(context); 

       if (participantType == 'user') {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => ProfileScreen(
               userId: participantId,
               viewMode: 'public', // Assume public view when opened from chat
             ),
           ),
         );
       } else if (participantType == 'restaurant') {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => ProducerScreen(
               producerId: participantId,
                userId: widget.userId, // Pass current user ID if needed by ProducerScreen
             ),
           ),
         );
       } else if (participantType == 'leisure') {
         // Fetch data for Leisure producer before navigating
         final url = Uri.parse('${ApiConfig.baseUrl}/api/producers/leisure/$participantId'); // Adjust API endpoint if needed
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
            throw Exception("Failed to load leisure producer data (${response.statusCode})");
         }
       } else if (participantType == 'wellness' || participantType == 'beauty') {
          // Fetch data for Wellness/Beauty producer before navigating
         final url = Uri.parse('${ApiConfig.baseUrl}/api/unified/$participantId'); // Use unified or specific endpoint
         final response = await http.get(url);
          if (response.statusCode == 200) {
             final data = json.decode(response.body);
             Navigator.push(
                 context,
                 MaterialPageRoute(
                 builder: (context) => WellnessProducerProfileScreen(producerData: data),
                 ),
             );
          } else {
             throw Exception("Failed to load wellness/beauty producer data (${response.statusCode})");
          }
       } else {
         print("⚠️ Unknown participant type for profile navigation: $participantType");
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Type de profil inconnu: $participantType"))
         );
       }
     } catch (e) {
         // Ensure loading dialog is closed on error too
         // Navigator.pop(context); // Pop might already be called
         print("❌ Error navigating to profile: $e");
         ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Erreur lors du chargement du profil: $e"))
         );
     }
   }
 // --- End Profile Navigation ---

  // --- WebSocket Initialization and Handling ---
  void _initWebSocket() {
    try {
      final String socketUrl = constants.getBaseUrlSync(); // Get base URL directly
      print('🔌 Initializing WebSocket connection to $socketUrl');

      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        // Add auth/query parameters if needed by your backend
         'query': {
           'userId': widget.userId, // Example: Send user ID for authentication/identification
           // 'token': await _getToken(), // If token-based auth is used
         },
      });

      _socket!.onConnect((_) {
        print('✅ WebSocket connected: ${_socket?.id}');
        // Join the room for this specific conversation
        _socket!.emit('join_conversation', widget.conversationId);
        print('🚪 Joining conversation room: ${widget.conversationId}');
      });

      _socket!.on('new_message', (data) {
        print('📩 Received new_message event via WebSocket');
        if (data is Map<String, dynamic>) {
           // Ensure the message is for this conversation (optional, backend should handle rooms)
           if (data['conversationId'] == widget.conversationId) {
             final newMessage = Map<String, dynamic>.from(data);
             // Check if message already exists (from optimistic update)
             final existingIndex = _messages.indexWhere((m) => m['_id'] == newMessage['_id']);

             if (mounted) {
                 setState(() {
                   if (existingIndex == -1) {
                     // Add the new message if it doesn't exist
                     _messages.add(newMessage);
                     print(' L> Message added from WebSocket');
                   } else {
                      // Update existing message (e.g., status from temp to sent)
                      // This might not be needed if backend sends final data
                      _messages[existingIndex] = newMessage;
                      print(' L> Message updated from WebSocket');
                   }
                 });

                 // Scroll to bottom
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (_scrollController.hasClients) {
                     _scrollController.animateTo(
                       _scrollController.position.maxScrollExtent,
                       duration: Duration(milliseconds: 300),
                       curve: Curves.easeOut,
                     );
                   }
                 });
             }
           }
        } else {
             print('⚠️ Received new_message event with unexpected data format: $data');
        }
      });

      _socket!.on('message_read', (data) {
        if (data is Map && data['conversationId'] == widget.conversationId) {
          setState(() {
            _messageReadStatus = Map<String, dynamic>.from(data);
          });
        }
      });

      _socket!.on('conversation_updated', (data) {
        if (data is Map && data['conversationId'] == widget.conversationId) {
          setState(() {
            _conversationUpdates = Map<String, dynamic>.from(data);
            if (data['groupName'] != null) _recipientName = data['groupName'];
            if (data['groupAvatar'] != null) _recipientAvatar = data['groupAvatar'];
          });
        }
      });

      _socket!.onDisconnect((_) => print('🔌 WebSocket disconnected'));
      _socket!.onError((error) => print('❌ WebSocket Error: $error'));
      _socket!.onConnectError((error) => print('❌ WebSocket Connection Error: $error'));

    } catch (e) {
      print('❌ Failed to initialize WebSocket: $e');
    }
  }

  void _markAsReadOnOpen() async {
    try {
      await _conversationService.markConversationAsRead(widget.conversationId, widget.userId);
      _emitMessageRead();
    } catch (e) {
      print('Erreur lors du mark as read: $e');
    }
  }

  void _emitMessageRead() {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('message_read', {
        'conversationId': widget.conversationId,
        'userId': widget.userId,
      });
    }
  }

  // Placeholder pour picker d'émojis -> toggle réel
  void _showEmojiPicker() {
    setState(() {
      _isEmojiVisible = !_isEmojiVisible;
      if (_isEmojiVisible) {
        // Cacher le clavier virtuel
        FocusScope.of(context).unfocus();
      } else {
        // Rétablir le focus sur le champ de saisie
        _messageFocusNode.requestFocus();
      }
    });
  }

  void _showGifPicker() async {
    final gifUrl = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => TenorGifPicker(),
    );
    if (gifUrl != null && gifUrl.isNotEmpty) {
      _messageController.text += ' $gifUrl ';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
  }

  Future<void> _fetchPinMuteStatus() async {
    try {
      final details = await _conversationService.getConversationDetails(widget.conversationId);
      if (mounted) {
        setState(() {
          _isPinned = details['isPinned'] == true;
          _isMuted = details['isMuted'] == true;
        });
      }
    } catch (e) {
      print('Erreur chargement pin/mute: $e');
    }
  }

  Future<void> _togglePin() async {
    try {
      await _conversationService.updateGroupInfo(widget.conversationId);
      setState(() => _isPinned = !_isPinned);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isPinned ? 'Conversation épinglée' : 'Conversation désépinglée')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleMute() async {
    try {
      await _conversationService.updateGroupInfo(widget.conversationId);
      setState(() => _isMuted = !_isMuted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isMuted ? 'Conversation muette' : 'Notifications activées')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _onScrollForReadReceipt() {
    if (_scrollController.hasClients &&
        _scrollController.offset >= _scrollController.position.maxScrollExtent - 40) {
      _emitMessageRead();
    }
  }

  void _showMessageMenu(BuildContext context, Map<String, dynamic> message, bool isCurrentUser) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.reply, color: _primaryColor),
                title: Text('Répondre'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingMessage = message);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: _primaryColor),
                title: Text('Copier'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message['content'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Message copié')),
                  );
                },
              ),
              if (isCurrentUser)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Supprimer pour moi', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _messages.removeWhere((m) => m['_id'] == message['_id']);
                    });
                    // TODO: Appeler l'API pour suppression côté serveur si besoin
                  },
                ),
            ],
          ),
        );
      },
    );
  }
} 