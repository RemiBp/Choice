import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Import the Post model if you are type-checking against it
import '../../models/post.dart';

// TODO: Fetch actual stats from backend API based on postId
// TODO: Implement chart widgets if needed (e.g., using fl_chart)

class PostStatsModal {
  static Future<void> show(BuildContext context, dynamic post) {
    String postId = 'inconnu';
    int likesCount = 0;
    int commentsCount = 0;
    int sharesCount = 0;
    int viewsCount = 0;

    if (post is Post) {
        postId = post.id;
        // Access direct fields from Post model
        likesCount = post.likesCount ?? 0;
        commentsCount = post.comments.length; // Assuming comments is always List
        // sharesCount = post.sharesCount ?? 0; // Use if field exists
        // viewsCount = post.viewsCount ?? 0;   // Use if field exists
    } else if (post is Map<String, dynamic>) {
        postId = post['_id'] ?? 'inconnu';
        final statsMap = post['stats'];
        if (statsMap is Map) {
           likesCount = statsMap['likes_count'] ?? 0;
           commentsCount = statsMap['comments_count'] ?? 0;
           sharesCount = statsMap['shares_count'] ?? 0;
           viewsCount = statsMap['views_count'] ?? 0;
        } else {
            likesCount = post['likes_count'] ?? 0;
            commentsCount = (post['comments'] as List?)?.length ?? 0;
            sharesCount = post['shares_count'] ?? 0;
            viewsCount = post['views_count'] ?? 0;
        }
    }

    // Placeholder values - Replace with actual fetched data
    String impressions = _formatStatNumber(viewsCount * 3 + 123); // Example calculation
    String engagement = _formatStatNumber(likesCount + commentsCount + sharesCount + 42);
    String profileVisits = _formatStatNumber((viewsCount * 0.15).round() + 15);
    String engagementRate = viewsCount > 0 ? '${((likesCount + commentsCount + sharesCount) / viewsCount * 100).toStringAsFixed(1)}%' : '0.0%';
    String profileVisitRate = viewsCount > 0 ? '${(((viewsCount * 0.15).round() + 15) / viewsCount * 100).toStringAsFixed(1)}%' : '0.0%';

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75, // Start a bit higher
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, // Use theme card color
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                 // Drag handle
                 Container(
                    width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                       color: Colors.grey[400],
                       borderRadius: BorderRadius.circular(10)
                    ),
                 ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 10, 10), // Adjusted padding
                  child: Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Colors.teal, size: 26),
                      const SizedBox(width: 10),
                       Text(
                        'Statistiques du post',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Fermer',
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[300], height: 1),
                // Scrollable Content Area
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // --- Key Metrics ---
                      _buildStatCard(
                        icon: Icons.visibility_outlined,
                        title: 'Impressions', // Views in the feed
                        value: impressions,
                        subtitle: 'Vues uniques estimées', // Clarify meaning
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        icon: Icons.touch_app_outlined,
                        title: 'Engagement', // Likes, comments, shares
                        value: _formatStatNumber(likesCount + commentsCount + sharesCount), // Use extracted counts
                        subtitle: engagementRate,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        icon: Icons.person_outline,
                        title: 'Visites de profil', // Clicks to profile from post
                        value: profileVisits,
                        subtitle: '$profileVisitRate des impressions',
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 24),

                      // --- Interactions Breakdown ---
                       Text(
                        'Répartition des interactions',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor, // Use scaffold background
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200)
                        ),
                        child: IntrinsicHeight( // Make rows same height
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceAround,
                             children: [
                               _buildInteractionTypeItem(
                                 icon: Icons.favorite, label: 'Likes', count: _formatStatNumber(likesCount), color: Colors.redAccent
                               ),
                                const VerticalDivider(),
                               _buildInteractionTypeItem(
                                 icon: Icons.chat_bubble_outline, label: 'Commentaires', count: _formatStatNumber(commentsCount), color: Colors.blue
                               ),
                                const VerticalDivider(),
                               _buildInteractionTypeItem(
                                 icon: Icons.share_outlined, label: 'Partages', count: _formatStatNumber(sharesCount), color: Colors.purple
                               ),
                               // Add other interaction types if tracked (e.g., saves, clicks)
                             ],
                           ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- Placeholder Demographics --- (Requires API data)
                      Text(
                        'Audience (Exemple)',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                       const SizedBox(height: 10),
                       Container(
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: Theme.of(context).scaffoldBackgroundColor,
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.grey.shade200)
                         ),
                         child: Row(
                           children: [
                             Expanded(child: _buildPlaceholderChart('Genre', Colors.pink)),
                             const SizedBox(width: 16),
                             Expanded(child: _buildPlaceholderChart('Âge', Colors.teal)),
                           ],
                         ),
                       ),
                       const SizedBox(height: 24),

                      // --- Placeholder AI Recommendations --- (Requires API data)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Conseils IA (Exemple)',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                             Text(
                              'Ce post performe bien! Suggestions :',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            _buildRecommendationItem(
                              'Publier à nouveau ce type de contenu le week-end.'
                            ),
                            _buildRecommendationItem(
                              'Créer une offre spéciale liée à ce sujet.'
                            ),
                            _buildRecommendationItem(
                              'Interagir avec les commentaires pour booster la visibilité.'
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper to format numbers for display
  static String _formatStatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)} k'.replaceAll('.0', '');
    return '${(number / 1000000).toStringAsFixed(1)} M'.replaceAll('.0', '');
  }

  // --- Reusable Stat Card Widget ---
  static Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Interaction Type Item ---
  static Widget _buildInteractionTypeItem({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

   // --- Placeholder Chart --- (Replace with actual chart implementation)
   static Widget _buildPlaceholderChart(String title, Color color) {
     return Column(
        children: [
           Text(
             title,
             style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
           ),
           const SizedBox(height: 8),
           Container(
             height: 100,
             decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
             ),
             child: Center(
                child: Icon(Icons.show_chart_outlined, color: color, size: 40)
             ),
           ),
           const SizedBox(height: 4),
           Text('Données non disponibles', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey))
        ],
     );
   }

  // --- Reusable Recommendation Item ---
  static Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

} 