import 'package:flutter/material.dart';
import '../models/growth_analytics_models.dart';

class TrendChart extends StatelessWidget {
  final List<EngagementPoint> data;
  final String title;
  final Color lineColor;
  final String metric; // 'likes', 'comments', 'shares', 'posts'
  
  const TrendChart({
    Key? key,
    required this.data,
    required this.title,
    required this.lineColor,
    required this.metric,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('Aucune donnée disponible'));
    }
    
    // Trouver les valeurs min et max pour l'échelle
    final values = data.map((point) {
      switch (metric) {
        case 'likes': return point.likes;
        case 'comments': return point.comments;
        case 'shares': return point.shares;
        case 'posts': return point.posts;
        default: return 0;
      }
    }).toList();
    
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: Size.infinite,
                painter: ChartPainter(
                  data: data,
                  metric: metric,
                  lineColor: lineColor,
                  maxValue: maxValue.toDouble(),
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(data.first.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  _formatDate(data.last.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      return '${parts[2]}/${parts[1]}';
    }
    return dateStr;
  }
}

class ChartPainter extends CustomPainter {
  final List<EngagementPoint> data;
  final String metric;
  final Color lineColor;
  final double maxValue;
  
  ChartPainter({
    required this.data,
    required this.metric,
    required this.lineColor,
    required this.maxValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final fillPath = Path();
    
    // Sécurité pour éviter division par zéro
    if (maxValue == 0 || data.isEmpty) return;
    
    final horizontalStep = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final value = _getValue(point);
      
      final x = i * horizontalStep;
      final y = size.height - (value / maxValue * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      
      // Ajouter un point pour les valeurs
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = lineColor,
      );
    }
    
    // Compléter le chemin pour le remplissage
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    // Dessiner le remplissage d'abord
    canvas.drawPath(fillPath, fillPaint);
    // Puis dessiner la ligne
    canvas.drawPath(path, paint);
  }
  
  int _getValue(EngagementPoint point) {
    switch (metric) {
      case 'likes': return point.likes;
      case 'comments': return point.comments;
      case 'shares': return point.shares;
      case 'posts': return point.posts;
      default: return 0;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 