import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/premium_feature_service.dart';

class ProducerProfileHeader extends StatefulWidget {
  final Map<String, dynamic> producer;
  final bool hasActivePromotion;
  final DateTime? promotionEndDate;
  final double promotionDiscount;
  final VoidCallback onEditProfile;
  final VoidCallback onShowPromotionDialog;
  final VoidCallback onDeactivatePromotion;
  final VoidCallback onNavigateToStats;
  final VoidCallback onNavigateToClients;

  const ProducerProfileHeader({
    Key? key,
    required this.producer,
    required this.hasActivePromotion,
    this.promotionEndDate,
    required this.promotionDiscount,
    required this.onEditProfile,
    required this.onShowPromotionDialog,
    required this.onDeactivatePromotion,
    required this.onNavigateToStats,
    required this.onNavigateToClients,
  }) : super(key: key);

  @override
  State<ProducerProfileHeader> createState() => _ProducerProfileHeaderState();
}

class _ProducerProfileHeaderState extends State<ProducerProfileHeader> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    print('--- DEBUG: ProfileHeader build ---');
    print('DEBUG: Received hasActivePromotion: ${widget.hasActivePromotion} (Type: ${widget.hasActivePromotion.runtimeType})');
    print('---------------------------------');

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
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
                      onTap: widget.onEditProfile,
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
                          tag: 'producer-photo-${widget.producer['_id']}',
                          child: ClipOval(
                            child: Image.network(
                              widget.producer['photo'] ?? 'https://via.placeholder.com/100',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
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
                                  widget.producer['name'] ?? 'Nom non spécifié',
                                  style: const TextStyle(
                                    fontSize: 24, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.black87,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              widget.hasActivePromotion 
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '-${widget.promotionDiscount.toStringAsFixed(0)}%',
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
                              _buildRatingStars(widget.producer['rating']),
                              const SizedBox(width: 8),
                              Text(
                                '(${widget.producer['user_ratings_total'] ?? 0})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Adresse avec icône
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.producer['address'] ?? 'Adresse non spécifiée',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          
                          // Description
                          Text(
                            widget.producer['description'] ?? 'Description non spécifiée',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'Éditer',
                      onTap: widget.onEditProfile,
                    ),
                    
                    _buildActionButton(
                      icon: Icons.monetization_on_outlined,
                      label: widget.hasActivePromotion ? 'Promo active' : 'Promotion',
                      onTap: widget.hasActivePromotion ? widget.onDeactivatePromotion : widget.onShowPromotionDialog,
                      isHighlighted: widget.hasActivePromotion,
                    ),
                    
                    _buildActionButton(
                      icon: Icons.insights,
                      label: 'Statistiques',
                      onTap: widget.onNavigateToStats,
                    ),
                    
                    _buildActionButton(
                      icon: Icons.people,
                      label: 'Clients',
                      onTap: widget.onNavigateToClients,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Widget pour afficher les étoiles de notation
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
              // Étoile pleine
              return const Icon(Icons.star, color: Colors.amber, size: 20);
            } else if (index < ratingValue.ceil() && ratingValue.floor() != ratingValue.ceil()) {
              // Étoile à moitié pleine
              return const Icon(Icons.star_half, color: Colors.amber, size: 20);
            } else {
              // Étoile vide
              return const Icon(Icons.star_border, color: Colors.amber, size: 20);
            }
          }),
        ),
        const SizedBox(width: 4),
        Text(
          ratingValue > 0 ? ratingValue.toStringAsFixed(1) : 'N/A',
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: Colors.amber,
          ),
        ),
      ],
    );
  }
  
  // Widget pour les boutons d'action dans le header
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.orangeAccent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isHighlighted ? Colors.white : Colors.orangeAccent,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isHighlighted ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pour afficher la bannière de promotion
class PromotionBanner extends StatelessWidget {
  final DateTime? promotionEndDate;
  final double promotionDiscount;
  final VoidCallback onDeactivate;

  const PromotionBanner({
    Key? key,
    this.promotionEndDate,
    required this.promotionDiscount,
    required this.onDeactivate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orangeAccent, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Promotion active!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (promotionEndDate != null)
                  Text(
                    'Réduction de $promotionDiscount% sur tous les plats jusqu\'au ${DateFormat('dd/MM/yyyy').format(promotionEndDate!)}',
                    style: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onDeactivate,
          ),
        ],
      ),
    );
  }
} 