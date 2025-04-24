import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Placeholder functions for actions - replace with actual navigation/logic
void _showMediaPickerSheet(BuildContext context, String mediaType) {
  print('Action: Show Media Picker ($mediaType)');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fonctionnalité ($mediaType) à implémenter')));
}

void _createGenericPost(BuildContext context, String type) {
   print('Action: Create $type Post');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Création de post ($type) à implémenter')));
}

// Specific post creation placeholders
void _createDishPost(BuildContext context) => _createGenericPost(context, 'Plat du menu');
void _createEventPost(BuildContext context) => _createGenericPost(context, 'Événement');
void _createPromotionPost(BuildContext context) => _createGenericPost(context, 'Promotion');
void _createActivityPost(BuildContext context) => _createGenericPost(context, 'Activité');
void _createShowPost(BuildContext context) => _createGenericPost(context, 'Spectacle');
void _createServicePost(BuildContext context) => _createGenericPost(context, 'Service');
void _createClassPost(BuildContext context) => _createGenericPost(context, 'Cours/Atelier');
void _createTipsPost(BuildContext context) => _createGenericPost(context, 'Conseils');


class CreatePostModal {
  static Future<void> show(BuildContext context, String producerTypeString) {
    Color primaryColor;
    String modalTitle;
    List<Widget> options = [];

    // Determine color and base options
    switch (producerTypeString) {
      case 'leisure':
        primaryColor = Colors.deepPurple;
        modalTitle = 'Créer (Loisir)';
        break;
      case 'wellness':
        primaryColor = Colors.green; // Assuming green for wellness
        modalTitle = 'Créer (Bien-être)';
        break;
      case 'restaurant':
      default:
        primaryColor = Colors.orange;
        modalTitle = 'Créer (Restaurant)';
        break;
    }

    // --- Base Options --- (Photo/Video)
    options.addAll([
      ListTile(
        leading: Icon(Icons.photo_library_outlined, color: primaryColor),
        title: const Text('Photo / Vidéo'),
        subtitle: const Text('Partager une image ou une courte vidéo'),
        onTap: () {
          Navigator.pop(context);
          // Decide which picker based on some logic or show another choice?
          _showMediaPickerSheet(context, 'image/video');
        },
      ),
      ListTile(
        leading: Icon(Icons.article_outlined, color: primaryColor),
        title: const Text('Texte simple'),
         subtitle: const Text('Écrire une annonce ou une nouvelle'),
        onTap: () {
          Navigator.pop(context);
          _createGenericPost(context, 'Texte simple');
        },
      ),
      const Divider(), // Separator
    ]);

    // --- Specific Options based on Producer Type ---
    if (producerTypeString == 'restaurant') {
      options.addAll([
        ListTile(
          leading: Icon(Icons.restaurant_menu_outlined, color: primaryColor),
          title: const Text('Nouveau plat du menu'),
          onTap: () {
            Navigator.pop(context);
            _createDishPost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.event_outlined, color: primaryColor),
          title: const Text('Événement spécial'),
          subtitle: const Text('Brunch, soirée à thème, dégustation...'),
          onTap: () {
            Navigator.pop(context);
            _createEventPost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.local_offer_outlined, color: primaryColor),
          title: const Text('Promotion / Offre'),
           subtitle: const Text('Happy hour, réduction...'),
          onTap: () {
            Navigator.pop(context);
            _createPromotionPost(context);
          },
        ),
      ]);
    } else if (producerTypeString == 'leisure') {
      options.addAll([
        ListTile(
          leading: Icon(Icons.event_outlined, color: primaryColor),
          title: const Text('Nouvel événement'),
          onTap: () {
            Navigator.pop(context);
            _createEventPost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.palette_outlined, color: primaryColor),
          title: const Text('Nouvelle exposition / Activité'),
          onTap: () {
            Navigator.pop(context);
            _createActivityPost(context);
          },
        ),
         ListTile(
          leading: Icon(Icons.music_note_outlined, color: primaryColor),
          title: const Text('Concert / Spectacle'),
          onTap: () {
            Navigator.pop(context);
            _createShowPost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.local_offer_outlined, color: primaryColor),
          title: const Text('Promotion / Offre spéciale'),
          onTap: () {
            Navigator.pop(context);
            _createPromotionPost(context);
          },
        ),
      ]);
    } else if (producerTypeString == 'wellness') {
      options.addAll([
        ListTile(
          leading: Icon(Icons.spa_outlined, color: primaryColor),
          title: const Text('Nouveau soin / Service'),
          onTap: () {
            Navigator.pop(context);
            _createServicePost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.school_outlined, color: primaryColor),
          title: const Text('Nouveau cours / Atelier'),
          onTap: () {
            Navigator.pop(context);
            _createClassPost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.event_outlined, color: primaryColor),
          title: const Text('Nouvel événement bien-être'),
          onTap: () {
            Navigator.pop(context);
            _createEventPost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.local_offer_outlined, color: primaryColor),
          title: const Text('Promotion / Offre spéciale'),
          onTap: () {
            Navigator.pop(context);
            _createPromotionPost(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.lightbulb_outline, color: primaryColor),
          title: const Text('Conseils bien-être'),
          onTap: () {
            Navigator.pop(context);
            _createTipsPost(context);
          },
        ),
      ]);
    }

    // --- Show Modal Sheet ---
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow modal to take more height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
             expand: false, // Content fits within bounds
             initialChildSize: 0.6, // Start at 60% height
             minChildSize: 0.4,   // Min height
             maxChildSize: 0.85,  // Max height
             builder: (_, scrollController) {
                return Container(
                  padding: const EdgeInsets.only(top: 12), // Padding top for handle
                  child: Column(
                    children: [
                       // Drag handle
                       Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                             color: Colors.grey[300],
                             borderRadius: BorderRadius.circular(10)
                          ),
                       ),
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(
                               modalTitle,
                               style: GoogleFonts.poppins(
                                 fontSize: 20,
                                 fontWeight: FontWeight.bold,
                                 color: primaryColor,
                               ),
                             ),
                             IconButton(
                               icon: const Icon(Icons.close),
                               onPressed: () => Navigator.pop(context),
                             ),
                           ],
                         ),
                       ),
                       const Divider(height: 1),
                       Expanded(
                         child: ListView.separated(
                            controller: scrollController, // Use the controller
                            itemCount: options.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (context, index) {
                               return options[index];
                            },
                            padding: const EdgeInsets.only(bottom: 16), // Padding at the bottom
                         ),
                       ),
                    ],
                  ),
                );
           },
        );
      },
    );
  }
} 