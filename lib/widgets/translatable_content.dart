import 'package:flutter/material.dart';
import '../services/translation_service.dart';

/// Widget qui affiche du texte avec la possibilité de le traduire à la volée
/// Comme sur Instagram, il affiche un lien "Voir la traduction" lorsque
/// le texte est dans une langue différente de celle de l'utilisateur
class TranslatableContent extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final int expandThreshold;
  
  const TranslatableContent({
    Key? key, 
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.expandThreshold = 100, // Seuil à partir duquel on affiche "voir plus"
  }) : super(key: key);

  @override
  _TranslatableContentState createState() => _TranslatableContentState();
}

class _TranslatableContentState extends State<TranslatableContent> {
  bool _needsTranslation = false;
  bool _showTranslation = false;
  String _translatedText = '';
  String _originalLanguage = '';
  String _userLanguage = 'fr';
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkTranslation();
  }
  
  @override
  void didUpdateWidget(TranslatableContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _checkTranslation();
    }
  }
  
  Future<void> _checkTranslation() async {
    if (widget.text.isEmpty) return;
    
    try {
      if (!mounted) return;
      
      _userLanguage = await TranslationService.getUserPreferredLanguage();
      _originalLanguage = await TranslationService.detectLanguage(widget.text);
      
      if (!mounted) return;
      
      setState(() {
        _needsTranslation = _originalLanguage != _userLanguage;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors de la vérification de traduction: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _toggleTranslation() async {
    if (_isLoading) return;
    
    // Si on affiche déjà la traduction, revenir à l'original
    if (_showTranslation) {
      if (!mounted) return;
      setState(() => _showTranslation = false);
      return;
    }
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      _translatedText = await TranslationService.translateText(
        widget.text, 
        _userLanguage,
        sourceLanguage: _originalLanguage
      );
      
      if (!mounted) return;
      setState(() {
        _showTranslation = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors de la traduction: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayText = _showTranslation ? _translatedText : widget.text;
    final bool needsExpansion = displayText.length > widget.expandThreshold;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Texte (original ou traduit)
        Text(
          displayText,
          style: widget.style,
          maxLines: (_isExpanded || !needsExpansion) ? null : (widget.maxLines ?? 3),
          overflow: (_isExpanded || !needsExpansion) ? null : (widget.overflow ?? TextOverflow.ellipsis),
          textAlign: widget.textAlign,
        ),
        
        // Bouton "voir plus" si le texte est long
        if (needsExpansion)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded 
                  ? (_userLanguage == 'fr' ? 'Voir moins' : 'See less')
                  : (_userLanguage == 'fr' ? 'Voir plus' : 'See more'),
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        
        // Bouton de traduction si nécessaire (style Instagram)
        if (_needsTranslation)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: GestureDetector(
              onTap: _isLoading ? null : _toggleTranslation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey[400]!,
                        ),
                      ),
                    )
                  else
                    Icon(
                      _showTranslation ? Icons.language : Icons.translate,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _showTranslation 
                      ? (_userLanguage == 'fr' ? 'Voir l\'original' : 'See original')
                      : (_userLanguage == 'fr' 
                         ? 'Voir la traduction' 
                         : 'See translation'),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!_isLoading)
                    Text(
                      '(${TranslationService.getLanguageName(_originalLanguage)})',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
} 