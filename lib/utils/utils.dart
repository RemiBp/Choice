import 'constants.dart' as constants;

/// Returns the base URL for API requests
String getBaseUrl() {
  print("! [utils.dart] ATTENTION: Version dépréciée de getBaseUrl() utilisée.");
  print("! [utils.dart] Veuillez modifier votre code pour utiliser constants.getBaseUrlSync() directement.");
  
  // Retourner l'URL de production en utilisant la méthode synchrone
  return constants.getBaseUrlSync();
}

/// Formate un nombre pour l'affichage (ex: 1200 -> 1.2K)
String formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  } else {
    return number.toString();
  }
}

// Pour le service spécifique (était précédemment localhost:3000)
String getServiceUrl() {
  return 'https://api.choiceapp.fr';
}

// Autres fonctions utilitaires...