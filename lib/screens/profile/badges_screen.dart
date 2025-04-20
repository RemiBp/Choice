import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/badges/badge_model.dart';
import '../../services/badge_service.dart';
import '../../widgets/badge_display_widget.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({Key? key}) : super(key: key);

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BadgeCategory? _selectedCategory;
  bool _showObtainedOnly = false;
  bool _showUnobtainedOnly = false;
  bool _showPinnedFirst = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialiser le service de badges si ce n'est pas déjà fait
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final badgeService = Provider.of<BadgeService>(context, listen: false);
      if (!badgeService.initialized) {
        badgeService.initialize();
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Badges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Obtenus'),
            Tab(text: 'À Débloquer'),
          ],
        ),
      ),
      body: Consumer<BadgeService>(
        builder: (context, badgeService, child) {
          if (badgeService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (badgeService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur de chargement: ${badgeService.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[400]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => badgeService.initialize(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          // Badges stats
          final totalBadges = badgeService.badgeCollection.getAllBadges().length;
          final visibleBadges = badgeService.getVisibleBadges();
          final obtainedBadges = visibleBadges.where((b) => b.isObtained).length;
          final completion = badgeService.completionPercentage;
          final totalPoints = badgeService.getTotalRewardPoints();
          
          return Column(
            children: [
              // En-tête avec les points
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Points totaux',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$totalPoints pts',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: 40,
                    ),
                  ],
                ),
              ),
              
              // Statistiques des badges
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          context, 
                          '$obtainedBadges/$totalBadges', 
                          'Badges Obtenus',
                          Icons.emoji_events,
                        ),
                        _buildStatItem(
                          context, 
                          '${completion.toStringAsFixed(0)}%', 
                          'Complété',
                          Icons.star,
                        ),
                        _buildStatItem(
                          context, 
                          '$totalPoints', 
                          'Points',
                          Icons.emoji_events_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: completion / 100,
                      backgroundColor: Colors.grey[300],
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              
              // Filtres de catégorie
              if (_selectedCategory != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Chip(
                    label: Text(
                      'Catégorie: ${_selectedCategory!.displayName}',
                      style: TextStyle(
                        color: _getCategoryColor(_selectedCategory!),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: _getCategoryColor(_selectedCategory!).withOpacity(0.1),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                  ),
                ),
              
              // Liste de badges
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tous les badges
                    SingleChildScrollView(
                      child: BadgeDisplayWidget(
                        displayType: BadgeDisplayType.grid,
                        category: _selectedCategory,
                        pinnedFirst: _showPinnedFirst,
                      ),
                    ),
                    
                    // Badges obtenus
                    SingleChildScrollView(
                      child: BadgeDisplayWidget(
                        displayType: BadgeDisplayType.grid,
                        category: _selectedCategory,
                        obtainedOnly: true,
                        pinnedFirst: _showPinnedFirst,
                      ),
                    ),
                    
                    // Badges à débloquer
                    SingleChildScrollView(
                      child: BadgeDisplayWidget(
                        displayType: BadgeDisplayType.grid,
                        category: _selectedCategory,
                        unobtainedOnly: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCategorySelector,
        child: const Icon(Icons.category),
        tooltip: 'Filtrer par catégorie',
      ),
    );
  }
  
  // Construction d'un élément de statistique
  Widget _buildStatItem(BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // Afficher le sélecteur de catégorie
  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filtrer par catégorie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Option pour voir toutes les catégories
                  ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Toutes'),
                    backgroundColor: _selectedCategory == null 
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : null,
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  
                  // Une puce pour chaque catégorie
                  ...BadgeCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return ActionChip(
                      avatar: CircleAvatar(
                        backgroundColor: _getCategoryColor(category),
                        radius: 10,
                        child: isSelected
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      label: Text(category.displayName),
                      backgroundColor: isSelected 
                          ? _getCategoryColor(category).withOpacity(0.1)
                          : null,
                      labelStyle: isSelected
                          ? TextStyle(color: _getCategoryColor(category), fontWeight: FontWeight.bold)
                          : null,
                      onPressed: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Afficher les options de filtre
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Options de filtre',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Épinglés en premier'),
                    subtitle: const Text('Afficher les badges épinglés en haut de la liste'),
                    value: _showPinnedFirst,
                    onChanged: (value) {
                      setModalState(() {
                        _showPinnedFirst = value;
                      });
                      setState(() {
                        _showPinnedFirst = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'Mode de tri',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  RadioListTile<int>(
                    title: const Text('Par défaut'),
                    subtitle: const Text('Les badges obtenus d\'abord, puis par progression'),
                    value: 0,
                    groupValue: _showObtainedOnly ? 1 : (_showUnobtainedOnly ? 2 : 0),
                    onChanged: (value) {
                      setModalState(() {
                        _showObtainedOnly = false;
                        _showUnobtainedOnly = false;
                      });
                      setState(() {
                        _showObtainedOnly = false;
                        _showUnobtainedOnly = false;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Appliquer'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getCategoryColor(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.engagement: return Colors.blue;
      case BadgeCategory.discovery: return Colors.green;
      case BadgeCategory.social: return Colors.orange;
      case BadgeCategory.challenge: return Colors.purple;
      case BadgeCategory.special: return Colors.red;
      default: return Colors.grey;
    }
  }
} 