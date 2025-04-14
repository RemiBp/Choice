import 'package:flutter/material.dart';

class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minRadius;
  final double maxRadius;
  final Color color;

  const PulseAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minRadius = 20.0,
    this.maxRadius = 50.0,
    this.color = Colors.blue,
  }) : super(key: key);

  @override
  _PulseAnimationState createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    
    _animation = Tween<double>(
      begin: widget.minRadius,
      end: widget.maxRadius,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: PulsePainter(
            radius: _animation.value,
            color: widget.color,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class PulsePainter extends CustomPainter {
  final double radius;
  final Color color;

  PulsePainter({
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(1 - (radius / 50).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) {
    return radius != oldDelegate.radius || color != oldDelegate.color;
  }
}

// Widget de bulle utilisateur animée pour la carte
class UserBubble extends StatelessWidget {
  final String? label;
  final double size;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const UserBubble({
    Key? key,
    this.label,
    this.size = 40.0,
    this.color = Colors.blue,
    this.isActive = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget bubble = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: label != null
            ? Text(
                label!,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                ),
              )
            : Icon(
                Icons.person,
                color: Colors.white,
                size: size * 0.6,
              ),
      ),
    );

    final Widget result = GestureDetector(
      onTap: onTap,
      child: isActive
          ? PulseAnimation(
              color: color.withOpacity(0.5),
              minRadius: size * 0.6,
              maxRadius: size * 1.2,
              child: bubble,
            )
          : bubble,
    );

    return result;
  }
} 