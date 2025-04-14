import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../services/conversation_service.dart';
import '../models/contact.dart';
import 'conversation_detail_screen.dart';

class GroupCreationScreen extends StatefulWidget {
  final String userId;
  final String producerType; // 'restaurant', 'leisureProducer', 'wellnessProducer'
  
  const GroupCreationScreen({
    Key? key, 
    required this.userId,
    required this.producerType,
  }) : super(key: key);

  @override
  _GroupCreationScreenState createState() => _GroupCreationScreenState();
}

class _GroupCreationScreenState extends State<GroupCreationScreen> with SingleTickerProviderStateMixin {
  final ConversationService _conversationService = ConversationService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  
  List<Contact> _searchResults = [];
  List<Contact> _selectedUsers = [];
  bool _isSearching = false;
  bool _isCreatingGroup = false;
  bool _showErrorMessage = false;
  String _errorMessage = '';
  
  // Couleurs pour les différents types de recherche
  final Map<String, Color> _typeColors = {
    'users': Colors.blue,
    'restaurants': Colors.orange,
    'leisure': Colors.purple,
  };
  
  // Icônes pour les différents types de recherche
  final Map<String, IconData> _typeIcons = {
    'users': Icons.person,
    'restaurants': Icons.restaurant,
    'leisure': Icons.sports_volleyball,
  };
  
  late TabController _tabController;
  String _searchType = 'users'; // 'users', 'restaurants', 'leisure'
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _searchType = 'users';
            break;
          case 1:
            _searchType = 'restaurants';
            break;
          case 2:
            _searchType = 'leisure';
            break;
        }
        _searchResults = [];
      });
      if (_searchController.text.isNotEmpty) {
        _searchContacts(_searchController.text);
      }
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    _tabController.dispose();
    super.dispose();
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
      _showErrorMessage = false;
    });
    
    try {
      final response = await _conversationService.searchParticipants(query, _searchType);
      
      setState(() {
        _searchResults = (response['results'] as List)
            .map((result) => Contact(
                  id: result['id'],
                  name: result['name'],
                  avatar: result['avatar'],
                  type: result['type'],
                  address: result['address'],
                ))
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      print('Erreur lors de la recherche: $e');
      setState(() {
        _isSearching = false;
        _showErrorMessage = true;
        _errorMessage = 'La recherche a échoué. Veuillez réessayer.';
      });
    }
  }
  
  void _selectContact(Contact contact) {
    // Ne pas ajouter de doublons
    if (_selectedUsers.any((user) => user.id == contact.id)) {
      return;
    }
    
    setState(() {
      _selectedUsers.add(contact);
    });
  }
  
  void _removeContact(String id) {
    setState(() {
      _selectedUsers.removeWhere((user) => user.id == id);
    });
  }
  
  Future<void> _createGroup() async {
    if (_groupNameController.text.isEmpty) {
      setState(() {
        _showErrorMessage = true;
        _errorMessage = 'Veuillez entrer un nom pour le groupe';
      });
      return;
    }
    
    if (_selectedUsers.isEmpty) {
      setState(() {
        _showErrorMessage = true;
        _errorMessage = 'Veuillez sélectionner au moins un participant';
      });
      return;
    }
    
    setState(() {
      _isCreatingGroup = true;
      _showErrorMessage = false;
    });
    
    try {
      // S'assurer que tous les IDs sont non-null avant de les passer
      final List<String> nonNullParticipantIds = _selectedUsers
          .where((user) => user.id != null)
          .map((user) => user.id!)
          .toList();
      
      final result = await _conversationService.createGroup(
        widget.userId,
        nonNullParticipantIds,
        _groupNameController.text,
      );
      
      setState(() {
        _isCreatingGroup = false;
      });
      
      if (result['success'] == true) {
        // Naviguer vers la conversation
        Navigator.pop(context); // Retourner à l'écran précédent
        
        // Accéder à la conversation créée
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationDetailScreen(
              conversationId: result['conversation_id'],
              userId: widget.userId,
              recipientName: _groupNameController.text,
              recipientAvatar: result['groupAvatar'] ?? 'https://via.placeholder.com/150',
              isGroup: true,
              participants: result['participants'],
            ),
          ),
        );
      } else {
        setState(() {
          _showErrorMessage = true;
          _errorMessage = result['message'] ?? 'La création du groupe a échoué.';
        });
      }
    } catch (e) {
      print('Erreur lors de la création du groupe: $e');
      setState(() {
        _isCreatingGroup = false;
        _showErrorMessage = true;
        _errorMessage = 'La création du groupe a échoué. Veuillez réessayer.';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un groupe'),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.person), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.restaurant), text: 'Restaurants'),
            Tab(icon: Icon(Icons.sports_volleyball), text: 'Loisirs'),
          ],
          indicatorColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          // Nom du groupe
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Nom du groupe',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          
          // Affichage des participants sélectionnés
          if (_selectedUsers.isNotEmpty)
            Container(
              height: 90,
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = _selectedUsers[index];
                  final contactColor = _getColorForContactType(user.type);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundImage: CachedNetworkImageProvider(
                                user.avatar ?? 'https://via.placeholder.com/150',
                              ),
                              backgroundColor: contactColor.withOpacity(0.2),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => _removeContact(user.id!),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          _truncateText(user.name ?? 'Contact', 10),
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher des participants',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                if (value.length >= 2) {
                  _searchContacts(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),
          
          // Message d'erreur
          if (_showErrorMessage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            ),
          
          // Résultats de recherche
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Recherchez des utilisateurs ou producteurs à ajouter'
                              : 'Aucun résultat trouvé',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final contact = _searchResults[index];
                          final isSelected = _selectedUsers.any((user) => user.id == contact.id);
                          final contactColor = _getColorForContactType(contact.type);
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                contact.avatar ?? 'https://via.placeholder.com/150',
                              ),
                              backgroundColor: contactColor.withOpacity(0.2),
                            ),
                            title: Text(contact.name ?? 'Contact'),
                            subtitle: contact.address != null && contact.address!.isNotEmpty
                                ? Text(contact.address!, maxLines: 1, overflow: TextOverflow.ellipsis)
                                : null,
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: Colors.green)
                                : Icon(Icons.add_circle_outline, color: Colors.grey),
                            onTap: () => _selectContact(contact),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingGroup ? null : _createGroup,
        icon: Icon(Icons.group_add),
        label: Text('Créer le groupe'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
  
  Color _getColorForContactType(String? type) {
    if (type == null) return Colors.blue;
    return _typeColors[type] ?? Colors.blue;
  }
  
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }
} 
