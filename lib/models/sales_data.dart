import 'package:flutter/foundation.dart';

// Represents a single data point for sales/trends charts.
class SalesData {
  final String day; // Label for the x-axis (e.g., "Lun", "15:00", "2023-10-26")
  final num sales; // Value for the current period (e.g., number of interactions)
  final num lastWeek; // Value for the previous period for comparison

  SalesData({
    required this.day,
    required this.sales,
    this.lastWeek = 0, // Default to 0 if not provided
  });

  factory SalesData.fromJson(Map<String, dynamic> json) {
    return SalesData(
      day: json['day'] as String ?? 'N/A',
      // Ensure numeric conversion, default to 0
      sales: (json['sales'] as num?) ?? 0,
      lastWeek: (json['lastWeek'] as num?) ?? 0,
    );
  }

   Map<String, dynamic> toJson() => {
        'day': day,
        'sales': sales,
        'lastWeek': lastWeek,
      };
} 