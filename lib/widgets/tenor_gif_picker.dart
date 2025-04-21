import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart' show getImageProvider;

class TenorGifPicker extends StatefulWidget {
  @override
  _TenorGifPickerState createState() => _TenorGifPickerState();
}

class _TenorGifPickerState extends State<TenorGifPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _gifUrls = [];
  bool _isLoading = false;
  String _error = '';

  // Mets ta clé Tenor ici (crée un compte sur https://tenor.com/gifapi/documentation)
  static const String _tenorApiKey = 'LIVDSRZULELA'; // Remplace par ta vraie clé !

  @override
  void initState() {
    super.initState();
    _searchGifs('funny'); // Recherche par défaut
  }

  Future<void> _searchGifs(String query) async {
    setState(() {
      _isLoading = true;
      _error = '';
      _gifUrls = [];
    });
    try {
      final url = Uri.parse('https://tenor.googleapis.com/v2/search?q=$query&key=$_tenorApiKey&limit=24&media_filter=gif');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        setState(() {
          _gifUrls = results
              ?.map((item) => item['media_formats']?['gif']?['url'] as String?)
              .where((url) => url != null)
              .cast<String>()
              .toList() ?? [];
        });
      } else {
        setState(() {
          _error = 'Erreur Tenor: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un GIF',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (q) => _searchGifs(q.trim()),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchGifs(_searchController.text.trim()),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_error, style: TextStyle(color: Colors.red)),
            ),
          if (!_isLoading && _gifUrls.isNotEmpty)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _gifUrls.length,
                itemBuilder: (context, index) {
                  final url = _gifUrls[index];
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: getImageProvider(url) != null
                          ? Image(
                              image: getImageProvider(url)!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                    ),
                  );
                },
              ),
            ),
          if (!_isLoading && _gifUrls.isEmpty && _error.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Aucun GIF trouvé.'),
            ),
        ],
      ),
    );
  }
} 