import 'package:flutter/material.dart';
import '../models/post.dart';

class ShareOptionsBottomSheet extends StatelessWidget {
  final Post post;

  const ShareOptionsBottomSheet({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Partager en externe'),
            onTap: () => Navigator.pop(context, 'external'),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Reposter dans l\'app'),
            onTap: () => Navigator.pop(context, 'internal'),
          ),
        ],
      ),
    );
  }
} 