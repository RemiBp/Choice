import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io'; // Pour File si non-web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data'; // Pour Uint8List
import 'dart:convert'; // Pour base64Decode
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Pour MediaType

import '../services/auth_service.dart';
import '../utils/utils.dart'; // Pour getBaseUrl

class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage; // Image sélectionnée
  Uint8List? _pickedImageBytes; // Bytes pour affichage web/mobile

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
      final token = await authService.getTokenInstance();
      final url = Uri.parse('${getBaseUrl()}/api/users/${widget.userId}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userData = data;
          _nameController.text = data['name'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load user data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des données: $e';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedImage = image;
          _pickedImageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection de l'image: $e"),
        ),
      );
    }
  }

  ImageProvider? _getImageProvider() {
    // Priorité à l'image fraîchement sélectionnée
    if (_pickedImageBytes != null) {
      return MemoryImage(_pickedImageBytes!);
    }
    // Sinon, image actuelle de l'utilisateur
    final currentPhotoUrl = _userData?['photo_url'];
    if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) {
       if (currentPhotoUrl.startsWith('data:image')) {
        try {
          final commaIndex = currentPhotoUrl.indexOf(',');
          if (commaIndex != -1) {
            final base64String = currentPhotoUrl.substring(commaIndex + 1);
            final bytes = base64Decode(base64String);
            return MemoryImage(bytes);
          }
        } catch (e) {
          print('Erreur décodage base64 pour profil: $e');
          return null; // Fallback
        }
      } else if (currentPhotoUrl.startsWith('http')) {
        return CachedNetworkImageProvider(currentPhotoUrl);
      }
    }
    // Fallback si aucune image
    return null;
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
        final token = await authService.getTokenInstance();
        if (token == null) {
          throw Exception('Token not available');
        }

        final url = Uri.parse('${getBaseUrl()}/api/users/${widget.userId}');
        var request = http.MultipartRequest('PUT', url);
        request.headers['Authorization'] = 'Bearer $token';

        // Ajouter les champs texte
        request.fields['name'] = _nameController.text;
        request.fields['bio'] = _bioController.text;

        // Ajouter l'image si elle a été modifiée
        if (_pickedImage != null && _pickedImageBytes != null) {
           request.files.add(
             http.MultipartFile.fromBytes(
               'profilePicture', // Nom du champ attendu par le backend
               _pickedImageBytes!,
               filename: _pickedImage!.name,
               contentType: MediaType('image', _pickedImage!.mimeType?.split('/').last ?? 'jpeg'), // Extrait l'extension
             )
           );
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis à jour avec succès!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); // Retourne true pour indiquer qu'il faut rafraîchir
        } else {
           final errorData = json.decode(response.body);
          throw Exception('Failed to update profile: ${response.statusCode} - ${errorData['message'] ?? response.body}');
        }

      } catch (e) {
        setState(() {
          _errorMessage = 'Erreur lors de la sauvegarde: $e';
        });
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
          );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final imageProvider = _getImageProvider();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                : const Icon(Icons.save),
            tooltip: 'Enregistrer',
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _userData == null // Afficher erreur seulement si pas de données initiales
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                         const SizedBox(height: 10),
                        ElevatedButton(onPressed: _fetchUserData, child: const Text('Réessayer'))
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: imageProvider,
                                child: imageProvider == null
                                  ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                                  : null,
                              ),
                              Material(
                                color: Theme.of(context).primaryColor,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _pickImage,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom',
                            border: OutlineInputBorder(),
                             prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre nom';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _bioController,
                          decoration: const InputDecoration(
                            labelText: 'Bio',
                            hintText: 'Parlez un peu de vous...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info_outline),
                          ),
                          maxLines: 3,
                           validator: (value) {
                             // La bio peut être vide
                            return null;
                          },
                        ),
                        const SizedBox(height: 32.0),
                         // Afficher l'erreur de sauvegarde ici aussi si nécessaire
                        if (_errorMessage != null && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_alt),
                          label: Text(_isSaving ? 'Sauvegarde...' : 'Enregistrer les modifications'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
} 