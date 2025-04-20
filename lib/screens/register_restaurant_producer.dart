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

class RegisterRestaurantProducerPage extends StatefulWidget {
  const RegisterRestaurantProducerPage({Key? key}) : super(key: key);

  @override
  _RegisterRestaurantProducerPageState createState() => _RegisterRestaurantProducerPageState();
}

class _RegisterRestaurantProducerPageState extends State<RegisterRestaurantProducerPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _termsAccepted = false;
  final ImagePicker _picker = ImagePicker();
  File? _logoImage;
  File? _restaurantImage;

  // Form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  String _cuisineType = 'Française';
  final List<String> _cuisineTypes = [
    'Française', 'Italienne', 'Asiatique', 'Américaine', 'Méditerranéenne', 
    'Végétarienne', 'Mexicaine', 'Indienne', 'Japonaise', 'Autre'
  ];
  
  String _priceRange = '€€';
  final List<String> _priceRanges = ['€', '€€', '€€€', '€€€€'];

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
          _restaurantImage = File(image.path);
        }
      });
    }
  }

  Future<void> _registerRestaurantProducer() async {
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
    final Uri url = Uri.parse('$baseUrl/api/producers/register/restaurant');
    
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
        'cuisineType': _cuisineType,
        'priceRange': _priceRange,
        'openingHours': {
          'monday': {'open': '08:00', 'close': '22:00'},
          'tuesday': {'open': '08:00', 'close': '22:00'},
          'wednesday': {'open': '08:00', 'close': '22:00'},
          'thursday': {'open': '08:00', 'close': '22:00'},
          'friday': {'open': '08:00', 'close': '23:00'},
          'saturday': {'open': '08:00', 'close': '23:00'},
          'sunday': {'open': '10:00', 'close': '22:00'},
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
          const SnackBar(content: Text('Compte restaurateur créé avec succès!')),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userId: producerId,
              accountType: 'RestaurantProducer',
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
        title: const Text('Inscription Restaurateur'),
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
                    'Créez votre compte restaurateur',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Commencez à promouvoir votre restaurant et attirez de nouveaux clients',
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
                            'Images du restaurant',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
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
                                    child: _restaurantImage != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              _restaurantImage!,
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
                  
                  // Restaurant info card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations du restaurant',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Restaurant name
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nom du restaurant',
                              prefixIcon: const Icon(Icons.restaurant, color: Colors.deepOrange),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Veuillez entrer le nom du restaurant' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // Cuisine type
                          DropdownButtonFormField<String>(
                            value: _cuisineType,
                            decoration: InputDecoration(
                              labelText: 'Type de cuisine',
                              prefixIcon: const Icon(Icons.restaurant_menu, color: Colors.deepOrange),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _cuisineTypes.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _cuisineType = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Price range
                          DropdownButtonFormField<String>(
                            value: _priceRange,
                            decoration: InputDecoration(
                              labelText: 'Gamme de prix',
                              prefixIcon: const Icon(Icons.euro, color: Colors.deepOrange),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _priceRanges.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _priceRange = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Address
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Adresse',
                              prefixIcon: const Icon(Icons.location_on, color: Colors.deepOrange),
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
                              prefixIcon: const Icon(Icons.description, color: Colors.deepOrange),
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
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Email
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email, color: Colors.deepOrange),
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
                              prefixIcon: const Icon(Icons.phone, color: Colors.deepOrange),
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
                              prefixIcon: const Icon(Icons.web, color: Colors.deepOrange),
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
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Password
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock, color: Colors.deepOrange),
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
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepOrange),
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
                    activeColor: Colors.deepOrange,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Register button
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
                        : ElevatedButton(
                            onPressed: _registerRestaurantProducer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Créer mon compte restaurateur',
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
                          'Déjà un compte restaurateur?',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/recover'),
                          child: const Text(
                            'Récupérer',
                            style: TextStyle(color: Colors.deepOrange),
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