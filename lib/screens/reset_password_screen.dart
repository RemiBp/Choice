import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import '../services/auth_service.dart';
import 'login_user.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isObscure = true;
  bool _isObscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/newuser/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': widget.token,
          'newPassword': _passwordController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Réinitialisation réussie
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Rediriger vers la page de connexion
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginUserPage()),
            (route) => false,
          );
        });
      } else {
        // Erreur de réinitialisation
        final data = json.decode(response.body);
        setState(() {
          _errorMessage = data['message'] ?? 'Une erreur est survenue lors de la réinitialisation du mot de passe.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur de connexion. Veuillez vérifier votre connexion internet et réessayer.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réinitialiser le mot de passe'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo et titre
                const SizedBox(height: 20),
                Image.asset(
                  'assets/logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Définir un nouveau mot de passe',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Veuillez entrer votre nouveau mot de passe ci-dessous.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 30),

                // Formulaire
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Nouveau mot de passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isObscure,
                        decoration: InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          hintText: 'Entrez votre nouveau mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isObscure = !_isObscure;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un mot de passe';
                          } else if (value.length < 6) {
                            return 'Le mot de passe doit contenir au moins 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Confirmer mot de passe
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _isObscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                          hintText: 'Confirmez votre nouveau mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscureConfirm ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isObscureConfirm = !_isObscureConfirm;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer votre mot de passe';
                          } else if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                      
                      // Message d'erreur
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 30),
                      
                      // Bouton de réinitialisation
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator()
                              : const Text(
                                  'Réinitialiser le mot de passe',
                                  style: TextStyle(fontSize: 16),
                                ),
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
    );
  }
} 