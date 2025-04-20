import 'package:flutter/material.dart';
import 'package:your_app/services/tag_service.dart';
import 'package:your_app/models/contact_tag.dart';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;

  const ContactDetailScreen({Key? key, required this.contact}) : super(key: key);

  @override
  _ContactDetailScreenState createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  Future<List<ContactTag>> _loadContactTags() async {
    final tagService = TagService();
    await tagService.initialize();
    return tagService.getTagsForContact(widget.contact.id);
  }

  Widget _buildTagChip(ContactTag tag) {
    return GestureDetector(
      onLongPress: () => _showTagOptions(tag),
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: tag.color,
          child: Icon(
            tag.icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        label: Text(
          tag.name,
          style: TextStyle(color: _getTextColor(tag.color)),
        ),
        backgroundColor: tag.color.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tag.color),
        ),
      ),
    );
  }

  Color _getTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _showTagOptions(ContactTag tag) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: tag.color,
              child: Icon(
                tag.icon,
                color: Colors.white,
              ),
            ),
            title: Text(tag.name),
            subtitle: Text(
              tag.description ?? 'Aucune description',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Retirer ce tag'),
            onTap: () {
              Navigator.pop(context);
              _removeTagFromContact(tag);
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Trouver des contacts similaires'),
            onTap: () {
              Navigator.pop(context);
              _findContactsWithSameTag(tag);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showAddTagDialog() async {
    final tagService = TagService();
    await tagService.initialize();
    
    final allTags = tagService.tags;
    final contactTags = await _loadContactTags();
    
    final availableTags = allTags.where(
      (tag) => !contactTags.any((t) => t.id == tag.id)
    ).toList();
    
    if (availableTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tous les tags sont déjà associés à ce contact'),
        ),
      );
      return;
    }
    
    final selectedTag = await showDialog<ContactTag>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un tag'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTags.length,
            itemBuilder: (context, index) {
              final tag = availableTags[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: tag.color,
                  child: Icon(
                    tag.icon,
                    color: Colors.white,
                  ),
                ),
                title: Text(tag.name),
                subtitle: Text(
                  tag.description ?? 'Aucune description',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, tag),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/tag-management')
              .then((_) => Navigator.pop(context)),
            child: const Text('Gérer les tags'),
          ),
        ],
      ),
    );
    
    if (selectedTag != null) {
      await tagService.addTagToContact(widget.contact.id, selectedTag.id);
      setState(() {});
    }
  }

  Future<void> _removeTagFromContact(ContactTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le retrait'),
        content: Text(
          'Êtes-vous sûr de vouloir retirer le tag "${tag.name}" de ce contact ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final tagService = TagService();
      await tagService.initialize();
      await tagService.removeTagFromContact(widget.contact.id, tag.id);
      setState(() {});
    }
  }

  void _findContactsWithSameTag(ContactTag tag) {
    Navigator.pushNamed(
      context,
      '/contacts-by-tag',
      arguments: {
        'tagId': tag.id,
        'tagName': tag.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détail du contact'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contact.name,
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              widget.contact.email,
              style: Theme.of(context).textTheme.bodyText1,
            ),
            Text(
              widget.contact.phone,
              style: Theme.of(context).textTheme.bodyText1,
            ),
            Container(
              margin: const EdgeInsets.only(top: 16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tags',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddTagDialog(),
                        tooltip: 'Ajouter un tag',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  FutureBuilder<List<ContactTag>>(
                    future: _loadContactTags(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            ),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erreur lors du chargement des tags',
                            style: TextStyle(color: Colors.red[300]),
                          ),
                        );
                      }
                      
                      final tags = snapshot.data ?? [];
                      
                      if (tags.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: Text(
                              'Aucun tag pour ce contact',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: tags.map((tag) => _buildTagChip(tag)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 