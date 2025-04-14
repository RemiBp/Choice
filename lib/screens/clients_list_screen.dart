import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart' as constants;

class ClientsListScreen extends StatefulWidget {
  final String producerId;

  const ClientsListScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  // Récupérer la liste des clients
  Future<void> _fetchClients() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Pour l'instant, on utilise des données fictives car l'API n'est pas en place
      await Future.delayed(const Duration(seconds: 1)); // Simuler un temps de chargement
      
      setState(() {
        _clients = List.generate(20, (index) => {
          'id': 'client-$index',
          'name': 'Client ${index + 1}',
          'email': 'client${index + 1}@example.com',
          'phone': '+33 6 ${10000000 + index * 11111}',
          'visits': (index % 5) + 1,
          'lastVisit': DateTime.now().subtract(Duration(days: index)),
          'totalSpent': (100 + index * 20).toDouble(),
          'avatar': 'https://randomuser.me/api/portraits/${index % 2 == 0 ? 'men' : 'women'}/${(index % 70) + 1}.jpg',
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Erreur lors du chargement des clients: $e';
      });
      print('❌ Erreur lors du chargement des clients: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Clients', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orangeAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Fonction de recherche (à implémenter)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recherche à implémenter')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchClients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                        onPressed: _fetchClients,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _clients.length,
                        itemBuilder: (context, index) {
                          final client = _clients[index];
                          return _buildClientCard(client);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        child: const Icon(Icons.add),
        onPressed: () {
          // Fonction pour ajouter un client manuellement (à implémenter)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ajout de client à implémenter')),
          );
        },
      ),
    );
  }

  // Barre de filtres
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Trier par:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: 'recent',
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'recent', child: Text('Plus récent')),
              DropdownMenuItem(value: 'oldest', child: Text('Plus ancien')),
              DropdownMenuItem(value: 'visits', child: Text('Nb. visites')),
              DropdownMenuItem(value: 'spent', child: Text('Dépenses')),
            ],
            onChanged: (value) {
              // Fonction de tri (à implémenter)
            },
          ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.filter_list),
            label: const Text('Filtrer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              side: const BorderSide(color: Colors.orangeAccent),
            ),
            onPressed: () {
              // Afficher les options de filtrage (à implémenter)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filtres à implémenter')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Carte client
  Widget _buildClientCard(Map<String, dynamic> client) {
    final lastVisitDate = client['lastVisit'] as DateTime;
    final formattedDate = '${lastVisitDate.day}/${lastVisitDate.month}/${lastVisitDate.year}';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(client['avatar']),
        ),
        title: Text(
          client['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${client['visits']} visites'),
            Text('Dernière visite: $formattedDate'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${client['totalSpent']} €',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Total dépensé',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        onTap: () {
          // Afficher le détail du client (à implémenter)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Détails de ${client['name']}')),
          );
        },
      ),
    );
  }
} 