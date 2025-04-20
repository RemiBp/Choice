import '../../utils.dart' show getImageProvider;

class CommentsTile extends StatelessWidget {
  // ... existing code ...

  @override
  Widget build(BuildContext context) {
    // ... existing code ...

    return Container(
      // ... existing code ...

      backgroundImage: getImageProvider(comment.authorAvatar!),
      // ... existing code ...
    );
  }
} 