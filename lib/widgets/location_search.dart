import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import '../utils/utils.dart' show getImageProvider;
import '../utils/api_config.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LocationSearch extends StatefulWidget {
  final String type; // 'restaurant' or 'event' or 'beautyPlace'
  final Function(Map<String, dynamic>) onLocationSelected;

  const LocationSearch({
    Key? key,
    required this.type,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  _LocationSearchState createState() => _LocationSearchState();
}

class _LocationSearchState extends State<LocationSearch> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Utiliser l'API unified pour tous les types
      final String endpoint = '/api/unified/search';
      final String typeParam = widget.type == 'restaurant' 
          ? 'restaurant' 
          : widget.type == 'event' 
              ? 'event' 
              : 'beautyPlace';
      
      final String baseUrl = await constants.getBaseUrl(); 
      final String apiUrl = '$baseUrl$endpoint?query=$query&type=$typeParam';
      
      print('>>> LocationSearch: Attempting to call API: $apiUrl');
      
      final response = await http.get(
        Uri.parse(apiUrl),
      );

      print('>>> LocationSearch: API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        print('>>> LocationSearch: API Error Response Body: ${response.body}');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Erreur lors de la recherche. Code: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('>>> LocationSearch: Exception caught in _search: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Impossible de se connecter au serveur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400, // Hauteur fixe pour résoudre le problème de contrainte non bornée
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _getHintText(),
                prefixIcon: Icon(
                  _getIconData(),
                  color: Theme.of(context).primaryColor,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                if (value.length > 2) {
                  _search(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_hasError)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_searchResults.isEmpty && !_isLoading && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Aucun résultat trouvé pour "${_searchController.text}"',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final location = _searchResults[index];
                  final String title = location['name'] ?? 'Lieu inconnu';
                  final String subtitle = location['address'] ?? 'Adresse inconnue';
                  final String? imageUrl = location['avatar'] ?? location['image_url'] ?? location['image'];

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => widget.onLocationSelected(location),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Image
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade300,
                                    child: Icon(
                                      _getIconData(),
                                      color: Colors.grey.shade600,
                                      size: 40,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade300,
                                    child: Icon(
                                      _getIconData(),
                                      color: Colors.grey.shade600,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getIconData(),
                                  color: Colors.grey.shade600,
                                  size: 40,
                                ),
                              ),
                            const SizedBox(width: 16),
                            // Information
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
                                    subtitle,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Additional info
                                  if (location['rating'] != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${location['rating']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                ],
                              ),
                            ),
                            // Indicateur visuel de sélection
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to get the appropriate icon based on the type
  IconData _getIconData() {
    switch (widget.type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'event':
        return Icons.event;
      case 'beautyPlace':
        return Icons.spa;
      default:
        return Icons.location_on;
    }
  }

  // Helper method to get the appropriate hint text based on the type
  String _getHintText() {
    switch (widget.type) {
      case 'restaurant':
        return 'Rechercher un restaurant...';
      case 'event':
        return 'Rechercher un événement...';
      case 'beautyPlace':
        return 'Rechercher un établissement de bien-être...';
      default:
        return 'Rechercher...';
    }
  }
}