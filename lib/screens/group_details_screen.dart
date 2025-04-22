import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/conversation_service.dart';
import '../utils/api_config.dart';
import '../utils.dart' show getImageProvider;
import 'package:google_fonts/google_fonts.dart';
// import '../widgets/user_search_delegate.dart'; // Commented out: File not found

class GroupDetailScreen extends StatefulWidget {
  final String conversationId;
  final String userId;
  final String groupName;
  final String groupAvatar;
  final bool isDarkMode;
  final ConversationService conversationService;

  const GroupDetailScreen({
    Key? key,
    required this.conversationId,
    required this.userId,
    required this.groupName,
    required this.groupAvatar,
    required this.isDarkMode,
    required this.conversationService,
  }) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<dynamic> _participants = [];
  String _groupName = '';
  String? _groupAvatarUrl;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;

  bool _isEditing = false;
  late TextEditingController _groupNameController;
  File? _newAvatarFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _initializeScreen();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _fetchCurrentUserId();
    await _fetchGroupDetails();
    if (_errorMessage == null) {
       await _fetchParticipants();
    } else {
       setState(() {
        _isLoading = false;
       });
    }
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      _currentUserId = await widget.conversationService.getCurrentUserId();
      print("Current user ID fetched: $_currentUserId");
    } catch (e) {
       print("Error fetching current user ID: $e");
       setState(() {
         _errorMessage = "Impossible de récupérer l'ID utilisateur actuel.";
         _isLoading = false;
       });
    }
  }

  Future<void> _fetchGroupDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final conversationDetails = await widget.conversationService.getConversationById(widget.conversationId);
      if (mounted) {
        setState(() {
          _groupName = conversationDetails['name'] ?? 'Groupe sans nom';
          _groupAvatarUrl = conversationDetails['avatarUrl'];
          _groupNameController.text = _groupName;
        });
      }
    } catch (e) {
      print("Error fetching group details: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la récupération des détails du groupe: $e';
        });
      }
    }
  }

  Future<void> _fetchParticipants() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final participants = await widget.conversationService.getConversationParticipants(widget.conversationId);
      if (mounted) {
        setState(() {
          _participants = participants;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print("Error fetching participants: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la récupération des participants: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickNewAvatar() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newAvatarFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    final newName = _groupNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du groupe ne peut pas être vide.'), backgroundColor: Colors.orange),
      );
      return;
    }

    bool nameChanged = newName != _groupName;
    bool avatarChanged = _newAvatarFile != null;

    if (!nameChanged && !avatarChanged) {
      setState(() { _isEditing = false; });
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await widget.conversationService.updateGroupDetails(
        widget.conversationId,
        name: nameChanged ? newName : null,
        avatarFile: _newAvatarFile,
      );

      if (mounted) {
        setState(() {
          if (nameChanged) _groupName = newName;
          _newAvatarFile = null;
          _isEditing = false;
          _isLoading = false;
          _fetchGroupDetails();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Groupe mis à jour avec succès!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error saving changes: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.grey[100]!;
    final Color cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final Color primaryColor = widget.isDarkMode ? Colors.purple[200]! : Colors.deepPurple;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Modifier le groupe' : 'Détails du groupe',
          style: GoogleFonts.poppins(
              color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: _buildAppBarActions(),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _fetchParticipants,
                  color: primaryColor,
                  child: ListView(
                    children: [
                      _buildGroupHeader(),
                      SizedBox(height: 8),
                      _buildParticipantList(cardColor, textColor),
                      SizedBox(height: 8),
                      _buildActions(cardColor, textColor, primaryColor),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_isEditing) {
      return [
        IconButton(
          icon: const Icon(Icons.cancel),
          tooltip: 'Annuler',
          onPressed: () {
            setState(() {
              _isEditing = false;
              _newAvatarFile = null;
              _groupNameController.text = _groupName;
            });
          },
        ),
            IconButton(
              icon: const Icon(Icons.save),
          tooltip: 'Sauvegarder',
              onPressed: _saveChanges,
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Modifier',
          onPressed: () {
            setState(() {
              _isEditing = true;
              _groupNameController.text = _groupName;
            });
          },
        ),
      ];
    }
  }

  Widget _buildGroupHeader() {
    if (_errorMessage != null && _participants.isEmpty) {
       return Padding(
         padding: const EdgeInsets.all(16.0),
         child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
       );
    }

    if (_isLoading && _participants.isEmpty && _errorMessage == null) {
        return const Center(child: CircularProgressIndicator());
    }

    final avatarUrl = _groupAvatarUrl;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_isEditing)
            _buildAvatarEditor(avatarUrl)
          else
             CircleAvatar(
                 radius: 40,
                 backgroundImage: _newAvatarFile != null
                    ? FileImage(_newAvatarFile!)
                    : (avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null) as ImageProvider?,
                 child: (avatarUrl == null || avatarUrl.isEmpty) && _newAvatarFile == null
                    ? const Icon(Icons.group, size: 40)
                    : null,
              ),
          const SizedBox(height: 10),
           if (_isEditing)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
               child: TextField(
                 controller: _groupNameController,
                 textAlign: TextAlign.center,
                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                 decoration: const InputDecoration(
                   hintText: 'Nom du groupe',
                   isDense: true,
                 ),
               ),
             )
           else
            Text(
              _groupName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 10),
          Text('${_participants.length} participant(s)'),
        ],
      ),
    );
  }

  Widget _buildAvatarEditor(String? currentAvatarUrl) {
    return Stack(
      alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
          radius: 40,
          backgroundImage: _newAvatarFile != null
              ? FileImage(_newAvatarFile!)
              : (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty
                  ? NetworkImage(currentAvatarUrl)
                  : null) as ImageProvider?,
           child: (_newAvatarFile == null && (currentAvatarUrl == null || currentAvatarUrl.isEmpty))
               ? const Icon(Icons.group, size: 40)
               : null,
        ),
        Material(
           color: Colors.blue,
           shape: const CircleBorder(),
           clipBehavior: Clip.antiAlias,
           elevation: 2,
           child: InkWell(
                    onTap: _pickNewAvatar,
             child: const Padding(
               padding: EdgeInsets.all(4.0),
               child: Icon(Icons.edit, color: Colors.white, size: 18),
             ),
           ),
         )

      ],
    );
  }

  Widget _buildParticipantList(Color cardColor, Color textColor) {
    return Container(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              '${_participants.length} Participants',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7)),
            ),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[400],
              child: Icon(Icons.person_add, color: Colors.white),
            ),
            title: Text('Ajouter des participants', style: TextStyle(color: Colors.green[400])),
            onTap: () {
              _selectParticipants();
            },
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _participants.length,
            itemBuilder: (context, index) {
              final participant = _participants[index];
              final String name = participant['name'] ?? 'Utilisateur';
              final String avatarUrl = participant['avatar'] ?? '';
              final bool isCurrentUser = participant['id'] == _currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: getImageProvider(avatarUrl),
                  backgroundColor: Colors.grey.shade300,
                  child: getImageProvider(avatarUrl) == null ? Icon(Icons.person, size: 20, color: Colors.grey.shade500) : null,
                ),
                title: Text(
                  name,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  isCurrentUser ? 'Vous' : (participant['username'] ?? ''),
                  style: TextStyle(color: textColor.withOpacity(0.6)),
                ),
                trailing: isCurrentUser
                    ? null
                    : PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: textColor.withOpacity(0.6)),
                        color: cardColor,
                        onSelected: (value) {
                          if (value == 'remove') {
                            _removeParticipant(participant['id']);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'remove',
                            child: Text('Retirer du groupe', style: TextStyle(color: textColor)),
                          ),
                        ],
                      ),
                onTap: () {
                  // TODO: Voir le profil de l'utilisateur ?
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Color cardColor, Color textColor, Color primaryColor) {
    return Container(
      color: cardColor,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: Text('Quitter le groupe', style: TextStyle(color: Colors.redAccent)),
            onTap: _leaveGroup,
          ),
        ],
      ),
    );
  }

  Future<void> _removeParticipant(String participantId) async {
    if (participantId == _currentUserId) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Utilisez le bouton "Quitter le groupe" pour vous retirer.'), backgroundColor: Colors.orange),
       );
       return;
     }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirer le participant?'),
        content: Text('Voulez-vous vraiment retirer ce participant du groupe?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Retirer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      print("Retrait du participant $participantId");
      try {
        await widget.conversationService.removeParticipant(widget.conversationId, participantId);
        await _fetchParticipants();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors du retrait: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de déterminer l'utilisateur actuel."), backgroundColor: Colors.red),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quitter le groupe?'),
        content: Text('Voulez-vous vraiment quitter ce groupe?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Quitter', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      print("Quitter le groupe ${widget.conversationId}");
      try {
        await widget.conversationService.removeParticipant(widget.conversationId, _currentUserId!);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vous avez quitté le groupe')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur pour quitter le groupe: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _selectParticipants() async {
    final List<Map<String, dynamic>> selected = [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        TextEditingController ctrl = TextEditingController();
        List<Map<String, dynamic>> results = [];
        bool loading = false;
        return StatefulBuilder(builder: (ctx, setModal) {
          Future<void> search(String q) async {
            if (q.length < 2) return;
            setModal(() => loading = true);
            final r = await widget.conversationService.searchUsers(q);
            setModal(() {
              results = r.where((e) => e['type'] == 'user').toList();
              loading = false;
            });
          }

          return Padding(
            padding: MediaQuery.of(ctx).viewInsets,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher…'),
                  onChanged: search,
                ),
              ),
              if (loading) const CircularProgressIndicator(),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final u = results[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: getImageProvider(u['avatar'] ?? '') ?? const AssetImage('assets/images/default_avatar.png'),
                        child: getImageProvider(u['avatar'] ?? '') == null ? Icon(Icons.person, color: Colors.grey[400]) : null,
                      ),
                      title: Text(u['name'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          selected.add(u);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              )
            ]),
          );
        });
      },
    );
    if (selected.isNotEmpty) {
      try {
        final participantIds = selected.map((p) => p['id'] as String).toList();
        await widget.conversationService.addParticipantsByIds(widget.conversationId, participantIds);
        await _fetchParticipants();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'ajout: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}