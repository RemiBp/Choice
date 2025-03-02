import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:choice_app/screens/producer_screen.dart';
import 'package:choice_app/screens/eventLeisure_screen.dart';
import 'package:intl/intl.dart';
import 'package:choice_app/screens/profile_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:choice_app/screens/producerLeisure_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/feed/post_card.dart';
import '../widgets/feed/comments_sheet.dart';

class FeedScreen extends StatefulWidget {
  final String userId;

  const FeedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _heartAnimationController;
  final Map<String, bool> _isDoubleTapInProgress = {};
  late Future<List<dynamic>> _feedFuture;
  final ScrollController _scrollController = ScrollController();
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  
  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _apiService.getFeed(widget.userId, 1, 10);
      setState(() {
        _posts = posts;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      print('Erreur lors du chargement des posts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);
    try {
      final newPosts = await _apiService.getFeed(widget.userId, _currentPage + 1, 10);
      setState(() {
        if (newPosts.isEmpty) {
          _hasMore = false;
        } else {
          _posts.addAll(newPosts);
          _currentPage++;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement de plus de posts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleInterested(String postId) async {
    try {
      final post = _posts.firstWhere((p) => p.id == postId);
      final success = await _apiService.markInterested(
        widget.userId, 
        postId,
        isLeisureProducer: post.isLeisureProducer,
      );
      if (success) {
        setState(() {
          _posts = _posts.map((p) {
            if (p.id == postId) {
              return p.copyWith(
                isInterested: !p.isInterested,
                interestedCount: p.isInterested ? p.interestedCount - 1 : p.interestedCount + 1,
              );
            }
            return p;
          }).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _handleChoice(String postId) async {
    try {
      final success = await _apiService.markChoice(widget.userId, postId);
      if (success) {
        setState(() {
          _posts = _posts.map((p) {
            if (p.id == postId) {
              return p.copyWith(
                isChoice: !p.isChoice,
                choiceCount: p.isChoice ? p.choiceCount - 1 : p.choiceCount + 1,
              );
            }
            return p;
          }).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showComments(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsSheet(
        post: post,
        userId: widget.userId,
        onCommentAdded: (newComment) => _handleCommentAdded(post.id, newComment),
      ),
    );
  }

  void _handleCommentAdded(String postId, Comment newComment) {
    setState(() {
      _posts = _posts.map((p) {
        if (p.id == postId) {
          return p.copyWith(
            comments: [...p.comments, newComment],
          );
        }
        return p;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Feed')),
      body: RefreshIndicator(
        onRefresh: _loadInitialPosts,
        child: _isLoading && _posts.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              itemCount: _posts.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _posts.length) {
                  return _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : SizedBox();
                }
                
                final post = _posts[index];
                return PostCard(
                  post: post,
                  onInterested: _handleInterested,
                  onChoice: _handleChoice,
                  onCommentTap: () => _showComments(post),
                );
              },
            ),
      ),
    );
  }
}