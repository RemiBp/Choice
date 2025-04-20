import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/conversation_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String userId;

  const GroupDetailsScreen({
    Key? key,
    required this.groupId,
    required this.userId,
  }) : super(key: key);

  @override
  _GroupDetailsScreenState createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final ConversationService _conversationService = ConversationService();
  bool _isLoading = true;
  Map<String, dynamic> _groupInfo = {};
  List<Map<String, dynamic>> _participants = [];
  
  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }
  
  Future<void> _loadGroupDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Dans une vraie implémentation, récupérez les détails du groupe depuis le service
      // final details = await _conversationService.getConversationDetails(widget.groupId);
      
      // Pour la démo, nous simulons des données
      await Future.delayed(Duration(seconds: 1));
      
      final Map<String, dynamic> groupInfo = {
        'name': 'Groupe de discussion',
        'avatar': 'https://via.placeholder.com/150',
        'createdAt': DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
        'type': 'general',
      };
      
      final List<Map<String, dynamic>> participants = [
        {
          'id': widget.userId,
          'name': 'Vous (Admin)',
          'avatar': 'https://via.placeholder.com/150',
          'isAdmin': true,
        },
        {
          'id': 'user2',
          'name': 'Julie Martin',
          'avatar': 'https://via.placeholder.com/150',
          'isAdmin': false,
        },
        {
          'id': 'user3',
          'name': 'Thomas Dubois',
          'avatar': 'https://via.placeholder.com/150',
          'isAdmin': false,
        }
      ];
      
      setState(() {
        _groupInfo = groupInfo;
        _participants = participants;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des détails du groupe: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des détails')),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Détails du groupe',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'leave') {
                _showLeaveGroupConfirmation();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Quitter le groupe', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildGroupHeader(),
                  Divider(),
                  _buildParticipantsList(),
                  Divider(),
                  _buildGroupOptions(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildGroupHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: CachedNetworkImageProvider(_groupInfo['avatar']),
            backgroundColor: Colors.grey[200],
          ),
          SizedBox(height: 16),
          Text(
            _groupInfo['name'],
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${_participants.length} participants',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Créé le ${_formatDate(_groupInfo['createdAt'])}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildParticipantsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Participants',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _participants.length,
          itemBuilder: (context, index) {
            final participant = _participants[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(participant['avatar']),
                backgroundColor: Colors.grey[200],
              ),
              title: Text(
                participant['name'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: participant['isAdmin']
                  ? Text(
                      'Administrateur',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    )
                  : null,
              trailing: participant['id'] != widget.userId
                  ? IconButton(
                      icon: Icon(Icons.more_vert),
                      onPressed: () => _showParticipantOptions(participant),
                    )
                  : null,
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildGroupOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Options du groupe',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.edit),
          title: Text('Modifier le nom du groupe'),
          onTap: _showRenameGroupDialog,
        ),
        ListTile(
          leading: Icon(Icons.photo_camera),
          title: Text('Changer la photo du groupe'),
          onTap: () {
            // Implémenter la modification de la photo
          },
        ),
        ListTile(
          leading: Icon(Icons.person_add),
          title: Text('Ajouter des participants'),
          onTap: () {
            // Implémenter l'ajout de participants
          },
        ),
        ListTile(
          leading: Icon(Icons.notifications),
          title: Text('Notifications'),
          trailing: Switch(
            value: true,
            onChanged: (value) {
              // Implémenter la gestion des notifications
            },
          ),
        ),
      ],
    );
  }
  
  void _showParticipantOptions(Map<String, dynamic> participant) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(participant['avatar']),
                ),
                title: Text(participant['name']),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.message),
                title: Text('Envoyer un message privé'),
                onTap: () {
                  Navigator.pop(context);
                  // Implémenter l'envoi de message privé
                },
              ),
              ListTile(
                leading: Icon(Icons.admin_panel_settings),
                title: Text(participant['isAdmin'] ? 'Retirer les droits d\'admin' : 'Faire administrateur'),
                onTap: () {
                  Navigator.pop(context);
                  // Implémenter la gestion des droits d'admin
                },
              ),
              ListTile(
                leading: Icon(Icons.remove_circle_outline, color: Colors.red),
                title: Text('Retirer du groupe', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveParticipantConfirmation(participant);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showRenameGroupDialog() {
    final TextEditingController nameController = TextEditingController(text: _groupInfo['name']);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Renommer le groupe'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'Nom du groupe',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                
                if (nameController.text.trim().isNotEmpty) {
                  // Implémenter le renommage du groupe
                  setState(() {
                    _groupInfo['name'] = nameController.text.trim();
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Groupe renommé avec succès')),
                  );
                }
              },
              child: Text('Renommer'),
            ),
          ],
        );
      },
    );
  }
  
  void _showRemoveParticipantConfirmation(Map<String, dynamic> participant) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Retirer le participant'),
          content: Text('Êtes-vous sûr de vouloir retirer ${participant['name']} du groupe ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context);
                
                // Implémenter la suppression du participant
                setState(() {
                  _participants.removeWhere((p) => p['id'] == participant['id']);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${participant['name']} a été retiré du groupe')),
                );
              },
              child: Text('Retirer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  
  void _showLeaveGroupConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quitter le groupe'),
          content: Text('Êtes-vous sûr de vouloir quitter ce groupe ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context);
                // Implémenter la sortie du groupe
                Navigator.pop(context); // Retour à l'écran de conversation
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Vous avez quitté le groupe')),
                );
              },
              child: Text('Quitter', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
} 