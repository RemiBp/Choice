// Represents a single AI-generated recommendation for a producer.
class RecommendationData {
  final String title;
  final String description;
  final String iconName; // Name of the Material icon to display
  final String impact; // e.g., "Élevé", "Moyen", "Faible"
  final String effort; // e.g., "Faible", "Moyen", "Élevé"

  RecommendationData({
    required this.title,
    required this.description,
    required this.iconName,
    required this.impact,
    required this.effort,
  });

  factory RecommendationData.fromJson(Map<String, dynamic> json) {
    return RecommendationData(
      title: json['title'] as String ?? 'Recommandation',
      description: json['description'] as String ?? 'Détails non disponibles.',
      iconName: json['iconName'] as String ?? 'lightbulb_outline', // Default icon
      impact: json['impact'] as String ?? '-',
      effort: json['effort'] as String ?? '-',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'iconName': iconName,
        'impact': impact,
        'effort': effort,
      };
} 