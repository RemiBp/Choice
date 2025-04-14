import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Affiche une SnackBar personnalisée avec différents types (succès, erreur, info, warning)
class CustomSnackBar {
  static void show({
    required BuildContext context, 
    required String message,
    String? title,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final Color backgroundColor = _getBackgroundColor(type);
    final Color textColor = Colors.white;
    final IconData icon = _getIcon(type);
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(8),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static Color _getBackgroundColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Colors.green.shade700;
      case SnackBarType.error:
        return Colors.red.shade700;
      case SnackBarType.warning:
        return Colors.orange.shade700;
      case SnackBarType.info:
      default:
        return Colors.blue.shade700;
    }
  }

  static IconData _getIcon(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Icons.check_circle;
      case SnackBarType.error:
        return Icons.error;
      case SnackBarType.warning:
        return Icons.warning;
      case SnackBarType.info:
      default:
        return Icons.info;
    }
  }

  /// Affiche un message de succès
  static void showSuccess({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.success,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Affiche un message d'erreur
  static void showError({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.error,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Affiche un message d'information
  static void showInfo({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.info,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Affiche un message d'avertissement
  static void showWarning({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.warning,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }
}

enum SnackBarType {
  success,
  error,
  info,
  warning,
} 