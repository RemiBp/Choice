import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:choice_app/main.dart'; // Assurez-vous que MainNavigation est bien importé
import 'utils.dart';

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
  bool _isLoading = false;

  Future<void> registerUser() async {
    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url;
    
    if (baseUrl.startsWith('http://')) {
      // Si c'est http://
      final domain = baseUrl.replaceFirst('http://', '');
      url = Uri.http(domain, '/api/newuser/register-or-recover');
    } else if (baseUrl.startsWith('https://')) {
      // Si c'est https://
      final domain = baseUrl.replaceFirst('https://', '');
      url = Uri.https(domain, '/api/newuser/register-or-recover');
    } else {
      // Utiliser Uri.parse comme solution de secours
      url = Uri.parse('$baseUrl/api/newuser/register-or-recover');
    }

    try {
      setState(() {
        _isLoading = true;
      });

      print('--- DEBUG: Fonction registerUser() déclenchée ---');

      // Vérification des champs vides
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        print('--- DEBUG: Champs vides détectés ---');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('--- DEBUG: Champs validés ---');
      print('Nom : $name, Email : $email, Mot de passe : $password');

      final requestPayload = {
        'name': name,
        'email': email,
        'password': password,
        'gender': 'Non spécifié', // Exemple par défaut
        'liked_tags': [], // Liste vide par défaut
      };
      print('--- DEBUG: Payload envoyé au serveur : $requestPayload');
      print('--- DEBUG: URL utilisée : $url');

      // Effectuer la requête POST avec timeout
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestPayload),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('--- DEBUG: Timeout de la requête détecté ---');
              throw Exception('Timeout de la requête');
            },
          );

      print('--- DEBUG: Réponse HTTP reçue ---');
      print('Statut HTTP : ${response.statusCode}');
      print('Corps de la réponse : ${response.body}');

      // Vérification du statut
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final userId = data['user']['_id']; // Récupération de l'userId
        print('--- DEBUG: Réponse JSON décodée avec userId : $userId ---');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compte créé pour ${data['user']['name']} !')),
        );

        // Navigation vers MainNavigation
        print('--- DEBUG: Navigation vers MainNavigation avec userId : $userId ---');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              print('--- DEBUG: Navigation réellement exécutée avec userId : $userId ---');
              return MainNavigation(userId: userId, accountType: 'user'); // Ajoutez accountType ici
            },
          ),
        );
      } else {
        final responseJson = jsonDecode(response.body);
        final error = responseJson['error'] ?? 'Erreur inconnue';
        print('--- DEBUG: Erreur renvoyée par le serveur : $error');
        print('--- DEBUG: Réponse complète : $responseJson');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $error')),
        );
      }
    } catch (e) {
      print('--- DEBUG: Exception attrapée lors de la requête ---');
      print('Type d\'exception : ${e.runtimeType}');
      print('Détails de l\'exception : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion au serveur : ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('--- DEBUG: Fin de la requête ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte utilisateur')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nom'),
                onChanged: (value) {
                  name = value;
                  print('Nom entré : $name');
                },
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  email = value;
                  print('Email entré : $email');
                },
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un email' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                onChanged: (value) {
                  password = value;
                  print('Mot de passe entré : $password');
                },
                validator: (value) => value!.length < 6 ? 'Mot de passe trop court' : null,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        print('--- DEBUG: Bouton "Créer mon compte" cliqué ---');
                        if (_formKey.currentState!.validate()) {
                          print('--- DEBUG: Validation réussie ---');
                          registerUser();
                        } else {
                          print('--- DEBUG: Validation échouée ---');
                        }
                      },
                      child: const Text('S\'inscrire'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
