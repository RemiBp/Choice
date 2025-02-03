import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:choice_app/main.dart'; // Assurez-vous que MainNavigation est bien importé

class LoginUserPage extends StatefulWidget {
  @override
  _LoginUserPageState createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool _isLoading = false;

  Future<void> loginUser() async {
    // URL de l'API pour se connecter
    const String apiUrl = 'http://10.0.2.2:5000/api/newuser/login';

    try {
      setState(() {
        _isLoading = true;
      });

      print('--- DEBUG: Fonction loginUser() déclenchée ---');

      // Vérification des champs vides
      if (email.isEmpty || password.isEmpty) {
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
      print('Email : $email, Mot de passe : $password');

      final requestPayload = {
        'email': email,
        'password': password,
      };
      print('--- DEBUG: Payload envoyé au serveur : $requestPayload');

      // Effectuer la requête POST avec timeout
      final response = await http
          .post(
            Uri.parse(apiUrl),
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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['user']['_id']; // Récupération de l'userId
        print('--- DEBUG: Réponse JSON décodée avec userId : $userId ---');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bienvenue ${data['user']['name']} !')),
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
      appBar: AppBar(title: const Text('Se connecter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
                        print('--- DEBUG: Bouton "Se connecter" cliqué ---');
                        if (_formKey.currentState!.validate()) {
                          print('--- DEBUG: Validation réussie ---');
                          loginUser();
                        } else {
                          print('--- DEBUG: Validation échouée ---');
                        }
                      },
                      child: const Text('Se connecter'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

