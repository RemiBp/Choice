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
import 'package:flutter/services.dart'; // Added for HapticFeedback
import '../utils/constants.dart' as constants; // Restore alias
import '../models/user_model.dart'; // Corrected import from user_profile.dart
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/loading_indicator.dart';
import '../../utils.dart' show getImageProvider;
// import '../widgets/custom_app_bar.dart'; // Commented out missing widget
// import '../widgets/user_avatar.dart'; // Commented out missing widget
import 'mywellness_producer_profile_screen.dart';

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
  final FocusNode _searchFocusNode = FocusNode(); // Added for better focus control
  
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
  bool _isSearchingApi = false; // Renamed for clarity
  bool _hasError = false;
  String _errorMessage = '';
  bool _showSearchInterface = false;
  
  late TabController _tabController;
  
  // Couleurs pour les types d'utilisateurs/producteurs
  // Removed - will use theme colors or derive from producer type dynamically
  
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
    _searchFocusNode.dispose(); // Dispose focus node
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
        _searchFocusNode.unfocus(); // Unfocus search field
      });
    }
    _filterConversations(); // Update filtered list for the new tab
  }
  
  Future<void> _loadConversations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }
    
    try {
      print('🔄 Chargement des conversations pour producteur ${widget.producerId} (type: ${widget.producerType})');
      
      final conversations = await _conversationService.getProducerConversations(
        widget.producerId,
        widget.producerType,
      );
      
      print('✅ ${conversations.length} conversations récupérées avec succès');
      
      if (conversations.isEmpty) {
        print('ℹ️ Aucune conversation trouvée pour ce producteur');
      }
      
      // Sort conversations by time (most recent first) before categorizing
      conversations.sort((a, b) {
        final timeA = DateTime.tryParse(a['time'] ?? '') ?? DateTime(0);
        final timeB = DateTime.tryParse(b['time'] ?? '') ?? DateTime(0);
        return timeB.compareTo(timeA);
      });
      
      setState(() {
        _conversations = conversations;
        _categorizeConversations(_conversations); // Categorize the sorted list
        _filterConversations(); // Apply initial filtering/tab selection
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur lors du chargement des conversations: $e');
      
      String errorMsg = 'Une erreur est survenue lors du chargement de vos conversations.';
      if (e.toString().contains('timeout')) {
        errorMsg = 'Impossible de se connecter. Vérifiez votre connexion et réessayez.';
      } else if (e.toString().contains('404') || e.toString().contains('500')) {
        errorMsg = 'Le service de messagerie est indisponible. Réessayez plus tard.';
      }
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = errorMsg;
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
    _userConversations = [];
    _sameTypeProducerConversations = [];
    _restaurantProducerConversations = [];
    _leisureProducerConversations = [];
    _wellnessProducerConversations = [];
    
    // Create a set of this producer's own IDs to avoid self-conversation categorization if applicable
    final Set<String> ownIds = {widget.producerId}; // Add other potential IDs if necessary
    
    for (var conversation in conversations) {
        // Determine participant type (user, restaurant, leisure, wellness)
        String participantType = 'user'; // Default
        if (conversation['isGroup'] == true) {
             // Groups are handled separately, not categorized by participant type here
            continue;
        } else if (conversation['isRestaurant'] == true) {
            participantType = 'restaurant';
        } else if (conversation['isLeisure'] == true) {
            participantType = 'leisureProducer'; // Match type used in producerType
        } else if (conversation['isWellness'] == true) {
            participantType = 'wellnessProducer'; // Match type used in producerType
        } else if (conversation['isUser'] == true) {
             participantType = 'user';
        }
        // Add more types if needed (e.g., 'beauty')

        // Skip if it's somehow a conversation with self (unlikely for producers, but safety check)
        final String otherParticipantId = conversation['participants']?.firstWhere(
            (pId) => !ownIds.contains(pId), 
            orElse: () => null) ?? '';
        if (otherParticipantId.isEmpty && conversation['isGroup'] != true) {
            continue; 
        }

        if (participantType == 'user') {
            _userConversations.add(conversation);
        } else if (participantType == widget.producerType) {
             _sameTypeProducerConversations.add(conversation);
        } else if (participantType == 'restaurant') {
            _restaurantProducerConversations.add(conversation);
        } else if (participantType == 'leisureProducer') {
            _leisureProducerConversations.add(conversation);
        } else if (participantType == 'wellnessProducer') {
            _wellnessProducerConversations.add(conversation);
        }
        // Add other categories if needed
    }

     // Ensure the main filtered list reflects the current tab after categorization
     _filterConversations();
}
  
  // Renamed from _searchConversations for clarity
  void _filterCurrentTabConversations(String query) {
    setState(() {
      _filterConversations(); // Call the main filtering logic
    });
  }
  
  Future<void> _searchContacts(String query) async {
    if (query.length < 2) { // Require at least 2 characters for API search
      setState(() {
        _searchResults = [];
        _isSearchingApi = false;
      });
      return;
    }
    
    setState(() {
      _isSearchingApi = true;
    });
    
    try {
      List<Map<String, dynamic>> results = [];
      String searchType = 'all'; // Default for "Toutes" tab
      
      switch (_tabController.index) {
        case 1: // Clients (Utilisateurs)
          results = await _conversationService.searchUsers(query);
          // Filter client-side just in case API returns others
          results = results.where((c) => c['type'] == 'user').toList(); 
          break;
        case 2: // Onglet Producteurs du même type
          searchType = widget.producerType;
          results = await _conversationService.searchProducersByType(query, searchType);
          break;
        case 3: // Onglet Restaurants
          searchType = 'restaurant';
          results = await _conversationService.searchProducersByType(query, searchType);
          break;
        case 4: // Onglet Loisirs
          searchType = 'leisureProducer';
          results = await _conversationService.searchProducersByType(query, searchType);
          break;
        case 5: // Onglet Bien-être
          searchType = 'wellnessProducer';
          results = await _conversationService.searchProducersByType(query, searchType);
          break;
        default: // Onglet Toutes (recherche globale)
           results = await _conversationService.searchAll(query);
           // Filter out self if present in results
           results.removeWhere((c) => c['id'] == widget.producerId);
          break;
      }
      
      setState(() {
        _searchResults = results;
        _isSearchingApi = false;
      });
    } catch (e) {
      print("❌ Erreur recherche contacts: $e");
      setState(() {
        _isSearchingApi = false;
        // Optionally show a snackbar or small error message here
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur de recherche: ${e.toString().split(':').last}')),
        );
        _searchResults = []; // Clear results on error
      });
    }
  }
  
  void _navigateToConversation(Map<String, dynamic> conversation) {
     HapticFeedback.lightImpact(); // Add haptic feedback
    final String conversationId = conversation['id'] ?? '';
    final String recipientName = conversation['name'] ?? 'Conversation';
    final String recipientAvatar = conversation['avatar'] ?? '';
    final bool isGroup = conversation['isGroup'] ?? false;
    
    // Determine if the current user is a producer in this context
    // This logic might need refinement based on your exact user/producer model
    final bool currentUserIsProducer = true; // Assuming always true for this screen

    if (conversationId.isEmpty) {
        print("❌ Erreur: ID de conversation manquant.");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir cette conversation.'))
        );
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailScreen(
          conversationId: conversationId,
          recipientName: recipientName,
          recipientAvatar: recipientAvatar,
          userId: widget.producerId, // Pass the producer's ID as the current user ID
          isProducer: currentUserIsProducer, 
          isGroup: isGroup,
        ),
      ),
    ).then((_) => _loadConversations(showLoading: false)); // Refresh without full loading indicator
  }
  
  // Removed _createOrGetConversation as _startConversation handles it
  
  void _navigateToGroupCreation() {
    HapticFeedback.lightImpact();
    print('🔍 ProducerMessagingScreen: Navigation vers la création de groupe');
    print('🔍 ProducerMessagingScreen: ID Producteur: ${widget.producerId}, Type: ${widget.producerType}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCreationScreen(
          userId: widget.producerId, // Pass producerId as userId for creation context
          producerType: widget.producerType,
        ),
      ),
    ).then((didCreate) {
      // Reload conversations if group creation might have occurred
      if (didCreate == true) {
         _loadConversations(showLoading: false);
      }
    });
  }
  
  // Simplified navigation logic
  void _navigateToProfile(String profileId, String type) {
     HapticFeedback.lightImpact();
     print("Navigating to profile: ID=$profileId, Type=$type");
     
     // Use a specific screen based on type, fallback to generic ProfileScreen if needed
     Widget screen;
     if (type == 'restaurant') {
         screen = ProducerScreen(producerId: profileId); // Assuming this handles restaurants
     } else if (type == 'leisureProducer') {
          screen = ProducerLeisureScreen(producerId: profileId); // Assuming specific screen
     } else if (type == 'wellnessProducer') {
          // Decide which screen is appropriate for wellness producers
          screen = ProducerScreen(producerId: profileId); // Or a specific WellnessProducerScreen?
     } else if (type == 'user') {
         screen = ProfileScreen(userId: profileId);
     } else {
          print("⚠️ Type de profil inconnu: $type. Navigation annulée.");
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Impossible d\'afficher le profil ($type).'))
           );
          return; // Don't navigate if type is unknown
     }

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }
  
  String _formatDate(String dateString) {
    try {
        final dateTime = DateTime.parse(dateString).toLocal(); // Convert to local time
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

        if (date == today) {
        return DateFormat('HH:mm').format(dateTime);
        } else if (date == yesterday) {
        return 'Hier';
        } else if (now.difference(dateTime).inDays < 7) {
        // Use 'fr_FR' locale for French day names
        return DateFormat('EEEE', 'fr_FR').format(dateTime); 
        } else {
        return DateFormat('dd/MM/yy').format(dateTime); // Short year format
        }
    } catch (e) {
        print("⚠️ Erreur formatage date '$dateString': $e");
        return ''; // Return empty string on error
    }
}
  
  Color _getProducerColor() {
     // Use theme colors or constants if available
     // Example using Theme.of(context)
     // return Theme.of(context).colorScheme.primary; 
    switch (widget.producerType) {
      case 'restaurant':
        return Colors.orange; // Fallback color
      case 'leisureProducer':
        return Colors.purple; // Fallback color
      case 'wellnessProducer':
        return Colors.green; // Fallback color
      default:
        return Theme.of(context).colorScheme.primary; // Fallback to primary theme color
    }
  }
  
  IconData _getProducerIcon() {
    switch (widget.producerType) {
      case 'restaurant':
        return Icons.restaurant_menu_outlined; // Use outlined icons for consistency
      case 'leisureProducer':
        return Icons.local_activity_outlined;
      case 'wellnessProducer':
        return Icons.spa_outlined;
      default:
        return Icons.business_center_outlined;
    }
  }
  
  String _getProducerTitle() {
     // Use localization keys if available: 'producerMessaging.titleRestaurant'.tr()
    switch (widget.producerType) {
      case 'restaurant':
        return 'Messagerie Restaurant';
      case 'leisureProducer':
        return 'Messagerie Loisirs';
      case 'wellnessProducer':
        return 'Messagerie Bien-être';
      default:
        return 'Messagerie';
    }
  }

  // Helper to get color based on participant type string
  Color _getColorForType(String type) {
      switch (type) {
          case 'restaurant': return Colors.orange; // Fallback color
          case 'leisureProducer': return Colors.purple; // Fallback color
          case 'wellnessProducer': return Colors.green; // Fallback color
          case 'user': return Colors.blue; // Fallback color
          case 'group': return Colors.blueGrey; // Specific color for groups
          default: return Colors.grey;
      }
  }

  // Helper to get icon based on participant type string
  IconData _getIconForType(String type) {
      switch (type) {
          case 'restaurant': return Icons.restaurant_menu_outlined;
          case 'leisureProducer': return Icons.local_activity_outlined;
          case 'wellnessProducer': return Icons.spa_outlined;
          case 'user': return Icons.person_outline;
          case 'group': return Icons.group_outlined;
          default: return Icons.chat_bubble_outline;
      }
  }

  // Helper to get display text based on participant type string
  String _getTextForType(String type) {
     // Use localization if available: 'participantType.$type'.tr()
     switch (type) {
          case 'restaurant': return 'Restaurant';
          case 'leisureProducer': return 'Loisir';
          case 'wellnessProducer': return 'Bien-être';
          case 'user': return 'Client';
          case 'group': return 'Groupe';
          default: return 'Contact';
      }
  }
  
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = _getProducerColor();
    final Color unselectedColor = Colors.grey.shade600;
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDarkTheme ? Colors.black : Colors.white;
    final Color cardColor = isDarkTheme ? Colors.grey.shade900 : Colors.grey.shade50;
    final Color searchFieldColor = isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade100;

    // Define common text styles
    final TextStyle titleStyle = GoogleFonts.poppins(
        fontWeight: FontWeight.bold, fontSize: 20);
    final TextStyle tabLabelStyle = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600); // Smaller tab labels
    final TextStyle emptyStateTitleStyle = GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]);
     final TextStyle emptyStateMessageStyle = GoogleFonts.poppins(
        fontSize: 14, color: Colors.grey[500]);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: isDarkTheme ? Colors.white : Colors.black, // Adapt icon/text color
          title: Row(
            children: [
              Icon(_getProducerIcon(), color: primaryColor, size: 26),
              const SizedBox(width: 10),
              Text(_getProducerTitle(), style: titleStyle),
            ],
          ),
          actions: [
             IconButton(
              icon: Icon(Icons.group_add_outlined, color: unselectedColor),
              onPressed: _navigateToGroupCreation,
              tooltip: 'Créer un groupe',
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: unselectedColor),
              onPressed: () => _loadConversations(showLoading: true), // Force loading indicator
              tooltip: 'Actualiser',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: unselectedColor,
            labelStyle: tabLabelStyle,
            unselectedLabelStyle: tabLabelStyle.copyWith(fontWeight: FontWeight.w500),
            isScrollable: true,
            tabAlignment: TabAlignment.start, // Align tabs to the start
            tabs: [
              const Tab(text: 'Toutes'),
              const Tab(text: 'Clients'),
              Tab(
                child: Row( mainAxisSize: MainAxisSize.min, children: [
                    Icon(_getIconForType(widget.producerType), size: 16), // Use dynamic icon
                    const SizedBox(width: 4), const Text('Même type'),
                ]),
              ),
              Tab(
                 child: Row( mainAxisSize: MainAxisSize.min, children: [
                    Icon(_getIconForType('restaurant'), size: 16, color: _getColorForType('restaurant')),
                    const SizedBox(width: 4), const Text('Restaurants'),
                 ]),
              ),
              Tab(
                 child: Row( mainAxisSize: MainAxisSize.min, children: [
                    Icon(_getIconForType('leisureProducer'), size: 16, color: _getColorForType('leisureProducer')),
                    const SizedBox(width: 4), const Text('Loisirs'),
                ]),
              ),
              Tab(
                 child: Row( mainAxisSize: MainAxisSize.min, children: [
                    Icon(_getIconForType('wellnessProducer'), size: 16, color: _getColorForType('wellnessProducer')),
                    const SizedBox(width: 4), const Text('Bien-être'),
                 ]),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab Toutes les conversations
             _buildTabContent(context, _filteredConversations),
            // Tab Clients (utilisateurs)
            _buildTabContent(context, _userConversations),
            // Tab Producteurs du même type
            _buildTabContent(context, _sameTypeProducerConversations),
            // Tab Restaurants
            _buildTabContent(context, _restaurantProducerConversations),
            // Tab Loisirs
            _buildTabContent(context, _leisureProducerConversations),
            // Tab Bien-être
            _buildTabContent(context, _wellnessProducerConversations),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _showSearchInterface = !_showSearchInterface;
              if (_showSearchInterface) {
                  _searchFocusNode.requestFocus(); // Focus search field when opening
              } else {
                 _searchResults = [];
                 _searchController.clear();
                 _searchFocusNode.unfocus(); // Unfocus when closing
              }
            });
             HapticFeedback.mediumImpact();
          },
          backgroundColor: primaryColor,
          foregroundColor: Colors.white, // Ensure icon contrasts with background
          tooltip: _showSearchInterface ? 'Fermer la recherche' : 'Rechercher des contacts',
          child: AnimatedSwitcher( // Nice transition for the icon
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                    _showSearchInterface ? Icons.close : Icons.search,
                    key: ValueKey<bool>(_showSearchInterface), // Key for animation
                 ),
             ),
        ),
      ),
    );
  }

  // Helper widget to build content for each tab (handles loading, error, list, search)
  Widget _buildTabContent(BuildContext context, List<Map<String, dynamic>> specificConversations) {
     // Use the tab index to decide whether to show search interface for this tab
     final bool showSearchForThisTab = _showSearchInterface && _tabController.indexIsChanging == false;

     if (showSearchForThisTab) {
         return _buildSearchInterfaceForCurrentTab(context);
     } else if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
     } else if (_hasError) {
        return _buildErrorView(context);
     } else {
        // Determine which list to show based on tab index vs the passed list
        List<Map<String, dynamic>> listToShow;
        if (_tabController.index == 0) {
             listToShow = _filteredConversations; // "Toutes" uses the main filtered list
        } else {
            listToShow = specificConversations; // Other tabs use their categorized lists
        }
        return _buildConversationsList(context, listToShow);
     }
  }

  // Updated Search Interface Builder
  Widget _buildSearchInterfaceForCurrentTab(BuildContext context) {
      String hintText;
      IconData iconData;
      Color color = _getProducerColor(); // Default to producer's color

      // Customize hint text, icon, and color based on the active tab
      switch (_tabController.index) {
          case 1:
              hintText = 'Rechercher des clients...';
              iconData = _getIconForType('user');
              color = _getColorForType('user');
              break;
          case 2:
              hintText = 'Rechercher des ${_getTextForType(widget.producerType)}...';
              iconData = _getIconForType(widget.producerType);
              color = _getColorForType(widget.producerType);
              break;
          case 3:
              hintText = 'Rechercher des ${_getTextForType('restaurant')}...';
              iconData = _getIconForType('restaurant');
              color = _getColorForType('restaurant');
              break;
          case 4:
              hintText = 'Rechercher des ${_getTextForType('leisureProducer')}...';
              iconData = _getIconForType('leisureProducer');
              color = _getColorForType('leisureProducer');
              break;
          case 5:
              hintText = 'Rechercher des ${_getTextForType('wellnessProducer')}...';
              iconData = _getIconForType('wellnessProducer');
              color = _getColorForType('wellnessProducer');
              break;
          default: // Case 0 (Toutes)
              hintText = 'Rechercher tous contacts...';
              iconData = Icons.search;
              color = Theme.of(context).colorScheme.primary; // Use primary theme color for 'All'
              break;
      }
      
      final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
      final Color searchFieldColor = isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade100;
      final TextStyle searchHintStyle = GoogleFonts.poppins(color: Colors.grey[600]);
      final TextStyle searchInputStyle = GoogleFonts.poppins(); // Default input style

      return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // No bottom padding
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _searchContacts,
                      autofocus: true, // Keep autofocus
                      style: searchInputStyle,
                      decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: searchHintStyle,
                          prefixIcon: Icon(iconData, color: color, size: 22),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: searchFieldColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Adjust padding
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                      _searchController.clear();
                                      _searchContacts(''); // Trigger empty search
                                       HapticFeedback.lightImpact();
                                  },
                                )
                              : null,
                      ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildSearchResultsList(context, iconData, color)),
              ],
          ),
      );
  }

  // Helper to build the search results list or empty state
  Widget _buildSearchResultsList(BuildContext context, IconData emptyIcon, Color emptyIconColor) {
       final TextStyle emptyStateTitleStyle = GoogleFonts.poppins(
           fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]);
       final TextStyle emptyStateMessageStyle = GoogleFonts.poppins(
           fontSize: 14, color: Colors.grey[500]);

      if (_isSearchingApi) {
          return const Center(child: CircularProgressIndicator());
      } else if (_searchResults.isNotEmpty) {
          // Use ListView.separated for dividers
          return ListView.separated(
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => Divider(height: 1, indent: 80, endIndent: 16, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                  final contact = _searchResults[index];
                  return _buildContactListTile(context, contact);
              },
              padding: EdgeInsets.zero, // Remove padding around list
          );
      } else if (_searchController.text.length >= 2) { // Show 'No Results' only if search attempted
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Icon(Icons.search_off_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Aucun résultat trouvé', style: emptyStateTitleStyle),
                  ],
              ),
          );
      } else { // Initial empty state (before typing enough)
          return Center(
              child: SingleChildScrollView( // Allow scrolling if content overflows
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(emptyIcon, size: 64, color: emptyIconColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Rechercher des contacts', style: emptyStateTitleStyle),
                        const SizedBox(height: 8),
                        Text(
                            _getSearchTipForCurrentTab(),
                            textAlign: TextAlign.center,
                            style: emptyStateMessageStyle,
                        ),
                    ],
                ),
              ),
          );
      }
  }
  
  // Updated Contact List Tile Builder
  Widget _buildContactListTile(BuildContext context, Map<String, dynamic> contact) {
      final String contactType = contact['type'] ?? 'user'; // Default to user
      final IconData typeIcon = _getIconForType(contactType);
      final Color typeColor = _getColorForType(contactType);
      final String typeText = _getTextForType(contactType);

      Widget avatarWidget;
      String avatarUrl = contact['avatar'] ?? '';
      String contactName = contact['name'] ?? 'Contact Inconnu';

      try {
          if (avatarUrl.startsWith('data:image')) {
              final imageData = base64Decode(avatarUrl.split(',')[1]);
              avatarWidget = CircleAvatar(
                  radius: 25,
                  backgroundImage: MemoryImage(imageData),
                  backgroundColor: Colors.grey[200],
              );
          } else if (avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true) {
              avatarWidget = CircleAvatar(
                  radius: 25,
                  backgroundImage: getImageProvider(avatarUrl),
                  backgroundColor: Colors.grey[200],
                   // Optional: Fallback icon inside if image fails
                  onBackgroundImageError: (exception, stackTrace) {
                      print("⚠️ Error loading image: $avatarUrl");
                  },
                 child: getImageProvider(avatarUrl).hashCode == null // Crude check if provider is empty
                      ? Icon(typeIcon, size: 25, color: typeColor.withOpacity(0.7))
                      : null,
              );
          } else {
              // Generate placeholder avatar
               avatarWidget = CircleAvatar(
                  radius: 25,
                  backgroundColor: typeColor.withOpacity(0.15),
                  child: Text(
                      contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 20, color: typeColor, fontWeight: FontWeight.bold),
                  ),
              );
          }
      } catch (e) {
           print("❌ Error building avatar: $e");
           avatarWidget = CircleAvatar( // Fallback placeholder
               radius: 25,
               backgroundColor: typeColor.withOpacity(0.15),
               child: Icon(typeIcon, size: 25, color: typeColor.withOpacity(0.7)),
          );
      }

      // Add a border around the avatar
      Widget finalAvatar = Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: typeColor.withOpacity(0.5), width: 1.5),
          ),
          padding: const EdgeInsets.all(2), // Padding inside the border
          child: avatarWidget,
      );

      // Contact Type Chip
      Widget typeChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              // border: Border.all(color: typeColor.withOpacity(0.3)), // Optional border
          ),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                  Icon(typeIcon, size: 12, color: typeColor),
                  const SizedBox(width: 4),
                  Text(
                      typeText,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600, // Bolder type text
                          color: typeColor,
                      ),
                  ),
              ],
          ),
      );

      return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: finalAvatar,
          title: Text(
              contactName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              typeChip, // Put the chip in the subtitle
              if (contact['address'] != null && contact['address'].toString().isNotEmpty)
                 Expanded(
                    child: Padding(
                       padding: const EdgeInsets.only(left: 8.0),
                       child: Text(
                          contact['address'],
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                       ),
                    ),
                 ),
            ],
          ),
          trailing: Row( // Keep actions in trailing
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  icon: Icon(Icons.visibility_outlined, color: typeColor),
                  tooltip: 'Voir le profil',
                  onPressed: () => _viewContactProfile(contact),
                  iconSize: 22,
              ),
              IconButton(
                  icon: Icon(Icons.chat_bubble_outline, color: typeColor),
                  tooltip: 'Démarrer la conversation',
                  onPressed: () {
                       HapticFeedback.lightImpact();
                      _startConversation(Contact(
                          id: contact['id'],
                          name: contactName,
                          avatar: avatarUrl,
                          type: contactType,
                      ));
                  },
                  iconSize: 22,
              ),
            ],
          ),
          onTap: () { // Make the whole tile tappable to start chat
              HapticFeedback.lightImpact();
              _startConversation(Contact(
                   id: contact['id'],
                   name: contactName,
                   avatar: avatarUrl,
                   type: contactType,
              ));
          },
      );
  }
  
  String _getProducerTypeLabel() {
    // Use localization: 'producerType.${widget.producerType}'.tr()
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
    // Use localization keys
    switch (_tabController.index) {
      case 1:
        return 'Trouvez vos clients et discutez directement.';
      case 2:
        return 'Connectez-vous avec d\'autres ${_getProducerTypeLabel()} comme vous.';
      case 3:
        return 'Trouvez des restaurants partenaires.';
      case 4:
        return 'Collaborez avec des producteurs de loisirs.';
      case 5:
        return 'Échangez avec des pros du bien-être.';
      default:
        return 'Recherchez parmi tous les utilisateurs et producteurs.';
    }
  }

  // Builds the list of conversations for a tab
  Widget _buildConversationsList(BuildContext context, List<Map<String, dynamic>> conversations) {
     final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
     final Color searchFieldColor = isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade100;
     final Color primaryColor = _getProducerColor();
     final TextStyle emptyStateTitleStyle = GoogleFonts.poppins(
         fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]);
      final TextStyle emptyStateMessageStyle = GoogleFonts.poppins(
         fontSize: 14, color: Colors.grey[500]);

     if (conversations.isEmpty) {
          return Center(
              child: SingleChildScrollView(
                 padding: const EdgeInsets.all(32.0),
                 child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(
                            Icons.forum_outlined, // Use outlined icon
                            size: 64,
                            color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text('Aucune conversation ici', style: emptyStateTitleStyle),
                        const SizedBox(height: 8),
                        Text(
                            'Commencez par rechercher un contact pour démarrer une discussion.',
                            textAlign: TextAlign.center,
                            style: emptyStateMessageStyle,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                            onPressed: () {
                                setState(() => _showSearchInterface = true);
                                _searchFocusNode.requestFocus();
                                 HapticFeedback.lightImpact();
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('Rechercher des contacts'),
                            style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white, backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Rounded button
                            ),
                        ),
                    ],
                ),
              ),
          );
      }

      // Filter conversations based on the search field *within this tab*
      final String filterText = _searchController.text.toLowerCase();
      final List<Map<String, dynamic>> displayedConversations = filterText.isEmpty
          ? conversations
          : conversations.where((conv) {
              final name = (conv['name'] ?? '').toLowerCase();
              final lastMessage = (conv['lastMessage'] ?? '').toLowerCase();
              return name.contains(filterText) || lastMessage.contains(filterText);
          }).toList();

      return Column(
          children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                     controller: _searchController, // Use the main search controller
                     onChanged: _filterCurrentTabConversations, // Update filter on change
                     decoration: InputDecoration(
                         hintText: 'Filtrer cette liste...',
                         prefixIcon: Icon(Icons.filter_list, color: Colors.grey.shade500, size: 20),
                         border: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(30),
                             borderSide: BorderSide.none,
                         ),
                         filled: true,
                         fillColor: searchFieldColor,
                         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Adjusted padding
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                      _searchController.clear();
                                      _filterCurrentTabConversations('');
                                       HapticFeedback.lightImpact();
                                  },
                                )
                              : null,
                     ),
                  ),
              ),
               if (displayedConversations.isEmpty && filterText.isNotEmpty)
                  Padding(
                     padding: const EdgeInsets.only(top: 50.0),
                     child: Center(
                        child: Text(
                          'Aucune conversation ne correspond à "${_searchController.text}"',
                           style: emptyStateMessageStyle,
                        )
                     ),
                  )
               else
                  Expanded(
                     child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
                        itemCount: displayedConversations.length,
                        itemBuilder: (context, index) {
                            final conversation = displayedConversations[index];
                            return _buildConversationTile(context, conversation);
                        },
                     ),
                  ),
          ],
      );
  }

  // Updated Conversation Tile Builder
  Widget _buildConversationTile(BuildContext context, Map<String, dynamic> conversation) {
      final bool isGroup = conversation['isGroup'] ?? false;
      final int unreadCount = conversation['unreadCount'] ?? 0;
      final bool hasUnread = unreadCount > 0;
      
      // Determine type, icon, color
      String convType = 'user'; // Default
      if (isGroup) {
          convType = 'group';
      } else if (conversation['isRestaurant'] == true) {
          convType = 'restaurant';
      } else if (conversation['isLeisure'] == true) {
          convType = 'leisureProducer';
      } else if (conversation['isWellness'] == true) {
          convType = 'wellnessProducer';
      } // Add other types (beauty, etc.) if needed

      final IconData typeIcon = _getIconForType(convType);
      final Color typeColor = _getColorForType(convType);
      final String typeText = _getTextForType(convType); // Not used directly in tile, but useful

      // Format time
      final String formattedTime = _formatDate(conversation['time'] ?? DateTime.now().toIso8601String());

      // Avatar Logic (similar to contact tile)
      Widget avatarWidget;
      String avatarUrl = conversation['avatar'] ?? '';
      String convName = conversation['name'] ?? (isGroup ? 'Groupe sans nom' : 'Contact inconnu');

       try {
          if (avatarUrl.startsWith('data:image')) {
              final imageData = base64Decode(avatarUrl.split(',')[1]);
              avatarWidget = CircleAvatar(
                  radius: 25,
                  backgroundImage: MemoryImage(imageData),
                  backgroundColor: Colors.grey[200],
              );
          } else if (avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true) {
              avatarWidget = CircleAvatar(
                  radius: 25,
                  backgroundImage: getImageProvider(avatarUrl),
                  backgroundColor: Colors.grey[200],
                   // Optional: Fallback icon inside if image fails
                  onBackgroundImageError: (exception, stackTrace) {
                      print("⚠️ Error loading image: $avatarUrl");
                  },
                 child: getImageProvider(avatarUrl).hashCode == null // Crude check if provider is empty
                      ? Icon(typeIcon, size: 25, color: typeColor.withOpacity(0.7))
                      : null,
              );
          } else {
              // Generate placeholder avatar
               avatarWidget = CircleAvatar(
                  radius: 25,
                  backgroundColor: typeColor.withOpacity(0.15),
                  child: Text(
                      convName.isNotEmpty ? convName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 20, color: typeColor, fontWeight: FontWeight.bold),
                  ),
              );
          }
      } catch (e) {
           print("❌ Error building avatar: $e");
           avatarWidget = CircleAvatar( // Fallback placeholder
               radius: 25,
               backgroundColor: typeColor.withOpacity(0.15),
               child: Icon(typeIcon, size: 25, color: typeColor.withOpacity(0.7)),
          );
      }

      // Add indicator for unread messages and type icon
      Widget finalAvatar = Stack(
          alignment: Alignment.bottomRight,
          children: [
              Container( // Border container
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: hasUnread ? typeColor : Colors.grey.shade300, // Highlight border if unread
                          width: hasUnread ? 2.0 : 1.5,
                       ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: avatarWidget,
              ),
              Container( // Small icon container
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).cardColor, width: 1.5), // Border matching card bg
                  ),
                  child: Icon(typeIcon, size: 10, color: Colors.white), // White icon
              ),
          ],
      );

      final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
       final Color cardColor = hasUnread 
           ? typeColor.withOpacity(0.1) // Use type color with opacity for unread background
           : (isDarkTheme ? Colors.grey.shade800.withOpacity(0.5) : Colors.white); // More subtle background otherwise
       final Color textColor = isDarkTheme ? Colors.white : Colors.black87;
       final Color subtitleColor = Colors.grey.shade600;
       final Color unreadIndicatorColor = _getProducerColor(); // Use producer's main color for unread count

      return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12), // Adjust margin
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // More rounded corners
          child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: finalAvatar,
              title: Row(
                  children: [
                      Expanded(
                          child: Text(
                              convName,
                              style: GoogleFonts.poppins(
                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 15,
                                  color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                          ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          formattedTime,
                          style: TextStyle(
                              fontSize: 11, // Smaller time font
                              color: hasUnread ? textColor.withOpacity(0.8) : subtitleColor,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                      ),
                  ],
              ),
              subtitle: Row(
                  children: [
                      Expanded(
                          child: Text(
                              conversation['lastMessage'] ?? '',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: hasUnread ? textColor.withOpacity(0.9) : subtitleColor,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                          ),
                      ),
                      if (hasUnread)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: CircleAvatar(
                                radius: 10,
                                backgroundColor: unreadIndicatorColor,
                                child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                    ),
                                ),
                            ),
                          ),
                  ],
              ),
              onTap: () => _navigateToConversation(conversation),
              onLongPress: () {
                   HapticFeedback.mediumImpact();
                  _showConversationOptions(conversation);
               },
          ),
      );
  }
  
  // Updated Error View
  Widget _buildErrorView(BuildContext context) {
     final Color errorColor = Colors.red.shade300;
     final Color primaryColor = _getProducerColor();
     final TextStyle titleStyle = GoogleFonts.poppins(
         fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]);
     final TextStyle messageStyle = GoogleFonts.poppins(color: Colors.grey[600]);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: errorColor),
            const SizedBox(height: 16),
            Text('Oups ! Une erreur...', style: titleStyle),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Impossible de charger les données.',
              textAlign: TextAlign.center,
              style: messageStyle,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadConversations(showLoading: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                 foregroundColor: Colors.white, backgroundColor: primaryColor,
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Rounded button
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Updated Conversation Options Modal
  void _showConversationOptions(Map<String, dynamic> conversation) {
    final bool isGroup = conversation['isGroup'] ?? false;
    final String convName = conversation['name'] ?? 'Conversation';
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkTheme ? Colors.grey.shade900 : Colors.white, // Adapt background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)), // More rounded
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0), // Reduced vertical padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Optional: Add a drag handle
              Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10)
                ),
              ),
              // Title for context
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                 child: Text(
                   convName,
                   style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                   textAlign: TextAlign.center,
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
               const Divider(height: 1),
              // Options
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Notifications (Bientôt)'), // Indicate WIP
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Gestion des notifications par conversation bientôt disponible.')),
                  );
                },
              ),
              if (isGroup)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: const Text('Ajouter des participants'),
                  onTap: () {
                    Navigator.pop(context);
                    _addParticipantsToGroup(conversation);
                  },
                ),
              if (isGroup)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Renommer le groupe'),
                  onTap: () {
                    Navigator.pop(context);
                    _renameGroup(conversation);
                  },
                ),
               const Divider(height: 1), // Divider before destructive action
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text('Supprimer la conversation', style: TextStyle(color: Colors.red.shade400)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteConversation(conversation);
                },
              ),
              const SizedBox(height: 10), // Add space at the bottom
            ],
          ),
        );
      },
    );
  }
  
  // Add Participants - Placeholder, needs UI/Logic
  void _addParticipantsToGroup(Map<String, dynamic> conversation) async {
      // TODO: Implement participant selection UI
      // 1. Navigate to a screen/show a dialog to search/select users/producers
      //    - Could reuse `_buildSearchInterfaceForCurrentTab` logic or a dedicated screen
      //    - Need to get a list of selected participant IDs (List<String> newParticipantIds)
      List<String>? newParticipantIds = await _selectParticipants(); // Placeholder for selection logic

      if (newParticipantIds != null && newParticipantIds.isNotEmpty) {
          final String conversationId = conversation['id'];
           try {
              print("➕ Tentative d'ajout de participants: $newParticipantIds à $conversationId");
              // Assuming conversationService has this method
              await _conversationService.addParticipantsToGroup(conversationId, newParticipantIds);

              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Participants ajoutés avec succès')),
              );
               _loadConversations(showLoading: false); // Refresh list
          } catch (e) {
              print("❌ Erreur ajout participants: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de l\'ajout: ${e.toString()}')),
              );
          }
      } else {
         print("ℹ️ Ajout de participants annulé ou aucun sélectionné.");
      }
  }

  // Placeholder for participant selection UI
  Future<List<String>?> _selectParticipants() async {
      // This should navigate to a new screen or show a complex dialog
      // allowing the user to search and select multiple contacts.
      // Returns a list of selected user/producer IDs.
      print("⚠️ _selectParticipants: UI non implémentée.");
       ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Sélection des participants non implémentée')),
       );
      return null; // Return null indicating no selection for now
  }
  
  // Rename Group - Connects to service
  void _renameGroup(Map<String, dynamic> conversation) {
    final TextEditingController nameController = TextEditingController(text: conversation['name']);
    final String conversationId = conversation['id'];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renommer le groupe'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nouveau nom'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                 final String newName = nameController.text.trim();
                 Navigator.pop(context); // Close dialog immediately

                 if (newName.isNotEmpty && newName != conversation['name']) {
                     try {
                         print("✏️ Tentative de renommer $conversationId en '$newName'");
                         // Assuming conversationService has this method - Commenting out as it doesn't exist
                         // await _conversationService.updateGroupInfo(conversationId, newName);
                         ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Groupe renommé avec succès (Simulation)')), // Updated message
                         );
                         _loadConversations(showLoading: false); // Refresh list
                     } catch (e) {
                          print("❌ Erreur renommage groupe: $e");
                         ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur renommage: ${e.toString()}')),
                         );
                     }
                 } else if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Le nom ne peut pas être vide')),
                     );
                 }
              },
              child: const Text('Renommer'),
            ),
          ],
        );
      },
    );
  }
  
  // Confirm Delete - No changes needed here
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
                _deleteConversation(conversation); // Call the delete method
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  
  // Delete Conversation - Connects to service
  void _deleteConversation(Map<String, dynamic> conversation) async {
    final String conversationId = conversation['id'];
    // Optimistically remove from UI first
    final int originalIndex = _conversations.indexWhere((conv) => conv['id'] == conversationId);
    Map<String, dynamic>? removedConversation;
    if (originalIndex != -1) {
        setState(() {
            removedConversation = _conversations.removeAt(originalIndex);
             _filterConversations(); // Update UI based on current tab/filter
        });
    }

    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
           content: Text('"${conversation['name']}" supprimée.'),
           action: SnackBarAction( // Add undo option
              label: 'Annuler',
              onPressed: () {
                if (removedConversation != null && originalIndex != -1) {
                    setState(() {
                       _conversations.insert(originalIndex, removedConversation!);
                       _filterConversations();
                    });
                 }
              },
           ),
        ),
    );
    
    try {
        print("🗑️ Tentative de suppression de la conversation $conversationId via API");
        // *** UNCOMMENTED API CALL ***
        await _conversationService.deleteConversation(conversationId, widget.producerId); // Use widget.producerId
        print("✅ Suppression API réussie pour $conversationId");
        // No need to reload conversations if API succeeds, UI already updated
    } catch (e) {
        print("❌ Erreur suppression API conversation $conversationId: $e");
        // Revert UI change if API fails and we have the data
         if (removedConversation != null && originalIndex != -1) {
            setState(() {
                 _conversations.insert(originalIndex, removedConversation!);
                 _filterConversations();
            });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: Impossible de supprimer "${conversation['name']}".')),
        );
    }
  }
  
  // View Contact Profile - No changes needed here
  void _viewContactProfile(Map<String, dynamic> contact) {
    final String contactId = contact['id'] ?? '';
    final String contactType = contact['type'] ?? 'user';
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
          builder: (context) => MyWellnessProducerProfileScreen(
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
      print('⚠️ Type de profil inconnu: $contactType');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil de $contactName non disponible (type: $contactType)')),
      );
    }
  }

  // Start Conversation - Refined logging and error handling
  void _startConversation(Contact contact) async {
     HapticFeedback.lightImpact();
     if (contact.id == null || contact.id!.isEmpty) {
         print("❌ Impossible de démarrer: ID de contact invalide.");
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de démarrer la conversation (ID manquant).'))
         );
         return;
     }
     
     // Prevent starting conversation with self
     if (contact.id == widget.producerId) {
          print("❌ Impossible de démarrer une conversation avec soi-même.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous ne pouvez pas discuter avec vous-même.'))
         );
          return;
     }

     print("🚀 Démarrage conversation: Producteur (${widget.producerId}) -> Contact (${contact.name} - ${contact.id})");
      
     // Optional: Show a temporary loading indicator
     // showDialog(context: context, builder: (_) => Center(child: CircularProgressIndicator()));

     try {
         // Use the appropriate method based on whether we're dealing with a producer
         final Map<String, dynamic> result;
         if (widget.producerType != null && widget.producerType.isNotEmpty) {
             print("🔍 Utilisation de createProducerConversation avec type: ${widget.producerType}");
             result = await _conversationService.createProducerConversation(
                 widget.producerId,
                 contact.id!,
                 widget.producerType,
             );
         } else {
             print("🔍 Utilisation de createOrGetConversation (standard)");
             result = await _conversationService.createOrGetConversation(
                 widget.producerId,
                 contact.id!,
             );
         }

         // if (Navigator.canPop(context)) Navigator.pop(context); // Close loading indicator

         print("✅ Résultat conversation: $result");
         
         final conversationId = result['conversationId'] ?? result['conversation_id'] ?? result['_id'];
         
         if (conversationId == null || conversationId.isEmpty) {
             print("❌ ID de conversation non trouvé dans la réponse API.");
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Erreur: Impossible de récupérer l\'ID de la conversation.'))
             );
             return;
         }
         
         print("✅ Navigation vers ConversationDetailScreen (ID: $conversationId)");

         // Check if conversation already exists in the list to avoid duplicates visually before refresh
         bool conversationExists = _conversations.any((c) => c['id'] == conversationId);

         Navigator.push(
             context,
             MaterialPageRoute(
                 builder: (context) => ConversationDetailScreen(
                     conversationId: conversationId,
                     userId: widget.producerId, // Producer is the current user
                     recipientName: contact.name ?? "Contact",
                     recipientAvatar: contact.avatar ?? "", // Pass empty if null
                     isGroup: false, // It's a 1-on-1 conversation
                      isProducer: true, // The current user is a producer
                 ),
             ),
         ).then((_) {
             // Refresh conversations after returning, unless it already existed
             if (!conversationExists) {
                  _loadConversations(showLoading: false);
             }
          });

     } catch (e) {
         print("❌ Erreur lors de _startConversation: $e");
          // if (Navigator.canPop(context)) Navigator.pop(context); // Close loading indicator
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: Impossible de démarrer la conversation. ${e.toString().split(':').last}')),
         );
     }
  }

  // Main filtering logic - updates _filteredConversations based on current tab
  void _filterConversations() {
     List<Map<String, dynamic>> baseList;
      switch (_tabController.index) {
          case 1: baseList = _userConversations; break;
          case 2: baseList = _sameTypeProducerConversations; break;
          case 3: baseList = _restaurantProducerConversations; break;
          case 4: baseList = _leisureProducerConversations; break;
          case 5: baseList = _wellnessProducerConversations; break;
          default: baseList = _conversations; // Tab 0: Toutes
      }

      // Apply search text filter if not in API search mode
      if (!_showSearchInterface) {
         final String filterText = _searchController.text.toLowerCase();
         if (filterText.isEmpty) {
             _filteredConversations = List.from(baseList); // Use a copy
         } else {
            _filteredConversations = baseList.where((conv) {
                final name = (conv['name'] ?? '').toLowerCase();
                final lastMessage = (conv['lastMessage'] ?? '').toLowerCase();
                return name.contains(filterText) || lastMessage.contains(filterText);
            }).toList();
         }
      } else {
         // When search interface is active, the conversation list just shows the base list for the tab
         // The search results are handled separately in _buildSearchInterfaceForCurrentTab
         _filteredConversations = List.from(baseList);
      }

      // No need to call setState here if called within another setState or build method
      // If called from elsewhere (like _loadConversations), ensure setState is called afterwards.
  }
  
  // Removed _filterContactsByTab as search is now handled by _searchContacts directly based on tab index
  
  // Removed auxiliary search methods (_searchAllContacts, _searchUserContacts, _searchProducersByType)
  // as the logic is now consolidated within _searchContacts.
} 

// Assuming Contact model exists somewhere like this:
/*
class Contact {
  final String? id;
  final String? name;
  final String? avatar;
  final String? type;

  Contact({this.id, this.name, this.avatar, this.type});
}
*/
