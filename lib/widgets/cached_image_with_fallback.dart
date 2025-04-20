import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';

/// Un widget qui ajoute une gestion des erreurs 404 pour les images Unsplash
/// en fournissant automatiquement des images de secours
class CachedImageWithFallback extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool useDefaultPlaceholder;

  const CachedImageWithFallback({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.useDefaultPlaceholder = true,
  }) : super(key: key);

  /// Fonction pour générer une URL de secours en cas d'erreur
  String _getFallbackUrl() {
    // Vérifier si c'est une URL Unsplash
    if (imageUrl.contains('unsplash.com')) {
      // Utiliser le service Picsum pour une image de remplacement
      final seed = imageUrl.hashCode % 1000;
      return 'https://picsum.photos/seed/$seed/${(width ?? 400).round()}/${(height ?? 300).round()}';
    } 
    
    // Pour les autres types d'URL, utiliser une image générique
    return 'https://via.placeholder.com/${(width ?? 400).round()}x${(height ?? 300).round()}?text=Image+indisponible';
  }

  @override
  Widget build(BuildContext context) {
    final Widget imageWidget =
        imageUrl.isNotEmpty && getImageProvider(imageUrl) != null
            ? Image(
                image: getImageProvider(imageUrl)!,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, error, stackTrace) {
                  // En cas d'erreur 404 ou HttpException, charger une image de secours
                  if (error.toString().contains('404') || 
                      error.toString().contains('HttpException')) {
                    print('🖼️ Image non disponible: $imageUrl - Utilisation d\'une image de secours');
                    return Image(
                      image: getImageProvider(_getFallbackUrl()),
                      width: width,
                      height: height,
                      fit: fit,
                      errorBuilder: (context, error, stackTrace) => errorWidget ?? 
                        Container(
                          color: Colors.grey[300],
                          width: width,
                          height: height,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image_not_supported, size: 32, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                Text('Image non disponible', 
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    );
                  }
                  // Pour les autres types d'erreurs, afficher le widget d'erreur standard
                  return errorWidget ?? 
                    Container(
                      color: Colors.grey[300],
                      width: width,
                      height: height,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 32, color: Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text('Erreur de chargement', 
                                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                },
              )
            : Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(Icons.image, size: 32, color: Colors.grey[500]),
                ),
              );

    // Appliquer un borderRadius si spécifié
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
} 