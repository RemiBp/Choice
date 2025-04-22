import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'register_user.dart';
import '../main.dart'; // Import pour MainNavigation
import 'onboarding_screen.dart';
import 'dart:convert';
import 'dart:async'; // Ajout de l'import pour TimeoutException
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginUserPage extends StatefulWidget {
  @override
  _LoginUserPageState createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Vérifier si les services Google Play sont disponibles
  Future<bool> _checkGooglePlayServices(BuildContext context) async {
    try {
      // Éviter d'utiliser canAccessScopes sur Android car non implémenté
      if (Platform.isAndroid) {
        // Sur Android, on essaie simplement de vérifier si GoogleSignIn est disponible
        final GoogleSignIn googleSignIn = GoogleSignIn();
        // Pas de vérification avec canAccessScopes - cette méthode n'est pas implémentée sur Android
        return true;
      } else {
        // Sur iOS, on peut utiliser la méthode normale
        final GoogleSignIn googleSignIn = GoogleSignIn();
        try {
          final isAvailable = await googleSignIn.canAccessScopes(['email', 'profile']);
          
          if (!isAvailable) {
            if (!mounted) return false;
            
            // Afficher un message si les services ne sont pas disponibles
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Les services Google Play ne sont pas disponibles sur cet appareil.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              )
            );
            return false;
          }
          return true;
        } catch (e) {
          print('Erreur lors de la vérification des services Google sur iOS: $e');
          return true; // On continue quand même
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification des services Google Play: $e');
      return true; // On continue malgré l'erreur pour tenter de se connecter
    }
  }

  Future<void> loginUser() async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.login(email, password);

      if (result['success']) {
        // La navigation sera gérée automatiquement par le Provider dans main.dart
        // Mais nous ajoutons une navigation explicite pour assurer la compatibilité iOS
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion réussie !')),
        );
        
        // Forcer la navigation vers l'écran principal ou l'onboarding
        // après un court délai pour permettre à l'état de se propager
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          
          // Vérifier si l'utilisateur a besoin de compléter l'onboarding
          if (result['needsOnboarding']) {
            // Rediriger vers l'écran d'onboarding
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => OnboardingScreen(
                  userId: result['userId'],
                  accountType: result['accountType'] ?? 'user',
                ),
              ),
              (route) => false,
            );
          } else {
            // Rediriger vers l'écran principal
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MainNavigation(
                  userId: authService.userId!,
                  accountType: authService.accountType!,
                ),
              ),
              (route) => false,
            );
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email ou mot de passe incorrect')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion : ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // Afficher un indicateur de chargement
      setState(() => _isLoading = true);
      
      // Vérifier d'abord si les services Google Play sont disponibles
      final servicesAvailable = await _checkGooglePlayServices(context);
      if (!servicesAvailable) {
        setState(() => _isLoading = false);
        // Montrer une option de connexion alternative
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Les services Google Play ne sont pas disponibles. Veuillez utiliser l\'email et mot de passe.'),
            duration: Duration(seconds: 6),
          )
        );
        return;
      }
      
      // Configurer les options avec un serverId pour résoudre les problèmes avec GMS
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // Utiliser le ID client correspondant à la plateforme
        serverClientId: Platform.isIOS 
            ? '429425452401-o80vo4lkd7psgss4rrmmfjsr1qad0ip1.apps.googleusercontent.com'
            : '429425452401-dibk2q2t0tlgpa2gpj2n2o8439qosdal.apps.googleusercontent.com',
      );
      
      // Tentative de connexion avec timeout
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException("La connexion Google a pris trop de temps");
        }
      );
      
      if (googleUser == null) {
        // L'utilisateur a annulé la connexion
        setState(() => _isLoading = false);
        return;
      }
      
      try {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        // Code temporaire pour afficher le token ID (à retirer après les tests)
        print('🔑 GOOGLE ID TOKEN (à copier pour Postman):');
        print(googleAuth.idToken);
        print('🔑 FIN DU TOKEN');
        
        // Vérifier si le token est valide
        if (googleAuth.idToken == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: Impossible de récupérer le token d\'authentification'))
          );
          setState(() => _isLoading = false);
          return;
        }
        
        // Envoyer les informations au backend
        final response = await http.post(
          Uri.parse('${constants.getBaseUrl()}/api/auth/google/token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'idToken': googleAuth.idToken,
            'email': googleUser.email,
            'name': googleUser.displayName,
            'photoUrl': googleUser.photoUrl,
          }),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Sauvegarder les informations d'authentification
          final authService = Provider.of<AuthService>(context, listen: false);
          
          // Mettre à jour l'AuthService
          await authService.updateUserInfo(
            userId: data['userId'],
            accountType: data['accountType'],
            token: data['token'],
          );
          
          // Sauvegarder dans SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', data['userId']);
          await prefs.setString('accountType', data['accountType']);
          await prefs.setString('userToken', data['token']);
          await prefs.setString('userPhoto', googleUser.photoUrl ?? '');
          
          // Récupération des données utilisateur
          final userId = data['userId'];
          final accountType = data['accountType'];
          final needsOnboarding = data['needsOnboarding'] ?? false;
          
          // Rediriger vers l'écran principal
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connexion réussie !'))
          );
          
          // Forcer la navigation vers l'écran principal
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            
            // Vérifier si l'utilisateur a besoin de compléter l'onboarding
            if (needsOnboarding) {
              // Rediriger vers l'écran d'onboarding
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen(
                    userId: userId,
                    accountType: accountType,
                  ),
                ),
                (route) => false,
              );
            } else {
              // Rediriger vers l'écran principal
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MainNavigation(
                    userId: userId,
                    accountType: accountType,
                  ),
                ),
                (route) => false,
              );
            }
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur d\'authentification: ${response.body}'))
          );
        }
      } catch (authError) {
        print('Erreur d\'authentification Google: $authError');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'authentification: $authError'))
        );
      }
    } catch (e) {
      print('Exception lors de la connexion Google: $e');
      
      // Gérer spécifiquement l'erreur API GMS
      String errorMessage = 'Erreur de connexion';
      
      if (e.toString().contains('ApiException: 10')) {
        // Erreur 10: Google Play services is missing or disabled
        errorMessage = 'Erreur de connexion Google: Services Google Play manquants ou désactivés. Vérifiez votre appareil.';
        print('⚠️ Diagnostic: Erreur 10 - Les services Google Play ne sont pas disponibles.');
      } else if (e.toString().contains('ApiException: 12')) {
        // Erreur 12: Connection failed due to network error
        errorMessage = 'Erreur de connexion Google: Problème de réseau. Vérifiez votre connexion internet.';
      } else if (e.toString().contains('ApiException: 13')) {
        // Erreur 13: Connection to Play Services failed
        errorMessage = 'Erreur de connexion Google: Impossible de se connecter aux services Google Play.';
        print('⚠️ Diagnostic: Erreur 13 - Problème de connexion aux services Google Play.');
      } else if (e.toString().contains('ApiException: 16')) {
        // Erreur 16: Google Play Services out of date
        errorMessage = 'Erreur de connexion Google: Services Google Play obsolètes. Mettez à jour Google Play.';
        print('⚠️ Diagnostic: Erreur 16 - Les services Google Play doivent être mis à jour.');
      } else if (e.toString().contains('PlatformException')) {
        errorMessage = 'Erreur de l\'appareil: Impossible d\'utiliser les services Google.';
        print('⚠️ Diagnostic PlatformException: ${e.toString()}');
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage))
      );
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
        title: const Text('Connexion'),
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
                  'Connectez-vous',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bienvenue ! Entrez vos identifiants pour vous connecter à votre compte.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Login card
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
                          // Email field
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email, color: Colors.blue),
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
                                borderSide: const BorderSide(color: Colors.blue),
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
                              prefixIcon: const Icon(Icons.lock, color: Colors.blue),
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
                                borderSide: const BorderSide(color: Colors.blue),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            obscureText: _obscurePassword,
                            onChanged: (value) => password = value,
                            validator: (value) => 
                              value!.isEmpty ? 'Veuillez entrer votre mot de passe' : 
                              value.length < 6 ? 'Le mot de passe doit contenir au moins 6 caractères' : null,
                          ),
                          
                          // Forgot password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                // Afficher une boîte de dialogue pour demander l'email
                                final TextEditingController emailController = TextEditingController();
                                
                                bool? result = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Réinitialisation du mot de passe'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Veuillez entrer votre adresse email pour recevoir un lien de réinitialisation de mot de passe.',
                                          ),
                                          const SizedBox(height: 16),
                                          TextFormField(
                                            controller: emailController,
                                            decoration: const InputDecoration(
                                              labelText: 'Email',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.emailAddress,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Envoyer'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                
                                if (result == true && emailController.text.isNotEmpty) {
                                  try {
                                    // Afficher un indicateur de chargement
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Envoi en cours...')),
                                    );
                                    
                                    // Envoyer la demande de réinitialisation
                                    final response = await http.post(
                                      Uri.parse('${constants.getBaseUrl()}/api/newuser/forgot-password'),
                                      headers: {'Content-Type': 'application/json'},
                                      body: json.encode({
                                        'email': emailController.text,
                                      }),
                                    );
                                    
                                    if (response.statusCode == 200) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Si cet email existe dans notre base de données, un message de récupération a été envoyé.'),
                                          duration: Duration(seconds: 5),
                                        ),
                                      );
                                    } else {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Une erreur est survenue. Veuillez réessayer plus tard.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur de connexion: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Login button
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                              : ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      loginUser();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Se connecter',
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
                
                // Register section
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Vous n\'avez pas de compte ?',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterUserPage()),
                          );
                        },
                        child: const Text('Créer un compte'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Divider with "or"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[400])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OU', style: TextStyle(color: Colors.grey[600])),
                    ),
                    Expanded(child: Divider(color: Colors.grey[400])),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Google sign-in button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton.icon(
                    icon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(2.0),
                          child: Image.asset(
                            'assets/images/google_logo.png', 
                            height: 32,
                            width: 32,
                            errorBuilder: (context, error, stackTrace) {
                              // Utiliser une icône Flutter si l'image n'est pas trouvée
                              return Icon(Icons.g_mobiledata, color: Colors.red, size: 32);
                            },
                          ),
                        ),
                      ),
                    ),
                    label: const Text('Se connecter avec Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _signInWithGoogle(context),
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

