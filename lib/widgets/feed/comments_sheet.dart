import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../models/comment.dart';

class CommentsSheet extends StatefulWidget {
  final Post post;
  final Function(String) onCommentAdded;  // Changed from Function(Comment) to Function(String)

  const CommentsSheet({
    Key? key,
    required this.post,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.post.comments.length,
            itemBuilder: (context, index) {
              final comment = widget.post.comments[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(comment.authorAvatar),
                ),
                title: Text(comment.authorName),
                subtitle: Text(comment.content),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 8,
              right: 8,
            ),
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
                      widget.onCommentAdded(_commentController.text);
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
