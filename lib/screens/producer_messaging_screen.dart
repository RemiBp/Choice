import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/conversation_service.dart';
import 'conversation_detail_screen.dart';
import 'group_creation_screen.dart';
import 'profile_screen.dart';
import 'producer_screen.dart'; 
import 'producerLeisure_screen.dart';
import 'dart:convert';
import 'dart:ui';
import '../models/contact.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProducerMessagingScreen extends StatefulWidget {
  final String producerId;
  final String producerType; // 'restaurant', 'leisureProducer', 'wellnessProducer'
  
  const ProducerMessagingScreen({
    Key? key, 
    required this.producerId,
    required this.producerType, 
  }) : super(key: key);

  @override
  _ProducerMessagingScreenState createState() => _ProducerMessagingScreenState();
}

class _ProducerMessagingScreenState extends State<ProducerMessagingScreen> with SingleTickerProviderStateMixin {
  final ConversationService _conversationService = ConversationService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  List<Map<String, dynamic>> _searchResults = [];
  
  // Catégories de conversations
  List<Map<String, dynamic>> _userConversations = [];
  List<Map<String, dynamic>> _sameTypeProducerConversations = [];
  List<Map<String, dynamic>> _restaurantProducerConversations = [];
  List<Map<String, dynamic>> _leisureProducerConversations = [];
  List<Map<String, dynamic>> _wellnessProducerConversations = [];
  
  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showSearchInterface = false;
  
  late TabController _tabController;
  
  // Couleurs pour les types d'utilisateurs/producteurs
  final Map<String, Color> _userTypeColors = {
    'user': Colors.blue,
    'restaurant': Colors.orange,
    'leisureProducer': Colors.purple,
    'wellnessProducer': Colors.green,
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadConversations();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    // Reset search interface when tab changes
    if (_showSearchInterface) {
      setState(() {
        _showSearchInterface = false;
        _searchResults = [];
        _searchController.clear();
      });
    }
  }
  
  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      print('🔄 Chargement des conversations pour producteur ${widget.producerId} (type: ${widget.producerType})');
      
      final conversations = await _conversationService.getProducerConversations(
        widget.producerId,
        widget.producerType,
      );
      
      print('✅ ${conversations.length} conversations récupérées avec succès');
      
      // Si aucune conversation n'est récupérée, ne pas considérer comme une erreur
      if (conversations.isEmpty) {
        print('ℹ️ Aucune conversation trouvée pour ce producteur');
      }
      
      // Trier les conversations par catégories
      _categorizeConversations(conversations);
      
