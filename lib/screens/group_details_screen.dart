import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/conversation_service.dart';
import '../utils/api_config.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String groupName;
  final String groupAvatar;
  final List<Map<String, dynamic>> participants; // {id,name,avatar}

  const GroupDetailsScreen({
    Key? key,
    required this.conversationId,
    required this.currentUserId,
    required this.groupName,
    required this.groupAvatar,
    required this.participants,
  }) : super(key: key);

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late TextEditingController _nameController;
  late String _avatarUrl;
  bool _isSaving = false;
  final ConversationService _conversationService = ConversationService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.groupName);
    _avatarUrl = widget.groupAvatar;
  }

  Future<void> _pickNewAvatar() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    setState(() => _isSaving = true);
    try {
      // simple upload using same upload service used elsewhere
      final uploaded = await _conversationService.uploadFile(File(img.path));
      if (uploaded != null) {
        setState(() => _avatarUrl = uploaded);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    setState(() => _isSaving = true);
    try {
      await _conversationService.updateGroupInfo(
        widget.conversationId,
        groupName: newName != widget.groupName ? newName : null,
        groupAvatar: _avatarUrl != widget.groupAvatar ? _avatarUrl : null,
      );
      Navigator.pop(context, {
        'groupName': newName,
        'groupAvatar': _avatarUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du groupe'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: CachedNetworkImageProvider(_avatarUrl),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickNewAvatar,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blueAccent,
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du groupe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Participants', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...widget.participants.map((p) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(
                      p['avatar'] ?? 'https://via.placeholder.com/100'),
                ),
                title: Text(p['name'] ?? 'Utilisateur'),
                trailing: p['id'] != widget.currentUserId
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Retirer du groupe ?'),
                              content: Text('Retirer ${p['name']} du groupe ?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annuler')),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Retirer')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _conversationService.removeParticipant(
                                widget.conversationId, p['id']);
                            setState(() => widget.participants.remove(p));
                          }
                        },
                      )
                    : null,
              )),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Ajouter des participants'),
            onPressed: () async {
              final added = await _selectParticipants();
              if (added.isNotEmpty) {
                await _conversationService.addParticipants(
                    widget.conversationId, added);
                setState(() => widget.participants.addAll(added));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _selectParticipants() async {
    // simple implementation: reuse producer search modal but for users only
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
            final r = await _conversationService.searchUsers(q);
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
                        backgroundImage: CachedNetworkImageProvider(u['avatar'] ?? ''),
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
    return selected;
  }
}