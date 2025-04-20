import 'package:flutter/material.dart';

class PostInteractionBar extends StatelessWidget {
  final Map<String, dynamic> post;
  final String userId;
  final VoidCallback onRefresh;
  final Color? themeColor;

  const PostInteractionBar({
    Key? key,
    required this.post,
    required this.userId,
    required this.onRefresh,
    this.themeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Récupérer les compteurs depuis le post
    final int likeCount = post['likes']?.length ?? 0;
    final int interestCount = post['interests']?.length ?? 0;
    final int choiceCount = post['choices']?.length ?? 0;
    
    // Vérifier si l'utilisateur a interagi avec ce post
    final bool isLiked = post['likes']?.contains(userId) ?? false;
    final bool isInterested = post['interests']?.contains(userId) ?? false;
    final bool isChosen = post['choices']?.contains(userId) ?? false;

    // Couleur thématique (orange par défaut, violet pour les loisirs)
    final Color primaryColor = themeColor ?? Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInteractionButton(
            icon: Icons.favorite,
            label: 'J\'aime',
            count: likeCount,
            isActive: isLiked,
            color: isLiked ? Colors.red : Colors.grey,
            onTap: () => _handleLike(context),
          ),
          _buildInteractionButton(
            icon: Icons.star,
            label: 'Intéressé',
            count: interestCount,
            isActive: isInterested,
            color: isInterested ? primaryColor : Colors.grey,
            onTap: () => _handleInterest(context),
          ),
          _buildInteractionButton(
            icon: Icons.check_circle,
            label: 'Choix',
            count: choiceCount,
            isActive: isChosen,
            color: isChosen ? Colors.green : Colors.grey,
            onTap: () => _handleChoice(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? color : Colors.grey[700],
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Gestion des interactions
  void _handleLike(BuildContext context) async {
    // Implémenter la logique pour aimer un post
    try {
      // Simuler un appel API
      await Future.delayed(const Duration(milliseconds: 300));
      // Rafraîchir l'UI
      onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _handleInterest(BuildContext context) async {
    // Implémenter la logique pour marquer l'intérêt
    try {
      // Simuler un appel API
      await Future.delayed(const Duration(milliseconds: 300));
      // Rafraîchir l'UI
      onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _handleChoice(BuildContext context) async {
    // Implémenter la logique pour faire un choix
    try {
      // Simuler un appel API
      await Future.delayed(const Duration(milliseconds: 300));
      // Rafraîchir l'UI
      onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
} 