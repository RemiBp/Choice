import 'package:flutter/material.dart';

/// A custom card widget with enhanced styling options
class CustomCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final double borderRadius;
  final VoidCallback? onTap;
  final Border? border;
  final Gradient? gradient;
  
  const CustomCard({
    Key? key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.elevation,
    this.borderRadius = 12.0,
    this.onTap,
    this.border,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        gradient: gradient,
        boxShadow: elevation != null && elevation! > 0
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: elevation! * 2,
                  offset: Offset(0, elevation! / 2),
                  spreadRadius: elevation! / 2,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// A gradient card with preset gradient styles
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final double borderRadius;
  final VoidCallback? onTap;
  final List<Color> gradientColors;
  final GradientType gradientType;

  const GradientCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.borderRadius = 12.0,
    this.onTap,
    this.gradientColors = const [Colors.blue, Colors.indigo],
    this.gradientType = GradientType.linear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Gradient gradient;
    
    switch (gradientType) {
      case GradientType.linear:
        gradient = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case GradientType.radial:
        gradient = RadialGradient(
          colors: gradientColors,
          center: Alignment.center,
          radius: 1.0,
        );
        break;
      case GradientType.sweep:
        gradient = SweepGradient(
          colors: gradientColors,
          center: Alignment.center,
        );
        break;
    }

    return CustomCard(
      padding: padding,
      margin: margin,
      elevation: elevation,
      borderRadius: borderRadius,
      onTap: onTap,
      gradient: gradient,
      child: child,
    );
  }
}

enum GradientType {
  linear,
  radial,
  sweep,
}