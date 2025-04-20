import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/wellness_service.dart';
import '../models/wellness_producer.dart';
import 'package:intl/intl.dart';
// Import user_service si nécessaire, sinon commenter ou retirer
// import '../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/api_config.dart';

class RegisterWellnessProducerPage extends StatefulWidget {
  const RegisterWellnessProducerPage({Key? key}) : super(key: key);

  @override
  _RegisterWellnessProducerPageState createState() => _RegisterWellnessProducerPageState();
}

class _RegisterWellnessProducerPageState extends State<RegisterWellnessProducerPage> {
  final _formKey = GlobalKey<FormState>();
  final _wellnessService = WellnessService();
  
  // Contrôleurs pour les champs du formulaire
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  
  // Variables d'état
  String _selectedCategory = '';
  String _selectedSousCategory = '';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  Map<String, dynamic>? _categories;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _wellnessService.getWellnessCategories();
      setState(() {
        _categories = Map<String, dynamic>.from(categories as Map);
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des catégories: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)));
      });
    }
  }

  Future<Map<String, dynamic>> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      throw Exception('Impossible d\'obtenir la position: $e');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Obtenir la position actuelle
      final location = await _getCurrentLocation();

      // Préparer les données du producteur
      final producerData = {
        'name': _nameController.text,
        'category': _selectedCategory,
        'sous_categorie': _selectedSousCategory,
        'address': _addressController.text,
        'gps_coordinates': location,
        'phone': _phoneController.text,
        'website': _websiteController.text,
        'photos': [], // Les photos seront gérées séparément
        'notes': {},
        'last_updated': DateTime.now().toIso8601String(),
        'creation_date': DateTime.now().toIso8601String(),
      };

      // Créer le producteur
      final producer = await _wellnessService.createWellnessProducer(producerData);

      // Gérer l'upload des photos si nécessaire
      if (_selectedImages.isNotEmpty) {
        // TODO: Implémenter l'upload des photos
      }

      // Rediriger vers la page de profil
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/wellness-profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'inscription: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inscription Producteur Bien-être',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nom de l'établissement
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'établissement',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom de l\'établissement';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Catégorie
              DropdownButtonFormField<String>(
                value: _selectedCategory.isEmpty ? null : _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categories?.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.key),
                  );
                }).toList() ?? [],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value ?? '';
                    _selectedSousCategory = '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner une catégorie';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Sous-catégorie
              if (_selectedCategory.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSousCategory.isEmpty ? null : _selectedSousCategory,
                  decoration: InputDecoration(
                    labelText: 'Sous-catégorie',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _categories?[_selectedCategory]?['sous_categories']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList() ?? [],
                  onChanged: (value) {
                    setState(() {
                      _selectedSousCategory = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez sélectionner une sous-catégorie';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 20),

              // Adresse
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Adresse',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer l\'adresse';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Téléphone
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // Site web
              TextFormField(
                controller: _websiteController,
                decoration: InputDecoration(
                  labelText: 'Site web (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),

              // Photos
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: Text('Ajouter des photos (${_selectedImages.length})'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Bouton d'inscription
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'S\'inscrire',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }
} 