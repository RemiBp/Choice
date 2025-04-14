import 'package:flutter/material.dart';
import '../models/contact_tag.dart';
import '../services/tag_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({Key? key}) : super(key: key);

  @override
  _TagManagementScreenState createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  final TagService _tagService = TagService();
  List<ContactTag> _tags = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    await _tagService.initialize();
    
    setState(() {
      _tags = List.from(_tagService.tags);
      _isLoading = false;
    });
  }

  // Filtrer les tags en fonction de la recherche
  List<ContactTag> get _filteredTags {
    if (_searchQuery.isEmpty) return _tags;
    
    final lowerQuery = _searchQuery.toLowerCase();
    return _tags.where((tag) => 
      tag.name.toLowerCase().contains(lowerQuery) ||
      (tag.description != null && tag.description!.toLowerCase().contains(lowerQuery))
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des tags'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTags,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Rechercher un tag',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                
                // Liste des tags
                Expanded(
                  child: _filteredTags.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'Aucun tag disponible'
                                : 'Aucun résultat pour "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredTags.length,
                          itemBuilder: (context, index) {
                            final tag = _filteredTags[index];
                            return _buildTagListItem(tag);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(),
        child: const Icon(Icons.add),
        backgroundColor: Colors.teal,
      ),
    );
  }

  // Construire un élément de la liste de tags
  Widget _buildTagListItem(ContactTag tag) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tag.color,
          child: Icon(
            tag.icon,
            color: Colors.white,
          ),
        ),
        title: Text(
          tag.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          tag.description ?? 'Aucune description',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showTagDialog(tag: tag),
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteTag(tag),
              tooltip: 'Supprimer',
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        onTap: () => _showTagDetails(tag),
      ),
    );
  }

  // Afficher une boîte de dialogue pour créer ou modifier un tag
  Future<void> _showTagDialog({ContactTag? tag}) async {
    // Valeurs initiales
    final nameController = TextEditingController(
      text: tag?.name ?? '',
    );
    final descriptionController = TextEditingController(
      text: tag?.description ?? '',
    );
    Color selectedColor = tag?.color ?? Colors.teal;
    IconData selectedIcon = tag?.icon ?? Icons.tag;
    
    // Liste d'icônes disponibles
    final List<IconData> availableIcons = [
      Icons.home,
      Icons.work,
      Icons.school,
      Icons.favorite,
      Icons.star,
      Icons.people,
      Icons.family_restroom,
      Icons.sports,
      Icons.music_note,
      Icons.movie,
      Icons.restaurant,
      Icons.flight,
      Icons.shop,
      Icons.attach_money,
      Icons.celebration,
      Icons.sports_soccer,
      Icons.pets,
      Icons.tag,
      Icons.person,
      Icons.phone,
      Icons.email,
      Icons.location_on,
      Icons.business,
      Icons.group,
      Icons.cake,
      Icons.local_hospital,
      Icons.local_bar,
      Icons.directions_car,
    ];

    // Valider le formulaire
    final formKey = GlobalKey<FormState>();
    bool isValid = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(tag == null ? 'Nouveau tag' : 'Modifier le tag'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom du tag
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      icon: Icon(Icons.label),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom est obligatoire';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnelle)',
                      icon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  
                  // Sélection de couleur
                  Text(
                    'Couleur du tag',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final Color? color = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Choisir une couleur'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: selectedColor,
                              onColorChanged: (color) => selectedColor = color,
                              pickerAreaHeightPercent: 0.8,
                              enableAlpha: false,
                              labelTypes: const [],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, selectedColor),
                              child: const Text('Valider'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedColor,
                              ),
                            ),
                          ],
                        ),
                      );
                      
                      if (color != null) {
                        setState(() {
                          selectedColor = color;
                        });
                      }
                    },
                    child: const Text('Changer la couleur'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sélection d'icône
                  Text(
                    'Icône du tag',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 1,
                      ),
                      itemCount: availableIcons.length,
                      itemBuilder: (context, index) {
                        final icon = availableIcons[index];
                        final isSelected = selectedIcon.codePoint == icon.codePoint;
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.grey[200] : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.all(4),
                            child: Icon(
                              icon,
                              color: isSelected ? selectedColor : Colors.grey[700],
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                isValid = formKey.currentState?.validate() ?? false;
                if (isValid) {
                  Navigator.pop(context);
                }
              },
              child: Text(tag == null ? 'Créer' : 'Modifier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
    
    // Si le formulaire est valide, créer ou modifier le tag
    if (isValid) {
      try {
        if (tag == null) {
          // Créer un nouveau tag
          await _tagService.createTag(
            name: nameController.text.trim(),
            color: selectedColor,
            icon: selectedIcon,
            description: descriptionController.text.trim().isNotEmpty
                ? descriptionController.text.trim()
                : null,
          );
        } else {
          // Modifier un tag existant
          await _tagService.updateTag(
            id: tag.id,
            name: nameController.text.trim(),
            color: selectedColor,
            icon: selectedIcon,
            description: descriptionController.text.trim().isNotEmpty
                ? descriptionController.text.trim()
                : null,
          );
        }
        
        // Rafraîchir la liste
        _loadTags();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tag == null
                    ? 'Tag créé avec succès'
                    : 'Tag modifié avec succès',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Confirmer la suppression d'un tag
  Future<void> _confirmDeleteTag(ContactTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le tag "${tag.name}" ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _tagService.deleteTag(tag.id);
        
        // Rafraîchir la liste
        _loadTags();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tag supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Afficher les détails d'un tag
  void _showTagDetails(ContactTag tag) async {
    // Récupérer les contacts associés à ce tag
    final contactIds = _tagService.getContactsForTag(tag.id);
    
    // Afficher une boîte de dialogue avec les détails
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails du tag: ${tag.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tag.color,
                  child: Icon(
                    tag.icon,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (tag.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          tag.description!,
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Contacts associés: ${contactIds.length}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créé le: ${_formatDate(tag.createdAt)}',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dernière modification: ${_formatDate(tag.updatedAt)}',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showTagDialog(tag: tag);
            },
            child: const Text('Modifier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  // Formater une date
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
} 