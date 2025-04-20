import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/badges/badge_model.dart';
import '../../services/badge_service.dart';
import '../../widgets/badge_display_widget.dart';
import '../../screens/profile/badges_screen.dart';

/// Widget qui affiche un résumé des badges de l'utilisateur sur son profil
class BadgesSummaryWidget extends StatelessWidget {
  /// Nombre maximum de badges à afficher
  final int badgesLimit;
  
  /// Afficher les badges les plus récemment obtenus en premier
  final bool recentFirst;
  
  /// Afficher les badges d'une catégorie spécifique
  final BadgeCategory? category;

  const BadgesSummaryWidget({
    Key? key,
    this.badgesLimit = 5,
    this.recentFirst = true,
    this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final badgeService = Provider.of<BadgeService>(context);
    
    // Obtenir les badges visibles (non secrets ou débloqués)
    final visibleBadges = badgeService.getVisibleBadges();
    
    // Filtrer pour ne montrer que les badges obtenus
    final obtainedBadges = visibleBadges
        .where((b) => b.isObtained)
        .toList();
    
    // Si pas de badges, afficher un message d'information
    if (obtainedBadges.isEmpty) {
      return Container(
        // ... existing code ...
      );
    }

    // Trier par date d'obtention si demandé
    if (recentFirst && obtainedBadges.isNotEmpty) {
      obtainedBadges.sort((a, b) {
        if (a.dateObtained == null) return 1;
        if (b.dateObtained == null) return -1;
        return b.dateObtained!.compareTo(a.dateObtained!);
      });
    }
    
    // Calculer la progression générale
    final totalBadges = badgeService.getVisibleBadges().length;
    final obtainedCount = obtainedBadges.length;
    final progressPercentage = totalBadges > 0 
        ? obtainedCount / totalBadges 
        : 0.0;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Titre avec compteur
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.emoji_events),
                const SizedBox(width: 8),
                const Text(
                  'Mes Badges',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$obtainedCount/$totalBadges',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Barre de progression
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progressPercentage,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complété à ${progressPercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 24),
          
          // Affichage des badges
          if (obtainedBadges.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pas encore de badges obtenus',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Continuez à explorer l\'application!',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            SizedBox(
              height: 120,
              child: BadgeDisplayWidget(
                displayType: BadgeDisplayType.carousel,
                obtainedOnly: true,
                category: category,
                limit: badgesLimit,
              ),
            ),
          ],
          
          // Bouton pour voir tous les badges
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BadgesScreen()),
                );
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
              child: const Text('Voir tous mes badges'),
            ),
          ),
        ],
      ),
    );
  }
} 