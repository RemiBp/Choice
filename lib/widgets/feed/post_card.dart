import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/post.dart';
import '../../models/media.dart';
import '../../models/comment.dart';
import 'post_media.dart';
import 'post_interaction_bar.dart';
import 'comments_sheet.dart';
import 'media_detail_view.dart';
import '../../utils/constants.dart';
import 'animations/double_tap_animation.dart';

typedef PostCallback = Function(Post);

class PostCard extends StatefulWidget {
  final Post post;
  final PostCallback onLike;
  final PostCallback onInterested;
  final PostCallback onChoice;
  final PostCallback onCommentTap;
  final VoidCallback onUserTap;
  final PostCallback onShare;
  final PostCallback onSave;

  const PostCard({
    Key? key,
    required this.post,
    required this.onLike,
    required this.onInterested,
    required this.onChoice,
    required this.onCommentTap,
    required this.onUserTap,
    required this.onShare,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isInterested = false;
  bool _isChoice = false;
  int _likesCount = 0;
  int _interestedCount = 0;
  int _choiceCount = 0;
  int _commentsCount = 0;
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  bool _isVideoPlaying = false;
  VideoPlayerController? _videoController;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initializeState();
    if (widget.post.media.isNotEmpty && widget.post.media.first.type == 'video') {
      _initVideoController(Uri.parse(widget.post.media.first.url));
    }
  }

  void _initializeState() {
    _isLiked = widget.post.isLiked ?? false;
    _isInterested = widget.post.isInterested ?? false;
    _isChoice = widget.post.isChoice ?? false;
    _likesCount = widget.post.likesCount ?? 0;
    _interestedCount = widget.post.interestedCount ?? 0;
    _choiceCount = widget.post.choiceCount ?? 0;
    _commentsCount = widget.post.comments.length;
  }

  void _initVideoController(Uri videoUri) async {
    _videoController = VideoPlayerController.networkUrl(videoUri);
    await _videoController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: widget.post.isProducerPost ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: widget.post.isProducerPost ? Colors.grey[900]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.post.media.isNotEmpty) _buildMedia(),
          _buildContent(),
          _buildInteractionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => widget.onUserTap(),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: CachedNetworkImageProvider(widget.post.authorAvatar),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => widget.onUserTap(),
                  child: Text(
                    widget.post.authorName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.post.isProducerPost ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (widget.post.locationName != null && widget.post.locationName!.isNotEmpty)
                  Text(
                    widget.post.locationName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.post.isProducerPost ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: widget.post.isProducerPost ? Colors.white : Colors.black,
            ),
            onPressed: () => _showPostOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    return DoubleTapAnimation(
      onDoubleTap: () {
        if (!_isLiked) {
          setState(() {
            _isLiked = true;
            _likesCount++;
          });
          widget.onLike(widget.post);
        }
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: PageView.builder(
          itemCount: widget.post.media.length,
          itemBuilder: (context, index) {
            final media = widget.post.media[index];
            if (media.type == 'video') {
              return _buildVideoPlayer(media.url);
            }
            return CachedNetworkImage(
              imageUrl: media.url,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    if (_videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(_videoController!),
        if (!_isVideoPlaying)
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 50, color: Colors.white),
            onPressed: () {
              setState(() {
                _isVideoPlaying = true;
                _videoController!.play();
              });
            },
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (widget.post.description?.isEmpty ?? true) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.description!,
            style: TextStyle(
              fontSize: 14,
              color: widget.post.isProducerPost ? Colors.white : Colors.black87,
            ),
            maxLines: _isExpanded ? null : 3,
            overflow: _isExpanded ? null : TextOverflow.ellipsis,
          ),
          if (widget.post.description!.length > 100)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? 'Voir moins' : 'Voir plus',
                style: TextStyle(
                  color: widget.post.isProducerPost ? Colors.blue[300] : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractionBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : (widget.post.isProducerPost ? Colors.white : Colors.black),
                ),
                onPressed: () {
                  setState(() {
                    _isLiked = !_isLiked;
                    _likesCount += _isLiked ? 1 : -1;
                  });
                  widget.onLike(widget.post);
                },
              ),
              IconButton(
                icon: Icon(
                  _isInterested ? Icons.star : Icons.star_border,
                  color: _isInterested ? Colors.amber : (widget.post.isProducerPost ? Colors.white : Colors.black),
                ),
                onPressed: () {
                  setState(() {
                    _isInterested = !_isInterested;
                    _interestedCount += _isInterested ? 1 : -1;
                  });
                  widget.onInterested(widget.post);
                },
              ),
              IconButton(
                icon: Icon(
                  _isChoice ? Icons.check_circle : Icons.check_circle_outline,
                  color: _isChoice ? Colors.green : (widget.post.isProducerPost ? Colors.white : Colors.black),
                ),
                onPressed: () {
                  setState(() {
                    _isChoice = !_isChoice;
                    _choiceCount += _isChoice ? 1 : -1;
                  });
                  widget.onChoice(widget.post);
                },
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved ? Colors.blue : (widget.post.isProducerPost ? Colors.white : Colors.black),
                ),
                onPressed: () {
                  setState(() {
                    _isSaved = !_isSaved;
                  });
                  widget.onSave(widget.post);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.share,
                  color: widget.post.isProducerPost ? Colors.white : Colors.black,
                ),
                onPressed: () => widget.onShare(widget.post),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Text(
                '$_likesCount j\'aime',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.post.isProducerPost ? Colors.white : Colors.black,
                ),
              ),
              if (_interestedCount > 0) ...[
                const SizedBox(width: 16),
                Text(
                  '$_interestedCount intéressé${_interestedCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.post.isProducerPost ? Colors.white : Colors.black,
                  ),
                ),
              ],
              if (_choiceCount > 0) ...[
                const SizedBox(width: 16),
                Text(
                  '$_choiceCount choix',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.post.isProducerPost ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: () => widget.onCommentTap(widget.post),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'Voir les $_commentsCount commentaires',
              style: TextStyle(
                color: widget.post.isProducerPost ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: widget.post.isProducerPost ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.flag,
                color: widget.post.isProducerPost ? Colors.white : Colors.black,
              ),
              title: Text(
                'Signaler',
                style: TextStyle(
                  color: widget.post.isProducerPost ? Colors.white : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement report functionality
              },
            ),
            ListTile(
              leading: Icon(
                Icons.copy,
                color: widget.post.isProducerPost ? Colors.white : Colors.black,
              ),
              title: Text(
                'Copier le lien',
                style: TextStyle(
                  color: widget.post.isProducerPost ? Colors.white : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement copy link functionality
              },
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: widget.post.isProducerPost ? Colors.white : Colors.black,
              ),
              title: Text(
                'Masquer',
                style: TextStyle(
                  color: widget.post.isProducerPost ? Colors.white : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement hide functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}
