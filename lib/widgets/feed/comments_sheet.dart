import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../models/comment.dart';

class CommentsSheet extends StatefulWidget {
  final Post post;
  final String userId;
  final Function(Comment) onCommentAdded;

  const CommentsSheet({
    Key? key,
    required this.post,
    required this.userId,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.post.comments.length,
              itemBuilder: (context, index) {
                final comment = widget.post.comments[index];
                return ListTile(
                  title: Text(comment.username),
                  subtitle: Text(comment.content),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un commentaire...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_commentController.text.isNotEmpty) {
                      // TODO: Implémenter l'ajout de commentaire
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
