import 'dart:convert';
import 'package:http/http.dart' as http;
import 'utils/constants.dart' as constants;
import 'dart:io';
import 'package:flutter/material.dart';

/*
 * Utilitaire de test pour vérifier la connexion à l'API
 * Exécuter ce fichier pour diagnostiquer les problèmes de connectivité 
 * entre l'application Flutter et le serveur backend
 */

class TestApiScreen extends StatefulWidget {
  const TestApiScreen({Key? key}) : super(key: key);

  @override
  _TestApiScreenState createState() => _TestApiScreenState();
}

class _TestApiScreenState extends State<TestApiScreen> {
  String _result = 'Cliquez sur un bouton pour tester';
  bool _isLoading = false;

  // Toujours utiliser l'URL de production
  final String apiUrl = 'https://api.choiceapp.fr';

  // Test d'une requête API simple
  Future<void> _testApi() async {
    setState(() {
      _isLoading = true;
      _result = 'Envoi de la requête...';
    });

    try {
      final response = await http.get(Uri.parse('$apiUrl/api/health-check'));
      
      setState(() {
        _isLoading = false;
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _result = 'Succès! Réponse: ${data.toString()}';
        } else {
          _result = 'Erreur ${response.statusCode}: ${response.body}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Exception: $e';
      });
    }
  }

  // Test de connexion à différentes URLs
  Future<void> _testConnectivity() async {
    setState(() {
      _isLoading = true;
      _result = 'Test de connectivité en cours...';
    });

    final urls = [
      'https://api.choiceapp.fr'
    ];

    final results = <String>[];

    for (final url in urls) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 5),
          onTimeout: () => http.Response('Timeout', 408),
        );
        
        final status = response.statusCode == 200 ? 'OK' : 'KO (${response.statusCode})';
        results.add('$url: $status');
      } catch (e) {
        results.add('$url: Erreur - $e');
      }
    }

    setState(() {
      _isLoading = false;
      _result = results.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test API'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testApi,
              child: const Text('Tester l\'API'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnectivity,
              child: const Text('Tester la connectivité'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Text(_result),
            ),
          ],
        ),
      ),
    );
  }
}

// Fonction min pour String
int min(int a, int b) {
  return a < b ? a : b;
}

// Exception personnalisée pour les timeouts
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() {
    return message;
  }
} 