      setState(() {
        _conversations = conversations;
        _filteredConversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur lors du chargement des conversations: $e');
      
      // Message d'erreur plus user-friendly selon le type d'erreur
      String errorMsg = 'Une erreur est survenue lors du chargement de vos conversations.';
      
      if (e.toString().contains('timeout') || e.toString().contains("délai d'attente")) {
        errorMsg = 'Impossible de se connecter au serveur. Vérifiez votre connexion internet et réessayez.';
      } else if (e.toString().contains('404')) {
        errorMsg = 'Le service de messagerie est temporairement indisponible. Veuillez réessayer plus tard.';
      } else if (e.toString().contains('500')) {
        errorMsg = 'Une erreur serveur est survenue. Notre équipe technique a été notifiée.';
      }
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = errorMsg;
        
        // Même en cas d'erreur, initialiser des listes vides pour éviter les null checks
        _conversations = [];
        _filteredConversations = [];
        _userConversations = [];
        _sameTypeProducerConversations = [];
        _restaurantProducerConversations = [];
        _leisureProducerConversations = [];
        _wellnessProducerConversations = [];
      });
    }
  }
  
  void _categorizeConversations(List<Map<String, dynamic>> conversations) {
    // Réinitialiser toutes les listes
    _userConversations = [];
    _sameTypeProducerConversations = [];
    _restaurantProducerConversations = [];
    _leisureProducerConversations = [];
    _wellnessProducerConversations = [];
    
    for (var conversation in conversations) {
      if (conversation['isGroup'] == true) {
        // Les groupes sont inclus dans toutes les conversations mais pas catégorisés
        continue;
      }
      
      // Utilisateurs réguliers
      if (conversation['isUser'] == true) {
        _userConversations.add(conversation);
      }
      // Conversations avec des producteurs du même type
      else if ((widget.producerType == 'restaurant' && conversation['isRestaurant'] == true) ||
               (widget.producerType == 'leisureProducer' && conversation['isLeisure'] == true) ||
               (widget.producerType == 'wellnessProducer' && conversation['isWellness'] == true)) {
        _sameTypeProducerConversations.add(conversation);
      }
      // Restaurants
      else if (conversation['isRestaurant'] == true) {
        _restaurantProducerConversations.add(conversation);
      }
      // Loisirs
      else if (conversation['isLeisure'] == true) {
        _leisureProducerConversations.add(conversation);
      }
      // Bien-être
      else if (conversation['isWellness'] == true) {
        _wellnessProducerConversations.add(conversation);
      }
    }
  }
  
  void _searchConversations(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredConversations = _conversations;
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _filteredConversations = _conversations.where((conversation) {
        return conversation['name'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
      _isSearching = true;
    });
  }
  
  Future<void> _searchContacts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      List<Map<String, dynamic>> results = [];
      // Selon l'onglet actif, nous filtrons différemment
      switch (_tabController.index) {
        case 1: // Onglet Clients (Utilisateurs)
          results = await _conversationService.searchUsers(query);
          break;
        case 2: // Onglet Producteurs du même type
          results = await _conversationService.searchProducersByType(
            query, 
            widget.producerType
          );
          break;
        case 3: // Onglet Restaurants
          results = await _conversationService.searchProducersByType(
            query, 
            'restaurant'
          );
          break;
        case 4: // Onglet Loisirs
          results = await _conversationService.searchProducersByType(
            query, 
            'leisureProducer'
          );
          break;
        case 5: // Onglet Bien-être
          results = await _conversationService.searchProducersByType(
            query, 
            'wellnessProducer'
          );
          break;
        default: // Onglet Toutes (recherche globale)
          results = await _conversationService.searchAll(query);
          break;
      }
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _hasError = true;
        _errorMessage = 'Erreur de recherche: $e';
      });
    }
  }
  
  void _navigateToConversation(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailScreen(
          conversationId: conversation['id'],
          recipientName: conversation['name'],
          recipientAvatar: conversation['avatar'],
          userId: widget.producerId,
          isProducer: conversation['isRestaurant'] || conversation['isLeisure'] || conversation['isWellness'],
          isGroup: conversation['isGroup'],
        ),
      ),
    ).then((_) => _loadConversations());
  }
  
  Future<void> _createOrGetConversation(Map<String, dynamic> user) async {
    // Utiliser directement la méthode _startConversation qui a été améliorée
    _startConversation(Contact(
      id: user['id'],
      name: user['name'],
      avatar: user['avatar'],
      type: user['type'],
    ));
  }
  
  void _navigateToGroupCreation() {
    print('🔍 ProducerMessagingScreen: Navigation vers la création de groupe');
    print('🔍 ProducerMessagingScreen: ID Producteur: ${widget.producerId}, Type: ${widget.producerType}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCreationScreen(
          userId: widget.producerId,
          producerType: widget.producerType,
        ),
      ),
    ).then((_) {
      // Recharger les conversations au retour
      _loadConversations();
    });
  }
  
  void _navigateToProfile(String userId, String type) {
    if (type == 'restaurant' || type == 'wellnessProducer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerScreen(
            producerId: userId,
          ),
        ),
      );
    } else if (type == 'leisureProducer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerLeisureScreen(
            producerId: userId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: userId),
        ),
      );
    }
  }
  
  String _formatDate(String dateString) {
    final dateTime = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE', 'fr_FR').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
  
  Color _getProducerColor() {
    switch (widget.producerType) {
      case 'restaurant':
        return Colors.orange;
      case 'leisureProducer':
        return Colors.purple;
      case 'wellnessProducer':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
  
  IconData _getProducerIcon() {
    switch (widget.producerType) {
      case 'restaurant':
        return Icons.restaurant;
      case 'leisureProducer':
        return Icons.event;
      case 'wellnessProducer':
        return Icons.spa;
      default:
        return Icons.business;
    }
  }
  
  String _getProducerTitle() {
    switch (widget.producerType) {
      case 'restaurant':
        return 'Messages Restaurant';
      case 'leisureProducer':
        return 'Messages Loisirs';
      case 'wellnessProducer':
        return 'Messages Bien-être';
      default:
        return 'Messages';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = _getProducerColor();
    
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(_getProducerIcon(), color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                _getProducerTitle(),
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            isScrollable: true,
            tabs: [
              Tab(text: 'Toutes'),
              Tab(text: 'Clients'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getProducerIcon(), size: 16),
                    const SizedBox(width: 4),
                    const Text('Même type'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    const Text('Restaurants'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.purple),
                    const SizedBox(width: 4),
                    const Text('Loisirs'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.spa, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Bien-être'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.group_add, color: Colors.grey),
              onPressed: _navigateToGroupCreation,
              tooltip: 'Créer un groupe',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: _loadConversations,
              tooltip: 'Actualiser',
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab Toutes les conversations
            _showSearchInterface && _tabController.index == 0
                ? _buildSearchInterfaceForCurrentTab()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? _buildErrorView()
                        : _buildConversationsTab(_filteredConversations),
            
            // Tab Clients (utilisateurs)
            _showSearchInterface && _tabController.index == 1
                ? _buildSearchInterfaceForCurrentTab()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? _buildErrorView()
                        : _buildConversationsTab(_userConversations),
            
            // Tab Producteurs du même type
            _showSearchInterface && _tabController.index == 2
                ? _buildSearchInterfaceForCurrentTab()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? _buildErrorView()
                        : _buildConversationsTab(_sameTypeProducerConversations),
            
            // Tab Restaurants
            _showSearchInterface && _tabController.index == 3
                ? _buildSearchInterfaceForCurrentTab()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? _buildErrorView()
                        : _buildConversationsTab(_restaurantProducerConversations),
            
            // Tab Loisirs
            _showSearchInterface && _tabController.index == 4
                ? _buildSearchInterfaceForCurrentTab()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? _buildErrorView()
                        : _buildConversationsTab(_leisureProducerConversations),
            
            // Tab Bien-être
            _showSearchInterface && _tabController.index == 5
                ? _buildSearchInterfaceForCurrentTab()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? _buildErrorView()
                        : _buildConversationsTab(_wellnessProducerConversations),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _showSearchInterface = !_showSearchInterface;
              if (!_showSearchInterface) {
                _searchResults = [];
                _searchController.clear();
              }
            });
          },
          backgroundColor: primaryColor,
          child: Icon(_showSearchInterface ? Icons.close : Icons.search),
        ),
      ),
    );
  }
  
  Widget _buildSearchInterfaceForCurrentTab() {
    String hintText = 'Rechercher';
    IconData iconData = Icons.search;
    
    // Personnaliser le texte et l'icône selon l'onglet actif
    switch (_tabController.index) {
      case 1:
        hintText = 'Rechercher des clients';
        iconData = Icons.person;
        break;
      case 2:
        hintText = 'Rechercher des ${_getProducerTypeLabel()}';
        iconData = _getProducerIcon();
        break;
      case 3:
        hintText = 'Rechercher des restaurants';
        iconData = Icons.restaurant;
        break;
      case 4:
        hintText = 'Rechercher des loisirs';
        iconData = Icons.event;
        break;
      case 5:
        hintText = 'Rechercher des bien-être';
        iconData = Icons.spa;
        break;
      default:
        hintText = 'Rechercher tous types de contacts';
        iconData = Icons.search;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _searchContacts,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(iconData, color: _getProducerColor()),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _searchContacts('');
                    },
                  )
                : null,
            ),
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final contact = _searchResults[index];
                  return _buildContactListTile(contact);
                },
              ),
            )
          else if (_searchController.text.isNotEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun résultat trouvé',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconData,
                      size: 64,
                      color: _getProducerColor().withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Commencer à taper pour rechercher',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _getSearchTipForCurrentTab(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildContactListTile(Map<String, dynamic> contact) {
    // Déterminer le type de contact
    String contactType = 'Utilisateur';
    IconData typeIcon = Icons.person;
    Color typeColor = Colors.blue;
    
    if (contact['type'] == 'restaurant') {
      contactType = 'Restaurant';
      typeIcon = Icons.restaurant;
      typeColor = Colors.orange;
    } else if (contact['type'] == 'leisureProducer') {
      contactType = 'Loisir';
      typeIcon = Icons.sports_volleyball;
      typeColor = Colors.purple;
    } else if (contact['type'] == 'wellnessProducer') {
      contactType = 'Bien-être';
      typeIcon = Icons.spa;
      typeColor = Colors.green;
    }
    
    // Gérer les images en base64 et les URLs
    Widget avatarWidget;
    String avatarUrl = contact['avatar'] ?? '';
    
    if (avatarUrl.startsWith('data:image')) {
      try {
        // Convertir base64 en widget d'image
        final imageData = avatarUrl.split(',')[1];
        avatarWidget = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: typeColor, width: 2),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundImage: MemoryImage(base64Decode(imageData)),
            backgroundColor: Colors.grey[200],
          ),
        );
      } catch (e) {
        // Fallback en cas d'erreur de décodage
        avatarWidget = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: typeColor, width: 2),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: typeColor.withOpacity(0.2),
            child: Icon(typeIcon, color: typeColor),
          ),
        );
      }
    } else {
      // URL standard
      avatarWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: typeColor, width: 2),
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
          backgroundColor: Colors.grey[200],
          child: avatarUrl.isEmpty || avatarUrl.contains('placeholder.com')
              ? Icon(typeIcon, color: typeColor)
              : null,
        ),
      );
    }
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: avatarWidget,
        title: Row(
          children: [
            Expanded(
              child: Text(
                contact['name'] ?? 'Sans nom',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(typeIcon, size: 12, color: typeColor),
                  const SizedBox(width: 4),
                  Text(
                    contactType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: contact['address'] != null && contact['address'].toString().isNotEmpty
            ? Text(
                contact['address'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: typeColor),
              tooltip: 'Voir le profil',
              onPressed: () => _viewContactProfile(contact),
              iconSize: 20,
            ),
            IconButton(
              icon: Icon(Icons.chat, color: typeColor),
              tooltip: 'Démarrer une conversation',
              onPressed: () => _startConversation(Contact(
                id: contact['id'],
                name: contact['name'],
                avatar: contact['avatar'],
                type: contact['type'],
              )),
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  String _getProducerTypeLabel() {
    switch (widget.producerType) {
      case 'restaurant':
        return 'restaurants';
      case 'leisureProducer':
        return 'loisirs';
      case 'wellnessProducer':
        return 'bien-être';
      default:
        return 'producteurs';
    }
  }
  
  String _getSearchTipForCurrentTab() {
    switch (_tabController.index) {
      case 1:
        return 'Trouvez vos clients et commencez à discuter directement avec eux';
      case 2:
        return 'Connectez-vous avec d\'autres ${_getProducerTypeLabel()} comme vous';
      case 3:
        return 'Créez des partenariats avec des restaurants';
      case 4:
        return 'Collaborez avec des producteurs de loisirs';
      case 5:
        return 'Échangez avec des professionnels du bien-être';
      default:
        return 'Recherchez parmi tous vos contacts potentiels';
    }
  }
  
  Widget _buildConversationsTab(List<Map<String, dynamic>> conversations) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez une nouvelle conversation en utilisant la recherche',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showSearchInterface = true;
                });
              },
              icon: const Icon(Icons.search),
              label: const Text('Rechercher des contacts'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _getProducerColor(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _searchConversations,
            decoration: InputDecoration(
              hintText: 'Filtrer les conversations',
              prefixIcon: const Icon(Icons.filter_list, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _buildConversationTile(conversation);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final bool isGroup = conversation['isGroup'] ?? false;
    final Color indicatorColor = conversation['unreadCount'] > 0 ? _getProducerColor() : Colors.transparent;
    
    // Déterminer le type de conversation et ses caractéristiques visuelles
    IconData typeIcon;
    Color typeColor;
    String typeText;
    
    if (isGroup) {
      typeIcon = Icons.group;
      typeColor = Colors.blue;
      typeText = 'Groupe';
    } else if (conversation['isUser'] == true) {
      typeIcon = Icons.person;
      typeColor = Colors.blue;
      typeText = 'Client';
    } else if (conversation['isRestaurant'] == true) {
      typeIcon = Icons.restaurant;
      typeColor = Colors.orange;
      typeText = 'Restaurant';
    } else if (conversation['isLeisure'] == true) {
      typeIcon = Icons.sports_volleyball;
      typeColor = Colors.purple;
      typeText = 'Loisir';
    } else if (conversation['isWellness'] == true) {
      typeIcon = Icons.spa;
      typeColor = Colors.green;
      typeText = 'Bien-être';
    } else {
      typeIcon = Icons.chat;
      typeColor = Colors.grey;
      typeText = 'Conversation';
    }
    
    // Formater l'heure du dernier message
    final String formattedTime = _formatDate(conversation['time']);
    
    // Gérer les images en base64 et les URLs
    Widget avatarWidget;
    String avatarUrl = conversation['avatar'] ?? '';
    
    if (avatarUrl.startsWith('data:image')) {
      try {
        // Convertir base64 en widget d'image
        final imageData = avatarUrl.split(',')[1];
        avatarWidget = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: typeColor, width: 2),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundImage: MemoryImage(base64Decode(imageData)),
            backgroundColor: Colors.grey[200],
            child: isGroup ? const Icon(Icons.group, color: Colors.white) : null,
          ),
        );
      } catch (e) {
        // Fallback en cas d'erreur de décodage
        avatarWidget = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: typeColor, width: 2),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: typeColor.withOpacity(0.2),
            child: Icon(typeIcon, color: typeColor),
          ),
        );
      }
    } else {
      // URL standard
      avatarWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: typeColor, width: 2),
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
          backgroundColor: Colors.grey[200],
          child: isGroup && (avatarUrl.isEmpty || avatarUrl.contains('placeholder.com'))
              ? const Icon(Icons.group, color: Colors.white)
              : null,
        ),
      );
    }
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: conversation['unreadCount'] > 0 ? Colors.blue[50] : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            avatarWidget,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  typeIcon,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation['name'],
                style: GoogleFonts.poppins(
                  fontWeight: conversation['unreadCount'] > 0 ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              formattedTime,
              style: TextStyle(
                fontSize: 12,
                color: conversation['unreadCount'] > 0 ? Colors.black87 : Colors.grey,
                fontWeight: conversation['unreadCount'] > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, size: 12, color: typeColor),
                const SizedBox(width: 4),
                Text(
                  typeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation['lastMessage'],
                      style: TextStyle(
                        color: conversation['unreadCount'] > 0 ? Colors.black87 : Colors.grey,
                        fontWeight: conversation['unreadCount'] > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (conversation['unreadCount'] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getProducerColor(),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        conversation['unreadCount'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _navigateToConversation(conversation),
        onLongPress: () => _showConversationOptions(conversation),
      ),
    );
  }
  
  String _getSubtitleByType(String type) {
    switch (type) {
      case 'restaurant':
        return 'Restaurant';
      case 'leisureProducer':
        return 'Producteur Loisir';
      case 'wellnessProducer':
        return 'Producteur Bien-être';
      case 'user':
        return 'Utilisateur';
      default:
        return 'Contact';
    }
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Une erreur est survenue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadConversations,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _getProducerColor(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Nouvelle méthode pour afficher les options d'une conversation
  void _showConversationOptions(Map<String, dynamic> conversation) {
    final bool isGroup = conversation['isGroup'] ?? false;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Désactiver les notifications'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications désactivées pour cette conversation')),
                  );
                },
              ),
              if (isGroup)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Ajouter des participants'),
                  onTap: () {
                    Navigator.pop(context);
                    _addParticipantsToGroup(conversation);
                  },
                ),
              if (isGroup)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Renommer le groupe'),
                  onTap: () {
                    Navigator.pop(context);
                    _renameGroup(conversation);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer la conversation', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteConversation(conversation);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Méthode pour ajouter des participants à un groupe
  void _addParticipantsToGroup(Map<String, dynamic> conversation) {
    // Implémenter l'ajout de participants à un groupe existant
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité en cours de développement')),
    );
  }
  
  // Méthode pour renommer un groupe
  void _renameGroup(Map<String, dynamic> conversation) {
    final TextEditingController nameController = TextEditingController(text: conversation['name']);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renommer le groupe'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nouveau nom du groupe',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Implémenter la mise à jour du nom du groupe
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Groupe renommé avec succès')),
                );
              },
              child: const Text('Renommer'),
            ),
          ],
        );
      },
    );
  }
  
  // Méthode pour confirmer la suppression d'une conversation
  void _confirmDeleteConversation(Map<String, dynamic> conversation) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la conversation'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette conversation ? Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Implémenter la suppression de la conversation
                _deleteConversation(conversation);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  
  // Méthode pour supprimer une conversation
  void _deleteConversation(Map<String, dynamic> conversation) {
    setState(() {
      _conversations.removeWhere((conv) => conv['id'] == conversation['id']);
      _filterConversations(); // Mettre à jour les listes filtrées
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversation supprimée avec succès')),
    );
    
    // Implémenter la suppression dans l'API
    // _conversationService.deleteConversation(conversation['id']);
  }
  
  // Méthode pour voir le profil d'un contact
  void _viewContactProfile(Map<String, dynamic> contact) {
    final String contactId = contact['id'] ?? '';
    final String contactType = contact['type'] ?? '';
    final String contactName = contact['name'] ?? 'Contact';
    
    if (contactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de contact invalide')),
      );
      return;
    }
    
    print('🔍 Navigation vers le profil de $contactName (ID: $contactId, type: $contactType)');
    
    if (contactType == 'restaurant') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerScreen(
            producerId: contactId,
          ),
        ),
      );
    } else if (contactType == 'leisureProducer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerLeisureScreen(
            producerId: contactId,
          ),
        ),
      );
    } else if (contactType == 'wellnessProducer') {
      // Pour le moment, utiliser également ProducerScreen pour bien-être
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProducerScreen(
            producerId: contactId,
          ),
        ),
      );
    } else if (contactType == 'user') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            userId: contactId,
          ),
        ),
      );
    } else {
      // Fallback pour les autres types
      print('⚠️ Type de profil non reconnu: $contactType');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil de $contactName non disponible (type: $contactType)')),
      );
    }
  }

  // Démarrer une conversation avec un contact
  void _startConversation(Contact contact) async {
    try {
      if (contact == null || contact.id == null || contact.id!.isEmpty) {
        print("❌ Impossible de démarrer une conversation: contact ou ID du contact invalide");
        return;
      }
      
      print("🔍 ProducerMessagingScreen: Démarrage conversation avec contact: ${contact.name} (ID: ${contact.id})");
      print("🔍 ProducerMessagingScreen: Utilisation de l'ID producteur: ${widget.producerId}");
      
      final result = await _conversationService.createOrGetConversation(
        widget.producerId,
        contact.id!,
      );
      
      print("📦 ProducerMessagingScreen: Résultat création conversation: $result");
      
      // Récupérer l'ID de conversation, en vérifiant les différentes clés possibles
      final conversationId = result['conversationId'] ?? 
                            result['conversation_id'] ?? 
                            result['_id'];
      
      if (conversationId == null || conversationId.isEmpty) {
        print("❌ ProducerMessagingScreen: Impossible de récupérer l'ID de conversation dans la réponse");
        return;
      }
      
      print("✅ ProducerMessagingScreen: Conversation créée avec ID: $conversationId");
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            conversationId: conversationId,
            userId: widget.producerId,
            recipientName: contact.name ?? "Contact",
            recipientAvatar: contact.avatar ?? "https://via.placeholder.com/150",
            isGroup: false,
          ),
        ),
      );
    } catch (e) {
      print("❌ ProducerMessagingScreen: Erreur lors du démarrage de la conversation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la création de la conversation: $e")),
      );
    }
  }

  // Ajouter cette méthode pour filtrer les conversations
  void _filterConversations() {
    // Filtrer les conversations en fonction du texte de recherche
    final searchText = _searchController.text.toLowerCase();
    
    _filteredConversations = _conversations.where((conv) {
      final name = (conv['name'] ?? '').toLowerCase();
      final lastMessage = (conv['lastMessage'] ?? '').toLowerCase();
      return name.contains(searchText) || lastMessage.contains(searchText);
    }).toList();
    
    // Filtrer les contacts en fonction du texte de recherche et de l'onglet actif
    _filterContactsByTab();
    
    // Forcer une mise à jour de l'interface
    setState(() {});
  }
  
  // Méthode pour filtrer les contacts en fonction de l'onglet sélectionné
  void _filterContactsByTab() {
    if (!_showSearchInterface || _searchController.text.isEmpty) {
      _searchResults = [];
      return;
    }
    
    final searchText = _searchController.text.toLowerCase();
    
    // Effectuer une recherche différente selon l'onglet actif
    switch (_tabController.index) {
      case 0: // Tous
        _searchAllContacts(searchText);
        break;
      case 1: // Utilisateurs
        _searchUserContacts(searchText);
        break;
      case 2: // Même type de producteur
        _searchProducersByType(searchText, widget.producerType);
        break;
      case 3: // Restaurants
        _searchProducersByType(searchText, 'restaurant');
        break;
      case 4: // Loisirs
        _searchProducersByType(searchText, 'leisureProducer');
        break;
      case 5: // Bien-être
        _searchProducersByType(searchText, 'wellnessProducer');
        break;
    }
  }
  
  // Méthodes auxiliaires pour la recherche
  void _searchAllContacts(String query) async {
    if (query.length < 2) return;
    
    try {
      final results = await _conversationService.searchAll(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Erreur de recherche: $e');
    }
  }
  
  void _searchUserContacts(String query) async {
    if (query.length < 2) return;
    
    try {
      final results = await _conversationService.searchUsers(query);
      setState(() {
        _searchResults = results.where((user) => user['type'] == 'user').toList();
      });
    } catch (e) {
      print('Erreur de recherche: $e');
    }
  }
  
  void _searchProducersByType(String query, String type) async {
    if (query.length < 2) return;
    
    try {
      final results = await _conversationService.searchProducersByType(query, type);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Erreur de recherche: $e');
    }
  }
} 
