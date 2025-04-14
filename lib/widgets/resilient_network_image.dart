import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget qui gère les erreurs HTTP 404 lors du chargement d'images
/// Remplace les images Unsplash non disponibles par des images de secours
class ResilientNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final BorderRadius? borderRadius;
  
  const ResilientNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.errorWidget,
    this.loadingWidget,
    this.borderRadius,
  }) : super(key: key);

  /// Remplace une URL Unsplash par une URL de secours si l'originale est invalide
  String _getFallbackUrl(String originalUrl) {
    // Si ce n'est pas une URL Unsplash, retourner l'URL originale
    if (!originalUrl.contains('unsplash.com')) {
      return originalUrl;
    }
    
    // Générer une URL de secours avec Picsum (service fiable d'images de test)
    final int seed = originalUrl.hashCode.abs() % 1000;
    return 'https://picsum.photos/seed/$seed/800/600';
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => loadingWidget ?? 
        Container(
          color: backgroundColor ?? Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      errorWidget: (context, url, error) {
        // Si l'erreur est 404, utiliser l'URL de secours
        if (error.toString().contains('404') || 
            error.toString().contains('HttpException')) {
          
          print('🖼️ Image non disponible: $url - Utilisation d\'une image de secours');
          
          return CachedNetworkImage(
            imageUrl: _getFallbackUrl(url),
            width: width,
            height: height,
            fit: fit,
            placeholder: (context, url) => loadingWidget ?? 
              Container(
                color: backgroundColor ?? Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            errorWidget: (context, url, error) => errorWidget ?? 
              Container(
                color: backgroundColor ?? Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
          );
        }
        
        // Pour les autres erreurs, afficher un widget d'erreur
        return errorWidget ?? 
          Container(
            color: backgroundColor ?? Colors.grey[200],
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          );
      },
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