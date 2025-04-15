// Represents a single Key Performance Indicator (KPI) data point.
class KpiData {
  final String label; // e.g., "Visibilité (Semaine)"
  final String value; // e.g., "12.3K vues"
  final String change; // e.g., "+8.2%" or "N/A"
  final bool isPositive; // Indicates if the change is positive (for styling)

  KpiData({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
  });

  factory KpiData.fromJson(Map<String, dynamic> json) {
    return KpiData(
      label: json['label'] as String ?? 'Inconnu',
      value: json['value'] as String ?? '-',
      change: json['change'] as String ?? 'N/A',
      isPositive: json['isPositive'] as bool ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'change': change,
        'isPositive': isPositive,
      };
} 