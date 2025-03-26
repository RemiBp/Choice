import 'package:flutter/material.dart';

class PostInteractionBar extends StatelessWidget {
  final bool isLiked;
  final bool isInterested;
  final bool isChoice;
  final int likesCount;
  final int interestedCount;
  final int choiceCount;
  final int commentsCount;
  final VoidCallback onLike;
  final VoidCallback onInterested;
  final VoidCallback onChoice;
  final VoidCallback onComment;
  final VoidCallback? onShare;
  final bool isProducerPost;
  final bool isLeisureProducer;

  const PostInteractionBar({
    Key? key,
    required this.isLiked,
    required this.isInterested,
    required this.isChoice,
    this.likesCount = 0,
    this.interestedCount = 0,
    this.choiceCount = 0,
    this.commentsCount = 0,
    required this.onLike,
    required this.onInterested,
    required this.onChoice,
    required this.onComment,
    this.onShare,
    this.isProducerPost = false,
    this.isLeisureProducer = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInteractionButton(
                icon: Icons.favorite_rounded,
                inactiveIcon: Icons.favorite_outline_rounded,
                text: likesCount > 0 ? '$likesCount' : 'Aimer',
                isActive: isLiked,
                activeColor: Colors.red,
                onPressed: onLike,
              ),
              
              if (isProducerPost) ...[
                _buildInteractionButton(
                  icon: Icons.star_rounded,
                  inactiveIcon: Icons.star_outline_rounded,
                  text: interestedCount > 0 ? '$interestedCount' : 'Intéressé',
                  isActive: isInterested,
                  activeColor: isLeisureProducer ? Colors.deepPurple : Colors.amber,
                  onPressed: onInterested,
                ),
                
                _buildInteractionButton(
                  icon: Icons.check_circle_rounded,
                  inactiveIcon: Icons.check_circle_outline_rounded,
                  text: choiceCount > 0 ? '$choiceCount' : 'Choix',
                  isActive: isChoice,
                  activeColor: isLeisureProducer ? Colors.indigo : Colors.green,
                  onPressed: onChoice,
                ),
              ],
              
              _buildInteractionButton(
                icon: Icons.chat_bubble_rounded,
                inactiveIcon: Icons.chat_bubble_outline_rounded,
                text: commentsCount > 0 ? '$commentsCount' : 'Commenter',
                isActive: false,
                activeColor: Colors.blue,
                onPressed: onComment,
              ),
              
              if (onShare != null)
                _buildInteractionButton(
                  icon: Icons.share_rounded,
                  inactiveIcon: Icons.share_outlined,
                  text: 'Partager',
                  isActive: false,
                  activeColor: Colors.purple,
                  onPressed: onShare!,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required IconData inactiveIcon,
    required String text,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: activeColor.withOpacity(0.1),
        highlightColor: activeColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    isActive ? icon : inactiveIcon,
                    key: ValueKey<bool>(isActive),
                    color: isActive ? activeColor : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? activeColor : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
