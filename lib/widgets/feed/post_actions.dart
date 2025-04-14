import 'package:flutter/material.dart';
import '../../models/post.dart';

class PostActions extends StatelessWidget {
  final Post post;
  final Function(String) onInterested;
  final Function(String) onChoice;
  final VoidCallback onCommentTap;

  const PostActions({
    Key? key,
    required this.post,
    required this.onInterested,
    required this.onChoice,
    required this.onCommentTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(
            Icons.star,
            color: post.isInterested ? Colors.yellow : Colors.grey,
          ),
          onPressed: () => onInterested(post.id),
        ),
        IconButton(
          icon: Icon(
            Icons.check_circle,
            color: post.isChoice ? Colors.green : Colors.grey,
          ),
          onPressed: () => onChoice(post.id),
        ),
        IconButton(
          icon: const Icon(Icons.comment),
          onPressed: onCommentTap,
        ),
      ],
    );
  }
}
