import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart';
import 'package:intl/intl.dart';

// Models (Assuming basic structure, adjust if you have detailed models)
class MenuItem {
  String id;
  String name;
  String description;
  double price;
  String category;
  Map<String, dynamic>? nutrition; // Optional: For calories, etc.
  String? photoUrl; // Optional

  MenuItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.category,
    this.nutrition,
    this.photoUrl,
  });

  // Basic fromJson, adjust based on actual API response
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), // Ensure ID exists
      name: json['nom']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['prix']?.toString() ?? '0') ?? 0,
      category: json['catégorie']?.toString() ?? 'Autres',
      nutrition: json['nutrition'] as Map<String, dynamic>?,
      photoUrl: json['photo']?.toString(),
    );
  }

   Map<String, dynamic> toJson() {
     return {
       '_id': id, // Include ID for updates
       'nom': name,
       'description': description,
       'prix': price,
       'catégorie': category,
       'nutrition': nutrition,
       'photo': photoUrl,
     };
   }
}

class Menu {
  String id;
  String name;
  String description;
  double price;
  List<MenuCategory> includedCategories; // Changed 'inclus' to be more descriptive

  Menu({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.includedCategories = const [],
  });

  // Basic fromJson, adjust based on actual API response for 'Menus Globaux'
  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), // Ensure ID exists
      name: json['nom']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['prix']?.toString() ?? '0') ?? 0,
      includedCategories: (json['inclus'] as List<dynamic>? ?? [])
          .where((cat) => cat is Map<String, dynamic>)
          .map((cat) => MenuCategory.fromJson(cat as Map<String, dynamic>))
          .toList(),
    );
  }

   Map<String, dynamic> toJson() {
     return {
       '_id': id, // Include ID for updates
       'nom': name,
       'description': description,
       'prix': price,
       'inclus': includedCategories.map((cat) => cat.toJson()).toList(),
     };
   }
}

class MenuCategory {
  String name;
  List<MenuItem> items; // Assuming items within a menu don't need separate price/category

  MenuCategory({required this.name, this.items = const []});

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      name: json['catégorie']?.toString() ?? 'Inclus',
      items: (json['items'] as List<dynamic>? ?? [])
          .where((item) => item is Map<String, dynamic>)
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>)) // Re-use MenuItem.fromJson
          .toList(),
    );
  }

   Map<String, dynamic> toJson() {
     return {
       'catégorie': name,
       'items': items.map((item) => item.toJson()).toList(), // Assuming items need full details
     };
   }
}
// End Models

class MenuManagementScreen extends StatefulWidget {
  final String producerId;
  
  const MenuManagementScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Menu> _globalMenus = [];
  Map<String, List<MenuItem>> _independentItems = {}; // Store items directly under category name
  List<String> _categories = []; // List of category names

  // Store original data for comparison and pending changes
  List<Menu>? _originalGlobalMenus;
  Map<String, List<MenuItem>>? _originalIndependentItems;

