import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:choice_app/models/post_model.dart';
import 'package:choice_app/models/choice_model.dart';
import 'package:choice_app/widgets/profile/choice_form.dart';
import 'package:choice_app/widgets/comment_tile.dart';
import 'package:choice_app/utils/validation_utils.dart';

// Placeholder pour PlaceDetails, à remplacer par le vrai modèle si disponible
class PlaceDetails {
  final String name;
  final String address;
  final String photoReference; // ou URL directe selon l'API

  PlaceDetails({required this.name, required this.address, required this.photoReference});
}

//==============================================================================
// WIDGET: ProfileTabs (Stateful)
// Gère les onglets (Posts, Choices, Commentaires) et leur contenu.
//==============================================================================
class ProfileTabs extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> user;
  final String formatTimestamp; // Passé en paramètre
  final Future<PlaceDetails?> Function(String) fetchPlaceDetails; // Passé en paramètre
  final Function(BuildContext, String) onShowCommentActions; // Callback pour actions commentaire
  final Function(String) onLikeComment; // Callback pour aimer commentaire
  final Function(String) onUnlikeComment; // Callback pour ne plus aimer commentaire

  const ProfileTabs({
    Key? key,
    required this.userId,
    required this.user,
    required this.formatTimestamp,
    required this.fetchPlaceDetails,
    required this.onShowCommentActions,
    required this.onLikeComment,
    required this.onUnlikeComment,
  }) : super(key: key);

  @override
  State<ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends State<ProfileTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<Post>> _getPostsStream() {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

 Stream<List<Choice>> _getChoicesStream() {
     return _firestore
         .collection('choices')
         .where('userId', isEqualTo: widget.userId)
         .orderBy('createdAt', descending: true)
         .snapshots()
         .map((snapshot) => snapshot.docs.map((doc) => Choice.fromFirestore(doc)).toList());
   }

 Stream<List<Map<String, dynamic>>> _getUserCommentsStream() {
   return _firestore
       .collectionGroup('comments')
       .where('authorId', isEqualTo: widget.userId)
       .orderBy('timestamp', descending: true)
       .snapshots()
       .map((snapshot) {
     return snapshot.docs.map((doc) {
       final data = doc.data();
       // Tentative de trouver l'ID du post parent
       String? postId;
       try {
          DocumentReference parentRef = doc.reference.parent.parent!; // Remonte de 2 niveaux (comment -> comments -> post)
          if (parentRef.path.startsWith('posts/') && ValidationUtils.isValidObjectId(parentRef.id)) {
              postId = parentRef.id;
          }
       } catch (e) {
         print("Erreur lors de la récupération de l'ID du post pour le commentaire ${doc.id}: $e");
       }
       // Ajoute postId aux données du commentaire
       data['postId'] = postId;
       data['commentId'] = doc.id;
       return data;
     }).toList();
   });
 }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre d'onglets
        Material(
           color: Colors.white,
           child: TabBar(
               controller: _tabController,
               indicatorColor: Colors.teal,
               labelColor: Colors.teal,
               unselectedLabelColor: Colors.grey,
               tabs: const [
                   Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
                   Tab(icon: Icon(Icons.check_circle), text: 'Choices'),
                   Tab(icon: Icon(Icons.comment), text: 'Commentaires'),
               ],
           ),
        ),
        // Contenu des onglets
        Expanded(
           child: TabBarView(
               controller: _tabController,
               children: [
                   _buildPostsGrid(),
                   _buildChoicesList(),
                   _buildCommentsList(),
               ],
           ),
        ),
      ],
    );
  }

  // --- Onglet Posts --- //
  Widget _buildPostsGrid() {
    return StreamBuilder<List<Post>>(
      stream: _getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucun post à afficher.'));
        }

        final posts = snapshot.data!;
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return InkWell(
              onTap: () { /* TODO: Naviguer vers détails du post */ },
              child: CachedNetworkImage(
                imageUrl: post.mediaUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            );
          },
        );
      },
    );
  }

 // --- Onglet Choices --- //
 Widget _buildChoicesList() {
     return StreamBuilder<List<Choice>>(
       stream: _getChoicesStream(),
       builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
         } else if (snapshot.hasError) {
           return Center(child: Text("Erreur de chargement des choices: ${snapshot.error}"));
         } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return const Center(child: Text("Aucun choice effectué pour le moment."));
         }

         final choices = snapshot.data!;
         return ListView.separated(
           padding: const EdgeInsets.all(8.0),
           itemCount: choices.length,
           separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
           itemBuilder: (context, index) {
             final choice = choices[index];
             final placeId = choice.googlePlaceId;

             return FutureBuilder<PlaceDetails?>(
               future: widget.fetchPlaceDetails(placeId), // Appel de la fonction passée
               builder: (context, placeSnapshot) {
                 if (placeSnapshot.connectionState == ConnectionState.waiting) {
                   // Afficheur pendant le chargement des détails du lieu
                   return ListTile(
                     leading: CircleAvatar(backgroundColor: Colors.grey.shade200),
                     title: Container(height: 16, color: Colors.grey.shade200),
                     subtitle: Container(height: 12, color: Colors.grey.shade200),
                     trailing: Text(widget.formatTimestamp(choice.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                   );
                 } else if (placeSnapshot.hasError) {
                   print("Erreur fetchPlaceDetails pour $placeId: ${placeSnapshot.error}");
                   return ListTile(
                       leading: const CircleAvatar(child: Icon(Icons.business, color: Colors.grey)),
                       title: Text("Impossible de charger les détails", style: TextStyle(color: Colors.red.shade700)),
                       subtitle: Text("Place ID: $placeId", style: TextStyle(color: Colors.red.shade400)),
                       trailing: Text(widget.formatTimestamp(choice.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                       onTap: () { /* Peut-être réessayer ? */ },
                   );
                 } else if (!placeSnapshot.hasData || placeSnapshot.data == null) {
                   return ListTile(
                       leading: const CircleAvatar(child: Icon(Icons.business, color: Colors.grey)),
                       title: const Text("Détails du lieu non trouvés"),
                       subtitle: Text("Place ID: $placeId"),
                       trailing: Text(widget.formatTimestamp(choice.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                       onTap: () { /* Action ? */ },
                   );
                 }

                 final placeDetails = placeSnapshot.data!;
                 // Affiche le Choice avec les détails du lieu
                 return ListTile(
                   leading: CircleAvatar(
                       backgroundImage: placeDetails.photoReference.isNotEmpty
                           ? CachedNetworkImageProvider(placeDetails.photoReference) // TODO: Construire l'URL Google Places Photo
                           : null, // Fallback si pas de photo
                       child: placeDetails.photoReference.isEmpty ? const Icon(Icons.business) : null,
                   ),
                   title: Text(placeDetails.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                   subtitle: Text(placeDetails.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                   trailing: Text(widget.formatTimestamp(choice.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                   onTap: () => _showChoiceForm(context, choice: choice, placeDetails: placeDetails), // Modifier le choice existant
                   // onLongPress: () { /* TODO: Options (supprimer ?) */ },
                 );
               },
             );
           },
         );
       },
     );
   }

    // Affiche le formulaire pour ajouter/modifier un Choice
   void _showChoiceForm(BuildContext context, {Choice? choice, PlaceDetails? placeDetails}) {
     // TODO: Assurer que placeDetails est non-null si choice est non-null
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       builder: (BuildContext bc) {
         return Padding(
           padding: EdgeInsets.only(bottom: MediaQuery.of(bc).viewInsets.bottom),
           child: ChoiceForm(
             userId: widget.userId,
             existingChoice: choice,
             placeDetails: placeDetails, // Peut être null si création
             // TODO: Passer les autres infos nécessaires (googlePlaceId si création)
           ),
         );
       },
     );
   }

  // --- Onglet Commentaires --- //
  Widget _buildCommentsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
       stream: _getUserCommentsStream(),
       builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
         } else if (snapshot.hasError) {
           return Center(child: Text('Erreur: ${snapshot.error}'));
         } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return const Center(child: Text('Aucun commentaire à afficher.'));
         }

         final comments = snapshot.data!;
         return ListView.builder(
           padding: const EdgeInsets.symmetric(vertical: 8.0),
           itemCount: comments.length,
           itemBuilder: (context, index) {
             final commentData = comments[index];
              final commentId = commentData['commentId'] as String? ?? 'inconnu'; // ID du commentaire
              final postId = commentData['postId'] as String?; // ID du post associé (peut être null)
              final likedBy = _ensureStringList(commentData['likedBy']);

             return CommentTile(
               authorName: widget.user['username'] ?? 'Utilisateur', // Utiliser le nom de l'utilisateur actuel
               authorImageUrl: widget.user['profile_photo'] ?? '',
               commentText: commentData['text'] as String? ?? '',
               timestamp: widget.formatTimestamp(commentData['timestamp']),
               likes: likedBy.length,
               isLiked: likedBy.contains(widget.userId),
               onLike: () => widget.onLikeComment(commentId),
               onUnlike: () => widget.onUnlikeComment(commentId),
               onTap: () {
                   if (postId != null && ValidationUtils.isValidObjectId(postId)) {
                      // TODO: Naviguer vers le post spécifique
                      print("Naviguer vers Post ID: $postId");
                   } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text("Impossible d'accéder au post associé.")),
                       );
                   }
               },
               onLongPress: () => widget.onShowCommentActions(context, commentId),
               // Ne pas afficher les réponses ici, c'est la liste des *propres* commentaires
             );
           },
         );
       },
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
} 