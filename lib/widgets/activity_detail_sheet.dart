import 'package:flutter/material.dart';
import '../utils.dart' show getImageProvider;

/// Widget pour afficher les détails d'une activité dans une bottom sheet
class ActivityDetailSheet extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback? onClose;
  final VoidCallback? onNavigate;
  final Function(String)? onViewProfile;

  const ActivityDetailSheet({
    Key? key,
    required this.activity,
    this.onClose,
    this.onNavigate,
    this.onViewProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extracting data from activity
    final venue = activity['venue'] ?? {};
    final friend = activity['friend'] ?? {};
    
    final String venueName = venue['name'] ?? "Lieu sans nom";
    final String category = venue['category'] ?? "Lieu";
    final double rating = venue['rating'] != null 
        ? (venue['rating'] is num ? (venue['rating'] as num).toDouble() : 0.0) 
        : 0.0;
    final String address = venue['address'] ?? "Adresse non disponible";
    final String imageUrl = venue['photo'] ?? venue['image'] ?? "https://via.placeholder.com/400x200?text=Activity";
    
    final String friendName = friend['name'] ?? "Ami";
    final String friendAvatar = friend['avatar'] ?? friend['photo_url'] ?? "";
    
    final bool isInterest = activity['type'] == 'interest';
    final Color accentColor = isInterest ? Colors.blue : Colors.orange;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with image
          Stack(
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: activity['image_url'] != null
                      ? Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            color: Colors.grey[300],
                          ),
                          child: Builder(
                            builder: (context) {
                              final imageUrl = activity['image_url'];
                              final imageProvider = getImageProvider(imageUrl);
                              
                              return ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                child: imageProvider != null
                                  ? Image(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        print("❌ Error loading activity image: $error");
                                        return Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]));
                                      },
                                    )
                                  : Center(child: Icon(Icons.image, size: 40, color: Colors.grey[600])),
                              );
                            }
                          ),
                        )
                      : SizedBox(height: 16),
                ),
              ),
              
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              
              // Name and category overlay
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venueName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (rating > 0) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Close button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Activity details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Friend section
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: friendAvatar.isNotEmpty 
                        ? getImageProvider(friendAvatar) ?? const AssetImage('assets/images/default_avatar.png')
                        : const AssetImage('assets/images/default_avatar.png'),
                      backgroundColor: Colors.grey[200],
                      child: friendAvatar.isEmpty ? Icon(Icons.person, color: Colors.grey[400]) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isInterest ? "Lieu d'intérêt de" : "Choix de",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            friendName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => onViewProfile?.call(friend['id'] ?? ''),
                      child: const Text('Voir profil'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            child: ElevatedButton(
              onPressed: onNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.directions),
                  SizedBox(width: 8),
                  Text('Itinéraire'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 