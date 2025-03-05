import 'package:flutter/material.dart';

class PostInteractionBar extends StatelessWidget {
  final bool isInterested;
  final bool isChoice;
  final int interestedCount;
  final int choiceCount;
  final VoidCallback onInterested;
  final VoidCallback onChoice;
  final VoidCallback onComment;
  final bool isProducerPost;

  const PostInteractionBar({
    Key? key,
    required this.isInterested,
    required this.isChoice,
    required this.interestedCount,
    required this.choiceCount,
    required this.onInterested,
    required this.onChoice,
    required this.onComment,
    this.isProducerPost = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isProducerPost) ...[
                  _buildActionButton(
                    icon: Icons.star,
                    isActive: isInterested,
                    activeColor: Colors.amber,
                    onPressed: onInterested,
                  ),
                  _buildActionButton(
                    icon: Icons.check_circle,
                    isActive: isChoice,
                    activeColor: Colors.green,
                    onPressed: onChoice,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: onComment,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: () {}, // TODO: Implémenter la sauvegarde
            ),
          ],
        ),
        if (isProducerPost)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  '$interestedCount intéressés',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(' • '),
                Text(
                  '$choiceCount choices',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? activeColor : Colors.grey,
      ),
      onPressed: onPressed,
    );
  }
}
