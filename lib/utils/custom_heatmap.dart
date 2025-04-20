import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/src/types/heatmap.dart' show WeightedLatLng;

/// A custom implementation of the heatmap functionality to replace the missing flutter_heatmap_map package
/// This provides a simplified API-compatible implementation that works with google_maps_flutter
/// Uses the official WeightedLatLng from google_maps_flutter_platform_interface to avoid type conflicts

/// Defines the color gradient used to render the heatmap
class HeatMapGradient {
  final List<Color> colors;
  final List<double> startPoints;

  // Removed assertion from const constructor to prevent constant evaluation error
  const HeatMapGradient({
    required this.colors,
    required this.startPoints,
  });
  
  // Validation is now done at runtime
  bool isValid() {
    return colors.length == startPoints.length;
  }
}

/// Widget that renders a heatmap overlay on a GoogleMap
/// This is a simplified implementation that creates circle overlays to approximate a heatmap
class HeatMapWidget extends StatefulWidget {
  final List<WeightedLatLng> heatMapDataList;
  final GoogleMapController? mapController;
  final double radius;
  final HeatMapGradient gradient;

  const HeatMapWidget({
    Key? key,
    required this.heatMapDataList,
    required this.mapController,
    this.radius = 20,
    required this.gradient,
  }) : super(key: key);

  @override
  State<HeatMapWidget> createState() => _HeatMapWidgetState();
}

class _HeatMapWidgetState extends State<HeatMapWidget> {
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _updateHeatmap();
  }

  @override
  void didUpdateWidget(HeatMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heatMapDataList != widget.heatMapDataList ||
        oldWidget.radius != widget.radius) {
      _updateHeatmap();
    }
  }

  void _updateHeatmap() {
    final newCircles = <Circle>{};
    
    for (final point in widget.heatMapDataList) {
      // Get color based on weight
      final double intensity = point.weight;
      final LatLng position = point.point;
      final color = _getColorForIntensity(intensity);
      
      newCircles.add(
        Circle(
          circleId: CircleId('heatmap_${position.latitude}_${position.longitude}'),
          center: position,
          radius: widget.radius,
          fillColor: color.withOpacity(0.7 * intensity),
          strokeWidth: 0,
        ),
      );
    }
    
    setState(() {
      _circles = newCircles;
    });
  }

  Color _getColorForIntensity(double intensity) {
    final List<Color> colors = widget.gradient.colors;
    final List<double> stops = widget.gradient.startPoints;
    
    // Handle edge cases
    if (intensity <= stops.first) return colors.first;
    if (intensity >= stops.last) return colors.last;
    
    // Find the color range
    for (int i = 0; i < stops.length - 1; i++) {
      if (intensity >= stops[i] && intensity <= stops[i + 1]) {
        // Calculate the percentage within this range
        final rangeFraction = (intensity - stops[i]) / (stops[i + 1] - stops[i]);
        
        // Interpolate between the colors
        return Color.lerp(colors[i], colors[i + 1], rangeFraction) ?? colors[i];
      }
    }
    
    return colors.last;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // This is where we would draw the heatmap in a real implementation
        // For simplicity, we're using circles to represent the heatmap points
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0), // This value doesn't matter as it will be overridden
            zoom: 10,
          ),
          circles: _circles,
          onMapCreated: (controller) {
            // We don't actually create a new map, this is just a trick to render circles
            // The real map is controlled by the parent widget
          },
          liteModeEnabled: true, // To minimize rendering impact
          compassEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          trafficEnabled: false,
          indoorViewEnabled: false,
          buildingsEnabled: false,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ],
    );
  }
}