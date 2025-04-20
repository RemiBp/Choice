import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/translation_service.dart';
import '../utils/translation_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final Function? onLanguageSelected;
  
  const LanguageSelectionScreen({Key? key, this.onLanguageSelected}) : super(key: key);

  @override
  _LanguageSelectionScreenState createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = 'fr';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo et titre
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.language,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Choisissez votre langue',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose your language',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Elija su idioma',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              
              // Liste des langues
              Expanded(
                child: ListView.builder(
                  itemCount: TranslationService.availableLanguages.length,
                  itemBuilder: (context, index) {
                    final language = TranslationService.availableLanguages[index];
                    final bool isSelected = language['code'] == _selectedLanguage;
                    
                    return Card(
                      elevation: isSelected ? 4 : 1,
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
                          child: Text(
                            language['code']!.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        title: Text(
                          language['name']!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: Colors.blue, size: 28)
                          : null,
                        onTap: () {
                          setState(() {
                            _selectedLanguage = language['code']!;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              
              // Bouton continuer
              ElevatedButton(
                onPressed: () => _setLanguageAndContinue(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continuer / Continue / Continuar',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setLanguageAndContinue(BuildContext context) async {
    try {
      // Marquer que l'utilisateur a déjà choisi une langue
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_selected_language', true);
      
      // Sauvegarder la langue sélectionnée
      await TranslationService.setUserPreferredLanguage(_selectedLanguage);
      
      // Changer la langue actuelle de l'application
      await context.setLocale(Locale(_selectedLanguage));
      
      // Notifier le parent si nécessaire
      if (widget.onLanguageSelected != null) {
        widget.onLanguageSelected!();
      }
      
      // Fermer l'écran et passer à la page suivante
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Erreur lors de la définition de la langue: $e');
      
      // Afficher un message d'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Une erreur est survenue. Veuillez réessayer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Fonction utilitaire pour vérifier si c'est le premier lancement
Future<bool> isFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  return !prefs.containsKey('has_selected_language');
} 