import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/badges/badge_model.dart';
import '../services/badge_service.dart';

/// Widget pour afficher une liste de badges avec différents modes de présentation
class BadgeDisplayWidget extends StatefulWidget {
  // Type d'affichage pour le widget (grille, liste, carrousel)
  final BadgeDisplayType displayType;
  
  // Catégorie spécifique à afficher (null pour toutes)
  final BadgeCategory? category;
  
  // Nombre de badges à afficher, null pour tous
  final int? limit;
  
  // Mode sélection (permet à l'utilisateur de sélectionner des badges)
  final bool selectionMode;
  
  // Badges déjà sélectionnés (en mode sélection)
  final List<String> selectedBadgeIds;
  
  // Callback quand un badge est appuyé
  final Function(AppBadge)? onBadgeTap;
  
  // Callback quand un badge est sélectionné/désélectionné (en mode sélection)
  final Function(AppBadge, bool)? onBadgeSelected;
  
  // Titre à afficher au-dessus des badges
  final String? title;
  
  // Afficher uniquement les badges obtenus
  final bool obtainedOnly;
  
  // Afficher uniquement les badges non obtenus
  final bool unobtainedOnly;
  
  // Afficher les badges épinglés en premier
  final bool pinnedFirst;

  const BadgeDisplayWidget({
    Key? key,
    this.displayType = BadgeDisplayType.grid,
    this.category,
    this.limit,
    this.selectionMode = false,
    this.selectedBadgeIds = const [],
    this.onBadgeTap,
    this.onBadgeSelected,
    this.title,
    this.obtainedOnly = false,
    this.unobtainedOnly = false,
    this.pinnedFirst = false,
  }) : super(key: key);

  @override
  State<BadgeDisplayWidget> createState() => _BadgeDisplayWidgetState();
}

