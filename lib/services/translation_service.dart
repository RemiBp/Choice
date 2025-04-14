import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class TranslationService {
  static const String LANGUAGE_CODE_KEY = 'language_code';
  static const String DEFAULT_LANGUAGE = 'fr';
  static const List<String> SUPPORTED_LANGUAGES = ['fr', 'en', 'es'];

  // Liste des langues disponibles dans l'application
  static final List<Map<String, String>> availableLanguages = [
    {'code': 'fr', 'name': 'Français'},
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Español'},
  ];
  
  // Traduire un texte en utilisant les fichiers de traduction d'EasyLocalization
  static String translateKey(String key, BuildContext context) {
    try {
      return key.tr();  // Utiliser l'extension de EasyLocalization
    } catch (e) {
      print('Erreur de traduction: $e');
      return key;  // Retourner la clé en cas d'erreur
    }
  }
  
  // Méthode de traduction mise à jour pour accepter la langue source et cible
  static Future<String> translateText(String text, String targetLanguage, {String? sourceLanguage}) async {
    try {
      // Ici, on pourrait utiliser un service de traduction externe comme Google Translate
      // Pour l'exemple, on va juste retourner le texte d'origine
      return text;
    } catch (e) {
      print('Erreur lors de la traduction: $e');
      return text;
    }
  }
  
  // Détecter la langue d'un texte
  static Future<String> detectLanguage(String text) async {
    try {
      // Dans une vraie application, on utiliserait un service comme Google Cloud Translation API
      // Pour l'exemple, on va retourner une langue par défaut
      return 'fr'; // Français par défaut
    } catch (e) {
      print('Erreur lors de la détection de langue: $e');
      return 'fr'; // Langue par défaut en cas d'erreur
    }
  }
  
  // Obtenir la langue préférée de l'utilisateur
  static Future<String> getUserPreferredLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString(LANGUAGE_CODE_KEY);
      
      if (langCode != null && SUPPORTED_LANGUAGES.contains(langCode)) {
        return langCode;
      }
      return DEFAULT_LANGUAGE;
    } catch (e) {
      print('Erreur lors de la récupération de la langue: $e');
      return DEFAULT_LANGUAGE;
    }
  }
  
  // Définir la langue préférée de l'utilisateur
  static Future<bool> setUserPreferredLanguage(String languageCode) async {
    try {
      if (!SUPPORTED_LANGUAGES.contains(languageCode)) {
        throw Exception('Langue non supportée: $languageCode');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LANGUAGE_CODE_KEY, languageCode);
      return true;
    } catch (e) {
      print('Erreur lors de la définition de la langue: $e');
      return false;
    }
  }
  
  // Changer la langue de l'application
  static Future<void> changeLanguage(BuildContext context, String languageCode) async {
    try {
      if (!SUPPORTED_LANGUAGES.contains(languageCode)) {
        throw Exception('Langue non supportée: $languageCode');
      }
      
      // Changer la langue avec easy_localization
      await context.setLocale(Locale(languageCode));
      
      // Sauvegarder le choix de l'utilisateur
      await setUserPreferredLanguage(languageCode);
      
      print('✅ Langue changée avec succès: $languageCode');
    } catch (e) {
      print('❌ Erreur lors du changement de langue: $e');
    }
  }
  
  // Obtenir le nom d'une langue à partir de son code
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
  
  // Obtenir le drapeau d'une langue à partir de son code
  static String getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return '🇫🇷';
      case 'en':
        return '🇬🇧';
      case 'es':
        return '🇪🇸';
      default:
        return '🏳️';
    }
  }
} 