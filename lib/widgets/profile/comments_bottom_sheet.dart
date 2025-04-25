import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:choice_app/models/user_model.dart'; // Assurez-vous que le chemin est correct
import 'package:choice_app/widgets/comment_tile.dart';
import 'package:choice_app/utils/validation_utils.dart';

// Type de fonction pour récupérer des informations utilisateur minimales
typedef FetchMinimalUserInfo = Future<Map<String, String>> Function(String userId);

//==============================================================================
// WIDGET: CommentsBottomSheet
// Feuille de dialogue modale pour afficher les commentaires et réponses.
//==============================================================================
class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String formatTimestamp; // Passé en paramètre
  final FetchMinimalUserInfo fetchMinimalUserInfo; // Passé en paramètre
  final Function(String) onLikeComment;
  final Function(String) onUnlikeComment;
  final Function(BuildContext, String) onShowCommentActions;
  final Function(String, String, String) onReplyToComment;
  final Function(String, String) onAddComment;

  const CommentsBottomSheet({
    Key? key,
    required this.postId,
    required this.currentUserId,
    required this.formatTimestamp,
    required this.fetchMinimalUserInfo,
    required this.onLikeComment,
    required this.onUnlikeComment,
    required this.onShowCommentActions,
    required this.onReplyToComment,
    required this.onAddComment,
  }) : super(key: key);

  @override
  _CommentsBottomSheetState createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _replyingToCommentId;
  String? _replyingToUsername;

  Stream<List<Map<String, dynamic>>> _getCommentsStream() {
    return _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('timestamp', descending: false) // Ordre chronologique
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> commentsData = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id; // Ajouter l'ID du commentaire
        var authorInfo = await widget.fetchMinimalUserInfo(data['authorId']);
        data['authorName'] = authorInfo['username'] ?? 'Utilisateur inconnu';
        data['authorImageUrl'] = authorInfo['profile_photo'] ?? '';
        // Récupérer les réponses
        var repliesSnapshot = await doc.reference.collection('replies').orderBy('timestamp').get();
        data['replies'] = await Future.wait(repliesSnapshot.docs.map((replyDoc) async {
          var replyData = replyDoc.data();
          replyData['id'] = replyDoc.id; // Ajouter l'ID de la réponse
          var replierInfo = await widget.fetchMinimalUserInfo(replyData['authorId']);
          replyData['authorName'] = replierInfo['username'] ?? 'Utilisateur inconnu';
          replyData['authorImageUrl'] = replierInfo['profile_photo'] ?? '';
          return replyData;
        }).toList());
        commentsData.add(data);
      }
      return commentsData;
    });
  }

  void _startReply(String commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
      FocusScope.of(context).requestFocus(FocusNode()); // Pour faire apparaître le clavier
      // Alternative: utiliser un FocusNode dédié pour le TextField
    });
    // Optionnel: faire défiler jusqu'au champ de texte si nécessaire
  }

  void _cancelReply() {
     setState(() {
       _replyingToCommentId = null;
       _replyingToUsername = null;
       _commentController.clear();
     });
     FocusScope.of(context).unfocus(); // Cacher le clavier
   }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      if (_replyingToCommentId != null) {
        widget.onReplyToComment(_replyingToCommentId!, text, widget.currentUserId);
      } else {
        widget.onAddComment(widget.postId, text);
      }
      _cancelReply(); // Réinitialise l'état après envoi
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
       padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75, // 75% de la hauteur de l'écran
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Titre et bouton Fermer
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    const Text('Commentaires', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
            ),
            const Divider(),
            // Liste des commentaires
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getCommentsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    print("Erreur stream commentaires: ${snapshot.error}");
                    return const Center(child: Text('Erreur lors du chargement des commentaires.'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Aucun commentaire pour le moment. Soyez le premier !'));
                  }

                  final comments = snapshot.data!;
                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final commentData = comments[index];
                      final commentId = commentData['id'];
                      final likedBy = _ensureStringList(commentData['likedBy']);
                      final repliesData = (commentData['replies'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

                      return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            CommentTile(
                              authorName: commentData['authorName'],
                              authorImageUrl: commentData['authorImageUrl'],
                              commentText: commentData['text'],
                              timestamp: widget.formatTimestamp(commentData['timestamp']),
                              likes: likedBy.length,
                              isLiked: likedBy.contains(widget.currentUserId),
                              onLike: () => widget.onLikeComment(commentId),
                              onUnlike: () => widget.onUnlikeComment(commentId),
                              onReply: () => _startReply(commentId, commentData['authorName']),
                              onLongPress: () => widget.onShowCommentActions(context, commentId),
                              isReply: false,
                            ),
                            // Affichage des réponses
                            if (repliesData.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 40.0, top: 8.0), // Indentation pour les réponses
                                child: Column(
                                    children: repliesData.map((replyData) {
                                      final replyId = replyData['id'];
                                      final replyLikedBy = _ensureStringList(replyData['likedBy']);
                                      return CommentTile(
                                        authorName: replyData['authorName'],
                                        authorImageUrl: replyData['authorImageUrl'],
                                        commentText: replyData['text'],
                                        timestamp: widget.formatTimestamp(replyData['timestamp']),
                                        likes: replyLikedBy.length,
                                        isLiked: replyLikedBy.contains(widget.currentUserId),
                                        onLike: () => widget.onLikeComment(replyId), // TODO: Need onLikeReply function
                                        onUnlike: () => widget.onUnlikeComment(replyId), // TODO: Need onUnlikeReply function
                                        // Pas de onReply pour une réponse pour l'instant
                                        onLongPress: () => widget.onShowCommentActions(context, replyId), // TODO: Need correct action context
                                        isReply: true,
                                      );
                                    }).toList(),
                                ),
                              ),
                         ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            // Champ de saisie de commentaire/réponse
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Indicateur si on répond à quelqu'un
           if (_replyingToCommentId != null)
             Padding(
               padding: const EdgeInsets.only(bottom: 4.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(
                     "Répondre à @$_replyingToUsername",
                     style: TextStyle(color: Colors.grey[600], fontSize: 12),
                   ),
                   InkWell(
                     onTap: _cancelReply,
                     child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                   )
                 ],
               ),
             ),
           // Champ de texte et bouton Envoyer
           Row(
             children: [
               Expanded(
                 child: TextField(
                   controller: _commentController,
                   decoration: InputDecoration(
                     hintText: _replyingToCommentId != null ? 'Ajouter une réponse...' : 'Ajouter un commentaire...',
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(20.0),
                       borderSide: BorderSide.none,
                     ),
                     filled: true,
                     fillColor: Colors.grey[200],
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                   ),
                   textInputAction: TextInputAction.send,
                   onSubmitted: (_) => _submitComment(),
                 ),
               ),
               IconButton(
                 icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                 onPressed: _submitComment,
               ),
             ],
           ),
         ],
       ),
     );
   }

   // Helper pour s'assurer qu'une liste dynamique contient des Strings (copié)
   List<String> _ensureStringList(dynamic list) {
     if (list == null) return <String>[];
     if (list is List<String>) return list;
     if (list is List) {
       return list.where((item) => item != null).map((item) => item.toString()).toList();
     }
     return <String>[];
   }

   @override
   void dispose() {
       _commentController.dispose();
       super.dispose();
   }
} 