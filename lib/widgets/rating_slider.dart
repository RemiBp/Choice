import 'package:flutter/material.dart';

class RatingSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int divisions;

  const RatingSlider({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 10.0,
    this.divisions = 20,
  }) : super(key: key);

  // Obtenir la couleur appropriée basée sur la valeur
  Color _getColorForValue(BuildContext context) {
    final percentage = (value - min) / (max - min);
    
    if (percentage < 0.3) {
      return Colors.redAccent;
    } else if (percentage < 0.7) {
      return Colors.amberAccent;
    } else {
      return Colors.greenAccent;
    }
  }

  // Obtenir un emoji basé sur la valeur
  String _getEmojiForValue() {
    final percentage = (value - min) / (max - min);
    
    if (percentage < 0.2) return '😞';
    if (percentage < 0.4) return '😕';
    if (percentage < 0.6) return '😐';
    if (percentage < 0.8) return '🙂';
    return '😁';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForValue(context);
    final emoji = _getEmojiForValue();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: Colors.grey.withOpacity(0.2),
                trackHeight: 8,
                thumbColor: Colors.white,
                thumbShape: SliderThumbShape(color: color),
                overlayColor: color.withOpacity(0.1),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                tickMarkShape: SliderTickMarkShape(),
                activeTickMarkColor: Colors.white,
                inactiveTickMarkColor: Colors.grey.withOpacity(0.3),
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorColor: color,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: value.toStringAsFixed(1),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.thumb_down, size: 16, color: Colors.redAccent.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Insuffisant',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.thumb_up, size: 16, color: Colors.greenAccent.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Excellent',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Classes personnalisées pour les composants du slider
class SliderThumbShape extends SliderComponentShape {
  final Color color;
  
  const SliderThumbShape({required this.color});
  
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size.fromRadius(10);
  }
  
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    // Animation du cercle au focus
    final radiusMultiplier = 1.0 + (0.2 * activationAnimation.value);
    
    canvas.drawCircle(
      center,
      10 * radiusMultiplier,
      fillPaint,
    );
    
    canvas.drawCircle(
      center,
      10 * radiusMultiplier,
      borderPaint,
    );
  }
}

class SliderTickMarkShape extends RoundSliderTickMarkShape {
  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    return const Size.fromRadius(2);
  }
  
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    if (!isEnabled) return;
    
    final Canvas canvas = context.canvas;
    
    final tickPaint = Paint()
      ..color = center.dx < thumbCenter.dx 
          ? sliderTheme.activeTickMarkColor! 
          : sliderTheme.inactiveTickMarkColor!;
    
    canvas.drawCircle(center, 2, tickPaint);
  }
}