class _BadgeDisplayWidgetState extends State<BadgeDisplayWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<BadgeService>(
      builder: (context, badgeService, child) {
        if (badgeService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtrer les badges selon les critères
        List<AppBadge> badges = _getFilteredBadges(badgeService);
        
        if (badges.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.obtainedOnly
                    ? 'Aucun badge obtenu dans cette catégorie'
                    : 'Aucun badge disponible dans cette catégorie',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Choisir le bon affichage selon le type
        Widget badgeWidget;
        switch (widget.displayType) {
          case BadgeDisplayType.carousel:
            badgeWidget = _buildCarousel(context, badges);
            break;
          case BadgeDisplayType.list:
            badgeWidget = _buildList(context, badges);
            break;
          case BadgeDisplayType.compact:
            badgeWidget = _buildCompactGrid(context, badges);
            break;
          case BadgeDisplayType.grid:
          default:
            badgeWidget = _buildGrid(context, badges);
            break;
        }

        // Ajouter un titre si spécifié
        if (widget.title != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.title!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              badgeWidget,
            ],
          );
        }

        return badgeWidget;
      },
    );
  }

  // Affichage en carrousel horizontal
  Widget _buildCarousel(BuildContext context, List<AppBadge> badges) {
    final limitedBadges = widget.limit != null 
        ? badges.take(widget.limit!).toList() 
        : badges;
    
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: limitedBadges.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, index) {
          final badge = limitedBadges[index];
          return _buildBadgeItem(
            context,
            badge,
            width: 100,
            isSelected: widget.selectedBadgeIds.contains(badge.id),
            showDetails: false,
          );
        },
      ),
    );
  }

  // Affichage en liste verticale
  Widget _buildList(BuildContext context, List<AppBadge> badges) {
    final limitedBadges = widget.limit != null 
        ? badges.take(widget.limit!).toList() 
        : badges;
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: limitedBadges.length,
      itemBuilder: (context, index) {
        final badge = limitedBadges[index];
        return _buildBadgeListItem(
          context,
          badge,
          isSelected: widget.selectedBadgeIds.contains(badge.id),
        );
      },
    );
  }

  // Affichage en grille standard
  Widget _buildGrid(BuildContext context, List<AppBadge> badges) {
    final limitedBadges = widget.limit != null 
        ? badges.take(widget.limit!).toList() 
        : badges;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: limitedBadges.length,
      itemBuilder: (context, index) {
        final badge = limitedBadges[index];
        return _buildBadgeItem(
          context,
          badge,
          isSelected: widget.selectedBadgeIds.contains(badge.id),
        );
      },
    );
  }

  // Affichage en grille compacte
  Widget _buildCompactGrid(BuildContext context, List<AppBadge> badges) {
    final limitedBadges = widget.limit != null 
        ? badges.take(widget.limit!).toList() 
        : badges;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: limitedBadges.map((badge) {
        return _buildBadgeItem(
          context,
          badge,
          width: 80,
          showDetails: false,
          isSelected: widget.selectedBadgeIds.contains(badge.id),
        );
      }).toList(),
    );
  }

  // Construction d'un élément badge (format carré)
  Widget _buildBadgeItem(
    BuildContext context,
    AppBadge badge, {
    double? width,
    bool showDetails = true,
    bool isSelected = false,
  }) {
    final isObtained = badge.isObtained;
    
    return GestureDetector(
      onTap: () {
        if (widget.selectionMode && widget.onBadgeSelected != null) {
          widget.onBadgeSelected!(badge, !isSelected);
        } else if (widget.onBadgeTap != null) {
          widget.onBadgeTap!(badge);
        } else {
          _showBadgeDetails(context, badge);
        }
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isSelected
              ? badge.getColor().withOpacity(0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: badge.getColor(), width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Badge image avec glow effect si obtenu
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isObtained 
                        ? badge.getColor().withOpacity(0.1)
                        : Colors.grey.withOpacity(0.05),
                    boxShadow: isObtained
                        ? [
                            BoxShadow(
                              color: badge.getColor().withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Image.asset(
                    badge.displayIconPath,
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback image
                      return CircleAvatar(
                        backgroundColor: isObtained 
                            ? badge.getColor()
                            : Colors.grey[300],
                        radius: 24,
                        child: Icon(
                          Icons.emoji_events,
                          color: isObtained 
                              ? Colors.white
                              : Colors.grey[600],
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
                
                // Indicator for selection
                if (widget.selectionMode && isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: badge.getColor(),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                
                // Level indicator
                if (badge.level > 1)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isObtained 
                            ? badge.getColor()
                            : Colors.grey[400],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        badge.level.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Locked indicator
                if (!isObtained && !badge.isSecret)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ),
                  ),
                
                // Secret indicator
                if (badge.isSecret && !isObtained)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
            
            if (showDetails) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  badge.name,
                  style: TextStyle(
                    fontWeight: isObtained ? FontWeight.bold : FontWeight.normal,
                    color: isObtained ? badge.getColor() : Colors.grey[700],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              if (!isObtained && badge.progress > 0 && !badge.isSecret) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: LinearProgressIndicator(
                    value: badge.progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(badge.getColor()),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(badge.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              
              if (badge.isRare && isObtained) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'RARE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Construction d'un élément badge (format liste)
  Widget _buildBadgeListItem(
    BuildContext context,
    AppBadge badge, {
    bool isSelected = false,
  }) {
    final isObtained = badge.isObtained;
    
    return ListTile(
      onTap: () {
        if (widget.selectionMode && widget.onBadgeSelected != null) {
          widget.onBadgeSelected!(badge, !isSelected);
        } else if (widget.onBadgeTap != null) {
          widget.onBadgeTap!(badge);
        } else {
          _showBadgeDetails(context, badge);
        }
      },
      selected: isSelected,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isObtained 
                  ? badge.getColor().withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              boxShadow: isObtained
                  ? [
                      BoxShadow(
                        color: badge.getColor().withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Image.asset(
              badge.displayIconPath,
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return CircleAvatar(
                  backgroundColor: isObtained 
                      ? badge.getColor()
                      : Colors.grey[300],
                  radius: 20,
                  child: Icon(
                    Icons.emoji_events,
                    color: isObtained 
                        ? Colors.white
                        : Colors.grey[600],
                    size: 18,
                  ),
                );
              },
            ),
          ),
          
          if (!isObtained && !badge.isSecret)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock,
                color: Colors.white54,
                size: 16,
              ),
            ),
          
          if (badge.isSecret && !isObtained)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline,
                color: Colors.white70,
                size: 22,
              ),
            ),
        ],
      ),
      title: Text(
        badge.name,
        style: TextStyle(
          fontWeight: isObtained ? FontWeight.bold : FontWeight.normal,
          color: isObtained ? badge.getColor() : Colors.grey[700],
        ),
      ),
      subtitle: Text(
        badge.isSecret && !isObtained 
            ? 'Badge secret' 
            : badge.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: isObtained
          ? Icon(
              Icons.check_circle,
              color: badge.getColor(),
            )
          : badge.progress > 0 && !badge.isSecret
              ? SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(badge.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badge.getColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: badge.progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(badge.getColor()),
                      ),
                    ],
                  ),
                )
              : null,
    );
  }

  // Filtrer les badges selon les critères spécifiés
  List<AppBadge> _getFilteredBadges(BadgeService badgeService) {
    // Obtenir les badges visibles au lieu d'utiliser userBadges directement
    List<AppBadge> badges = badgeService.getVisibleBadges();
    
    // Filtrer par catégorie si spécifiée
    if (widget.category != null) {
      badges = badges.where((badge) => badge.category == widget.category).toList();
    }
    
    // Filtrer selon obtention
    if (widget.obtainedOnly) {
      badges = badges.where((badge) => badge.isObtained).toList();
    } else if (widget.unobtainedOnly) {
      badges = badges.where((badge) => !badge.isObtained).toList();
    }
    
    // Filtrer les badges en progression
    if (widget.obtainedOnly && widget.unobtainedOnly) {
      badges = badges.where((b) => !b.isObtained && b.progress > 0).toList();
    }
    
    // Ne pas afficher les badges secrets non obtenus
    badges = badges.where((b) => !b.isSecret || b.isObtained).toList();
    
    // Trier selon les préférences
    if (widget.pinnedFirst) {
      badges.sort((a, b) {
        // D'abord par épinglage
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        
        // Ensuite par obtention
        if (a.isObtained && !b.isObtained) return -1;
        if (!a.isObtained && b.isObtained) return 1;
        
        // Ensuite par progression
        if (!a.isObtained && !b.isObtained) {
          return b.progress.compareTo(a.progress);
        }
        
        // Ensuite par date d'obtention
        if (a.dateObtained != null && b.dateObtained != null) {
          return b.dateObtained!.compareTo(a.dateObtained!);
        }
        
        return 0;
      });
    } else {
      // Tri par défaut, les obtenus en premier
      badges.sort((a, b) {
        // D'abord par obtention
        if (a.isObtained && !b.isObtained) return -1;
        if (!a.isObtained && b.isObtained) return 1;
        
        // Ensuite par progression
        if (!a.isObtained && !b.isObtained) {
          return b.progress.compareTo(a.progress);
        }
        
        // Ensuite par date d'obtention
        if (a.dateObtained != null && b.dateObtained != null) {
          return b.dateObtained!.compareTo(a.dateObtained!);
        }
        
        return 0;
      });
    }
    
    return badges;
  }

  // Ajouter des méthodes utilitaires pour category
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'engagement': return Colors.blue;
      case 'discovery': return Colors.green;
      case 'social': return Colors.orange;
      case 'challenge': return Colors.purple;
      case 'special': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'engagement': return 'Engagement';
      case 'discovery': return 'Découverte';
      case 'social': return 'Social';
      case 'challenge': return 'Challenge';
      case 'special': return 'Spécial';
      default: return 'Autre';
    }
  }

  // Afficher les détails d'un badge dans une modale
  void _showBadgeDetails(BuildContext context, AppBadge badge) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge title with category
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, 
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(badge.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getCategoryDisplayName(badge.category),
                      style: TextStyle(
                        color: _getCategoryColor(badge.category),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (badge.isRare) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, 
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RARE',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              
              // Badge image
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.isObtained 
                      ? badge.getColor().withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  boxShadow: badge.isObtained
                      ? [
                          BoxShadow(
                            color: badge.getColor().withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Image.asset(
                  badge.displayIconPath,
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return CircleAvatar(
                      backgroundColor: badge.isObtained 
                          ? badge.getColor()
                          : Colors.grey[300],
                      radius: 50,
                      child: Icon(
                        Icons.emoji_events,
                        color: badge.isObtained
                            ? Colors.white
                            : Colors.grey[600],
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Badge title
              Text(
                badge.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: badge.isObtained ? badge.getColor() : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Badge description
              Text(
                badge.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Badge status
              if (badge.isObtained) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Obtenu le ${_formatDate(badge.dateObtained!)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ] else if (!badge.isSecret) ...[
                Column(
                  children: [
                    Text(
                      'Progrès: ${(badge.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: badge.progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(badge.getColor()),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Restant: ${(badge.requiredActions - (badge.progress * badge.requiredActions).round())} actions',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock,
                      color: Colors.grey[500],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Badge secret à découvrir',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              
              // Badge rewards
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Récompense: ${badge.rewardPoints} points',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Close button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: badge.getColor(),
                ),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Format a date into a readable format
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

/// Type d'affichage pour le widget de badges
enum BadgeDisplayType {
  /// Grille standard 3x3
  grid,
  
  /// Liste verticale avec détails
  list,
  
  /// Carrousel horizontal
  carousel,
  
  /// Grille compacte sans détails
  compact,
} 