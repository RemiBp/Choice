import 'package:flutter/material.dart';
import '../models/contact_tag.dart';
import '../services/tag_service.dart';
import '../services/contacts_service.dart';

class ContactsByTagScreen extends StatefulWidget {
  final String tagId;
  final String tagName;

  const ContactsByTagScreen({
    Key? key,
    required this.tagId,
    required this.tagName,
  }) : super(key: key);

  @override
  _ContactsByTagScreenState createState() => _ContactsByTagScreenState();
}

class _ContactsByTagScreenState extends State<ContactsByTagScreen> {
  final TagService _tagService = TagService();
  final ContactsService _contactsService = ContactsService();
  
  bool _isLoading = true;
  List<Contact> _contacts = [];
  ContactTag? _tag;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialiser les services
      await _tagService.initialize();
      
      // Récupérer le tag
      _tag = _tagService.tags.firstWhere(
        (tag) => tag.id == widget.tagId,
        orElse: () => throw Exception('Tag non trouvé'),
      );
      
      // Récupérer les IDs des contacts associés à ce tag
      final contactIds = _tagService.getContactsForTag(widget.tagId);
      
      // Récupérer les détails des contacts
      final allContacts = await _contactsService.getContactsFromServer();
      
      // Filtrer pour obtenir uniquement les contacts avec ce tag
      _contacts = allContacts.where(
        (contact) => contactIds.contains(contact.id)
      ).toList();
      
      // Trier par nom
      _contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    } catch (e) {
      debugPrint('Erreur lors du chargement des contacts par tag: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts avec tag: ${widget.tagName}'),
        backgroundColor: _tag?.color ?? Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun contact avec ce tag',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tag?.color ?? Colors.teal,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // En-tête avec informations sur le tag
        if (_tag != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: _tag!.color.withOpacity(0.1),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _tag!.color,
                  child: Icon(
                    _tag!.icon,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tag!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_tag!.description != null)
                        Text(
                          _tag!.description!,
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _tag!.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _tag!.color),
                  ),
                  child: Text(
                    '${_contacts.length} contacts',
                    style: TextStyle(
                      color: _tag!.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Liste des contacts
        Expanded(
          child: ListView.builder(
            itemCount: _contacts.length,
            itemBuilder: (context, index) {
              final contact = _contacts[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage: contact.photoUrl != null
                        ? NetworkImage(contact.photoUrl!)
                        : null,
                    child: contact.photoUrl == null
                        ? Text(
                            _getInitials(contact.displayName),
                            style: TextStyle(
                              color: _tag?.color ?? Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(contact.displayName),
                  subtitle: _buildContactInfo(contact),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red,
                    tooltip: 'Retirer le tag',
                    onPressed: () => _confirmRemoveTag(contact),
                  ),
                  onTap: () => _navigateToContactDetail(contact),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Construire les informations de contact (email, téléphone)
  Widget _buildContactInfo(Contact contact) {
    String? email;
    String? phone;
    
    if (contact.emails.isNotEmpty) {
      email = contact.emails.first.value;
    }
    
    if (contact.phones.isNotEmpty) {
      phone = contact.phones.first.value;
    }
    
    if (email != null && phone != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email),
          Text(phone),
        ],
      );
    } else if (email != null) {
      return Text(email);
    } else if (phone != null) {
      return Text(phone);
    } else {
      return const Text('Aucune information de contact');
    }
  }

  // Obtenir les initiales d'un nom
  String _getInitials(String name) {
    if (name.isEmpty) return '';
    
    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}';
    } else {
      return name[0];
    }
  }

  // Confirmer le retrait du tag d'un contact
  Future<void> _confirmRemoveTag(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le retrait'),
        content: Text(
          'Êtes-vous sûr de vouloir retirer le tag "${widget.tagName}" de ${contact.displayName} ?',
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
      await _tagService.removeTagFromContact(contact.id, widget.tagId);
      
      // Mettre à jour la liste des contacts
      setState(() {
        _contacts.removeWhere((c) => c.id == contact.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag retiré de ${contact.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // Naviguer vers les détails du contact
  void _navigateToContactDetail(Contact contact) {
    Navigator.pushNamed(
      context,
      '/contact-detail',
      arguments: contact,
    ).then((_) => _loadData()); // Rafraîchir les données au retour
  }
} 