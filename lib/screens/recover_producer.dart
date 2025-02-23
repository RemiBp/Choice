import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; // Importez votre MainNavigation si nécessaire
import 'utils.dart';

class RecoverProducerPage extends StatefulWidget {
  const RecoverProducerPage({Key? key}) : super(key: key);

  @override
  _RecoverProducerPageState createState() => _RecoverProducerPageState();
}

class _RecoverProducerPageState extends State<RecoverProducerPage> {
  final _formKey = GlobalKey<FormState>();
  String producerId = '';

  /// Détermine le type de compte en fonction du préfixe de l'ID.
  String _determineAccountType(String producerId) {
    if (producerId.startsWith('675')) {
      return 'RestaurantProducer';
    } else if (producerId.startsWith('676')) {
      return 'LeisureProducer';
    } else {
      return 'UnknownProducer';
    }
  }

  Future<void> recoverProducer() async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/api/newuser/register-or-recover'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'producerId': producerId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Détermine le type de compte à partir de l'ID
        final accountType = _determineAccountType(producerId);

        // Naviguer vers MainNavigation avec les bons paramètres
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userId: producerId,
              accountType: accountType,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Récupérer un compte producer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Producer ID'),
                onChanged: (value) => producerId = value,
                validator: (value) =>
                    value!.isEmpty ? 'Veuillez entrer un ID producer' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    recoverProducer();
                  }
                },
                child: const Text('Récupérer le compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
