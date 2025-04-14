// configs/api_config.dart
// Fichier de compatibilité pour les imports existants
// Redirige vers utils/constants.dart pour une configuration unifiée

import '../utils/constants.dart' as constants;

// URL de base - utilise la même fonction que dans constants.dart
String get baseUrl => "https://api.choiceapp.fr";

// Valeur du mode de production
bool get isProduction => true;

// Fonction wrapper pour compatibilité
String getBaseUrl() {
  print("🔄 [configs/api_config.dart] getBaseUrl() appelé (compatibilité)");
  return "https://api.choiceapp.fr";
} 