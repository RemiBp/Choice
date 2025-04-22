import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/edit_profile_screen.dart'; // Pour la navigation
import '../../screens/myprofile_screen.dart'; // Pour les callbacks potentiels si non passés

//==============================================================================
// WIDGET: ProfileHeader (Stateless)
// Affiche la partie haute du profil (photo, nom, bio, actions)
//==============================================================================
class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isCurrentUser;
  final VoidCallback onEditProfile;
  final VoidCallback onStartConversation;
  final VoidCallback onShowMainMenu;
  final VoidCallback onShowExternalProfileOptions;

  const ProfileHeader({
     Key? key,
     required this.user,
     required this.isCurrentUser,
     required this.onEditProfile,
     required this.onStartConversation,
     required this.onShowMainMenu,
     required this.onShowExternalProfileOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Utiliser profilePicture ou photo_url
    final profileImageUrl = user['profilePicture'] ?? user['photo_url'];

    return SliverAppBar(
      expandedHeight: 200.0, // Hauteur quand déplié
      floating: false, // Ne flotte pas
      pinned: true,    // Reste visible en haut quand on scrolle
      backgroundColor: Colors.teal, // Couleur de fond de la barre réduite
      elevation: 1,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          // Dégradé pour l'arrière-plan
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [ Colors.teal.shade700, Colors.teal.shade500 ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image de fond floutée (si disponible)
              if (profileImageUrl != null && profileImageUrl.isNotEmpty)
                 Positioned.fill(
                   child: Opacity(
                     opacity: 0.15, // Rend l'image subtile
                     child: CachedNetworkImage(
                       imageUrl: profileImageUrl,
                       fit: BoxFit.cover,
                       errorWidget: (ctx, url, err) => Container(color: Colors.teal.shade300),
                     ),
                   ),
                 ),
              // Contenu principal (photo, nom, bio)
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 15, // Espace pour status bar
                  left: 20, right: 20, bottom: 15
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar circulaire
                    CircleAvatar(
                       radius: 40, backgroundColor: Colors.white.withOpacity(0.8),
                       child: CircleAvatar(
                         radius: 37, backgroundColor: Colors.grey[300],
                         backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                              ? CachedNetworkImageProvider(profileImageUrl) : null,
                         child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                       ),
                     ),
                    const SizedBox(width: 16),
                    // Nom et Bio
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text( user['name'] ?? 'Nom inconnu',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black38)]),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          if (user['bio'] != null && user['bio'].isNotEmpty)
                             Padding(
                               padding: const EdgeInsets.only(top: 4.0),
                               child: Text( user['bio'],
                                style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w300),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                               ),
                             ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Actions dans l'AppBar (différentes si profil courant ou non)
      actions: isCurrentUser
       ? [ // Utilisateur courant
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), tooltip: "Modifier", onPressed: onEditProfile),
            IconButton(icon: const Icon(Icons.menu, color: Colors.white), tooltip: "Menu", onPressed: onShowMainMenu),
         ]
       : [ // Profil externe
            // TODO: Ajouter FollowButton si nécessaire (avec état)
            IconButton(icon: const Icon(Icons.message_outlined, color: Colors.white), tooltip: "Message", onPressed: onStartConversation),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), tooltip: "Options", onPressed: onShowExternalProfileOptions),
         ],
    );
  }
} 