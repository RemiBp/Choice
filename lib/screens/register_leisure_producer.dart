import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../main.dart';
import 'utils.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/constants.dart' as constants;

class RegisterLeisureProducerPage extends StatefulWidget {
  const RegisterLeisureProducerPage({Key? key}) : super(key: key);

  @override
  _RegisterLeisureProducerPageState createState() => _RegisterLeisureProducerPageState();
}

class _RegisterLeisureProducerPageState extends State<RegisterLeisureProducerPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _termsAccepted = false;
  final ImagePicker _picker = ImagePicker();
  File? _logoImage;
  File? _venueImage;

  // Form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  String _activityType = 'Sport';
  final List<String> _activityTypes = [
    'Sport', 'Spectacle', 'Musée', 'Cinéma', 'Théâtre', 
    'Parc d\'attractions', 'Atelier', 'Concert', 'Exposition', 'Autre'
  ];
  
  String _ageGroup = 'Tout public';
  final List<String> _ageGroups = ['Enfants', 'Adolescents', 'Adultes', 'Seniors', 'Tout public'];
  
  // Facilities checkboxes
  bool _hasParking = false;
  bool _isAccessible = false;
  bool _hasRestaurant = false;
  bool _hasWiFi = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLogo) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (isLogo) {
          _logoImage = File(image.path);
        } else {
          _venueImage = File(image.path);
        }
      });
    }
  }

  Future<void> _registerLeisureProducer() async {
    if (!_formKey.currentState!.validate() || !_termsAccepted) {
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez accepter les conditions d\'utilisation')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Construire l'URL pour l'inscription
    final baseUrl = await constants.getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/producers/register/leisure');
    
    try {
      // Créer le body de la requête
      final Map<String, dynamic> requestBody = {
        'name': _nameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'website': _websiteController.text,
        'description': _descriptionController.text,
        'activityType': _activityType,
        'ageGroup': _ageGroup,
        'facilities': {
          'parking': _hasParking,
          'accessible': _isAccessible,
          'restaurant': _hasRestaurant,
          'wifi': _hasWiFi,
        },
        'openingHours': {
          'monday': {'open': '09:00', 'close': '19:00'},
          'tuesday': {'open': '09:00', 'close': '19:00'},
          'wednesday': {'open': '09:00', 'close': '19:00'},
          'thursday': {'open': '09:00', 'close': '19:00'},
          'friday': {'open': '09:00', 'close': '21:00'},
          'saturday': {'open': '10:00', 'close': '21:00'},
          'sunday': {'open': '10:00', 'close': '19:00'},
        },
      };

      // Envoyer la requête
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String producerId = data['producerId'];
        
        // Auto-login après inscription réussie
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.login(_emailController.text, _passwordController.text);
        
        // Naviguer vers la page principale
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte loisir créé avec succès!')),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userId: producerId,
              accountType: 'LeisureProducer',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
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
        title: const Text('Inscription Producteur Loisir'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page header
                  const Text(
                    'Créez votre compte loisir',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Commencez à promouvoir vos activités et attirez de nouveaux clients',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Image upload section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Images de votre activité',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Logo upload
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickImage(true),
                                  child: Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: _logoImage != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              _logoImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.add_photo_alternate, size: 30, color: Colors.grey),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Logo',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickImage(false),
                                  child: Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: _venueImage != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              _venueImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.add_photo_alternate, size: 30, color: Colors.grey),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Photo principale',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Activity info card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations de l\'activité',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Activity name
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nom de l\'activité',
                              prefixIcon: const Icon(Icons.sports_tennis, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Veuillez entrer le nom de l\'activité' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // Activity type
                          DropdownButtonFormField<String>(
                            value: _activityType,
                            decoration: InputDecoration(
                              labelText: 'Type d\'activité',
                              prefixIcon: const Icon(Icons.category, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _activityTypes.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _activityType = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Age group
                          DropdownButtonFormField<String>(
                            value: _ageGroup,
                            decoration: InputDecoration(
                              labelText: 'Tranche d\'âge',
                              prefixIcon: const Icon(Icons.people, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _ageGroups.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _ageGroup = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Address
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Adresse',
                              prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Veuillez entrer l\'adresse' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: const Icon(Icons.description, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 3,
                            validator: (value) =>
                                value!.isEmpty ? 'Veuillez entrer une description' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Facilities card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Équipements et services',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Facilities checkboxes
                          CheckboxListTile(
                            title: const Text('Parking disponible'),
                            value: _hasParking,
                            onChanged: (bool? value) {
                              setState(() {
                                _hasParking = value!;
                              });
                            },
                            activeColor: Colors.green,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            title: const Text('Accès handicapé'),
                            value: _isAccessible,
                            onChanged: (bool? value) {
                              setState(() {
                                _isAccessible = value!;
                              });
                            },
                            activeColor: Colors.green,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            title: const Text('Restauration sur place'),
                            value: _hasRestaurant,
                            onChanged: (bool? value) {
                              setState(() {
                                _hasRestaurant = value!;
                              });
                            },
                            activeColor: Colors.green,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            title: const Text('WiFi gratuit'),
                            value: _hasWiFi,
                            onChanged: (bool? value) {
                              setState(() {
                                _hasWiFi = value!;
                              });
                            },
                            activeColor: Colors.green,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Contact info card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations de contact',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Email
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Veuillez entrer un email';
                              } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Veuillez entrer un email valide';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Téléphone',
                              prefixIcon: const Icon(Icons.phone, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value!.isEmpty ? 'Veuillez entrer un numéro de téléphone' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // Website
                          TextFormField(
                            controller: _websiteController,
                            decoration: InputDecoration(
                              labelText: 'Site web (optionnel)',
                              prefixIcon: const Icon(Icons.web, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Account security card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sécurité du compte',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Password
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock, color: Colors.green),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            obscureText: !_showPassword,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Veuillez entrer un mot de passe';
                              } else if (value.length < 6) {
                                return 'Le mot de passe doit contenir au moins 6 caractères';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Confirm password
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Confirmer le mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            obscureText: !_showPassword,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Veuillez confirmer votre mot de passe';
                              } else if (value != _passwordController.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Terms and conditions
                  CheckboxListTile(
                    value: _termsAccepted,
                    onChanged: (bool? value) {
                      setState(() {
                        _termsAccepted = value!;
                      });
                    },
                    title: const Text(
                      'J\'accepte les conditions d\'utilisation et la politique de confidentialité',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.green,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Register button
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.green))
                        : ElevatedButton(
                            onPressed: _registerLeisureProducer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Créer mon compte loisir',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Login link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Déjà un compte loisir?',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/recover'),
                          child: const Text(
                            'Récupérer',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}