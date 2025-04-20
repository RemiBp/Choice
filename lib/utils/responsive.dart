import 'package:flutter/material.dart';

/// A simple utility class to help with responsive design
class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  /// Returns a value based on the screen size
  /// Mobile: returns the first value
  /// Tablet: returns the second value
  /// Desktop: returns the third value
  static T getValueForScreenType<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) {
      return desktop;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }

  /// Returns the screen width
  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Returns the screen height
  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;
}