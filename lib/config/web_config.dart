import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:js/js.dart' if (dart.library.html) 'dart:js';

class WebConfig {
  static bool get isWebPlatform => kIsWeb;
  
  static String getMediaUrl(String url) {
    if (kIsWeb) {
      return url.replaceAll('file://', '');
    }
    return url;
  }
}
