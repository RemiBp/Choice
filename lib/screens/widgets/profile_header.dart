import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils.dart' show getImageProvider;

class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool hasActivePromotion;
  final double promotionDiscount;
  final VoidCallback onEdit;
  final VoidCallback onPromotion;
  final Widget? actionsRow;

  const ProfileHeader({
    Key? key,
    required this.data,
    required this.hasActivePromotion,
    required this.promotionDiscount,
    required this.onEdit,
    required this.onPromotion,
    this.actionsRow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- DEBUG Print statement --- 
    print("--- DEBUG: ProfileHeader build ---");
    print("DEBUG: Received hasActivePromotion: $hasActivePromotion (Type: ${hasActivePromotion.runtimeType})");
    print("---------------------------------");
    // --- END DEBUG ---
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo de profil améliorée
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'producer-photo-${data['_id'] ?? data['id'] ?? ''}',
                    child: ClipOval(
                      child: Image(
                        image: getImageProvider(data['photo'] ?? '') 
                            ?? const AssetImage('assets/images/default_avatar.png'),
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.restaurant,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Informations principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['name'] ?? 'Nom non spécifié',
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        hasActivePromotion 
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '-${promotionDiscount.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Note avec étoiles améliorée
                    Row(
                      children: [
                        _buildRatingStars(data['rating']),
                        const SizedBox(width: 8),
                        Text(
                          '(${data['user_ratings_total'] ?? 0})',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Adresse avec icône
                    if (data['address'] != null && data['address'].toString().isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['address'],
                            style: TextStyle(fontSize: 14, color: Colors.blue[700], decoration: TextDecoration.underline),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (data['phone_number'] != null && data['phone_number'].toString().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            data['phone_number'],
                            style: TextStyle(fontSize: 14, color: Colors.blue[700], decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    if (data['website'] != null && data['website'].toString().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.language, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            data['website'],
                            style: TextStyle(fontSize: 14, color: Colors.blue[700], decoration: TextDecoration.underline),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      data['description'] ?? 'Description non spécifiée',
                      style: TextStyle(
                        fontSize: 14, 
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Boutons d'action améliorés
          actionsRow ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildRatingStars(dynamic rating) {
    double ratingValue = 0.0;
    if (rating is int) {
      ratingValue = rating.toDouble();
    } else if (rating is double) {
      ratingValue = rating;
    } else if (rating is String) {
      ratingValue = double.tryParse(rating) ?? 0.0;
    }
    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            if (index < ratingValue.floor()) {
              return const Icon(Icons.star, color: Colors.amber, size: 20);
            } else if (index < ratingValue.ceil() && ratingValue.floor() != ratingValue.ceil()) {
              return const Icon(Icons.star_half, color: Colors.amber, size: 20);
            } else {
              return const Icon(Icons.star_border, color: Colors.amber, size: 20);
            }
          }),
        ),
        const SizedBox(width: 4),
        Text(
          '$ratingValue',
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: Colors.amber,
          ),
        ),
      ],
    );
  }
} 