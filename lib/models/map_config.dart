import 'package:flutter/material.dart';
import 'map_type.dart';

/// Configuration for each map type
class MapConfig {
  final String? title;
  final String imageIcon;
  final Color color;
  final MapType mapType;
  final String route;

  const MapConfig({
    this.title,
    required this.imageIcon,
    required this.color,
    required this.mapType,
    required this.route,
  });
}

class MapColors {
  static const Color restaurantPrimary = Color(0xFFFF9800);
  static const Color leisurePrimary = Color(0xFF9C27B0);
  static const Color wellnessPrimary = Color(0xFF009688);
  static const Color friendsPrimary = Color(0xFF2196F3);
} 