import 'dart:math' as math;

class MapFilter extends StatefulWidget {
  // ... (existing code)
}

class _MapFilterState extends State<MapFilter> {
  // ... (existing code)

  @override
  Widget build(BuildContext context) {
    // ... (existing code)
  }

  void _handleFilter(FilterType type, dynamic value) {
    // ... (existing code)

    switch (type) {
      case FilterType.rating:
        if (value != null) {
          double ratingDiff = value - 5;
          double maxExceed = 5 - 1;
          if (maxExceed > 0) {
            // Attribution proportionnelle des points
            double rateScore = (ratingDiff / maxExceed) * RATING_WEIGHT;
            score += math.min(RATING_WEIGHT, rateScore); // Maximum de RATING_WEIGHT points
          } else {
            score += RATING_WEIGHT; // Si minRating est 5, attribuer tous les points
          }
        }
        break;

      case FilterType.toggle:
        if (value != null) {
          final fieldName = section.title.toLowerCase();
          
          if (place[fieldName] != null) {
            totalWeight += section.weight;
            
            if (place[fieldName] is bool) {
              final bool fieldValue = place[fieldName];
              if (fieldValue) {
                score += section.weight;
                matchCount++;
              }
            } else {
              score += section.weight;
              matchCount++;
            }
          }
        }
        break;

      case FilterType.search:
        // Non implémenté pour le moment
        break;
    }
  }
} 