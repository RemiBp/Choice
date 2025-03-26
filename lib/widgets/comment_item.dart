import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comment.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final String? highlightUsername;
  
  const CommentItem({
    Key? key,
    required this.comment,
    this.onReply,
    this.onLike,
    this.highlightUsername,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar de l'auteur
          CircleAvatar(
            radius: 18,
            backgroundImage: CachedNetworkImageProvider(
              comment.authorAvatar.isNotEmpty
                  ? comment.authorAvatar
                  : 'https://via.placeholder.com/100',
            ),
          ),
          const SizedBox(width: 12),
          
          // Contenu du commentaire
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom de l'auteur
                Text(
                  comment.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                
                // Contenu du commentaire
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                
                // Actions (like, reply)
                Row(
                  children: [
                    // Bouton like
                    if (onLike != null)
                      TextButton(
                        onPressed: onLike,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'J\'aime',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    
                    // Bouton répondre
                    if (onReply != null)
                      TextButton(
                        onPressed: onReply,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Répondre',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
} 