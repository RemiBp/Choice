import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/place.dart';

/// Carte d'information pour afficher les détails d'un lieu
class PlaceInfoCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final bool showDetails;
  final bool isSelected;

  const PlaceInfoCard({
    Key? key,
    required this.place,
    this.onTap,
    this.onClose,
    this.showDetails = false,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 8 : 4,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected 
              ? BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const Divider(),
              _buildBasicInfo(),
              if (showDetails) ...[
                const SizedBox(height: 8),
                _buildDetails(),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            place.name,
            style: AppStyles.subtitle1.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onClose != null)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 20,
          ),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getCategoryIcon(),
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                place.category ?? 'Non catégorisé',
                style: AppStyles.bodyText2.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                place.address,
                style: AppStyles.bodyText2.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Évaluation avec étoiles
            Row(
              children: [
                const Icon(
                  Icons.star,
                  size: 16,
                  color: Colors.amber,
                ),
                const SizedBox(width: 4),
                Text(
                  '${place.rating?.toStringAsFixed(1) ?? 'N/A'} (${place.choicesCount ?? 0})',
                  style: AppStyles.bodyText2,
                ),
              ],
            ),
            // Gamme de prix
            if (place.priceRange != null)
              Text(
                place.priceRange!,
                style: AppStyles.bodyText2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (place.description != null && place.description!.isNotEmpty) ...[
          Text(
            'Description',
            style: AppStyles.subtitle2,
          ),
          const SizedBox(height: 4),
          Text(
            place.description!,
            style: AppStyles.bodyText2,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        
        if (place.openingHours != null && place.openingHours!.isNotEmpty) ...[
          Text(
            'Horaires',
            style: AppStyles.subtitle2,
          ),
          const SizedBox(height: 4),
          ...place.openingHours!.map((hours) => Text(
                hours,
                style: AppStyles.bodyText2,
              )),
          const SizedBox(height: 8),
        ],
        
        if (place.emotions != null && place.emotions!.isNotEmpty) ...[
          Text(
            'Émotions',
            style: AppStyles.subtitle2,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: place.emotions!.map((emotion) => Chip(
              label: Text(
                emotion,
                style: AppStyles.caption.copyWith(
                  color: Colors.white,
                ),
              ),
              backgroundColor: _getEmotionColor(emotion),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            )).toList(),
          ),
        ],
      ],
    );
  }

  IconData _getCategoryIcon() {
    if (place.category == null) return Icons.place;
    
    final String category = place.category!.toLowerCase();
    
    if (category.contains('restaurant') || category.contains('café')) {
      return Icons.restaurant;
    } else if (category.contains('ciném') || category.contains('film')) {
      return Icons.movie;
    } else if (category.contains('théâtre') || category.contains('spectacle')) {
      return Icons.theater_comedy;
    } else if (category.contains('musée') || category.contains('exposition')) {
      return Icons.museum;
    } else if (category.contains('parc') || category.contains('jardin')) {
      return Icons.park;
    } else if (category.contains('sport')) {
      return Icons.sports;
    } else if (category.contains('concert') || category.contains('music')) {
      return Icons.music_note;
    } else if (category.contains('spa') || category.contains('massage')) {
      return Icons.spa;
    }
    
    return Icons.place;
  }

  Color _getEmotionColor(String emotion) {
    final String lowercaseEmotion = emotion.toLowerCase();
    
    if (lowercaseEmotion.contains('joie')) return AppColors.joy;
    if (lowercaseEmotion.contains('surprise')) return AppColors.surprise;
    if (lowercaseEmotion.contains('nostalgie')) return AppColors.nostalgia;
    if (lowercaseEmotion.contains('fascin')) return AppColors.fascination;
    if (lowercaseEmotion.contains('inspir')) return AppColors.inspiration;
    if (lowercaseEmotion.contains('amus')) return AppColors.amusement;
    if (lowercaseEmotion.contains('relax')) return AppColors.relaxation;
    if (lowercaseEmotion.contains('excit')) return AppColors.excitement;
    
    return Colors.grey;
  }
} 