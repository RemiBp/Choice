import 'dart:async';
import 'package:flutter/services.dart';

class FlutterAppBadger {
  static const MethodChannel _channel = MethodChannel('flutter_app_badger');

  /// Adds a badge to the app icon.
  ///
  /// The value should be an integer indicating the badge count.
  static Future<void> updateBadgeCount(int count) async {
    try {
      await _channel.invokeMethod('updateBadgeCount', {"count": count});
    } on PlatformException catch (e) {
      print("Failed to update app badge: '${e.message}'.");
    }
  }

  /// Removes the badge from the app icon.
  static Future<void> removeBadge() async {
    try {
      await _channel.invokeMethod('removeBadge');
    } on PlatformException catch (e) {
      print("Failed to remove app badge: '${e.message}'.");
    }
  }

  /// Checks if the device supports app badging.
  static Future<bool> isAppBadgeSupported() async {
    try {
      final bool result = await _channel.invokeMethod('isAppBadgeSupported');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check app badge support: '${e.message}'.");
      return false;
    }
  }
} 