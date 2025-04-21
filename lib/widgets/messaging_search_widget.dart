import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/conversation_service.dart';
import '../utils.dart';

class MessagingSearchWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onConversationCreated;
  final String userId;
  final bool isDarkMode;

  const MessagingSearchWidget({
    Key? key, 
    required this.onConversationCreated,
    required this.userId,
    this.isDarkMode = false,
  }) : super(key: key);

  @override
  State<MessagingSearchWidget> createState() => _MessagingSearchWidgetState();
}

class _MessagingSearchWidgetState extends State<MessagingSearchWidget> {
  final _searchController = TextEditingController();
  final _conversationService = ConversationService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Filtres de recherche
  String _selectedType = 'all';
  final List<Map<String, dynamic>> _filterOptions = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.all_inclusive},
    {'id': 'restaurant', 'name': 'Restaurants', 'icon': Icons.restaurant},
    {'id': 'leisure', 'name': 'Loisirs', 'icon': Icons.sports_basketball},
    {'id': 'wellness', 'name': 'Bien-être', 'icon': Icons.spa},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchBusinesses(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.choiceapp.fr';
      
      // Construire la requête en fonction du filtre sélectionné
      String endpoint = '$baseUrl/api/unified/search?query=$query';
      if (_selectedType != 'all') {
        endpoint += '&type=${_selectedType}';
      }
      
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Formater les résultats pour l'affichage
        List<Map<String, dynamic>> formattedResults = [];
        
        for (var item in data) {
          // Déterminer le type de producteur
          String type = 'business';
          if (item.containsKey('type')) {
            type = item['type'];
          } else if (item.containsKey('category')) {
            type = item['category'];
          }
          
          // Ne garder que les résultats qui correspondent au filtre sélectionné
          if (_selectedType != 'all' && type != _selectedType) {
            continue;
          }
          
          // Construire l'objet résultat
          Map<String, dynamic> formattedResult = {
            '_id': item['_id'],
            'name': item['name'] ?? item['lieu'] ?? 'Sans nom',
            'type': type,
            'address': item['address'] ?? item['adresse'] ?? 'Adresse non disponible',
            'image': item['photo'] ?? item['image'] ?? '',
          };
          
          formattedResults.add(formattedResult);
        }
        
        setState(() {
          _searchResults = formattedResults;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Erreur lors de la recherche";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de connexion au serveur";
        _isLoading = false;
      });
    }
  }

  Future<void> _startConversation(Map<String, dynamic> business) async {
    final TextEditingController messageController = TextEditingController();
    bool sendingMessage = false;

    // Show dialog to get initial message
    final message = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            "Message à ${business['name']}",
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: "Tapez votre message initial...",
                  hintStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                maxLines: 3,
              ),
              if (sendingMessage)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: CircularProgressIndicator(),
                )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Annuler",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: sendingMessage 
                ? null 
                : () {
                    if (messageController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Veuillez saisir un message")),
                      );
                      return;
                    }
                    setDialogState(() {
                      sendingMessage = true;
                    });
                    Navigator.pop(context, messageController.text);
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
              ),
              child: const Text("Envoyer"),
            ),
          ],
        ),
      ),
    );

    if (message == null || message.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final conversation = await _conversationService.startConversationWithBusiness(
        widget.userId,
        business['_id'],
        business['type'],
        message
      );
      
      widget.onConversationCreated(conversation);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Conversation démarrée avec ${business['name']}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getBusinessTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
        return '🍽️';
      case 'leisure':
        return '🎭';
      case 'beauty':
        return '💇';
      case 'wellness':
        return '💆';
      default:
        return '🏢';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final Color subtitleColor = widget.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color primaryColor = widget.isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple;

    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Rechercher un établissement...",
              hintStyle: TextStyle(color: subtitleColor),
              prefixIcon: Icon(Icons.search, color: subtitleColor),
              suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: subtitleColor),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                      });
                    },
                  )
                : null,
              filled: true,
              fillColor: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _searchBusinesses,
          ),
        ),
        
        // Filtres en chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final bool isSelected = _selectedType == filter['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    selectedColor: primaryColor.withOpacity(0.2),
                    checkmarkColor: primaryColor,
                    backgroundColor: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filter['icon'] as IconData,
                          size: 16,
                          color: isSelected ? primaryColor : subtitleColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          filter['name'] as String,
                          style: TextStyle(
                            color: isSelected ? primaryColor : subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = filter['id'] as String;
                        if (_searchController.text.isNotEmpty) {
                          _searchBusinesses(_searchController.text);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        
        const SizedBox(height: 8.0),
        
        // Résultats de recherche
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          )
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                "Aucun résultat trouvé",
                style: TextStyle(color: subtitleColor),
              ),
            ),
          )
        else if (_searchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemBuilder: (context, index) {
                final business = _searchResults[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  color: cardColor,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(
                      color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 0.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    leading: CircleAvatar(
                      backgroundColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      child: Text(_getBusinessTypeIcon(business['type'])),
                    ),
                    title: Text(
                      business['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business['type'].toString().capitalizeFirst(),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                          ),
                        ),
                        if (business['address'] != null)
                          Text(
                            business['address'],
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: OutlinedButton.icon(
                      icon: Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text('Contacter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _startConversation(business),
                    ),
                    isThreeLine: business['address'] != null,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// Extension pour capitaliser la première lettre
extension StringExtension on String {
  String capitalizeFirst() {
    if (this.isEmpty) return this;
    return this[0].toUpperCase() + this.substring(1);
  }
} 