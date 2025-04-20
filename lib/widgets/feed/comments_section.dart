import 'package:flutter/material.dart';
import '../../models/comment.dart'; // Using centralized Comment model
import '../../services/api_service.dart';
import '../../widgets/translatable_content.dart'; // Import du widget de contenu traduisible
import '../../utils.dart' show getImageProvider;

// Modifier la signature pour correspondre à l'utilisation dans FeedScreen
class CommentsSection extends StatefulWidget {
  final List<Comment> comments;
  final Function(Comment) onCommentTap;
  final Function(String) onAddComment;
  final Color textColor;

  const CommentsSection({
    Key? key,
    required this.comments,
    required this.onCommentTap,
    required this.onAddComment,
    required this.textColor,
  }) : super(key: key);

  @override
  State<CommentsSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildCommentList(),
          _buildEnhancedCommentInput(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCommentList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.comments.length,
        itemBuilder: (context, index) {
          final comment = widget.comments[index];
          return _buildCommentTile(comment);
        },
      ),
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateToProfile(comment.authorId),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: getImageProvider(comment.authorAvatar),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                TranslatableContent(
                  text: comment.content,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeAgo(comment.createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Ajouter un commentaire...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _handleSubmitComment,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmitComment() {
    if (_commentController.text.isNotEmpty) {
      widget.onAddComment(_commentController.text);
      _commentController.clear();
    }
  }

  void _navigateToProfile(String authorId) {
    // TODO: Implement navigation to profile
  }

  String _formatTimeAgo(DateTime createdAt) {
    // Implement the logic to format time ago
    return 'Just now';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
