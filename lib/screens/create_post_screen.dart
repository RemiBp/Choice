import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import '../utils/constants.dart' as constants;
import '../services/auth_service.dart'; // Import AuthService
import 'package:provider/provider.dart';


class CreatePostScreen extends StatefulWidget {
  final String producerId;

  const CreatePostScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _locationNameController = TextEditingController();
  String? _mediaUrl;
  String? _selectedLocationId;
  String? _selectedLocationType;
  String? _selectedLocationName;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _contentController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  Future<void> _uploadMedia(bool isImage) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final url = Uri.parse('${constants.getBaseUrl()}/api/upload');
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('media', pickedFile.path));

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final decodedData = json.decode(responseData);
          setState(() {
            _mediaUrl = decodedData['url']; // Assurez-vous que la clé est 'url'
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors du téléversement')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur réseau : $e')),
        );
      }
    }
  }


  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final url = Uri.parse('${constants.getBaseUrl()}/api/search?query=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la recherche.')),
        );
      }
    } catch (e) {
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau.')),
      );
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le contenu ne peut pas être vide.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    final url = Uri.parse('${constants.getBaseUrl()}/api/posts');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
        body: json.encode({
          'producerId': widget.producerId,
          'content': _contentController.text,
          'mediaUrl': _mediaUrl,
          'linkedLocationId': _selectedLocationId,
          'linkedLocationType': _selectedLocationType,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post créé avec succès!')),
        );
        Navigator.pop(context); // Retour à l'écran précédent
      } else {
        print('Erreur création post: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau.')),
      );
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedLocationId = null;
      _selectedLocationType = null;
      _selectedLocationName = null;
      _locationNameController.clear();
    });
  }

  Widget _buildMediaPreview() {
    if (_mediaUrl == null) return const SizedBox.shrink();

    // Pour le web, on utilise Image.network. Pour les autres plateformes,
    // on pourrait avoir besoin d'une gestion différente si l'URL n'est pas directement accessible.
    // Pour l'instant, on garde Image.network pour tous les cas.
    return Image.network(_mediaUrl!, height: 200, width: double.infinity, fit: BoxFit.cover);
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contenu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Partagez votre expérience...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rechercher un lieu associé',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _locationNameController,
              onChanged: _performSearch,
              enabled: _selectedLocationId == null, // Désactiver si un lieu est sélectionné
              decoration: const InputDecoration(
                hintText: 'Recherchez un restaurant ou un événement...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_searchResults.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView(
                  children: _searchResults.map((item) {
                    final String type = item['type'] ?? 'unknown';
                    final String name = item['name'] ?? item['intitulé'] ?? 'Nom inconnu';
                    final String imageUrl = item['photo'] ?? item['image'] ?? constants.getDefaultAvatarUrl();
                    final String id = item['_id'] ?? '';
                    
                    if (id.isEmpty) return const SizedBox.shrink();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(imageUrl),
                        onBackgroundImageError: (_, __) => print("Erreur image: $imageUrl"),
                      ),
                      title: Text(name),
                      subtitle: Text(type == 'producer' ? 'Restaurant' : 'Événement'),
                      onTap: () {
                        setState(() {
                          _selectedLocationId = id;
                          _selectedLocationType = type;
                          _selectedLocationName = name;
                          _searchResults = [];
                          _locationNameController.text = name;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            if (_selectedLocationId != null && _selectedLocationType != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Lieu sélectionné : $_selectedLocationName (Type : $_selectedLocationType)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _resetSelection,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Ajouter un média',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _uploadMedia(true), // isImage = true
                  child: const Text('Sélectionner une image'),
                ),
                // Pour l'instant, on désactive la vidéo, car la gestion est plus complexe
                // const SizedBox(width: 10),
                // ElevatedButton(
                //   onPressed: () => _uploadMedia(false), // isImage = false
                //   child: const Text('Sélectionner une vidéo'),
                // ),
              ],
            ),
            if (_mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildMediaPreview()
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createPost,
                    child: const Text('Poster'),
                  ),
          ],
        ),
      ),
    );
  }
} 