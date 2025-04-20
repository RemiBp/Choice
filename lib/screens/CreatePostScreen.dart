import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils.dart' show getImageProvider;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;

class CreatePostScreen extends StatefulWidget {
  final String userId;

  const CreatePostScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _mediaUrl;
  String? _mediaType;
  bool _isLoading = false;
  String? _selectedLocationId;
  String? _selectedLocationType;
  String? _selectedLocationName;
  List<dynamic> _searchResults = [];

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrlSync()}/api/unified/search?query=$query');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List<dynamic>;
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun résultat trouvé.')),
        );
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur réseau : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadMedia(bool isImage) async {
    final XFile? mediaFile = await (isImage
        ? _picker.pickImage(source: ImageSource.gallery, imageQuality: 50)
        : _picker.pickVideo(source: ImageSource.gallery));

    if (mediaFile != null) {
      final mediaPath = kIsWeb ? mediaFile.path : mediaFile.path;
      final mediaType = isImage ? "image" : "video";

      setState(() {
        _mediaUrl = mediaPath;
        _mediaType = mediaType;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun fichier sélectionné.')),
      );
    }
  }

  Future<void> _createPost() async {
    final content = _contentController.text;

    if (content.isEmpty || _selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le contenu et sélectionner un lieu.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> postData = {
        'userId': widget.userId,
        'content': content,
        'linkedId': _selectedLocationId,
        'linkedType': _selectedLocationType,
      };

      if (_mediaUrl != null) {
        postData['media'] = [_mediaUrl];
      }

      final url = Uri.parse('${constants.getBaseUrlSync()}/api/posts');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post créé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un post'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: !_isLoading ? _createPost : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contenu du post
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Qu\'avez-vous à partager ?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Recherche de lieu
            TextField(
              controller: _locationNameController,
              onChanged: _performSearch,
              decoration: const InputDecoration(
                hintText: 'Rechercher un lieu...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Résultats de recherche
            if (_searchResults.isNotEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final name = result['name'] ?? 'Sans nom';
                    final type = result['type'] ?? 'Lieu';
                    final id = result['_id'] ?? '';

                    return ListTile(
                      title: Text(name),
                      subtitle: Text(type),
                      onTap: () {
                        setState(() {
                          _selectedLocationId = id;
                          _selectedLocationType = type;
                          _selectedLocationName = name;
                          _locationNameController.text = name;
                          _searchResults = [];
                        });
                      },
                    );
                  },
                ),
              ),

            // Lieu sélectionné
            if (_selectedLocationName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, color: Colors.teal.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedLocationName!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedLocationId = null;
                          _selectedLocationType = null;
                          _selectedLocationName = null;
                          _locationNameController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Upload de média
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _uploadMedia(true),
                  icon: const Icon(Icons.photo),
                  label: const Text('Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _uploadMedia(false),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Vidéo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            // Aperçu du média
            if (_mediaUrl != null) ...[
              const SizedBox(height: 24),
              _mediaType == 'image'
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Builder(
                              builder: (context) {
                                final imageProvider = getImageProvider(_mediaUrl);
                                if (imageProvider != null) {
                                  return Image(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print("❌ Error loading post preview image: $error");
                                      return Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[600]));
                                    },
                                  );
                                } else {
                                  return Center(child: Icon(Icons.image, size: 50, color: Colors.grey[500]));
                                }
                              }
                            ),
                          ),
                          // Bouton de suppression
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _mediaUrl = null;
                                  _mediaType = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      height: 200,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.video_file, size: 48),
                      ),
                    ),
            ],

            const SizedBox(height: 24),

            // Bouton publier
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: !_isLoading ? _createPost : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('PUBLIER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 