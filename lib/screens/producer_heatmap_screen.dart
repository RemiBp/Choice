import 'package:flutter/material.dart';
import 'enhanced_heatmap_screen.dart';

class ProducerHeatmapScreen extends StatelessWidget {
  final String producerId;

  const ProducerHeatmapScreen({
    Key? key,
    required this.producerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EnhancedHeatmapScreen(
      producerId: producerId,
    );
  }
} 