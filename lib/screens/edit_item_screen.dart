import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart' as constants;


class EditItemScreen extends StatefulWidget {
  final String producerId;
  final Map<String, dynamic> item; // Peut être un menu global ou un item indépendant
  final String itemId; // ID de l'item ou du menu à modifier
  final String itemType; // 'menu' or 'item'
  final Function(Map<String, dynamic>) onSave; // Callback pour renvoyer l'item mis à jour

  const EditItemScreen({
    Key? key,
    required this.producerId,
    required this.item,
    required this.itemId,
    required this.itemType,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  bool _isLoading = false;

  // Pour les menus globaux: gestion des catégories incluses
  List<Map<String, dynamic>> _includedCategories = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['nom']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.item['description']?.toString() ?? '');
    _priceController = TextEditingController(text: widget.item['prix']?.toString() ?? '');

    // Si c'est un menu, charger les catégories incluses
    if (widget.itemType == 'menu' && widget.item['inclus'] is List) {
      // S'assurer que chaque élément est bien un Map<String, dynamic>
       _includedCategories = List<Map<String, dynamic>>.from(
            widget.item['inclus'].whereType<Map<String, dynamic>>());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    String endpoint;
    Map<String, dynamic> payload;

    // Préparer l'URL et le payload en fonction du type (menu ou item)
    if (widget.itemType == 'menu') {
      endpoint = '${constants.getBaseUrl()}/api/producers/${widget.producerId}/menus/${widget.itemId}'; 
      payload = {
        "nom": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "prix": _priceController.text.isNotEmpty ? double.tryParse(_priceController.text.replaceAll(',', '.')) : null,
        "inclus": _includedCategories, // Inclure les catégories mises à jour
      };
    } else { // C'est un item indépendant
      endpoint = '${constants.getBaseUrl()}/api/producers/${widget.producerId}/items/${widget.itemId}';
      payload = {
        "nom": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "prix": _priceController.text.isNotEmpty ? double.tryParse(_priceController.text.replaceAll(',', '.')) : null,
        // Si la catégorie doit être modifiable, ajoutez un champ pour cela
        // "catégorie": ... 
      };
    }
    
    print('📤 Envoi de la requête PUT vers $endpoint');
    print('📦 Payload : ${jsonEncode(payload)}');

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      setState(() => _isLoading = false);
      print('🛠️ Réponse Backend : ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        _showSuccess("Mise à jour réussie !");
        // Appeler le callback onSave avec les données mises à jour
        final updatedData = json.decode(response.body); // Utiliser la réponse si elle contient l'objet mis à jour
        widget.onSave(updatedData is Map<String, dynamic> ? updatedData : payload); // Renvoyer les données mises à jour
        if (mounted) {
           Navigator.pop(context); // Fermer l'écran après succès
        }
      } else {
        _showError("Erreur de mise à jour : ${response.body}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Erreur réseau lors de la mise à jour : $e');
      _showError("Erreur réseau : $e");
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  // --- Méthodes pour gérer les catégories incluses dans un menu ---
  
  void _addCategoryToMenu() {
    // Logique pour ajouter une catégorie (peut-être sélectionner parmi les catégories existantes d'items indépendants ?)
     showDialog(
        context: context,
        builder: (context) {
            final TextEditingController categoryNameController = TextEditingController();
            return AlertDialog(
                title: const Text('Ajouter une Catégorie au Menu'),
                content: TextField(
                    controller: categoryNameController,
                    decoration: const InputDecoration(hintText: 'Nom de la catégorie'),
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                    TextButton(
                        onPressed: () {
                            final name = categoryNameController.text.trim();
                            if (name.isNotEmpty) {
                                setState(() {
                                    _includedCategories.add({
                                        'catégorie': name,
                                        'items': [], // Commence avec une liste vide d'items spécifiques à ce menu
                                    });
                                });
                                Navigator.pop(context);
                            }
                        },
                        child: const Text('Ajouter'),
                    ),
                ],
            );
        },
    );
  }

  void _removeCategoryFromMenu(int categoryIndex) {
    setState(() {
      _includedCategories.removeAt(categoryIndex);
    });
  }

  void _addItemToIncludedCategory(int categoryIndex) {
     // Logique pour ajouter un item spécifique à une catégorie incluse dans ce menu
     // Cela pourrait ouvrir un autre dialogue pour entrer nom/description de l'item
     showDialog(
        context: context,
        builder: (context) {
            final TextEditingController itemNameController = TextEditingController();
            final TextEditingController itemDescController = TextEditingController();
            return AlertDialog(
                title: Text('Ajouter un Item à "${_includedCategories[categoryIndex]['catégorie']}"'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                         TextField(
                             controller: itemNameController,
                             decoration: const InputDecoration(hintText: 'Nom de l\'item'),
                         ),
                         TextField(
                             controller: itemDescController,
                             decoration: const InputDecoration(hintText: 'Description (optionnel)'),
                         ),
                    ],
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                    TextButton(
                        onPressed: () {
                            final name = itemNameController.text.trim();
                            if (name.isNotEmpty) {
                                setState(() {
                                    // S'assurer que 'items' est bien une liste mutable
                                    if (_includedCategories[categoryIndex]['items'] is! List) {
                                         _includedCategories[categoryIndex]['items'] = [];
                                    }
                                    // Ajouter l'item
                                    (_includedCategories[categoryIndex]['items'] as List).add({
                                        'nom': name,
                                        'description': itemDescController.text.trim(),
                                    });
                                });
                                Navigator.pop(context);
                            }
                        },
                        child: const Text('Ajouter'),
                    ),
                ],
            );
        },
    );
  }

  void _removeItemFromIncludedCategory(int categoryIndex, int itemIndex) {
    setState(() {
      if (_includedCategories[categoryIndex]['items'] is List) {
            (_includedCategories[categoryIndex]['items'] as List).removeAt(itemIndex);
        }
    });
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Modifier ${widget.itemType == 'menu' ? 'le Menu' : 'l\'Item'}")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Champs communs
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Nom"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: "Description"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: "Prix (€)"),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 24),
                  
                  // Section spécifique aux menus globaux
                  if (widget.itemType == 'menu') ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text("Catégories Incluses dans ce Menu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_includedCategories.isEmpty)
                        const Text("Aucune catégorie incluse pour le moment.", style: TextStyle(color: Colors.grey)),
                    ..._includedCategories.asMap().entries.map((entry) {
                        int catIndex = entry.key;
                        Map<String, dynamic> category = entry.value;
                        String catName = category['catégorie']?.toString() ?? 'Catégorie sans nom';
                        List<dynamic> items = category['items'] is List ? category['items'] : [];

                        return ExpansionTile(
                            title: Text(catName),
                             trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: "Retirer cette catégorie du menu",
                                onPressed: () => _removeCategoryFromMenu(catIndex),
                            ),
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            children: [
                                if (items.isEmpty)
                                     const Text("Aucun item spécifique défini pour cette catégorie dans ce menu."),
                                ...items.asMap().entries.map((itemEntry) {
                                    int itemIndex = itemEntry.key;
                                    Map<String, dynamic> item = itemEntry.value is Map<String, dynamic> ? itemEntry.value : {};
                                    String itemName = item['nom']?.toString() ?? 'Item sans nom';
                                    
                                    return ListTile(
                                        title: Text(itemName),
                                        subtitle: Text(item['description']?.toString() ?? ''),
                                        trailing: IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.orange),
                                            tooltip: "Retirer cet item de la catégorie",
                                            onPressed: () => _removeItemFromIncludedCategory(catIndex, itemIndex),
                                        ),
                                    );
                                }).toList(),
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text("Ajouter un item spécifique"),
                                        onPressed: () => _addItemToIncludedCategory(catIndex),
                                    ),
                                )
                            ],
                        );
                    }).toList(),
                    const SizedBox(height: 16),
                     ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("Ajouter une Catégorie au Menu"),
                        onPressed: _addCategoryToMenu,
                    ),
                    const SizedBox(height: 24),
                     const Divider(),
                  ],

                  // Bouton Enregistrer
                  Center(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text("Enregistrer les modifications"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 