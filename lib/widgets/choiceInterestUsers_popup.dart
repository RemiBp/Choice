import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/map_service.dart'; // À adapter si le service est ailleurs
import '../providers/user_provider.dart'; // Pour récupérer les followings
import '../models/user_model.dart'; // Si nécessaire pour typer les données user

class ChoiceInterestUsersPopup extends StatefulWidget {
  final String targetId;
  final String targetType; // 'event', 'venue', etc.
  final ScrollController scrollController;

  const ChoiceInterestUsersPopup({
    Key? key,
    required this.targetId,
    required this.targetType,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<ChoiceInterestUsersPopup> createState() => _ChoiceInterestUsersPopupState();
}

class _ChoiceInterestUsersPopupState extends State<ChoiceInterestUsersPopup> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _interactingUsers = []; // Liste de tous les utilisateurs
  List<Map<String, dynamic>> _followingUsers = []; // Utilisateurs suivis
  List<Map<String, dynamic>> _otherUsers = []; // Autres utilisateurs
  String? _errorMessage;
  Set<String> _currentUserFollowingIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Récupérer la liste des followings de l'utilisateur actuel
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // Essayer de récupérer les followings depuis userData
       _currentUserFollowingIds = Set<String>.from(
         // Essayer d'abord userData['following'] qui pourrait être une liste d'IDs
         (userProvider.userData?['following'] as List?)?.map((f) => f.toString()) 
         // Sinon, essayer userData['connections']?['following'] qui pourrait être une liste d'objets
         ?? (userProvider.userData?['connections']?['following'] as List?)
              ?.map((conn) => (conn is Map ? conn['userId']?.toString() : null))
              ?.where((id) => id != null).cast<String>() 
         ?? [] // Retourner un Set vide si aucune des structures n'est trouvée
       );
       print('🔑 IDs Followings récupérés: ${_currentUserFollowingIds.length}');


      // 2. Récupérer la liste des utilisateurs ayant interagi (API à créer/utiliser)
      final mapService = MapService(); // Ou le service approprié
      // *** APPEL API FICTIF - À REMPLACER ***
      _interactingUsers = await mapService.getInteractingUsers(widget.targetId, widget.targetType); 
      // Exemple de structure attendue pour chaque user dans la liste :
      // { 'userId': 'id123', 'username': 'Alice', 'profilePicture': 'url...', 'interactionType': 'choice'/'interest' }

      // 3. Séparer les utilisateurs en deux listes
      _followingUsers = [];
      _otherUsers = [];
      for (var user in _interactingUsers) {
        if (_currentUserFollowingIds.contains(user['userId']?.toString())) {
          _followingUsers.add(user);
        } else {
          _otherUsers.add(user);
        }
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print("❌ Erreur chargement données popup: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur lors du chargement des utilisateurs.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0, bottom: 16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Titre
          const Text(
            'Personnes ayant interagi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Contenu
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
                    : _interactingUsers.isEmpty
                        ? const Center(child: Text("Personne n'a encore interagi ici."))
                        : _buildUserLists(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserLists() {
    // Utiliser une ListView externe avec le controller pour le DraggableScrollableSheet
    return ListView(
      controller: widget.scrollController, // Utiliser le controller passé
      children: [
        if (_followingUsers.isNotEmpty) ...[
          _buildSectionTitle('Personnes que vous suivez (${_followingUsers.length})'),
          ..._followingUsers.map((user) => _buildUserTile(user)).toList(),
          const SizedBox(height: 24), // Espace entre les sections
        ],
        if (_otherUsers.isNotEmpty) ...[
          _buildSectionTitle('Autres personnes (${_otherUsers.length})'),
          ..._otherUsers.map((user) => _buildUserTile(user)).toList(),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['userId']?.toString();
    final username = user['username'] ?? 'Utilisateur inconnu';
    final profilePicture = user['profilePicture'] ?? '';
    final interactionType = user['interactionType']; // 'choice' or 'interest'

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: profilePicture.isNotEmpty ? NetworkImage(profilePicture) : null,
        child: profilePicture.isEmpty ? const Icon(Icons.person, size: 20) : null,
        backgroundColor: Colors.grey[200],
      ),
      title: Text(username),
      trailing: Icon(
        interactionType == 'choice' ? Icons.check_circle_outline : Icons.favorite_border,
        color: interactionType == 'choice' ? Colors.blue : Colors.pinkAccent,
        size: 20,
      ),
      onTap: () {
        if (userId != null) {
          print("Navigating to profile: $userId");
          // Fermer la modale avant de naviguer
          Navigator.pop(context); 
          Navigator.pushNamed(context, '/profile', arguments: {'userId': userId});
        }
      },
      contentPadding: EdgeInsets.symmetric(vertical: 4.0),
    );
  }
} 