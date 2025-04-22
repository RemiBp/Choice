import 'package:flutter/material.dart';

//==============================================================================
// WIDGET: ProfileStats (Stateless)
// Affiche les statistiques (abonnés, posts, etc.) et les tags aimés.
//==============================================================================
class ProfileStats extends StatelessWidget {
   final Map<String, dynamic> user;
   final Function(String, String) onNavigateToDetails; // Pour naviguer vers les détails d'un lieu (si besoin)
   final Function(BuildContext, List<String>, String) onShowUserList; // Pour afficher modal abonnés/abonnements
   final VoidCallback onShowChoicesList; // Pour afficher modal des choices

   const ProfileStats({
     Key? key,
     required this.user,
     required this.onNavigateToDetails,
     required this.onShowUserList,
     required this.onShowChoicesList,
   }) : super(key: key);

    // Helper pour s'assurer qu'une liste dynamique contient des Strings
    List<String> _ensureStringList(dynamic list) {
      if (list == null) return <String>[];
      if (list is List<String>) return list;
      if (list is List) {
        // Filtre les nulls et convertit en String
        return list.where((item) => item != null).map((item) => item.toString()).toList();
      }
      return <String>[]; // Retourne une liste vide si ce n'est pas une liste
    }

   @override
   Widget build(BuildContext context) {
     // Extraction et normalisation des données
     final followersIds = _ensureStringList(user['followers']);
     final followingIds = _ensureStringList(user['following']);
     final postsIds = _ensureStringList(user['posts']);
     final choices = (user['choices'] is List) ? user['choices'] : []; // S'assurer que c'est une liste
     final likedTags = _ensureStringList(user['liked_tags']);

     return Container(
       color: Colors.white,
       padding: const EdgeInsets.symmetric(vertical: 16), // Padding vertical uniquement
       child: Column(
          children: [
             // Ligne de statistiques
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Espacement équitable
               children: [
                 _buildStatButton(context, icon: Icons.people_outline, label: 'Abonnés', count: followersIds.length, onTap: () => onShowUserList(context, followersIds, 'Abonnés')),
                 _verticalDivider(),
                 _buildStatButton(context, icon: Icons.person_outline, label: 'Abonnements', count: followingIds.length, onTap: () => onShowUserList(context, followingIds, 'Abonnements')),
                 _verticalDivider(),
                 _buildStatButton(context, icon: Icons.article_outlined, label: 'Posts', count: postsIds.length, onTap: null), // Pas d'action spécifique pour les posts ici
                 _verticalDivider(),
                 _buildStatButton(context, icon: Icons.check_circle_outline, label: 'Choices', count: choices.length, onTap: onShowChoicesList),
               ],
             ),
             // Section des tags (si présents)
             if (likedTags.isNotEmpty) ...[
                 const SizedBox(height: 16),
                 const Divider(height: 1, indent: 20, endIndent: 20), // Séparateur avec marge
                 const SizedBox(height: 12),
                 _buildLikedTagsSection(context, likedTags), // Widget pour les tags
                 const SizedBox(height: 4), // Petit espace en bas
             ]
          ],
       ),
     );
   }

   // --- Widgets internes Helpers --- //

   /// Construit un bouton cliquable pour une statistique
   Widget _buildStatButton(BuildContext context, {required IconData icon, required String label, required int count, VoidCallback? onTap}) {
     return InkWell(
       onTap: onTap, // Action au clic
       borderRadius: BorderRadius.circular(8),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
         constraints: const BoxConstraints(minWidth: 70), // Largeur minimale
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Icon(icon, color: Colors.teal, size: 24),
             const SizedBox(height: 4),
             Text(count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
             const SizedBox(height: 2),
             Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
           ],
         ),
       ),
     );
   }

   /// Crée un séparateur vertical fin
   Widget _verticalDivider() {
     return Container(height: 30, width: 1, color: Colors.grey[200]);
   }

   /// Construit la section affichant les tags aimés
   Widget _buildLikedTagsSection(BuildContext context, List<String> tags) {
       return Container(
         width: double.infinity, // Prend toute la largeur
         padding: const EdgeInsets.symmetric(horizontal: 20),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Titre de la section
             Row(
               children: [
                 Icon(Icons.sell_outlined, size: 16, color: Colors.grey[700]),
                 const SizedBox(width: 8),
                 Text('Centres d'intérêt (Tags)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
               ],
             ),
             const SizedBox(height: 10),
             // Affichage des tags avec Wrap pour passer à la ligne
             Wrap(
               spacing: 6, // Espace horizontal entre les chips
               runSpacing: 6, // Espace vertical entre les lignes de chips
               children: tags.map<Widget>((tag) {
                 return Chip(
                   label: Text(tag, style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
                   backgroundColor: Colors.teal.withOpacity(0.08), // Fond léger
                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Taille minimale
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   side: BorderSide.none, // Pas de bordure
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Coins arrondis
                 );
               }).toList(),
             ),
           ],
         ),
       );
     }
} 