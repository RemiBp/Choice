import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../models/map_filter.dart';

/// Classe utilitaire pour générer des marqueurs stylisés pour les cartes
class MapMarkerGenerator {
  /// Génère un marqueur coloré avec un score de correspondance
  static Future<gmaps.BitmapDescriptor> createScoreMarker(
    double score, 
    MapType mapType, 
    {bool isSelected = false}
  ) async {
    final int size = 80;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Couleur basée sur le mapType
    final Color mainColor = _getColorForMapType(mapType);
    
    // Couleur basée sur le score (du rouge au vert)
    final Color scoreColor = HSVColor.fromAHSV(
      1.0, 
      120 * score, // 0° = rouge, 120° = vert
      0.8, 
      0.8
    ).toColor();
    
    // Dessiner le cercle principal
    final Paint circlePaint = Paint()..color = isSelected ? mainColor : scoreColor;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 4,
      circlePaint,
    );
    
    // Bordure blanche
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 4,
      borderPaint,
    );
    
    // Convertir le canvas en image
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    
    return gmaps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
  
  /// Génère un marqueur simple pour un lieu
  static Future<gmaps.BitmapDescriptor> createPlaceMarker(
    MapType mapType, 
    {bool isSelected = false}
  ) async {
    final int size = 80;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Couleur basée sur le mapType
    final Color mainColor = _getColorForMapType(mapType);
    
    // Dessiner le cercle principal
    final Paint circlePaint = Paint()..color = mainColor;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 4,
      circlePaint,
    );
    
    // Bordure blanche
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = isSelected ? 4 : 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 4,
      borderPaint,
    );
    
    // Convertir le canvas en image
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    
    return gmaps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
  
  /// Génère un marqueur pour la position actuelle
  static Future<gmaps.BitmapDescriptor> createCurrentLocationMarker() async {
    const int size = 100;
    
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Cercle extérieur bleu translucide
    final Paint outerCirclePaint = Paint()
      ..color = Colors.blue.withOpacity(0.3);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      outerCirclePaint,
    );
    
    // Cercle central bleu
    final Paint innerCirclePaint = Paint()
      ..color = Colors.blue;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 4,
      innerCirclePaint,
    );
    
    // Bordure blanche autour du cercle central
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 4,
      borderPaint,
    );
    
    // Convertir le canvas en image
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    
    return gmaps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
  
  /// Retourne la couleur appropriée pour un type de carte
  static Color _getColorForMapType(MapType mapType) {
    switch (mapType) {
      case MapType.restaurant:
        return Colors.orange;
      case MapType.leisure:
        return Colors.purple;
      case MapType.wellness:
        return Colors.teal;
      case MapType.friends:
        return Colors.blue;
      default:
        return Colors.red;
    }
  }
  
  /// Retourne une couleur contrastée (noir ou blanc) selon la couleur de fond
  static Color _getContrastColor(Color backgroundColor) {
    // Calculer la luminosité selon la formule YIQ
    final double yiq = (backgroundColor.red * 299 + 
                      backgroundColor.green * 587 + 
                      backgroundColor.blue * 114) / 1000;
    
    // Si la couleur de fond est claire, utiliser du noir, sinon du blanc
    return yiq >= 128 ? Colors.black : Colors.white;
  }
  
  /// Génère un marqueur personnalisé pour un ami sur la carte
  static Future<gmaps.BitmapDescriptor> generateFriendMarker(
    String name,
    Color color,
  ) async {
    try {
      // Créer un PictureRecorder pour dessiner l'icône
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..color = color;
      
      // Dessiner un cercle rempli
      canvas.drawCircle(
        const Offset(24, 24),
        22,
        paint,
      );
      
      // Ajouter un contour blanc
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(
        const Offset(24, 24),
        21,
        borderPaint,
      );
      
      // Ajouter les initiales de l'ami
      final String initials = _getInitials(name);
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(24 - textPainter.width / 2, 24 - textPainter.height / 2),
      );
      
      // Convertir en image
      final ui.Image image = await pictureRecorder.endRecording().toImage(48, 48);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (data == null) {
        return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure);
      }
      
      return gmaps.BitmapDescriptor.fromBytes(data.buffer.asUint8List());
    } catch (e) {
      print("❌ Erreur création marqueur ami: $e");
      return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure);
    }
  }
  
  /// Obtenir les initiales d'un nom
  static String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final List<String> parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Enum pour les différents types de cartes
enum MapType {
  restaurant,
  leisure,
  wellness,
  friends,
} 