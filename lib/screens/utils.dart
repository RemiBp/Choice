import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

String getBaseUrl() {
  return kIsWeb ? "https://api.choiceapp.fr" : "http://10.0.2.2:5000";
}

/// Vérifie si l'application tourne sur un mobile
bool isMobile() {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Vérifie si l'application tourne sur un desktop (Windows, Mac, Linux)
bool isDesktop() {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Vérifie si la plateforme supporte `dart:io`
bool supportsIO() {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (e) {
    return false;
  }
}
