import 'package:flutter/material.dart';

class RestaurantStatsScreen extends StatelessWidget {
  final String producerId;

  const RestaurantStatsScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: Colors.teal, // Couleur indicative
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Icon(Icons.bar_chart_rounded, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 24),
        const Text(
                'Fonctionnalité en Développement',
                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                 textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
              Text(
                'Accédez bientôt à des statistiques détaillées sur vos ventes, vos clients, la popularité de vos plats et bien plus encore.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
                ),
               const SizedBox(height: 32),
              ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Retour"),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
              )
            ],
          ),
        ),
      ),
    );
  }
} 