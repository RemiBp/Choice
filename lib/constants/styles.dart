import 'package:flutter/material.dart';
import 'colors.dart';

/// Constantes de styles utilisées dans l'application
class AppStyles {
  // Styles de texte
  static final TextStyle headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle headline2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle headline3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle subtitle2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  
  // Styles spécifiques aux écrans de carte
  static final TextStyle filterTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
  
  static final TextStyle bodySecondary = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  
  // Styles des cartes et conteneurs
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  static BoxDecoration roundedContainerDecoration = BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(8.0),
    border: Border.all(
      color: AppColors.divider,
      width: 1.0,
    ),
  );
  
  // Styles des boutons
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
  
  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.primary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.primary),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
  
  static final ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    side: BorderSide(color: AppColors.primary),
  );
  
  static final ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );
  
  // Styles des champs de saisie
  static final InputDecoration inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: Colors.grey.shade300,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: Colors.grey.shade300,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: AppColors.primary,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
  
  // Espacement
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing48 = 48;
  
  // Styles spécifiques par fonctionnalité
  static final ButtonStyle restaurantButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.restaurantPrimary,
    foregroundColor: Colors.white,
  );
  
  static final ButtonStyle leisureButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.leisurePrimary,
    foregroundColor: Colors.white,
  );
  
  static final ButtonStyle wellnessButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.wellnessPrimary,
    foregroundColor: Colors.white,
  );
  
  static final ButtonStyle friendsButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.friendsPrimary,
    foregroundColor: Colors.white,
  );
  
  // Animations
  static const Duration shortAnimationDuration = Duration(milliseconds: 250);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 500);
  static const Duration longAnimationDuration = Duration(milliseconds: 750);
  
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
}

/// Styles pour le bouton principal de l'application
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  
  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: AppStyles.primaryButtonStyle,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(text),
    );
  }
} 