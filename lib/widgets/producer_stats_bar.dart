import 'package:flutter/material.dart';

class ProducerStatsBar extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final int interestedCount;
  final int choicesCount;
  final List<String> followerIds;
  final List<String> followingIds;
  final List<String> interestedUserIds;
  final List<String> choiceUserIds;
  final Function(String, List<String>) onNavigateToUserList;

  const ProducerStatsBar({
    Key? key,
    required this.followersCount,
    required this.followingCount,
    required this.interestedCount,
    required this.choicesCount,
    required this.followerIds,
    required this.followingIds,
    required this.interestedUserIds,
    required this.choiceUserIds,
    required this.onNavigateToUserList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatButton(
            context,
            icon: Icons.people_outline,
            label: 'Abonnés',
            count: followersCount,
            onTap: () => onNavigateToUserList('Abonnés', followerIds),
          ),
          _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.person_add_alt_1_outlined,
            label: 'Abonnements',
            count: followingCount,
            onTap: () => onNavigateToUserList('Abonnements', followingIds),
          ),
          _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.emoji_objects_outlined,
            label: 'Intéressés',
            count: interestedCount,
            onTap: () => onNavigateToUserList('Intéressés', interestedUserIds),
          ),
          _verticalDivider(),
          _buildStatButton(
            context,
            icon: Icons.check_circle_outline,
            label: 'Choices',
            count: choicesCount,
            onTap: () => onNavigateToUserList('Choices', choiceUserIds),
          ),
        ],
      ),
    );
  }

  Widget _buildStatButton(BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(minWidth: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.teal, size: 24),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[200]);
  }
} 