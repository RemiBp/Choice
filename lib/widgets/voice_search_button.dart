import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/voice_recognition_service.dart';
import '../utils/constants.dart' as constants;

/// Widget qui affiche un bouton pour activer la recherche vocale
class VoiceSearchButton extends StatefulWidget {
  /// Callback pour récupérer le texte reconnu
  final Function(String) onResult;
  
  /// Si true, le texte reconnu est automatiquement soumis
  final bool autoSubmit;
  
  /// Si true, affiche les résultats partiels pendant la reconnaissance
  final bool partialResults;
  
  /// Durée maximale d'écoute en secondes
  final int listenDuration;
  
  /// Si true, le bouton peut demander le focus
  final bool canRequestFocus;
  
  /// Callback appelé lors d'un long press
  final VoidCallback? onLongPress;
  
  /// Tooltip pour le bouton
  final String? tooltip;

  const VoiceSearchButton({
    Key? key,
    required this.onResult,
    this.autoSubmit = true,
    this.partialResults = true,
    this.listenDuration = 10,
    this.canRequestFocus = true,
    this.onLongPress,
    this.tooltip,
  }) : super(key: key);

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton> with SingleTickerProviderStateMixin {
  final VoiceRecognitionService voiceService = VoiceRecognitionService();
  String _recognizedText = '';
  bool _isListening = false;
  double _confidenceScore = 0.0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Écouter les changements d'état
    voiceService.addListener(_onVoiceServiceChanged);
  }

  @override
  void dispose() {
    voiceService.removeListener(_onVoiceServiceChanged);
    _animationController.dispose();
    super.dispose();
  }

  // Mettre à jour l'état local lorsque le service change
  void _onVoiceServiceChanged() {
    final bool isServiceListening = voiceService.isListening;
    final String recognizedText = voiceService.lastRecognizedWords;
    
    if (mounted) {
      setState(() {
        _isListening = isServiceListening;
        
        if (_isListening && _recognizedText != recognizedText) {
          _recognizedText = recognizedText;
          
          // Envoyer le texte partiel si activé
          if (widget.partialResults) {
            widget.onResult(_recognizedText);
          }
        }
        
        // Mettre à jour l'animation
        if (_isListening) {
          _animationController.repeat();
        } else {
          _animationController.stop();
          _animationController.reset();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleListening,
          customBorder: const CircleBorder(),
          child: _isListening
              ? _buildListeningIndicator()
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.mic_none_rounded,
                    color: constants.primaryColor,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }

  // Afficher un indicateur de pulsation lors de l'écoute
  Widget _buildListeningIndicator() {
    return PulseEffect(
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: constants.primaryColor.withOpacity(0.1),
        ),
        child: Icon(
          Icons.mic,
          color: constants.primaryColor,
          size: 24,
        ),
      ),
    );
  }

  // Basculer entre l'écoute et l'arrêt
  Future<void> _toggleListening() async {
    // Vérifier la disponibilité
    if (!voiceService.isInitialized) {
      final initialized = await voiceService.checkAvailability();
      
      if (!initialized) {
        // Afficher un message si l'initialisation échoue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'activer la reconnaissance vocale: ${voiceService.lastError}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    
    if (_isListening) {
      // Arrêter l'écoute et envoyer le résultat final
      await voiceService.stopListening();
      widget.onResult(_recognizedText);
    } else {
      // Démarrer l'écoute
      _recognizedText = '';
      await voiceService.startListening(
        listenDuration: widget.listenDuration,
        onResult: (text) {
          widget.onResult(text);
        },
      );
    }
  }
}

// Créer l'effet de pulsation
class PulseEffect extends StatefulWidget {
  final Widget child;
  
  const PulseEffect({Key? key, required this.child}) : super(key: key);
  
  @override
  _PulseEffectState createState() => _PulseEffectState();
}

class _PulseEffectState extends State<PulseEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
} 