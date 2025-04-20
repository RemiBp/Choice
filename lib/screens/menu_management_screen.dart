import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart';
import 'package:intl/intl.dart';

class MenuManagementScreen extends StatefulWidget {
  final String producerId;
  
  const MenuManagementScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _menus = [];
  List<dynamic> _categories = [];
  Map<String, List<dynamic>> _items = {};
  
  // Variables pour le mode édition
  bool _isEditingMenu = false;
  Map<String, dynamic>? _currentMenu;
  final _menuNameController = TextEditingController();
  final _menuDescriptionController = TextEditingController();
  final _menuPriceController = TextEditingController();

  // Variables pour le système de vérification
  bool _pendingApproval = false;
  DateTime? _modificationDate;
  Map<String, List<String>> _modificationsHistory = {};

  // Animation controllers
  final _animDuration = const Duration(milliseconds: 300);
  
  @override
  void initState() {
    super.initState();
    _fetchMenuData();
    _fetchItemsAndCategories();
    _checkPendingModifications();
  }
  
  @override
  void dispose() {
    _menuNameController.dispose();
    _menuDescriptionController.dispose();
    _menuPriceController.dispose();
    super.dispose();
  }

  // Vérifier s'il y a des modifications en attente
  Future<void> _checkPendingModifications() async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/menu/pending');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pendingApproval = data['pending_approval'] ?? false;
          if (data['last_modified'] != null) {
            _modificationDate = DateTime.parse(data['last_modified']);
          }
          if (data['modifications_history'] != null && data['modifications_history'] is Map) {
            _modificationsHistory = Map<String, List<String>>.from(
              (data['modifications_history'] as Map).map((key, value) => 
                MapEntry(key, List<String>.from(value))
              )
            );
          }
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification des modifications en attente: $e');
    }
  }
  
  Future<void> _fetchMenuData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _menus = data['structured_data']?['Menus Globaux'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Erreur lors de la récupération des menus');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  Future<void> _fetchItemsAndCategories() async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['structured_data']?['Items Indépendants'] ?? [];
        
        final Map<String, List<dynamic>> itemsByCategory = {};
        final Set<String> categoriesSet = {};
        
        for (var category in items) {
          final categoryName = category['catégorie'] ?? 'Autres';
          categoriesSet.add(categoryName);
          
          if (!itemsByCategory.containsKey(categoryName)) {
            itemsByCategory[categoryName] = [];
          }
          
          for (var item in category['items'] ?? []) {
            itemsByCategory[categoryName]!.add(item);
          }
        }
        
        setState(() {
          _categories = categoriesSet.toList()..sort();
          _items = itemsByCategory;
        });
      } else {
        throw Exception('Erreur lors de la récupération des articles');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  Future<void> _saveMenu() async {
    try {
      final name = _menuNameController.text.trim();
      final description = _menuDescriptionController.text.trim();
      final priceText = _menuPriceController.text.trim();
      
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le nom du menu est requis')),
        );
        return;
      }
      
      final price = double.tryParse(priceText.replaceAll(',', '.')) ?? 0;
      
      // Ajout des métadonnées pour le système de vérification
      final now = DateTime.now();
      final menu = {
        'nom': name,
        'description': description,
        'prix': price,
        'inclus': _currentMenu?['inclus'] ?? [],
        'last_modified': now.toIso8601String(),
        'pending_approval': true,
      };
      
      // Tracker les modifications pour l'historique
      String modificationDescription = _currentMenu == null 
          ? "Nouveau menu créé: $name" 
          : "Menu modifié: ${_currentMenu!['nom']} → $name";
      
      // Si nous sommes en mode édition, mettre à jour le menu existant
      if (_currentMenu != null) {
        final index = _menus.indexWhere((m) => m['nom'] == _currentMenu!['nom']);
        if (index >= 0) {
          setState(() {
            _menus[index] = menu;
          });
        }
      } else {
        // Sinon ajouter un nouveau menu
        setState(() {
          _menus.add(menu);
        });
      }
      
      // Sauvegarder les modifications sur le serveur
      await _updateMenusOnServer(modificationDescription);
      
      setState(() {
        _isEditingMenu = false;
        _currentMenu = null;
        _pendingApproval = true;
        _modificationDate = now;
      });
      
      _resetFormControllers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menu sauvegardé avec succès. Les modifications seront vérifiées sous 24h.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  Future<void> _updateMenusOnServer(String modificationDescription) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/producers/${widget.producerId}/menu');
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(now);
      
      // Ajouter la modification à l'historique
      if (!_modificationsHistory.containsKey(formattedDate)) {
        _modificationsHistory[formattedDate] = [];
      }
      _modificationsHistory[formattedDate]!.add('[${DateFormat('HH:mm').format(now)}] $modificationDescription');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'menus': _menus,
          'pending_approval': true,
          'last_modified': now.toIso8601String(),
          'modifications_history': _modificationsHistory,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Erreur lors de la mise à jour des menus sur le serveur');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de synchronisation: $e')),
      );
    }
  }
  
  void _editMenu(Map<String, dynamic> menu) {
    setState(() {
      _currentMenu = Map<String, dynamic>.from(menu);
      _isEditingMenu = true;
      
      _menuNameController.text = menu['nom'] ?? '';
      _menuDescriptionController.text = menu['description'] ?? '';
      _menuPriceController.text = (menu['prix'] ?? '').toString();
    });
  }
  
  void _deleteMenu(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce menu ? Cette action sera vérifiée par notre équipe sous 24h.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final deletedMenu = _menus[index];
              final menuName = deletedMenu['nom'] ?? 'Menu sans nom';
              
              setState(() {
                _menus.removeAt(index);
                _pendingApproval = true;
                _modificationDate = DateTime.now();
              });
              
              // Mettre à jour avec une description de suppression
              await _updateMenusOnServer("Menu supprimé: $menuName");
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Menu supprimé. La suppression sera vérifiée sous 24h.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
  
  void _resetFormControllers() {
    _menuNameController.clear();
    _menuDescriptionController.clear();
    _menuPriceController.clear();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestion du Menu',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepOrange,
        actions: [
          if (_isEditingMenu)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditingMenu = false;
                  _currentMenu = null;
                  _resetFormControllers();
                });
              },
              tooltip: 'Annuler',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: _animDuration,
              child: _isEditingMenu
                  ? _buildMenuForm()
                  : _buildMenuContent(),
            ),
      floatingActionButton: !_isEditingMenu
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isEditingMenu = true;
                  _currentMenu = null;
                  _resetFormControllers();
                });
              },
              backgroundColor: Colors.deepOrange,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildMenuContent() {
    return Column(
      children: [
        // Notification de vérification en attente si nécessaire
        if (_pendingApproval) _buildPendingApprovalBanner(),
        
        // Liste des menus
        Expanded(
          child: _buildMenuList(),
        ),
      ],
    );
  }
  
  Widget _buildPendingApprovalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Modifications en attente de vérification',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _modificationDate != null
                ? 'Dernière modification: ${DateFormat('dd/MM/yyyy à HH:mm').format(_modificationDate!)}'
                : 'Des modifications sont en attente de vérification par notre équipe.',
            style: TextStyle(color: Colors.orange.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Les modifications seront examinées sous 24h ouvrées afin de vérifier que les éléments supprimés ou modifiés '
            'ne sont pas effectués uniquement pour les items ayant reçu de mauvaises notes.',
            style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuList() {
    if (_menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 70,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun menu disponible',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ajoutez votre premier menu pour présenter vos offres à vos clients',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Ajouter un menu'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  _isEditingMenu = true;
                  _currentMenu = null;
                  _resetFormControllers();
                });
              },
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _menus.length,
      itemBuilder: (context, index) {
        final menu = _menus[index];
        final includedItems = menu['inclus'] ?? [];
        final isPending = menu['pending_approval'] == true;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec le nom du menu et les boutons d'action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPending 
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.deepOrange.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    isPending
                        ? const Icon(Icons.pending, color: Colors.orange)
                        : const Icon(Icons.restaurant_menu, color: Colors.deepOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            menu['nom'] ?? 'Menu sans nom',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (menu['description'] != null && menu['description'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                menu['description'],
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (isPending)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'En attente de vérification',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${menu['prix']} €',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isPending ? Colors.orange : Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Boutons d'action
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                      onPressed: () => _editMenu(menu),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                      onPressed: () => _deleteMenu(index),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Contenu du menu
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.list_alt, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Contenu du menu',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    if (includedItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Aucun élément dans ce menu',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: includedItems.length,
                        itemBuilder: (context, catIndex) {
                          final category = includedItems[catIndex];
                          final items = category['items'] ?? [];
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    category['catégorie'] ?? 'Catégorie non spécifiée',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                
                                if (items.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'Aucun plat dans cette catégorie',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    itemBuilder: (context, itemIndex) {
                                      final item = items[itemIndex];
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8, left: 8),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.restaurant, size: 16, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                item['nom'] ?? 'Plat sans nom',
                                                style: GoogleFonts.nunito(fontSize: 14),
                                              ),
                                            ),
                                            if (item['prix'] != null)
                                              Text(
                                                '${item['prix']} €',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepOrange,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMenuForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentMenu == null ? 'Ajouter un menu' : 'Modifier le menu',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Nom du menu
                  TextField(
                    controller: _menuNameController,
                    decoration: InputDecoration(
                      labelText: 'Nom du menu',
                      hintText: 'Ex: Menu du jour, Menu dégustation...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.restaurant_menu),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: _menuDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optionnel)',
                      hintText: 'Décrivez brièvement le menu...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Prix
                  TextField(
                    controller: _menuPriceController,
                    decoration: InputDecoration(
                      labelText: 'Prix (€)',
                      hintText: 'Ex: 25.90',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.euro),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Boutons d'action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditingMenu = false;
                            _currentMenu = null;
                            _resetFormControllers();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _saveMenu,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(_currentMenu == null ? 'Créer le menu' : 'Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_currentMenu != null) ...[
            const SizedBox(height: 24),
            Text(
              'Éléments inclus dans le menu',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Liste des items par catégorie
            ..._categories.map((category) {
              final categoryItems = _items[category] ?? [];
              if (categoryItems.isEmpty) return const SizedBox.shrink();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: Text(
                    category,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  leading: const Icon(Icons.category),
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categoryItems.length,
                      itemBuilder: (context, index) {
                        final item = categoryItems[index];
                        final itemName = item['nom'] ?? 'Item sans nom';
                        final itemPrice = item['prix'] ?? 'N/A';
                        
                        // Vérifier si l'item est déjà dans le menu
                        bool isIncluded = false;
                        if (_currentMenu != null) {
                          final inclus = _currentMenu!['inclus'] ?? [];
                          for (var cat in inclus) {
                            if (cat['catégorie'] == category) {
                              final items = cat['items'] ?? [];
                              isIncluded = items.any((i) => i['nom'] == itemName);
                              break;
                            }
                          }
                        }
                        
                        return CheckboxListTile(
                          title: Text(
                            itemName,
                            style: GoogleFonts.nunito(),
                          ),
                          subtitle: Text(
                            'Prix: $itemPrice €',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          value: isIncluded,
                          onChanged: (newValue) {
                            if (newValue == null) return;
                            
                            setState(() {
                              if (_currentMenu == null) {
                                _currentMenu = {
                                  'nom': _menuNameController.text,
                                  'description': _menuDescriptionController.text,
                                  'prix': _menuPriceController.text,
                                  'inclus': [],
                                };
                              }
                              
                              var inclus = _currentMenu!['inclus'] as List<dynamic>;
                              
                              // Trouver la catégorie existante ou en créer une nouvelle
                              var categoryEntry = inclus.firstWhere(
                                (cat) => cat['catégorie'] == category,
                                orElse: () {
                                  final newCat = {'catégorie': category, 'items': []};
                                  inclus.add(newCat);
                                  return newCat;
                                },
                              );
                              
                              var items = categoryEntry['items'] as List<dynamic>;
                              
                              if (newValue) {
                                // Ajouter l'item s'il n'est pas déjà présent
                                if (!items.any((i) => i['nom'] == itemName)) {
                                  items.add(item);
                                }
                              } else {
                                // Retirer l'item
                                items.removeWhere((i) => i['nom'] == itemName);
                                
                                // Si la catégorie est vide, la retirer
                                if (items.isEmpty) {
                                  inclus.removeWhere((cat) => cat['catégorie'] == category);
                                }
                              }
                              
                              _currentMenu!['inclus'] = inclus;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
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
