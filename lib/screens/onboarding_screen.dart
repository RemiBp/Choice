import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'dart:io';

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final String accountType;

  const OnboardingScreen({
    Key? key, 
    required this.userId, 
    required this.accountType
  }) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  List<String> _selectedTags = [];
  bool _contactsPermissionGranted = false;
  bool _isLoading = false;
  
  // Liste de tags disponibles pour le user
  final List<String> _availableTags = [
    'Restaurants', 'Cuisine française', 'Gastronomie', 'Italien', 'Japonais',
    'Théâtre', 'Concerts', 'Expositions', 'Musées', 'Cinéma',
    'Nature', 'Sport', 'Bien-être', 'Famille', 'Entre amis',
    'Romantique', 'Afterwork', 'Brunch', 'Dîner', 'Déjeuner',
    'Végétarien', 'Vegan', 'Bio', 'Healthy', 'Street food',
    'Bar à vins', 'Cocktails', 'Ambiance', 'Vue', 'Terrasse',
    'Musique', 'Danse', 'Art', 'Photo', 'Design',
    'Tradition', 'Innovation', 'Luxe', 'Bon plan', 'Économique'
  ];
  
  // Liste simulée de contacts
  final List<Map<String, String>> _simulatedContacts = [
    {'name': 'Alice Dupont', 'phoneNumber': '+33 6 12 34 56 78'},
    {'name': 'Bruno Martin', 'phoneNumber': '+33 6 23 45 67 89'},
    {'name': 'Caroline Petit', 'phoneNumber': '+33 6 34 56 78 90'},
    {'name': 'David Lemaire', 'phoneNumber': '+33 6 45 67 89 01'},
    {'name': 'Emma Dubois', 'phoneNumber': '+33 6 56 78 90 12'},
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      // Gestion des erreurs
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection de l\'image: $e')),
      );
    }
  }

  void _toggleTagSelection(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _simulateContactsAccess() async {
    // Simulation d'une demande d'autorisation
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _contactsPermissionGranted = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accès aux contacts autorisé (simulation)')),
    );
  }

  Future<void> _completeOnboarding() async {
    if (_selectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un centre d\'intérêt')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService();
      
      String? photoUrl;
      
      // Upload de la photo de profil si elle existe
      if (_profileImage != null) {
        photoUrl = await apiService.uploadImage(_profileImage!.path);
      }
      
      // Enregistrement des préférences utilisateur
      final result = await authService.completeOnboarding(
        widget.userId,
        photoUrl,
        _selectedTags,
        _contactsPermissionGranted,
      );
      
      if (result['success']) {
        // Navigation vers l'écran principal
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userId: widget.userId,
              accountType: widget.accountType,
            ),
          ),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${result['message']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenue sur Choice'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() {
                    _currentStep += 1;
                  });
                } else {
                  _completeOnboarding();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() {
                    _currentStep -= 1;
                  });
                }
              },
              steps: [
                // Étape 1: Photo de profil
                Step(
                  title: const Text('Photo de profil'),
                  content: Column(
                    children: [
                      const Text(
                        'Choisissez une photo de profil pour personnaliser votre compte',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? const Icon(Icons.add_a_photo, size: 40)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  isActive: _currentStep == 0,
                ),
                
                // Étape 2: Centres d'intérêt
                Step(
                  title: const Text('Centres d\'intérêt'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sélectionnez vos centres d\'intérêt pour personnaliser votre feed',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _availableTags.map((tag) {
                          return FilterChip(
                            label: Text(tag),
                            selected: _selectedTags.contains(tag),
                            onSelected: (selected) {
                              _toggleTagSelection(tag);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  isActive: _currentStep == 1,
                ),
                
                // Étape 3: Accès aux contacts
                Step(
                  title: const Text('Contacts'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Permettez à Choice d\'accéder à vos contacts pour vous aider à retrouver vos proches',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      if (!_contactsPermissionGranted)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.people),
                          label: const Text('Autoriser l\'accès aux contacts'),
                          onPressed: _simulateContactsAccess,
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contacts disponibles (simulation):',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(
                              _simulatedContacts.length,
                              (index) => ListTile(
                                leading: CircleAvatar(
                                  child: Text(_simulatedContacts[index]['name']![0]),
                                ),
                                title: Text(_simulatedContacts[index]['name']!),
                                subtitle: Text(_simulatedContacts[index]['phoneNumber']!),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  isActive: _currentStep == 2,
                ),
              ],
            ),
    );
  }
}
