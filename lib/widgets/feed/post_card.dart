import 'package:flutter/material.dart';
import '../../models/post.dart';
import 'post_media.dart';
import 'post_actions.dart';
import '../../utils/constants.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final Function(String) onInterested;
  final Function(String) onChoice;
  final VoidCallback onCommentTap;

  const PostCard({
    Key? key,
    required this.post,
    required this.onInterested,
    required this.onChoice,
    required this.onCommentTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (post.mediaUrl != null || post.videoUrl != null)
            PostMedia(mediaUrl: post.mediaUrl, videoUrl: post.videoUrl),
          PostActions(
            post: post,
            onInterested: onInterested,
            onChoice: onChoice,
            onCommentTap: onCommentTap,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: post.authorPhotoUrl != null
            ? NetworkImage(post.authorPhotoUrl!)
            : NetworkImage(getDefaultAvatarUrl(post.authorId)),
      ),
      title: Text(post.authorName),
      subtitle: Text(post.content),
    );
  }
}
