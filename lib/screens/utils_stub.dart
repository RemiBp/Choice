// screens/utils_stub.dart (Default implementation)
// This file contains stub implementations that will be overridden by platform-specific code

String getBaseUrl() {
  return "https://api.choiceapp.fr"; // Default production URL
}

/// Vérifie si l'application tourne sur un mobile
bool isMobile() {
  return false; // Default implementation
}

/// Vérifie si l'application tourne sur un desktop (Windows, Mac, Linux)
bool isDesktop() {
  return false; // Default implementation
}

/// Vérifie si la plateforme supporte `dart:io`
bool supportsIO() {
  return false; // Default implementation
}