import 'dart:async'; 
import 'package:flutter/services.dart'; 
 
class FlutterAppBadger { 
  static const MethodChannel _channel = MethodChannel('flutter_app_badger'); 
 
  static Future<bool> isAppBadgeSupported() async { 
    return false; 
  } 
 
  static Future<void> updateBadgeCount(int count) async {} 
 
  static Future<void> removeBadge() async {} 
}
