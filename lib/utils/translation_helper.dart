import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Helper class pour faciliter l'utilisation des traductions dans l'application
class TranslationHelper {
  /// Change la langue de l'application
  static Future<void> changeLanguage(BuildContext context, String languageCode) async {
    // Utiliser la méthode setLocale d'EasyLocalization
    await context.setLocale(Locale(languageCode));
    print('Langue changée en $languageCode');
  }
  
  /// Obtient la langue actuelle de l'application
  static String getCurrentLanguage(BuildContext context) {
    // Utiliser la locale d'EasyLocalization
    return context.locale.languageCode;
  }
  
  /// Vérifie si une langue est actuellement active
  static bool isLanguageActive(BuildContext context, String languageCode) {
    // Vérifier si la langue actuelle correspond à celle demandée
    return context.locale.languageCode == languageCode;
  }
  
  /// Renvoie le nom de la langue en fonction du code
  static String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return 'Unknown';
    }
  }
  
  /// Liste des langues disponibles dans l'application
  static List<Map<String, String>> get availableLanguages => [
    {'code': 'fr', 'name': 'Français'},
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Español'},
  ];
}

/// Extension pour faciliter l'accès aux traductions
extension StringTranslationExtension on String {
  /// Traduit une clé de traduction
  String localTr({Map<String, String>? args, BuildContext? context}) {
    return this.tr(namedArgs: args);
  }
  
  // Méthode customTr pour éviter les conflits avec EasyLocalization
  String customTr({Map<String, String>? namedArgs, BuildContext? context}) {
    return this.tr(namedArgs: namedArgs);
  }
} 