import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart' as constants;
import 'edit_item_screen.dart'; // Assurez-vous que ce fichier sera créé

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

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<Map<String, dynamic>> globalMenus = [];
  Map<String, List<Map<String, dynamic>>> independentItems = {};
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchMenuData();
  }

  /// Récupère les données du menu depuis le backend
  Future<void> _fetchMenuData() async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}');
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Données du backend : $data");

        // Initialiser avec des structures vides si les données n'existent pas
        final structuredData = data?['structured_data'] as Map<String, dynamic>? ?? {}; 

        // Vérification et traitement des menus globaux
        List<Map<String, dynamic>> safeGlobalMenus = [];
        if (structuredData['Menus Globaux'] is List) {
            safeGlobalMenus = List<Map<String, dynamic>>.from(
                structuredData['Menus Globaux'].whereType<Map<String, dynamic>>()
            );
        } else {
            print("⚠️ 'Menus Globaux' non trouvé ou n'est pas une liste.");
        }

        // Vérification des items indépendants et regroupement par catégorie
        Map<String, List<Map<String, dynamic>>> groupedItems = {};
        if (structuredData['Items Indépendants'] is List) {
          for (var categoryData in structuredData['Items Indépendants']) {
            if (categoryData is! Map<String, dynamic>) continue;

            final categoryName = categoryData['catégorie']?.toString().trim();
            final itemsList = categoryData['items'];
            
            // S'assurer que categoryName n'est pas null ou vide
            if (categoryName == null || categoryName.isEmpty) {
                print("⚠️ Catégorie sans nom trouvée: $categoryData");
                continue; // Ignorer cette catégorie ou lui donner un nom par défaut
            }

            if (itemsList is List) {
                final items = List<Map<String, dynamic>>.from(itemsList.whereType<Map<String, dynamic>>());
                groupedItems.putIfAbsent(categoryName, () => <Map<String, dynamic>>[]).addAll(items);
            } else {
                print("⚠️ 'items' dans la catégorie '$categoryName' n'est pas une liste.");
            }
          }
        } else {
            print("⚠️ 'Items Indépendants' non trouvé ou n'est pas une liste.");
        }

        if (mounted) {
        setState(() {
            globalMenus = safeGlobalMenus;
            independentItems = groupedItems;
            isLoading = false;
          });
        }
      } else {
          if (mounted) {
              _showError("Erreur lors de la récupération des données (${response.statusCode}).");
              setState(() => isLoading = false); // Arrêter le chargement en cas d'erreur
          }
      }
    } catch (e) {
        if (mounted) {
            _showError("Erreur réseau : $e");
            setState(() => isLoading = false); // Arrêter le chargement en cas d'erreur
        }
    }
  }


  void _submitUpdates() async {
    final url = Uri.parse('${constants.getBaseUrl()}/api/producers/${widget.producerId}/update-items');

    // Convertir independentItems en la structure attendue par le backend
    final List<Map<String, dynamic>> independentItemsPayload = independentItems.entries.map((entry) {
        return {
            'catégorie': entry.key,
            'items': entry.value
        };
    }).toList();

    final updatedData = {
      "Menus Globaux": globalMenus,
      "Items Indépendants": independentItemsPayload, // Utiliser le payload converti
    };

    print("📤 Données envoyées pour mise à jour : ${jsonEncode(updatedData)}");

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updatedData),
      );

      if (response.statusCode == 200) {
        print("✅ Menus et items mis à jour avec succès !");
        if (mounted) {
            _showSuccess("Mise à jour réussie");
        }
        } else {
        print("❌ Erreur lors de la mise à jour : ${response.body}");
        if (mounted) {
            _showError("Erreur lors de la mise à jour : ${response.statusCode}");
        }
        }
    } catch (e) {
      print("❌ Erreur réseau : $e");
       if (mounted) {
            _showError("Erreur réseau : $e");
        }
    }
  }

  /// Affiche un message d'erreur
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Affiche un message de succès
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Gestion des menus globaux
  void _addGlobalMenu() {
    setState(() {
      globalMenus.add({
        "nom": "Nouveau Menu", // Nom par défaut
        "prix": "0.0", // Prix par défaut
        // La structure "inclus" doit correspondre à ce qu'attend le backend
        // Si "inclus" doit être une liste d'objets { catégorie, items }, initialisez-la comme telle.
        // Si c'est juste une liste de strings, changez la structure.
        "inclus": [], 
      });
    });
  }

  void _deleteGlobalMenu(int index) {
    setState(() {
      globalMenus.removeAt(index);
    });
  }

  /// Gestion des items indépendants
  void _addIndependentCategory() {
    // Demander le nom de la nouvelle catégorie à l'utilisateur
    showDialog(
        context: context,
      builder: (context) {
        final TextEditingController categoryController = TextEditingController();
            return AlertDialog(
          title: const Text('Nouvelle Catégorie'),
          content: TextField(
            controller: categoryController,
            decoration: const InputDecoration(hintText: 'Nom de la catégorie'),
               ),
               actions: [
                 TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                 ),
            TextButton(
              onPressed: () {
                final categoryName = categoryController.text.trim();
                if (categoryName.isNotEmpty && !independentItems.containsKey(categoryName)) {
                setState(() {
                        independentItems[categoryName] = []; // Ajouter la nouvelle catégorie vide
                    });
                    Navigator.pop(context);
                } else if (categoryName.isEmpty) {
                    _showError("Le nom de la catégorie ne peut pas être vide.");
                             } else {
                     _showError("Cette catégorie existe déjà.");
                }
              },
              child: const Text('Ajouter'),
                 ),
               ],
            );
      },
    );
  }


  void _addIndependentItem(String category) {
        setState(() {
      independentItems[category]?.add({
        "nom": "Nouvel Item", // Nom par défaut
        "description": "",
        "prix": "0.0", // Prix par défaut
      });
    });
  }

  void _deleteIndependentItem(String category, int itemIndex) {
    setState(() {
      independentItems[category]?.removeAt(itemIndex);
      // Optionnel: supprimer la catégorie si elle devient vide
      // if (independentItems[category]?.isEmpty ?? false) {
      //   independentItems.remove(category);
      // }
    });
  }

  void _deleteIndependentCategory(String category) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
           title: const Text('Confirmer la suppression'),
              content: Text('Voulez-vous vraiment supprimer la catégorie "$category" et tous ses items ?'),
           actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
             TextButton(
                      onPressed: () {
                          setState(() {
                              independentItems.remove(category);
                          });
                          Navigator.pop(context);
                      },
               child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Menus"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitUpdates,
            tooltip: "Enregistrer les modifications",
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  _buildGlobalMenusSection(),
                  const SizedBox(height: 20),
                  _buildIndependentItemsSection(),
                  const SizedBox(height: 20),
                  // Bouton pour ajouter une catégorie indépendante
                  ElevatedButton(
                      onPressed: _addIndependentCategory,
                      child: const Text("Ajouter une Catégorie Indépendante"),
                                              ),
                                          ],
                                        ),
      ),
    );
  }

  Widget _buildGlobalMenusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Menus Globaux", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (globalMenus.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text("Aucun menu global défini.", style: TextStyle(color: Colors.grey)),
            )
        else
            ...globalMenus.asMap().entries.map((entry) {
              final menuIndex = entry.key;
              final menu = entry.value;
              final menuName = menu["nom"]?.toString() ?? "Menu sans nom";
              final menuPrice = menu["prix"]?.toString() ?? "N/A";
              final menuId = menu["_id"]?.toString(); // Récupérer l'ID du menu s'il existe

                return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  // Clé unique pour conserver l'état d'expansion
                  key: PageStorageKey('globalMenu_$menuIndex'), 
                  title: Text(menuName),
                  subtitle: Text("Prix: $menuPrice"),
                  initiallyExpanded: false, // Commencer replié
                  childrenPadding: const EdgeInsets.all(16.0),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Champs pour éditer nom et prix (pourraient être dans EditItemScreen)
                    TextFormField(
                      initialValue: menuName,
                      decoration: const InputDecoration(labelText: "Nom du Menu"),
                      onChanged: (value) {
                        setState(() {
                          globalMenus[menuIndex]["nom"] = value;
                        });
                      },
                    ),
                    TextFormField(
                      initialValue: menuPrice,
                      decoration: const InputDecoration(labelText: "Prix du Menu"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          globalMenus[menuIndex]["prix"] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Boutons d'action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "Supprimer ce menu",
                          onPressed: () => _deleteGlobalMenu(menuIndex),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: "Modifier les détails/items inclus",
                          onPressed: () {
                            // Vérifier si menuId existe avant de naviguer
                            if (menuId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditItemScreen(
                                    producerId: widget.producerId,
                                    item: menu, // Passer tout l'objet menu
                                    itemId: menuId, // Passer l'ID spécifique
                                    itemType: 'menu', // Indiquer que c'est un menu
                                    onSave: (updatedMenu) {
                                      // Mise à jour locale après sauvegarde dans EditItemScreen
                                      setState(() {
                                        globalMenus[menuIndex] = updatedMenu;
                                      });
                                    },
                                  ),
                                ),
                              ).then((_) {
                                  // Optionnel: rafraîchir les données après retour
                                  // _fetchMenuData(); 
                              });
                            } else {
                                _showError("Impossible de modifier : ID du menu manquant.");
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        // Bouton pour ajouter un nouveau menu global
        Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
                onPressed: _addGlobalMenu,
                icon: const Icon(Icons.add),
                label: const Text("Ajouter un Menu Global"),
            ),
        ),
      ],
    );
  }

  Widget _buildIndependentItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Items Indépendants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (independentItems.isEmpty)
             const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text("Aucune catégorie d'items indépendants définie.", style: TextStyle(color: Colors.grey)),
            )
        else
            ...independentItems.entries.map((entry) {
              final category = entry.key;
              final items = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  key: PageStorageKey('independentCategory_$category'), // Clé unique
                  title: Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
                  initiallyExpanded: false,
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: "Supprimer cette catégorie",
                      onPressed: () => _deleteIndependentCategory(category),
                  ),
                  childrenPadding: const EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
                  children: [
                    if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Aucun item dans cette catégorie.", style: TextStyle(color: Colors.grey)),
                        )
                    else
                       ...items.asMap().entries.map((itemEntry) {
                        final itemIndex = itemEntry.key;
                        final item = itemEntry.value;
                        final itemName = item["nom"] ?? "Item sans nom";
                        final itemPrice = item["prix"]?.toString() ?? "N/A";
                        final itemId = item["_id"]?.toString(); // Récupérer l'ID de l'item

                      return ListTile(
                          title: Text(itemName),
                          subtitle: Text("Prix : $itemPrice"),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                  children: [
                             IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: "Modifier cet item",
                                onPressed: () {
                                   if (itemId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditItemScreen(
                                            producerId: widget.producerId,
                                            item: item,
                                            itemId: itemId, // Passer l'ID
                                            itemType: 'item', // Indiquer que c'est un item
                                            onSave: (updatedItem) {
                                              setState(() {
                                                // Assurer que la catégorie existe toujours
                                                if (independentItems.containsKey(category)) {
                                                  independentItems[category]![itemIndex] = updatedItem;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ).then((_) { 
                                          // Optionnel: rafraîchir 
                                          // _fetchMenuData(); 
                                      });
                                    } else {
                                        _showError("Impossible de modifier : ID de l'item manquant.");
                                    }
                                },
                             ),
                             IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: "Supprimer cet item",
                                onPressed: () => _deleteIndependentItem(category, itemIndex),
                             ),
                           ],
                         ),
                           // Optionnel: onTap pour voir les détails si nécessaire
                           // onTap: () { /* Naviguer vers une vue détaillée ? */ },
                        );
                      }).toList(),
                    // Bouton pour ajouter un item à cette catégorie
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                            onPressed: () => _addIndependentItem(category),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Ajouter un item"),
                        ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ],
    );
  }
} 
