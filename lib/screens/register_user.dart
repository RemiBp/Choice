import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:choice_app/main.dart';
import 'utils.dart';
import 'login_user.dart'; // Pour le lien vers la connexion
import 'onboarding_screen.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({Key? key}) : super(key: key);

  @override
  _RegisterUserPageState createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;

  Future<void> registerUser() async {

    try {
      setState(() {
        _isLoading = true;
      });

      // Vérification des champs vides
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Vérification que les mots de passe correspondent
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les mots de passe ne correspondent pas')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Vérification des termes et conditions
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez accepter les termes et conditions')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Utiliser AuthService pour l'inscription
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Préparer les centres d'intérêt 
      final List<String> initialTags = []; // Vide par défaut, sera rempli lors de l'onboarding
      
      // Appeler la méthode register d'AuthService
      final result = await authService.register(
        name, 
        email, 
        password,
        gender: 'Non spécifié', // Pourrait être ajouté comme champ dans le formulaire
        likedTags: initialTags,
      );
      
      // Vérification du statut
      if (result['success']) {
        final userId = result['userId'];
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé avec succès !')),
        );

        // Navigation vers l'écran d'onboarding pour les nouveaux utilisateurs
        // Les nouveaux utilisateurs ont toujours besoin d'onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(
              userId: userId,
              accountType: 'user', // Par défaut, les nouveaux comptes sont de type 'user'
            ),
          ),
        );
      } else {
        // Gérer les différents types d'erreurs
        final message = result['message'] ?? 'Erreur lors de l\'inscription';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion au serveur : ${e.toString()}')),
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
        title: const Text('Créer un compte'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Créez votre compte',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rejoignez notre communauté et découvrez les meilleurs restaurants et loisirs près de chez vous.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Registration card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name field
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Nom complet',
                              prefixIcon: const Icon(Icons.person, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (value) => name = value,
                            validator: (value) => 
                              value!.isEmpty ? 'Veuillez entrer votre nom complet' : null,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Email field
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) => email = value,
                            validator: (value) => 
                              value!.isEmpty ? 'Veuillez entrer votre email' : null,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Password field
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock, color: Colors.green),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            obscureText: _obscurePassword,
                            onChanged: (value) => password = value,
                            validator: (value) => 
                              value!.isEmpty ? 'Veuillez entrer un mot de passe' : 
                              value.length < 6 ? 'Le mot de passe doit contenir au moins 6 caractères' : null,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Confirm password field
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Confirmer le mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            obscureText: _obscureConfirmPassword,
                            onChanged: (value) => confirmPassword = value,
                            validator: (value) => 
                              value!.isEmpty ? 'Veuillez confirmer votre mot de passe' :
                              value != password ? 'Les mots de passe ne correspondent pas' : null,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Terms and conditions checkbox
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (value) {
                                    setState(() {
                                      _termsAccepted = value ?? false;
                                    });
                                  },
                                  activeColor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _termsAccepted = !_termsAccepted;
                                    });
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      text: 'J\'accepte les ',
                                      style: TextStyle(color: Colors.grey[700]),
                                      children: [
                                        TextSpan(
                                          text: 'termes et conditions',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Register button
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.green))
                              : ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      registerUser();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Créer mon compte',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Login link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Vous avez déjà un compte ?',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => LoginUserPage()),
                          );
                        },
                        child: const Text('Se connecter'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
