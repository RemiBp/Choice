import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../services/auth_service.dart';
import '../utils/constants.dart' as constants;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils.dart' show getImageProvider; // Pour afficher l'image existante
import 'dart:io'; // Import dart:io for File


class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  // Ajouter d'autres contrôleurs si nécessaire (ex: social links)

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _userData; // Pour stocker les données actuelles

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Ensure widget is still mounted before starting async operations
    if (!mounted) return;
    setState(() => _isLoading = true);

    final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
    final token = await authService.getTokenInstance();
    final baseUrl = constants.getBaseUrlSync(); // Utilisation directe

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Non authentifié.";
      });
      return;
    }

    try {
      final url = Uri.parse('$baseUrl/api/users/${widget.userId}'); // Utiliser l'endpoint user normal
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10)); // Add timeout

      if (!mounted) return;

      if (response.statusCode == 200) {
        _userData = json.decode(response.body);
        // Use null-aware operators and provide defaults
        _nameController.text = _userData?['name'] ?? '';
        _bioController.text = _userData?['bio'] ?? '';
        _websiteController.text = _userData?['website'] ?? '';
        _currentProfileImageUrl = _userData?['profilePicture'] ?? _userData?['photo_url'];
        setState(() => _isLoading = false);
      } else {
         String errorMsg = "Erreur serveur";
         try { errorMsg = json.decode(response.body)['message'] ?? errorMsg; } catch (_) {}
         setState(() {
          _isLoading = false;
          _errorMessage = "Erreur chargement ($errorMsg)";
        });
      }
    } catch (e) {
       if (!mounted) return;
       setState(() {
        _isLoading = false;
        _errorMessage = "Erreur réseau: $e";
      });
       print("❌ Erreur chargement user data: $e");
    }
  }

   Future<void> _pickImage() async {
       try {
           final XFile? pickedFile = await _picker.pickImage(
               source: ImageSource.gallery,
               imageQuality: 70, // Ajuster la qualité
               maxWidth: 1024, // Réduire la taille
           );
           if (pickedFile != null) {
                if (!mounted) return;
               setState(() {
                   _pickedImage = pickedFile;
               });
           }
       } catch (e) {
           print("Erreur sélection image: $e");
            if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Erreur lors de la sélection de l'image: $e"))
           );
       }
   }

   Future<void> _saveProfile() async {
     if (!_formKey.currentState!.validate()) {
       return; // Ne pas soumettre si le formulaire est invalide
     }
     if (_isLoading) return; // Empêcher double soumission

      if (!mounted) return;
     setState(() {
       _isLoading = true;
       _errorMessage = null;
     });

     final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
     final token = await authService.getTokenInstance();
     final baseUrl = constants.getBaseUrlSync();

     if (token == null) {
        if (!mounted) return;
        setState(() { _isLoading = false; _errorMessage = "Non authentifié."; });
        return;
     }

     try {
         // --- TODO: Gestion de l'upload de l'image ---
         // 1. Si _pickedImage n'est pas null, uploader l'image vers le backend.
         //    Ceci nécessite un endpoint backend spécifique (ex: POST /api/upload/profile-picture)
         //    qui retourne l'URL de l'image uploadée.
         String? newImageUrl = _currentProfileImageUrl; // Garder l'ancienne par défaut
         if (_pickedImage != null) {
             // Placeholder: Remplacer par la vraie logique d'upload
             print("TODO: Uploader ${_pickedImage!.path}");
              ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Upload d'image à implémenter !"))
              );
              // Simuler un upload pour l'exemple
              // newImageUrl = "https://via.placeholder.com/150/new"; // Simuler une nouvelle URL
         }
         // --- Fin TODO ---


        final url = Uri.parse('$baseUrl/api/users/profile'); // Endpoint de mise à jour du profil
        final updates = {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'website': _websiteController.text.trim(),
           // Inclure l'URL de l'image (nouvelle ou ancienne)
          // S'assurer que la clé correspond au backend ('profilePicture' ou 'photo_url')
          if (newImageUrl != null) 'profilePicture': newImageUrl,
          // Ajouter d'autres champs si nécessaire
        };

        // Nettoyer les valeurs nulles ou vides si le backend ne les gère pas
        updates.removeWhere((key, value) => value == null || (value is String && value.isEmpty && key != 'bio'));


        final response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(updates),
        ).timeout(const Duration(seconds: 15)); // Timeout plus long pour l'update

         if (!mounted) return;

        if (response.statusCode == 200) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil mis à jour avec succès !'), backgroundColor: Colors.green)
           );
           Navigator.pop(context, true); // Retourner true pour indiquer succès
        } else {
           String errorMsg = "Erreur serveur";
           try { errorMsg = json.decode(response.body)['error'] ?? json.decode(response.body)['message'] ?? errorMsg; } catch (_) {}
            if (!mounted) return;
           setState(() {
              _isLoading = false;
              _errorMessage = "Erreur (${response.statusCode}): $errorMsg";
           });
           print("❌ Erreur sauvegarde profil: ${response.statusCode} - ${response.body}");
        }

     } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur réseau/timeout: $e";
        });
         print("❌ Exception sauvegarde profil: $e");
     }
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Enregistrer',
            // Désactiver si en cours de chargement ou si on n'a pas chargé les données initiales
            onPressed: (_isLoading && _userData == null) || _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: (_isLoading && _userData == null) // Afficher chargement seulement au début
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // Centrer la photo
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),

                    // Photo de profil
                    Stack(
                       alignment: Alignment.bottomRight,
                       children: [
                          CircleAvatar(
                             radius: 60,
                             backgroundColor: Colors.grey[200],
                             backgroundImage: _pickedImage != null
                                 ? FileImage(File(_pickedImage!.path)) as ImageProvider // Cast ImageProvider
                                 : (_currentProfileImageUrl != null && _currentProfileImageUrl!.isNotEmpty)
                                     ? CachedNetworkImageProvider(_currentProfileImageUrl!) // Utiliser CachedNetworkImageProvider
                                     : null, // Pas d'image par défaut spécifique ici
                              child: (_pickedImage == null && (_currentProfileImageUrl == null || _currentProfileImageUrl!.isEmpty))
                                   ? const Icon(Icons.person, size: 60, color: Colors.grey) // Icône si aucune image
                                   : null,
                          ),
                          // Bouton pour changer la photo
                          Material( // Pour l'effet d'ondulation
                              color: Colors.teal,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                 onTap: _pickImage,
                                 child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.edit, color: Colors.white, size: 20),
                                 ),
                              ),
                          )
                       ],
                    ),
                    const SizedBox(height: 24),

                    // Champ Nom
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Champ Bio
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                         hintText: 'Parlez un peu de vous...',
                        border: OutlineInputBorder(),
                         prefixIcon: Icon(Icons.info_outline),
                         alignLabelWithHint: true, // Pour que le label monte correctement
                      ),
                      maxLines: 4, // Augmenter un peu
                      maxLength: 200, // Limite de caractères
                    ),
                    const SizedBox(height: 16),

                    // Champ Site Web
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Site Web (optionnel)',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                       keyboardType: TextInputType.url,
                       // Optionnel: Ajouter un validateur d'URL plus strict si nécessaire
                    ),
                    const SizedBox(height: 24),

                    // --- TODO: Ajouter d'autres champs ici ---
                    // Par exemple:
                    // - Localisation (ville, pays)
                    // - Liens réseaux sociaux
                    // - Préférences (tags, secteurs)
                    // -----------------------------------------

                    // Bouton Enregistrer
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // Désactiver si déjà en cours de sauvegarde
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.teal,
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(vertical: 14), // Hauteur bouton
                           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        child: _isLoading // Afficher indicateur si en cours de sauvegarde
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('Enregistrer les modifications'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

   @override
   void dispose() {
      _nameController.dispose();
      _bioController.dispose();
      _websiteController.dispose();
      super.dispose();
   }
}

// Note: 'FileImage' requires 'dart:io', which is not available on web.
// For cross-platform compatibility, consider using packages like 'universal_io'
// or conditional imports (kIsWeb) to handle File operations.
// For simplicity here, we keep dart:io but add a note. 