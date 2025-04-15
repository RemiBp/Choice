import 'dart:async';
import 'dart:convert';
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
                          // Tous les messages
                          _buildConversationList(_displayedConversations, primaryColor, bgColor, textColor),
                          
                          // Messages des restaurants
                          _buildConversationList(
                            _displayedConversations.where((c) => c['isRestaurant'] == true).toList(), 
                            primaryColor, 
                            bgColor, 
                            textColor,
                          ),
                          
                          // Messages des loisirs
                          _buildConversationList(
                            _displayedConversations.where((c) => c['isLeisure'] == true).toList(), 
                            primaryColor, 
                            bgColor, 
                            textColor,
                          ),
                          
                          // Groupes
                          _buildConversationList(
                            _displayedConversations.where((c) => c['isGroup'] == true).toList(), 
                            primaryColor, 
                            bgColor, 
                            textColor,
                          ),
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
  
  // Afficher les options de filtre avec animation et design moderne
  void _showFilterOptions() {
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    final Color primaryColor = _isDarkMode ? Colors.purple[200]! : Colors.deepPurple;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1.0,
        child: Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.6,
            expand: false,
            builder: (context, scrollController) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicateur de glissement
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Filtrer les conversations',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildFilterOption(
                        title: 'Tous les messages',
                        icon: Icons.chat,
                        isSelected: _tabController.index == 0,
                        onTap: () {
                          _tabController.animateTo(0);
                          Navigator.pop(context);
                        },
                        primaryColor: primaryColor,
                        textColor: textColor,
                      ),
                      _buildFilterOption(
                        title: 'Restaurants uniquement',
                        icon: Icons.restaurant,
                        isSelected: _tabController.index == 1,
                        onTap: () {
                          _tabController.animateTo(1);
                          Navigator.pop(context);
                        },
                        primaryColor: primaryColor,
                        textColor: textColor,
                      ),
                      _buildFilterOption(
                        title: 'Loisirs uniquement',
                        icon: Icons.local_activity,
                        isSelected: _tabController.index == 2,
                        onTap: () {
                          _tabController.animateTo(2);
                          Navigator.pop(context);
                        },
                        primaryColor: primaryColor,
                        textColor: textColor,
                      ),
                      _buildFilterOption(
                        title: 'Groupes uniquement',
                        icon: Icons.group,
                        isSelected: _tabController.index == 3,
                        onTap: () {
                          _tabController.animateTo(3);
                          Navigator.pop(context);
                        },
                        primaryColor: primaryColor,
                        textColor: textColor,
                      ),
                      _buildFilterOption(
                        title: 'Messages non lus',
                        icon: Icons.mark_email_unread,
                        isSelected: false,
                        onTap: () {
                          Navigator.pop(context);
                          // Filtrer les messages non lus
                          setState(() {
                            _displayedConversations = _conversations
                                .where((conv) => (conv['unreadCount'] ?? 0) > 0)
                                .toList();
                          });
                        },
                        primaryColor: primaryColor,
                        textColor: textColor,
                      ),
                      _buildFilterOption(
                        title: 'Messages récents',
                        icon: Icons.access_time,
                        isSelected: false,
                        onTap: () {
                          Navigator.pop(context);
                          // Filtrer par ordre chronologique inversé
                          setState(() {
                            _displayedConversations = List.from(_conversations)
                              ..sort((a, b) {
                                final aTime = DateTime.parse(a['time']);
                                final bTime = DateTime.parse(b['time']);
                                return bTime.compareTo(aTime);
                              });
                          });
                        },
                        primaryColor: primaryColor,
                        textColor: textColor,
                      ),
                      _buildFilterOption(
                        title: 'Effacer tous les filtres',
                        icon: Icons.clear_all,
                        isSelected: false,
                        onTap: () {
                          Navigator.pop(context);
                          _fetchConversations();
                        },
                        primaryColor: primaryColor,
                        textColor: textColor,
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
  
  // Construire une option de filtre avec animation au survol
  Widget _buildFilterOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color textColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? primaryColor : textColor.withOpacity(0.6),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primaryColor : textColor,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: primaryColor)
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  // Afficher les options pour nouveau message avec une interface moderne
  void _showNewMessageOptions() {
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1.0,
        child: Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Nouvelle conversation',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
              ),
              _buildNewMessageOption(
                icon: Icons.person,
                color: Colors.blue,
                title: 'Message individuel',
                subtitle: 'Envoyer un message à une personne',
                onTap: () {
                  Navigator.pop(context);
                  _showNewMessageDialog();
                },
                bgColor: bgColor,
                textColor: textColor,
              ),
              _buildNewMessageOption(
                icon: Icons.group,
                color: Colors.amber,
                title: 'Créer un groupe',
                subtitle: 'Nouvelle conversation de groupe',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToGroupCreation();
                },
                bgColor: bgColor,
                textColor: textColor,
              ),
              _buildNewMessageOption(
                icon: Icons.restaurant,
                color: Colors.orange,
                title: 'Contacter un restaurant',
                subtitle: 'Rechercher parmi les restaurants',
                onTap: () {
                  Navigator.pop(context);
                  _showNewMessageDialogWithFilter('restaurant');
                },
                bgColor: bgColor,
                textColor: textColor,
              ),
              _buildNewMessageOption(
                icon: Icons.local_activity,
                color: Colors.purple,
                title: 'Contacter un lieu de loisir',
                subtitle: 'Rechercher parmi les lieux de loisir',
                onTap: () {
                  Navigator.pop(context);
                  _showNewMessageDialogWithFilter('leisure');
                },
                bgColor: bgColor,
                textColor: textColor,
              ),
              _buildNewMessageOption(
                icon: Icons.spa,
                color: Colors.teal,
                title: 'Contacter un lieu de bien-être',
                subtitle: 'Rechercher parmi les lieux de bien-être',
                onTap: () {
                  Navigator.pop(context);
                  _showNewMessageDialogWithFilter('wellness');
                },
                bgColor: bgColor,
                textColor: textColor,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  // Construire une option pour le menu de nouveau message
  Widget _buildNewMessageOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color bgColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.8),
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: color,
            size: 16,
          ),
        ),
      ),
    );
  }
  
  // Chercher et afficher un nouveau dialogue de message avec filtre par type
  void _showNewMessageDialogWithFilter(String type) async {
    _showNewMessageDialog(filterType: type);
  }
  
  // Navigation vers la création de groupe
  void _navigateToGroupCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCreationScreen(
          userId: widget.userId,
          producerType: 'general',
        ),
      ),
    ).then((_) => _fetchConversations());
  }
  
  // Construction de la liste des conversations avec animations
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
          physics: const AlwaysScrollableScrollPhysics(),
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
  
  // Helper function to safely get a value as a specific type
  T _safeGet<T>(Map<String, dynamic> map, String key, T defaultValue) {
    try {
      final value = map[key];
      if (value is T) {
        return value;
      }
      // Attempt type conversion for common cases
      if (T == int && value is num) {
        return value.toInt() as T;
      }
      if (T == double && value is num) {
        return value.toDouble() as T;
      }
      if (T == String && value != null) {
        return value.toString() as T;
      }
      if (T == bool && value is int) {
        return (value == 1) as T;
      }
      if (T == bool && value is String) {
        return (value.toLowerCase() == 'true' || value == '1') as T;
      }
    } catch (e) {
      print("⚠️ Error safely getting key '$key': $e. Using default: $defaultValue");
    }
    return defaultValue;
  }

  // Construction d'une tuile de conversation avec design moderne
  Widget _buildConversationTile(Map<String, dynamic> conversation, Color primaryColor, Color bgColor, Color textColor) {
    // --- Safe Data Access ---
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

    // Formatage du temps avec try-catch
    String formattedTime = '';
    try {
      if (timeString.isNotEmpty) {
        final DateTime time = DateTime.parse(timeString);
        formattedTime = _formatConversationTime(time);
      }
    } catch (e) {
      print("⚠️ Error parsing conversation time '$timeString': $e");
      formattedTime = '--:--'; // Default value on error
    }

    // Avatar par défaut si l'URL est invalide ou vide
    final String defaultAvatarName = name.isNotEmpty && name != 'Conversation' && name != 'Utilisateur' 
        ? name 
        : '??';
    final String finalAvatarUrl = (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
        ? avatarUrl
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(defaultAvatarName)}&background=random&size=128'; // Use defaultAvatarName

    // Déterminer les couleurs spécifiques à ce type de conversation
    final Color typeColor = isRestaurant
        ? Colors.amber
        : isLeisure
            ? Colors.purple
            : isGroup
                ? Colors.teal
                : primaryColor;

    // Vérifier si quelqu'un est en train d'écrire
    final bool isTyping = _typingStatus[conversationId] ?? false;

    // Utiliser conversationId pour la clé et le tag Hero
    final String heroTag = 'avatar_$conversationId';
    final Key dismissibleKey = Key('conversation_$conversationId');

    // Get other participant info (added in ConversationService)
    final String otherParticipantId = _safeGet<String>(conversation, 'otherParticipantId', '');
    final String participantType = _safeGet<String>(conversation, 'participantType', 'user');

    return Dismissible(
      key: dismissibleKey,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
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
      },
      onDismissed: (direction) {
        // Supprimer la conversation
        _deleteConversation(conversationId); // Use safe ID
      },
      child: InkWell(
        onTap: () => _navigateToConversationDetail(conversation),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hasUnread
                ? (_isDarkMode ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.05))
                : bgColor,
            border: Border(
              bottom: BorderSide(
                color: _isDarkMode ? Colors.grey[900]! : Colors.grey[200]!,
                width: 0.5
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Wrap avatar Stack in GestureDetector for profile navigation
              GestureDetector(
                onTap: () {
                   // Only navigate to profile if it's NOT a group chat
                   if (!isGroup && otherParticipantId.isNotEmpty) {
                     _navigateToProfile(otherParticipantId, participantType);
                   }
                },
                child: Stack(
                  children: [
                    Hero(
                      tag: heroTag, 
                      child: CachedNetworkImage( 
                        imageUrl: finalAvatarUrl,
                        imageBuilder: (context, imageProvider) => CircleAvatar(
                          radius: 28,
                          backgroundImage: imageProvider,
                          child: isGroup && finalAvatarUrl.contains('ui-avatars.com')
                              ? Icon(Icons.group, color: Colors.white.withOpacity(0.8), size: 24)
                              : null,
                        ),
                        placeholder: (context, url) => CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey[300],
                          child: Icon(Icons.person, color: Colors.grey[600]),
                        ),
                        errorWidget: (context, url, error) {
                          print("⚠️ Error widget triggered for avatar: $url, error: $error");
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey[300],
                            child: Icon(Icons.broken_image, color: Colors.grey[600]), 
                          );
                        },
                      ),
                    ),
                    // Indicateur de type (condition seems complex, keep as is for now)
                    if ((isRestaurant || isLeisure || isGroup) && !isGroup && !isRestaurant && !isLeisure)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: typeColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 2),
                          ),
                          child: Icon(
                            isRestaurant ? Icons.restaurant : isLeisure ? Icons.local_activity : Icons.group,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    // Indicateur en ligne
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green, // Consider making this dynamic based on presence
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Détails de la conversation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nom
                        Expanded(
                          child: Text(
                            name, // Use safe name
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 16,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Heure
                        Text(
                          formattedTime, // Use safe formatted time
                          style: TextStyle(
                            color: hasUnread ? primaryColor : textColor.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Dernier message ou indicateur de frappe
                    Row(
                      children: [
                        // Icône de statut de message
                        if (!isTyping && lastMessage.isNotEmpty) // Check if last message exists
                          Icon(
                            hasUnread
                                ? Icons.mark_chat_unread
                                : Icons.check_circle, // Consider adding sent/delivered status
                            size: 14,
                            color: hasUnread ? primaryColor : Colors.grey,
                          ),

                        // Indicateur de frappe
                        if (isTyping)
                          Row(
                            children: [
                              Text(
                                "En train d'écrire",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildTypingIndicator(primaryColor),
                            ],
                          )
                        else if (lastMessage.isNotEmpty) // Only show last message if it exists
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                lastMessage, // Use safe last message
                                style: TextStyle(
                                  color: hasUnread ? textColor : textColor.withOpacity(0.6),
                                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(), // Use safe unread count
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
    );
  }
  
  // Animation d'indicateur de frappe
  Widget _buildTypingIndicator(Color color) {
    return SizedBox(
      width: 40,
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + (index * 200)),
              curve: Curves.easeInOut,
              builder: (context, double value, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 6 * value,
                  width: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
  
  // Supprimer une conversation
  Future<void> _deleteConversation(String conversationId) async {
    try {
      // Animation de suppression optimiste
      setState(() {
        _conversations.removeWhere((c) => c['id'] == conversationId);
        _filterConversationsByTab();
      });
      
      // Appel au service pour supprimer la conversation
      await _conversationService.deleteConversation(widget.userId, conversationId);
      
      // Notification de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Conversation supprimée'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // Récupérer en cas d'erreur en rechargeant les conversations
      _fetchConversations();
      
      // Notification d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
  
  // Formatage du temps de conversation
  String _formatConversationTime(DateTime time) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24 && now.day == time.day) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays < 7) {
      return DateFormat('E').format(time); // Jour de la semaine abrégé
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }
  
  // Démarrer une conversation avec un follower/ami
  void _startConversationWithUser(Map<String, dynamic> user) {
    _startConversation(Contact(
      id: user['id'],
      name: user['name'],
      avatar: user['avatar'],
      producerType: user['type'] == 'restaurant' || user['type'] == 'leisure' || user['type'] == 'wellness' ? user['type'] : null,
    ));
  }
  
  // Créer une nouvelle conversation avec un utilisateur
  Future<void> _startConversation(Contact contact) async {
    try {
      if (contact == null || contact.id == null || contact.id!.isEmpty) {
        print("❌ Impossible de démarrer une conversation: contact ou ID du contact invalide");
        return;
      }
      
      print("🔍 Démarrage conversation avec contact: ${contact.name} (ID: ${contact.id})");
      
      final result = await _conversationService.createOrGetConversation(
        widget.userId,
        contact.id!,
      );
      
      print("📦 Résultat création conversation: $result");
      
      // Récupérer l'ID de conversation, en vérifiant les différentes clés possibles
      final conversationId = result['conversationId'] ?? 
                             result['conversation_id'] ?? 
                             result['_id'];
      
      if (conversationId == null || conversationId.isEmpty) {
        print("❌ Impossible de récupérer l'ID de conversation dans la réponse");
        return;
      }
      
      print("✅ Conversation créée avec ID: $conversationId");
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            conversationId: conversationId,
            userId: widget.userId,
            recipientName: contact.name ?? "Contact",
            recipientAvatar: contact.avatar ?? "https://via.placeholder.com/150",
            isGroup: false,
          ),
        ),
      );
    } catch (e) {
      print("❌ Erreur lors du démarrage de la conversation: $e");
      // Afficher une notification d'erreur à l'utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la création de la conversation: $e")),
      );
    }
  }
  
  // Naviguer vers les détails de la conversation
  void _navigateToConversationDetail(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailScreen(
          conversationId: conversation['id'],
          recipientName: conversation['name'],
          recipientAvatar: conversation['avatar'],
          userId: widget.userId,
          isProducer: conversation['isRestaurant'] || conversation['isLeisure'],
          isGroup: conversation['isGroup'] ?? false,
        ),
      ),
    ).then((_) => _fetchConversations()); // Rafraîchir les conversations après le retour
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('darkMode', _isDarkMode);
  }

  Future<void> _initializeNotifications() async {
    // Écouter les notifications entrantes pour les messages
    _notificationService.onNotificationClick.listen((notification) {
      final payload = notification.payload;
      if (payload != null) {
        try {
          final data = json.decode(payload);
          if (data['type'] == 'message' && data['conversationId'] != null) {
            _navigateToConversationById(data['conversationId'], 
                                        data['senderName'] ?? 'Contact',
                                        data['senderAvatar'] ?? '');
          }
        } catch (e) {
          print('Erreur lors du traitement de la notification: $e');
        }
      }
    });
    
    // Effacer les badges
    await _notificationService.clearBadge();
  }

  void _navigateToConversationById(String conversationId, String name, String avatar) {
    // Chercher d'abord si la conversation existe dans notre liste
    final conversation = _conversations.firstWhere(
      (c) => c['id'] == conversationId, 
      orElse: () => {
        'id': conversationId,
        'name': name,
        'avatar': avatar,
        'isGroup': false,
        'isRestaurant': false,
        'isLeisure': false,
      },
    );
    
    _navigateToConversationDetail(conversation);
  }

  // Afficher le dialogue de création de nouveau message
  void _showNewMessageDialog({String filterType = ''}) {
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    final Color primaryColor = _isDarkMode ? Colors.purple[200]! : Colors.deepPurple;
    
    // Variables pour la gestion d'état interne
    List<Map<String, dynamic>> searchResults = [];
    String currentFilter = filterType;
    bool isLoading = false;
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          // Fonction pour effectuer la recherche
          Future<void> performSearch(String query) async {
            if (query.length < 2) {
              setState(() {
                searchResults = [];
                isLoading = false;
              });
              return;
            }
            
            setState(() {
              isLoading = true;
              searchQuery = query;
            });
            
            try {
              // Use the appropriate search methods based on filter type
              List<Map<String, dynamic>> results = [];
              
              switch(currentFilter) {
                case 'user':
                  results = await _conversationService.searchUsers(query);
                  break;
                case 'restaurant':
                  results = await _conversationService.searchProducersByType(query, 'restaurant');
                  break;
                case 'leisure':
                  results = await _conversationService.searchProducersByType(query, 'leisureProducer');
                  break;
                case 'wellness':
                  results = await _conversationService.searchProducersByType(query, 'wellnessProducer');
                  break;
                default:
                  // If no specific filter, use the unified search endpoint
                  results = await _conversationService.searchAll(query);
              }
              
              // Filter out results with missing IDs to prevent errors
              results = results.where((result) => 
                result['id'] != null && result['id'].toString().isNotEmpty
              ).toList();
              
              setState(() {
                searchResults = results;
                isLoading = false;
              });
            } catch (e) {
              setState(() {
                isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur de recherche: $e'),
                  behavior: SnackBarBehavior.floating,
                )
              );
            }
          }
          
          // Démarrer une conversation avec un utilisateur
          void startConversation(Map<String, dynamic> contact) async {
            try {
              Navigator.pop(context); // Fermer le modal
              
              // Afficher un indicateur de chargement
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(width: 16),
                      Text('Création de la conversation...')
                    ],
                  ),
                  duration: Duration(seconds: 2),
                )
              );
              
              // Créer la conversation
              final result = await _conversationService.createOrGetConversation(
                widget.userId,
                contact['id']
              );
              
              // Naviguer vers la conversation
              if (result != null && (result['conversationId'] != null || result['_id'] != null)) {
                final conversationId = result['conversationId'] ?? result['_id'] ?? result['conversation_id'];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversationDetailScreen(
                      conversationId: conversationId,
                      recipientName: contact['name'],
                      recipientAvatar: contact['avatar'] ?? 'https://via.placeholder.com/150',
                      userId: widget.userId,
                      isProducer: contact['type'] == 'restaurant' || 
                                contact['type'] == 'leisureProducer' ||
                                contact['type'] == 'wellnessProducer' ||
                                contact['type'] == 'beautyPlace',
                    ),
                  ),
                ).then((_) => _fetchConversations());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Impossible de créer la conversation. Réponse du serveur incomplète.'),
                    backgroundColor: Colors.red,
                  )
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: $e'),
                  backgroundColor: Colors.red,
                )
              );
            }
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Indicateur de glissement
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Nouvelle conversation',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                
                // Champ de recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un contact...',
                      prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.7)),
                      filled: true,
                      fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) {
                      performSearch(value);
                    },
                  ),
                ),
                
                // Catégories de contacts (Tous, Amis, Restaurants, Loisirs, Bien-être)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildContactTypeChip('Tous', currentFilter == '', (selected) {
                        setState(() {
                          currentFilter = '';
                          if (searchQuery.isNotEmpty) performSearch(searchQuery);
                        });
                      }),
                      SizedBox(width: 8),
                      _buildContactTypeChip('Amis', currentFilter == 'user', (selected) {
                        setState(() {
                          currentFilter = 'user';
                          if (searchQuery.isNotEmpty) performSearch(searchQuery);
                        });
                      }),
                      SizedBox(width: 8),
                      _buildContactTypeChip('Restaurants', currentFilter == 'restaurant', (selected) {
                        setState(() {
                          currentFilter = 'restaurant';
                          if (searchQuery.isNotEmpty) performSearch(searchQuery);
                        });
                      }),
                      SizedBox(width: 8),
                      _buildContactTypeChip('Loisirs', currentFilter == 'leisure', (selected) {
                        setState(() {
                          currentFilter = 'leisure';
                          if (searchQuery.isNotEmpty) performSearch(searchQuery);
                        });
                      }),
                      SizedBox(width: 8),
                      _buildContactTypeChip('Bien-être', currentFilter == 'wellness', (selected) {
                        setState(() {
                          currentFilter = 'wellness';
                          if (searchQuery.isNotEmpty) performSearch(searchQuery);
                        });
                      }),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Indicateur de chargement
                if (isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                
                // Liste des résultats de recherche
                Expanded(
                  child: searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Recherchez des contacts',
                              style: TextStyle(color: textColor.withOpacity(0.7)),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tapez au moins 2 caractères pour rechercher',
                              style: TextStyle(
                                color: textColor.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final contact = searchResults[index];
                          final contactType = contact['type'] ?? '';
                          
                          // Icône en fonction du type
                          IconData typeIcon;
                          Color typeColor;
                          
                          switch (contactType) {
                            case 'restaurant':
                              typeIcon = Icons.restaurant;
                              typeColor = Colors.amber;
                              break;
                            case 'leisureProducer':
                              typeIcon = Icons.local_activity;
                              typeColor = Colors.purple;
                              break;
                            case 'wellnessProducer':
                            case 'beautyPlace':
                              typeIcon = Icons.spa;
                              typeColor = Colors.teal;
                              break;
                            default:
                              typeIcon = Icons.person;
                              typeColor = Colors.blue;
                          }
                          
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(
                                    contact['avatar'] ?? 'https://via.placeholder.com/150',
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: typeColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: bgColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      typeIcon,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              contact['name'] ?? 'Contact',
                              style: TextStyle(color: textColor),
                            ),
                            subtitle: Text(
                              contact['category'] ?? _getContactCategory(contactType),
                              style: TextStyle(color: textColor.withOpacity(0.7)),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => startConversation(contact),
                              child: Text('Message'),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildContactTypeChip(String label, bool isSelected, Function(bool) onTap) {
    final Color primaryColor = _isDarkMode ? Colors.purple[200]! : Colors.deepPurple;
    
    return GestureDetector(
      onTap: () => onTap(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _isDarkMode ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Helper pour obtenir la catégorie à afficher dans l'interface
  String _getContactCategory(String type) {
    switch (type) {
      case 'user':
        return 'Utilisateur';
      case 'restaurant':
        return 'Restaurant';
      case 'leisureProducer':
        return 'Loisir';
      case 'wellnessProducer':
        return 'Bien-être';
      case 'beautyPlace':
        return 'Beauté';
      case 'event':
        return 'Événement';
      default:
        return 'Contact';
    }
  }

  // Méthode pour ouvrir la conversation sélectionnée
  void _openSelectedConversation() {
    if (widget.selectedConversationId == null) return;
    
    // Rechercher la conversation dans la liste
    final selectedConversation = _conversations.firstWhere(
      (conv) => conv['id'] == widget.selectedConversationId,
      orElse: () => {},
    );
    
    if (selectedConversation.isNotEmpty) {
      _openConversation(selectedConversation);
    }
  }
  
  // Méthode pour ouvrir une conversation en détail
  void _openConversation(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailScreen(
          conversationId: conversation['id'],
          recipientName: conversation['name'],
          recipientAvatar: conversation['avatar'],
          isGroup: conversation['isGroup'] == true,
          userId: widget.userId,
        ),
      ),
    );
  }

  // ---- Navigation Logic ----
  Future<void> _navigateToProfile(String participantId, String participantType) async {
    if (participantId.isEmpty) return;

    // Type is already determined by participantType parameter
    final String resolvedType = participantType;

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
        // Adjust API endpoint as needed (using unified/ID or specific beauty endpoint)
        final url = Uri.parse('${ApiConfig.baseUrl}/api/unified/$participantId'); 
        final response = await http.get(url);
         Navigator.pop(context); // Close loading dialog
        if (response.statusCode == 200) {
            final data = json.decode(response.body);
            // Pass the full data map to WellnessProducerProfileScreen
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
}