  // System for pending changes
  bool _pendingApproval = false;
  DateTime? _modificationDate;

  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _checkPendingModifications();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchStructuredData(),
        // _checkPendingModifications(), // Check separately or after fetch
      ]);
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Erreur de chargement: ${e.toString()}')),
          );
       }
    } finally {
       if (mounted) {
          setState(() => _isLoading = false);
       }
    }
  }

  Future<void> _fetchStructuredData() async {
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}');
      final response = await http.get(url);
      
    if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
      final structuredData = data['structured_data'];

      List<Menu> globalMenus = [];
      Map<String, List<MenuItem>> independentItems = {};
      List<String> categories = [];

      if (structuredData != null && structuredData is Map) {
        // Parse Global Menus
        if (structuredData['Menus Globaux'] is List) {
          globalMenus = (structuredData['Menus Globaux'] as List)
              .where((m) => m is Map<String, dynamic>)
              .map((m) => Menu.fromJson(m as Map<String, dynamic>))
              .toList();
        }

        // Parse Independent Items
        if (structuredData['Items Indépendants'] is List) {
          final itemsData = structuredData['Items Indépendants'] as List;
          final Set<String> categorySet = {};
          for (var categoryData in itemsData) {
            if (categoryData is Map<String, dynamic>) {
              final categoryName = categoryData['catégorie']?.toString() ?? 'Autres';
              categorySet.add(categoryName);
              if (categoryData['items'] is List) {
                final itemsList = (categoryData['items'] as List)
                    .where((i) => i is Map<String, dynamic>)
                    .map((i) => MenuItem.fromJson(i as Map<String, dynamic>..['catégorie'] = categoryName)) // Add category here if needed elsewhere
                    .toList();
                independentItems.putIfAbsent(categoryName, () => []).addAll(itemsList);
              }
            }
          }
          categories = categorySet.toList()..sort();
          }
        }
        
        setState(() {
        _globalMenus = globalMenus;
        _independentItems = independentItems;
        _categories = categories;
        // Store originals for comparison
        _originalGlobalMenus = List<Menu>.from(globalMenus.map((m) => Menu.fromJson(jsonDecode(jsonEncode(m.toJson()))))); // Deep copy
        _originalIndependentItems = Map<String, List<MenuItem>>.from(independentItems.map((key, value) => MapEntry(key, List<MenuItem>.from(value.map((item) => MenuItem.fromJson(jsonDecode(jsonEncode(item.toJson())))))))); // Deep copy
        });
      } else {
      throw Exception('Erreur API (${response.statusCode}) lors de la récupération des données structurées');
    }
  }

  Future<void> _checkPendingModifications() async {
     // Simplified check for demo purposes
     // In a real app, fetch this status from the backend
     // setState(() {
     //   _pendingApproval = ...; // Fetch status
     //   _modificationDate = ...; // Fetch date
     // });
  }

  // --- Save Logic ---
  Future<void> _saveChanges() async {
     setState(() => _isLoading = true);
     try {
        final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/menu'); // Correct endpoint? Verify

        // Prepare data in the expected backend format
        final List<Map<String, dynamic>> itemsIndependantsPayload = [];
        _independentItems.forEach((categoryName, itemsList) {
           itemsIndependantsPayload.add({
             'catégorie': categoryName,
             // Ensure items have necessary fields expected by backend, excluding temp fields if any
             'items': itemsList.map((item) => item.toJson()).toList(), 
           });
        });

        final payload = {
           'structured_data': {
             'Menus Globaux': _globalMenus.map((menu) => menu.toJson()).toList(),
             'Items Indépendants': itemsIndependantsPayload,
           },
           'pending_approval': true, // Mark changes as pending
           'last_modified': DateTime.now().toIso8601String(),
           // Add history tracking if needed by backend
        };

        final response = await http.post( // Use POST or PUT depending on API design
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        _pendingApproval = true;
             _modificationDate = DateTime.now();
             // Update original data to reflect saved state
            _originalGlobalMenus = List<Menu>.from(_globalMenus.map((m) => Menu.fromJson(jsonDecode(jsonEncode(m.toJson())))));
            _originalIndependentItems = Map<String, List<MenuItem>>.from(_independentItems.map((key, value) => MapEntry(key, List<MenuItem>.from(value.map((item) => MenuItem.fromJson(jsonDecode(jsonEncode(item.toJson()))))))));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
                 content: Text('Modifications enregistrées. En attente de validation.'),
                 backgroundColor: Colors.green,
        ),
      );
        } else {
           throw Exception('Erreur API (${response.statusCode}): ${response.body}');
        }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur sauvegarde: ${e.toString()}'), backgroundColor: Colors.red),
        );
     } finally {
       if (mounted) {
          setState(() => _isLoading = false);
       }
     }
  }

  // --- Dialogs for Adding/Editing ---

  // Show Dialog for Adding/Editing a Global Menu
  Future<void> _showEditMenuDialog({Menu? existingMenu}) async {
    final bool isEditing = existingMenu != null;
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: existingMenu?.name ?? '');
    final _descriptionController = TextEditingController(text: existingMenu?.description ?? '');
    final _priceController = TextEditingController(text: existingMenu?.price.toString() ?? '');
    // Potentially manage included items here if needed within the dialog

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Modifier le Menu' : 'Ajouter un Menu Global'),
        content: SingleChildScrollView( // Make dialog scrollable
           child: Form(
             key: _formKey,
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 TextFormField(
                   controller: _nameController,
                   decoration: const InputDecoration(labelText: 'Nom du Menu', hintText: 'Ex: Menu Déjeuner'),
                   validator: (value) => (value?.trim().isEmpty ?? true) ? 'Nom requis' : null,
                 ),
                 const SizedBox(height: 16),
                 TextFormField(
                   controller: _descriptionController,
                   decoration: const InputDecoration(labelText: 'Description (Optionnel)', hintText: 'Courte description du menu'),
                   maxLines: 2,
                 ),
                 const SizedBox(height: 16),
                 TextFormField(
                   controller: _priceController,
                   decoration: const InputDecoration(labelText: 'Prix (€)', hintText: 'Ex: 15.90'),
                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) return 'Prix requis';
                     if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Prix invalide';
                     return null;
                   },
                 ),
                 // Add controls for 'inclus' items if complex editing is needed here
                 // For simplicity, assume 'inclus' is managed elsewhere or not in this basic dialog
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
              if (_formKey.currentState!.validate()) {
                final newMenuData = {
                  'id': existingMenu?.id ?? DateTime.now().millisecondsSinceEpoch.toString(), // Generate new ID or use existing
                  'nom': _nameController.text.trim(),
                  'description': _descriptionController.text.trim(),
                  'prix': _priceController.text.replaceAll(',', '.'),
                  'inclus': existingMenu?.includedCategories.map((c) => c.toJson()).toList() ?? [], // Preserve existing included items
                };
              
              setState(() {
                  if (isEditing) {
                    final index = _globalMenus.indexWhere((m) => m.id == existingMenu.id);
                    if (index != -1) {
                      _globalMenus[index] = Menu.fromJson(newMenuData);
                    }
                  } else {
                    _globalMenus.add(Menu.fromJson(newMenuData));
                  }
                });
                Navigator.pop(context); // Close dialog
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }
  

  // Show Dialog for Adding/Editing an Independent Item
  Future<void> _showEditItemDialog({MenuItem? existingItem, String? initialCategory}) async {
     final bool isEditing = existingItem != null;
     final _formKey = GlobalKey<FormState>();
     final _nameController = TextEditingController(text: existingItem?.name ?? '');
     final _descriptionController = TextEditingController(text: existingItem?.description ?? '');
     final _priceController = TextEditingController(text: existingItem?.price.toString() ?? '');
     String selectedCategory = existingItem?.category ?? initialCategory ?? (_categories.isNotEmpty ? _categories.first : 'Autres');
     final _newCategoryController = TextEditingController();
     bool isCreatingNewCategory = false;

     await showDialog(
        context: context,
        // Use StatefulBuilder to manage category selection state within the dialog
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
               title: Text(isEditing ? 'Modifier l'Article' : 'Ajouter un Article'),
               content: SingleChildScrollView(
                 child: Form(
                    key: _formKey,
                    child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         TextFormField(
                           controller: _nameController,
                           decoration: const InputDecoration(labelText: 'Nom de l'article', hintText: 'Ex: Salade César'),
                           validator: (value) => (value?.trim().isEmpty ?? true) ? 'Nom requis' : null,
                         ),
                         const SizedBox(height: 16),
                         TextFormField(
                           controller: _descriptionController,
                           decoration: const InputDecoration(labelText: 'Description (Optionnel)', hintText: 'Ingrédients, allergènes...'),
                           maxLines: 2,
                         ),
                         const SizedBox(height: 16),
                         TextFormField(
                           controller: _priceController,
                           decoration: const InputDecoration(labelText: 'Prix (€)', hintText: 'Ex: 8.50'),
                           keyboardType: const TextInputType.numberWithOptions(decimal: true),
                           validator: (value) {
                             if (value == null || value.trim().isEmpty) return 'Prix requis';
                             if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Prix invalide';
                             return null;
                           },
                         ),
                         const SizedBox(height: 16),
                         // Category Selection or Creation
                         if (!isCreatingNewCategory)
                           DropdownButtonFormField<String>(
                             value: _categories.contains(selectedCategory) ? selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                             items: [
                               ..._categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                               const DropdownMenuItem(value: '__new__', child: Text('+ Nouvelle catégorie...')),
                             ],
                             onChanged: (value) {
                               if (value == '__new__') {
                                 setDialogState(() => isCreatingNewCategory = true);
                               } else if (value != null) {
                                 setDialogState(() => selectedCategory = value);
                               }
                             },
                             decoration: const InputDecoration(labelText: 'Catégorie'),
                              validator: (value) => (value == null && !isCreatingNewCategory) ? 'Catégorie requise' : null,
                           )
                         else
          Row(
            children: [
              Expanded(
                                 child: TextFormField(
                                    controller: _newCategoryController,
                                    decoration: const InputDecoration(labelText: 'Nouvelle catégorie'),
                                    validator: (value) => (value?.trim().isEmpty ?? true) ? 'Nom requis' : null,
                                    onChanged: (value) => setDialogState(() => selectedCategory = value.trim()), // Update selectedCategory live
                                 ),
                               ),
                               IconButton(
                                 icon: const Icon(Icons.close),
                                 tooltip: 'Annuler nouvelle catégorie',
                                 onPressed: () => setDialogState(() => isCreatingNewCategory = false),
              ),
            ],
          ),
                         // TODO: Add fields for photoUrl, nutrition if needed
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
                       if (_formKey.currentState!.validate()) {
                          final finalCategory = (isCreatingNewCategory ? _newCategoryController.text.trim() : selectedCategory);
                          if (finalCategory.isEmpty) {
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Le nom de la catégorie ne peut pas être vide.')),
                             );
                             return;
                          }

                          final newItemData = {
                             'id': existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                             'nom': _nameController.text.trim(),
                             'description': _descriptionController.text.trim(),
                             'prix': _priceController.text.replaceAll(',', '.'),
                             'catégorie': finalCategory, // Use final determined category
                             // 'nutrition': ...,
                             // 'photo': ...,
                          };

                          final newItem = MenuItem.fromJson(newItemData);

                setState(() {
                             // Remove from old category if editing and category changed
                             if (isEditing && existingItem.category != finalCategory) {
                                _independentItems[existingItem.category]?.removeWhere((item) => item.id == existingItem.id);
                                if (_independentItems[existingItem.category]?.isEmpty ?? false) {
                                   _independentItems.remove(existingItem.category);
                                    _categories.remove(existingItem.category);
                                }
                             }

                             // Add or update in the new/correct category
                             _independentItems.putIfAbsent(finalCategory, () => []);
                             final categoryList = _independentItems[finalCategory]!;

                             if (isEditing) {
                                final index = categoryList.indexWhere((item) => item.id == existingItem.id);
                                if (index != -1) {
                                   categoryList[index] = newItem;
                                } else { // If it wasn't found (e.g., category changed), add it
                                   categoryList.add(newItem);
                                }
                             } else {
                                categoryList.add(newItem);
                             }

                             // Add new category to list if created
                             if (!_categories.contains(finalCategory)) {
                                _categories.add(finalCategory);
                                _categories.sort();
                             }
                          });
                          Navigator.pop(context); // Close dialog
                       }
                    },
                    child: const Text('Sauvegarder'),
                 ),
               ],
            );
          }
        ),
      );
    }
    
  // --- Delete Actions ---
  Future<void> _deleteMenu(Menu menuToDelete) async {
     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
           title: const Text('Confirmer la suppression'),
           content: Text('Voulez-vous vraiment supprimer le menu "${menuToDelete.name}" ?'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
             TextButton(
               onPressed: () => Navigator.pop(context, true),
               child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
     );

     if (confirm == true) {
        setState(() {
           _globalMenus.removeWhere((menu) => menu.id == menuToDelete.id);
        });
        // Optionally trigger server update immediately or rely on main save button
        // await _saveChanges(); 
     }
  }

  Future<void> _deleteItem(MenuItem itemToDelete, String category) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
           title: const Text('Confirmer la suppression'),
           content: Text('Voulez-vous vraiment supprimer l'article "${itemToDelete.name}" de la catégorie "$category" ?'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
             TextButton(
               onPressed: () => Navigator.pop(context, true),
               child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
     );

     if (confirm == true) {
       setState(() {
         _independentItems[category]?.removeWhere((item) => item.id == itemToDelete.id);
         if (_independentItems[category]?.isEmpty ?? false) {
           _independentItems.remove(category);
           _categories.remove(category);
         }
       });
        // Optionally trigger server update immediately or rely on main save button
        // await _saveChanges(); 
     }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion Menu & Articles"),
        backgroundColor: primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
          indicatorColor: theme.colorScheme.onPrimary,
          tabs: const [
            Tab(text: 'Menus Globaux'),
            Tab(text: 'Articles Indépendants'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: theme.colorScheme.onPrimary),
            onPressed: _isLoading ? null : _saveChanges,
            tooltip: "Enregistrer les modifications",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
                  children: [
                if (_pendingApproval) _buildPendingApprovalBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                      children: [
                      _buildGlobalMenusTab(theme, primaryColor),
                      _buildIndependentItemsTab(theme, secondaryColor),
                    ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  // --- UI Builder Methods ---

  Widget _buildPendingApprovalBanner() {
    return Material(
      color: Colors.orange.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                        child: Row(
                                          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                'Des modifications sont en attente de validation (sous 24h).',
                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                          ],
                                        ),
      ),
    );
  }

  // Builder for the Global Menus Tab
  Widget _buildGlobalMenusTab(ThemeData theme, Color primaryColor) {
    return Scaffold( // Use Scaffold for FAB
      body: _globalMenus.isEmpty
          ? Center(child: Text('Aucun menu global défini.', style: theme.textTheme.titleMedium))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _globalMenus.length,
              itemBuilder: (context, index) {
                final menu = _globalMenus[index];
                return Card(
            elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(menu.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('${menu.price.toStringAsFixed(2)} €${menu.description.isNotEmpty ? '\n${menu.description}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                          tooltip: 'Modifier le menu',
                          onPressed: () => _showEditMenuDialog(existingMenu: menu),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                          tooltip: 'Supprimer le menu',
                          onPressed: () => _deleteMenu(menu),
                        ),
                      ],
                    ),
                    // Optional: Add onTap to view included items if needed
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ajouter Menu'),
        backgroundColor: primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () => _showEditMenuDialog(),
      ),
    );
  }

  // Builder for the Independent Items Tab
  Widget _buildIndependentItemsTab(ThemeData theme, Color secondaryColor) {
     final categoriesToDisplay = _categories.isNotEmpty ? _categories : _independentItems.keys.toList()..sort();

    return Scaffold( // Use Scaffold for FAB
      body: categoriesToDisplay.isEmpty
          ? Center(child: Text('Aucun article indépendant défini.', style: theme.textTheme.titleMedium))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: categoriesToDisplay.length,
              itemBuilder: (context, index) {
                final categoryName = categoriesToDisplay[index];
                final itemsInCategory = _independentItems[categoryName] ?? [];

                // Use ExpansionTile for categories
                return Card( // Card around ExpansionTile for better separation
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                    key: PageStorageKey(categoryName), // Preserve state on scroll
                    backgroundColor: secondaryColor.withOpacity(0.03),
                    collapsedBackgroundColor: Colors.white,
                    iconColor: secondaryColor,
                    collapsedIconColor: Colors.grey[600],
                  title: Text(
                      categoryName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: secondaryColor),
                    ),
                    subtitle: Text('${itemsInCategory.length} article(s)'),
                    childrenPadding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                    children: itemsInCategory.map((item) {
                      return ListTile(
                         dense: true,
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                         title: Text(item.name, style: theme.textTheme.bodyLarge),
                         subtitle: Text('${item.price.toStringAsFixed(2)} €${item.description.isNotEmpty ? '\n${item.description}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                  children: [
                             IconButton(
                               icon: Icon(Icons.edit_outlined, color: secondaryColor, size: 20),
                               tooltip: 'Modifier l'article',
                               onPressed: () => _showEditItemDialog(existingItem: item),
                             ),
                             IconButton(
                               icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                               tooltip: 'Supprimer l'article',
                               onPressed: () => _deleteItem(item, categoryName),
                             ),
                           ],
                         ),
                      );
                    }).toList(),
                  ),
                        );
                      },
                    ),
       floatingActionButton: FloatingActionButton.extended(
         icon: const Icon(Icons.add),
         label: const Text('Ajouter Article'),
         backgroundColor: secondaryColor,
         foregroundColor: theme.colorScheme.onSecondary,
         onPressed: () => _showEditItemDialog(),
      ),
    );
  }
}

class RestaurantStatsScreen extends StatelessWidget {
  final String producerId;
  
  const RestaurantStatsScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques du Restaurant'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Center(
        child: Text('Statistiques pour le restaurant ID: $producerId'),
      ),
    );
  }
}

class ClientsListScreen extends StatelessWidget {
  final String producerId;
  
  const ClientsListScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Clients'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Center(
        child: Text('Liste des clients pour le restaurant ID: $producerId'),
      ),
    );
  }
} 
