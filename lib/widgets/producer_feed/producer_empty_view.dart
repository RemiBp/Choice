import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProducerEmptyView extends StatelessWidget {
  final int tabIndex;
  final bool isLeisureProducer; // Or pass producerType string
  final VoidCallback onCreatePost; // Callback to trigger post creation

  const ProducerEmptyView({
    Key? key,
    required this.tabIndex,
    required this.isLeisureProducer,
    required this.onCreatePost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = isLeisureProducer ? Colors.deepPurple : Colors.orange;
    final Color lightColor = isLeisureProducer ? Colors.deepPurple[50]! : Colors.orange[50]!;
    final Color iconColor = isLeisureProducer ? Colors.deepPurple[200]! : Colors.orange[200]!;

    String emptyMessage;
    IconData emptyIcon;
    String subMessage;
    bool showExamples = false;
    bool showCreateButton = false;

    // Determine content based on the selected tab index
    // Note: Indices match the NEW requested order: 0:Trends, 1:Venue, 2:Interactions, 3:Followers
    switch (tabIndex) {
      case 0: // Tendances (Local Trends)
        emptyMessage = 'Aucune tendance locale à afficher';
        subMessage = 'Revenez plus tard pour voir les analyses.';
        emptyIcon = Icons.trending_up;
        break;
      case 1: // Mon lieu (Venue Posts)
        emptyMessage = isLeisureProducer
            ? 'Aucun post sur votre lieu culturel'
            : 'Aucun post sur votre restaurant';
        subMessage = isLeisureProducer
            ? 'Partagez événements et activités pour attirer des visiteurs!'
            : 'Partagez plats, promos et événements pour attirer des clients!';
        emptyIcon = isLeisureProducer ? Icons.museum_outlined : Icons.restaurant_menu_outlined;
        showExamples = true; // Show examples only for the venue tab
        showCreateButton = true;
        break;
      case 2: // Interactions
        emptyMessage = 'Aucune interaction récente';
        subMessage = 'Les likes, commentaires et partages apparaîtront ici.';
        emptyIcon = Icons.people_outline;
        break;
      case 3: // Followers
        emptyMessage = 'Aucun post récent de vos followers';
        subMessage = 'Le contenu partagé par ceux qui vous suivent s\'affichera ici.';
        emptyIcon = Icons.group_outlined;
        break;
      default:
        emptyMessage = 'Aucun contenu à afficher';
        subMessage = 'Sélectionnez un autre onglet ou revenez plus tard.';
        emptyIcon = Icons.inbox_outlined;
        break;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // Ensure refresh works
      child: Container(
        padding: const EdgeInsets.all(24.0),
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.6), // Ensure it takes some space
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              color: iconColor,
              size: 84,
            ),
            const SizedBox(height: 20),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 32),

            // Create Post Button (only on Venue tab)
            if (showCreateButton)
              ElevatedButton.icon(
                onPressed: onCreatePost,
                icon: const Icon(Icons.add_circle_outline, size: 24),
                label: Text(
                  'Créer une publication',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),

            // Examples (only on Venue tab)
            if (showExamples) ...[
              const SizedBox(height: 40),
              Text(
                'Exemples de contenu à partager',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor is MaterialColor ? primaryColor[800] : primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              ..._buildExampleItems(context, isLeisureProducer, primaryColor, lightColor),
            ],
            const SizedBox(height: 80), // Space at the bottom
          ],
        ),
      ),
    );
  }

  // Helper to build example items (extracted from original file)
  List<Widget> _buildExampleItems(BuildContext context, bool isLeisure, Color primary, Color light) {
    final List<Map<String, dynamic>> examples = isLeisure
        ? [
            {
              'title': 'Nouvelle exposition',
              'content': 'Présentez vos expos temporaires et événements spéciaux.',
              'icon': Icons.museum,
            },
            {
              'title': 'Événement à venir',
              'content': 'Annoncez concerts, spectacles ou activités culturelles.',
              'icon': Icons.event,
            },
            {
              'title': 'Offre spéciale',
              'content': 'Proposez tarifs réduits, visites guidées ou ateliers.',
              'icon': Icons.local_offer,
            },
          ]
        : [
            {
              'title': 'Plat du jour',
              'content': 'Partagez une photo de votre spécialité du moment.',
              'icon': Icons.restaurant_menu,
            },
            {
              'title': 'Promotion',
              'content': 'Annoncez offres spéciales, happy hours ou réductions.',
              'icon': Icons.local_offer,
            },
            {
              'title': 'Événement',
              'content': 'Présentez soirées à thème, brunchs ou dégustations.',
              'icon': Icons.event_available,
            },
          ];

    return examples.map((example) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: light,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              example['icon'] as IconData,
              color: primary,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    example['title'] as String,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    example['content'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
} 