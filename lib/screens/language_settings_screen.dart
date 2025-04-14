import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/translation_service.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({Key? key}) : super(key: key);

  @override
  _LanguageSettingsScreenState createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLanguage = 'fr';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final language = await TranslationService.getUserPreferredLanguage();
    if (mounted) {
      setState(() {
        _selectedLanguage = language;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile.language_settings'.tr()),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'profile.select_language'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildLanguageRadioTile('fr', '🇫🇷 Français'),
                _buildLanguageRadioTile('en', '🇬🇧 English'),
                _buildLanguageRadioTile('es', '🇪🇸 Español'),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'profile.language_note'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLanguageRadioTile(String languageCode, String languageName) {
    return RadioListTile<String>(
      title: Text(languageName),
      value: languageCode,
      groupValue: _selectedLanguage,
      onChanged: (value) async {
        if (value != null && value != _selectedLanguage) {
          setState(() {
            _isLoading = true;
          });
          
          // Changer la langue 
          await TranslationService.changeLanguage(context, value);
          
          setState(() {
            _selectedLanguage = value;
            _isLoading = false;
          });
          
          // Afficher un message de confirmation
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('profile.language_changed'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      activeColor: Theme.of(context).primaryColor,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            languageCode == 'fr' ? '🇫🇷' : (languageCode == 'en' ? '🇬🇧' : '🇪🇸'),
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
} 
