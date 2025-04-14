import 'package:flutter/foundation.dart';

class PlatformService {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;
  
  static Future<void> initializeWebFeatures() async {
    if (isWeb) {
      // Initialisation spécifique au web
    }
  }
}
