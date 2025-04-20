import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'conversation_detail_screen.dart';
import '../services/conversation_service.dart';
import '../services/notification_service.dart';
import 'group_creation_screen.dart';
import '../models/contact.dart';
import 'package:choice_app/screens/profile_screen.dart';
import 'package:choice_app/screens/producer_screen.dart';
import 'package:choice_app/screens/producerLeisure_screen.dart';
import 'package:choice_app/screens/wellness_producer_profile_screen.dart';
import '../utils/api_config.dart';

class MessagingScreen extends StatefulWidget {
  final String userId;
  final String? selectedConversationId;
  
  const MessagingScreen({Key? key, required this.userId, this.selectedConversationId}) : super(key: key);

  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ConversationService _conversationService = ConversationService();
  final NotificationService _notificationService = NotificationService();
  
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _displayedConversations = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isSearchingFriends = false;
  List<Map<String, dynamic>> _friendSearchResults = [];
  bool _isDarkMode = false;
  
  // Nouvelle propriété pour suivre les messages en cours de frappe
  Map<String, bool> _typingStatus = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchConversations();
    _loadThemePreference();
    
    // Initialiser les notifications et écouter les mises à jour
    _initializeNotifications();
    
    // Si un ID de conversation est fourni, ouvrir cette conversation après le chargement
    if (widget.selectedConversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openSelectedConversation();
      });
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _filterConversationsByTab();
    }
  }

  void _filterConversationsByTab() {
    if (_conversations.isEmpty) return;

    setState(() {
      switch (_tabController.index) {
        case 0: // Tous
          _displayedConversations = List.from(_conversations);
          break;
        case 1: // Restaurants
          _displayedConversations = _conversations
              .where((conv) => conv['isRestaurant'] == true)
              .toList();
          break;
        case 2: // Loisirs
          _displayedConversations = _conversations
              .where((conv) => conv['isLeisure'] == true)
              .toList();
          break;
        case 3: // Groupes
          _displayedConversations = _conversations
              .where((conv) => conv['isGroup'] == true)
              .toList();
          break;
      }
    });
  }

  Future<void> _fetchConversations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final conversations = await _conversationService.getConversations(widget.userId);
      
      // --- DEBUGGING START ---
      print("DEBUG: Type of conversations received: ${conversations.runtimeType}");
      print("DEBUG: Value of conversations received: $conversations"); 
      // --- DEBUGGING END ---
      
      // Même si les conversations sont vides, ne pas afficher d'erreur
      // Simuler des statuts d'écriture pour certaines conversations si la liste n'est pas vide
      if (conversations is List && conversations.isNotEmpty) {
        _simulateTypingStatuses(conversations);
      }
      
      setState(() {
        // Ensure conversations is actually a List before assigning
        if (conversations is List<Map<String, dynamic>>) {
          _conversations = conversations;
        } else if (conversations is List) {
           // Attempt to cast if it's a List<dynamic>
           try {
             _conversations = List<Map<String, dynamic>>.from(conversations.map((item) => Map<String, dynamic>.from(item as Map)));
           } catch (e) {
             print("DEBUG: Failed to cast conversations to List<Map<String, dynamic>>: $e");
             _hasError = true;
             _errorMessage = 'Erreur: Format de données invalide reçu du serveur.';
             _conversations = []; // Reset to empty list on error
           }
        } else {
          // Handle cases where it's not a list (e.g., an error map)
          print("DEBUG: Received data is not a List. Type: ${conversations.runtimeType}");
          _hasError = true;
          _errorMessage = 'Erreur: Réponse inattendue du serveur.';
          _conversations = []; // Reset to empty list on error
        }
        _filterConversationsByTab(); // Appliquer le filtre actuel
      });
      
      // Effacer le badge des notifications
      await _notificationService.clearBadge();
      
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Erreur: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Simuler des statuts d'écriture pour une démonstration UX fluide
  void _simulateTypingStatuses(List<Map<String, dynamic>> conversations) {
    if (conversations.isEmpty) return;
    
    // Choisir aléatoirement une conversation pour simuler "est en train d'écrire"
    final random = DateTime.now().millisecondsSinceEpoch % conversations.length;
    final selectedConversation = conversations[random];
    
    // Mettre à jour l'état
    setState(() {
      _typingStatus[selectedConversation['id']] = true;
    });
    
    // Programmer la fin du statut "en train d'écrire" après quelques secondes
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _typingStatus[selectedConversation['id']] = false;
        });
      }
    });
  }

  void _filterConversations(String query) {
    if (query.isEmpty) {
      _filterConversationsByTab();
      _isSearchingFriends = false;
      setState(() {
        _friendSearchResults = [];
      });
      return;
    }
    
    // Si la recherche commence par @, on cherche des followers
    if (query.startsWith('@') && query.length > 1) {
      _searchFollowers(query.substring(1));
      return;
    }
    
    setState(() {
      _isSearchingFriends = false;
      _friendSearchResults = [];
    });
    
    final filteredConversations = _conversations.where((conv) {
      return conv['name'].toString().toLowerCase().contains(query.toLowerCase());
    }).toList();
    
    setState(() {
      _displayedConversations = filteredConversations;
    });
  }
  
  Future<void> _searchFollowers(String query) async {
    if (query.length < 2) return;
    
    setState(() {
      _isSearchingFriends = true;
    });
    
    try {
      // Use searchUsers method instead of searchFollowers since it's more reliable
      // and the UI is showing general contacts that can be messaged
      final results = await _conversationService.searchUsers(query);
      
      setState(() {
        _friendSearchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de recherche: $e'),
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Définir la palette de couleurs selon le thème
    final Color primaryColor = _isDarkMode ? Colors.purple[200]! : Colors.deepPurple;
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    final Color subtitleColor = _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Bouton de thème sombre/clair
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              color: textColor,
            ),
            onPressed: _toggleTheme,
            tooltip: _isDarkMode ? 'Mode clair' : 'Mode sombre',
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: textColor),
            onPressed: _showFilterOptions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: subtitleColor,
          indicatorColor: primaryColor,
          isScrollable: true,
          tabs: [
            Tab(text: 'Tous'),
            Tab(text: 'Restaurants'),
            Tab(text: 'Loisirs'),
            Tab(text: 'Groupes'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche avec design Instagram
          Container(
            padding: const EdgeInsets.all(16),
            color: bgColor,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Rechercher ou @mention pour amis',
                hintStyle: TextStyle(color: subtitleColor),
                prefixIcon: Icon(Icons.search, color: subtitleColor),
                filled: true,
                fillColor: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _filterConversations,
            ),
          ),
          
          // Affichage des résultats de recherche d'amis si actif
          if (_isSearchingFriends && _friendSearchResults.isNotEmpty)
            AnimationLimiter(
              child: Container(
                height: 120,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border(
                    bottom: BorderSide(color: _isDarkMode ? Colors.grey[900]! : Colors.grey[200]!),
                  ),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _friendSearchResults.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final follower = _friendSearchResults[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        horizontalOffset: 50.0,
                        child: FadeInAnimation(
                          child: InkWell(
                            onTap: () => _startConversationWithUser(follower),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: CachedNetworkImageProvider(
                                          follower['avatar'] ?? 'https://via.placeholder.com/150',
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: cardColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    follower['name'] ?? 'Utilisateur',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Contenu des onglets
          Expanded(
            child: _isLoading 
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _fetchConversations,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Chaque onglet utilise _buildConversationList
                          _buildConversationList(_displayedConversations.where((c) => true).toList(), primaryColor, bgColor, textColor),
                          _buildConversationList(_displayedConversations.where((c) => c['isRestaurant'] == true).toList(), primaryColor, bgColor, textColor),
                          _buildConversationList(_displayedConversations.where((c) => c['isLeisure'] == true).toList(), primaryColor, bgColor, textColor),
                          _buildConversationList(_displayedConversations.where((c) => c['isGroup'] == true).toList(), primaryColor, bgColor, textColor),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        child: const Icon(Icons.add_comment, color: Colors.white),
        onPressed: _showNewMessageOptions,
      ),
    );
  }
  
  // Modifie _buildConversationList pour inclure AnimationLimiter
  Widget _buildConversationList(List<Map<String, dynamic>> conversations, Color primaryColor, Color bgColor, Color textColor) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 18,
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez à discuter avec les producteurs et les utilisateurs',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_comment),
              label: const Text('Nouvelle conversation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showNewMessageOptions,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchConversations,
      color: primaryColor,
      backgroundColor: bgColor,
      child: AnimationLimiter(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(), // Permet le refresh même si la liste est courte
          padding: EdgeInsets.zero, // Enlève le padding par défaut
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildConversationTile(conversations[index], primaryColor, bgColor, textColor),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Modifie _buildConversationTile pour un design plus épuré
  Widget _buildConversationTile(Map<String, dynamic> conversation, Color primaryColor, Color bgColor, Color textColor) {
    // ... (Récupération sûre des données existantes: conversationId, unreadCount, etc.) ...
    final String conversationId = _safeGet<String>(conversation, 'id', 'unknown_id_${DateTime.now().millisecondsSinceEpoch}');
    final int unreadCount = _safeGet<int>(conversation, 'unreadCount', 0);
    final bool hasUnread = unreadCount > 0;
    final bool isRestaurant = _safeGet<bool>(conversation, 'isRestaurant', false);
    final bool isLeisure = _safeGet<bool>(conversation, 'isLeisure', false);
    final bool isGroup = _safeGet<bool>(conversation, 'isGroup', false);
    final String name = _safeGet<String>(conversation, 'name', 'Conversation');
    final String lastMessage = _safeGet<String>(conversation, 'lastMessage', '');
    final String avatarUrl = _safeGet<String>(conversation, 'avatar', '');
    final String timeString = _safeGet<String>(conversation, 'time', '');
    final String otherParticipantId = _safeGet<String>(conversation, 'otherParticipantId', '');
    final String participantType = _safeGet<String>(conversation, 'participantType', 'user');
    final bool isMuted = _safeGet<bool>(conversation, 'isMuted', false); // Assume mute status exists
    final bool isPinned = _safeGet<bool>(conversation, 'isPinned', false); // Assume pin status exists

    String formattedTime = '';
    try {
      if (timeString.isNotEmpty) {
        final DateTime time = DateTime.parse(timeString);
        formattedTime = _formatConversationTime(time);
      }
    } catch (e) {
      formattedTime = '--:--'; 
    }

    final String defaultAvatarName = name.isNotEmpty && name != 'Conversation' && name != 'Utilisateur' ? name : '??';
    final String finalAvatarUrl = (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http') || avatarUrl.startsWith('data:image'))) 
      ? avatarUrl 
      : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(defaultAvatarName)}&background=random&bold=true&color=ffffff';
    final imageProvider = _getImageProvider(finalAvatarUrl);
    final bool isTyping = _typingStatus[conversationId] ?? false;
    final String heroTag = 'avatar_$conversationId';
    final Key dismissibleKey = Key('conversation_$conversationId');

    return Dismissible(
      key: dismissibleKey,
      background: Container(
        color: Colors.redAccent,
        padding: EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerStart,
        child: Icon(Icons.delete_sweep, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.blueAccent,
        padding: EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerEnd,
        child: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) { // Swipe right (Delete)
          return await showDialog(
             // ... (Dialogue confirmation suppression) ...
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: bgColor,
                  title: Text('Supprimer cette conversation?',
                    style: TextStyle(color: textColor),
                  ),
                  content: Text(
                    'Cette action ne peut pas être annulée.',
                    style: TextStyle(color: textColor.withOpacity(0.7)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Annuler', style: TextStyle(color: textColor)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
              },
          );
        } else { // Swipe left (Pin/Unpin)
          // Pin/Unpin logic here - For now, just return false to prevent dismissal
          _togglePinConversation(conversationId, !isPinned);
          return false; 
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _deleteConversation(conversationId); 
        }
      },
      child: Material(
        color: bgColor,
        child: InkWell(
          onTap: () => _navigateToConversationDetail(conversation),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Ajustement padding
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _isDarkMode ? Colors.grey[800]! : Colors.grey[200]!, width: 0.5)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  // ... (GestureDetector pour profil) ...
                  onTap: () {
                     if (!isGroup && otherParticipantId.isNotEmpty) {
                       _navigateToProfile(otherParticipantId, participantType);
                     }
                  },
                  child: Stack(
                    clipBehavior: Clip.none, // Permet aux badges de déborder légèrement
                    children: [
                      Hero(
                        tag: heroTag,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: imageProvider,
                          backgroundColor: Colors.grey[300],
                          child: imageProvider == null ? Icon(isGroup ? Icons.group : Icons.person, color: Colors.grey[600]) : null,
                        ),
                      ),
                      // Indicateur "En ligne" plus visible
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 15, height: 15,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent[400], // Couleur plus vive
                            shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 2.5), // Bordure plus épaisse
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPinned) Icon(Icons.push_pin, size: 14, color: textColor.withOpacity(0.6)),
                          if (isPinned) SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, // Un peu plus gras
                                fontSize: 16,
                                color: textColor,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            formattedTime,
                            style: GoogleFonts.poppins(
                              color: hasUnread ? primaryColor : textColor.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5), // Espace ajusté
                      Row(
                        children: [
                          Expanded(
                            child: isTyping
                                ? Row(children: [
                                    Text(
                                      "Écrit...", // Plus court
                                      style: GoogleFonts.poppins(
                                        color: primaryColor, fontStyle: FontStyle.italic, fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    _buildTypingIndicator(primaryColor),
                                  ])
                                : Text(
                                    lastMessage, // Icône de statut gérée plus bas si besoin
                                    style: GoogleFonts.poppins(
                                      color: textColor.withOpacity(0.7),
                                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          if (isMuted) Icon(Icons.volume_off, size: 16, color: textColor.withOpacity(0.5)),
                          if (isMuted) SizedBox(width: 8),
                          if (hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor, 
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                ),
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
      ),
    );
  }

  // Amélioration de l'indicateur de frappe
  Widget _buildTypingIndicator(Color color) {
    return SizedBox(
      height: 15, // Hauteur fixe pour éviter les sauts
      width: 30,  // Largeur fixe
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end, // Align dots at the bottom
        children: List.generate(3, (index) {
          return TypingDot(delay: Duration(milliseconds: index * 200), color: color);
        }),
      ),
    );
  }

  // ... (Autres méthodes: _deleteConversation, _formatConversationTime, etc.) ...
  
   // Méthode pour épingler/désépingler
  Future<void> _togglePinConversation(String conversationId, bool shouldPin) async {
    // TODO: Appeler l'API pour mettre à jour l'état "pinned" côté serveur
    try {
      // await _conversationService.setPinStatus(widget.userId, conversationId, shouldPin);
      
      // Mise à jour optimiste de l'UI
      setState(() {
        final index = _conversations.indexWhere((c) => c['id'] == conversationId);
        if (index != -1) {
          _conversations[index]['isPinned'] = shouldPin;
          // Trier pour mettre les épinglés en haut
          _conversations.sort((a, b) {
            final pinA = _safeGet<bool>(a, 'isPinned', false);
            final pinB = _safeGet<bool>(b, 'isPinned', false);
            if (pinA && !pinB) return -1;
            if (!pinA && pinB) return 1;
            // Trier ensuite par date
            final timeA = DateTime.tryParse(_safeGet<String>(a, 'time', '')) ?? DateTime(0);
            final timeB = DateTime.tryParse(_safeGet<String>(b, 'time', '')) ?? DateTime(0);
            return timeB.compareTo(timeA);
          });
          _filterConversationsByTab(); // Réappliquer le filtre
        }
      });
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shouldPin ? 'Conversation épinglée' : 'Conversation désépinglée')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
       // Revert UI change on error ? Or refresh from server ?
       _fetchConversations(); // Refresh to get actual state
    }
  }

  // STUB METHODS TO RESOLVE COMPILE ERRORS
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('darkMode', _isDarkMode);
  }

  Future<void> _initializeNotifications() async {
    // TODO: set up NotificationService listeners
  }

  void _openSelectedConversation() {
    // TODO: open conversation passed via selectedConversationId
  }

  void _showFilterOptions() {
    // TODO: implement filter UI
  }

  void _showNewMessageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.blue),
                  title: Text(
                    'Nouveau message',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _searchFollowers('');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_add, color: Colors.green),
                  title: Text(
                    'Créer un groupe',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupCreationScreen(
                          userId: widget.userId,
                          producerType: 'user', // Valeur par défaut pour le type de producteur
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startConversationWithUser(Map<String, dynamic> user) {
    final String userId = user['id'] ?? user['_id'] ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: ID utilisateur invalide')),
      );
      return;
    }
    
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isDarkMode ? Colors.purple[200]! : Colors.deepPurple
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Création de la conversation...',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    
    // Créer ou récupérer la conversation via le service Conversation
    _conversationService.createOrGetConversation(
      widget.userId,
      userId,
      producerType: user['type'],
    ).then((conversationResponse) {
      // Fermer le dialogue de chargement
      Navigator.pop(context);
      
      if (conversationResponse == null || 
          (conversationResponse['conversationId'] == null && 
           conversationResponse['_id'] == null && 
           conversationResponse['id'] == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Impossible de créer la conversation')),
        );
        return;
      }
      
      // Extraire l'ID de conversation quelle que soit la clé utilisée
      final String conversationId = conversationResponse['conversationId'] ?? 
                                   conversationResponse['_id'] ?? 
                                   conversationResponse['id'] ?? '';
      
      // Naviguer vers la nouvelle conversation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            userId: widget.userId,
            conversationId: conversationId,
            recipientName: user['name'] ?? 'Conversation',
            recipientAvatar: user['avatar'] ?? '',
            isProducer: user['type'] == 'restaurant' || user['type'] == 'producer',
            isGroup: false,
          ),
        ),
      ).then((_) {
        // Rafraîchir les conversations au retour
        _fetchConversations();
      });
    }).catchError((error) {
      // Fermer le dialogue de chargement en cas d'erreur
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${error.toString()}')),
      );
    });
  }

  T _safeGet<T>(Map<String, dynamic> map, String key, T defaultValue) {
    try {
      final value = map[key];
      if (value is T) return value;
    } catch (_) {}
    return defaultValue;
  }

  String _formatConversationTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(date);
    if (diff.inDays < 7) return DateFormat('E').format(date);
    return DateFormat('dd/MM').format(date);
  }

  ImageProvider? _getImageProvider(String? src) {
    if (src == null || src.isEmpty) return null;
    if (src.startsWith('http')) return NetworkImage(src);
    if (src.startsWith('data:image')) {
      final idx = src.indexOf(',');
      final bytes = base64Decode(src.substring(idx + 1));
      return MemoryImage(bytes);
    }
    return null;
  }

  void _navigateToProfile(String id, String type) {
    if (id.isEmpty) return;
    
    // Choisir l'écran approprié en fonction du type de producteur/utilisateur
    Widget profileScreen;
    
    switch (type.toLowerCase()) {
      case 'restaurant':
      case 'producer':
        profileScreen = ProducerScreen(
          producerId: id, 
          userId: widget.userId,
        );
        break;
      case 'leisure':
      case 'leisureproducer':
        profileScreen = ProducerLeisureScreen(
          producerId: id,
          userId: widget.userId,
        );
        break;
      case 'wellness':
      case 'wellnessproducer':
        profileScreen = WellnessProducerProfileScreen(
          producerId: id,
          userId: widget.userId,
        );
        break;
      case 'user':
      default:
        profileScreen = ProfileScreen(
          userId: id,
          viewMode: id == widget.userId ? 'private' : 'public', 
        );
        break;
    }
    
    // Naviguer vers l'écran de profil
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => profileScreen),
    );
  }

  void _navigateToConversationDetail(Map<String, dynamic> conversation) {
    final conversationId = _safeGet<String>(conversation, 'id', '');
    if (conversationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: ID de conversation invalide')),
      );
      return;
    }
    
    // Marquer comme lu localement (optimistic update)
    setState(() {
      final index = _conversations.indexWhere((c) => c['id'] == conversationId);
      if (index != -1) {
        _conversations[index]['unreadCount'] = 0;
        _filterConversationsByTab();
      }
    });
    
    // Naviguer vers l'écran de détail
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailScreen(
          userId: widget.userId,
          conversationId: conversationId,
          recipientName: _safeGet<String>(conversation, 'name', 'Conversation'),
          recipientAvatar: _safeGet<String>(conversation, 'avatar', ''),
          isProducer: _safeGet<bool>(conversation, 'isProducer', false),
          isGroup: _safeGet<bool>(conversation, 'isGroup', false),
          participants: _safeGet<List<dynamic>>(conversation, 'participants', []),
        ),
      ),
    ).then((_) {
      // Rafraîchir les conversations au retour
      _fetchConversations();
    });
  }

  Future<void> _deleteConversation(String id) async {
    // TODO: delete conversation logic
  }
}

// Widget séparé pour l'animation du point de frappe
class TypingDot extends StatefulWidget {
  final Duration delay;
  final Color color;
  const TypingDot({Key? key, required this.delay, required this.color}) : super(key: key);

  @override
  _TypingDotState createState() => _TypingDotState();
}

class _TypingDotState extends State<TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..addStatusListener((status) {
       if (status == AnimationStatus.completed) {
         Future.delayed(widget.delay, () {
           if (mounted) _controller.reverse();
         });
       } else if (status == AnimationStatus.dismissed) {
         Future.delayed(widget.delay, () {
            if (mounted) _controller.forward();
         });
       }
      });

    _animation = Tween<double>(begin: 0, end: 5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 6, height: 6,
          margin: EdgeInsets.only(bottom: _animation.value), // Move dot up and down
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

