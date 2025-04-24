import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Pour afficher l'avatar du producteur
import 'package:timeago/timeago.dart' as timeago; // Pour afficher les dates relatives
import 'package:intl/intl.dart'; // Pour formater les dates

import '../models/offer_model.dart'; // Importer le modèle
import '../services/offer_service.dart'; // Importer le service

class MyOffersScreen extends StatefulWidget { // <-- Changé en StatefulWidget
  const MyOffersScreen({super.key});

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> { // <-- State class
  final OfferService _offerService = OfferService();
  List<Offer> _offers = [];
  bool _isLoading = true;
  String? _errorMessage;
  // Map pour suivre les offres en cours de traitement (acceptation/rejet)
  final Map<String, bool> _processingOffers = {};

  @override
  void initState() {
    super.initState();
    _loadOffers();
    // Assurez-vous que timeago est initialisé pour le français, par exemple dans main.dart
    // timeago.setLocaleMessages('fr', timeago.FrMessages());
  }

  Future<void> _loadOffers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetchedOffers = await _offerService.fetchReceivedOffers();
      if (!mounted) return;
      setState(() {
        _offers = fetchedOffers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Méthode pour accepter une offre
  Future<void> _acceptOffer(Offer offer) async {
    if (_processingOffers[offer.id] == true) return; // Éviter les doubles clics
    
    setState(() {
      _processingOffers[offer.id] = true;
    });

    try {
      final updatedOffer = await _offerService.acceptOffer(offer.id);
      
      if (!mounted) return;
      
      // Mettre à jour l'offre dans la liste
      setState(() {
        final index = _offers.indexWhere((o) => o.id == offer.id);
        if (index != -1) {
          _offers[index] = updatedOffer;
        }
        _processingOffers[offer.id] = false;
      });
      
      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offre acceptée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _processingOffers[offer.id] = false;
      });
      
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'acceptation de l\'offre: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Méthode pour rejeter une offre
  Future<void> _rejectOffer(Offer offer) async {
    if (_processingOffers[offer.id] == true) return; // Éviter les doubles clics
    
    setState(() {
      _processingOffers[offer.id] = true;
    });

    try {
      final updatedOffer = await _offerService.rejectOffer(offer.id);
      
      if (!mounted) return;
      
      // Mettre à jour l'offre dans la liste
      setState(() {
        final index = _offers.indexWhere((o) => o.id == offer.id);
        if (index != -1) {
          _offers[index] = updatedOffer;
        }
        _processingOffers[offer.id] = false;
      });
      
      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offre rejetée'),
          backgroundColor: Colors.grey[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _processingOffers[offer.id] = false;
      });
      
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rejet de l\'offre: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_offers_screen.app_bar_title'.tr()),
      ),
      body: _buildBody(), // <-- Utiliser une méthode pour le corps
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 10),
              Text('my_offers_screen.error_loading'.tr(), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text('my_offers_screen.retry'.tr()),
                onPressed: _loadOffers,
              )
            ],
          ),
        ),
      );
    }

    if (_offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_offer_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'my_offers_screen.no_offers'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Afficher la liste des offres
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _offers.length,
        itemBuilder: (context, index) {
          final offer = _offers[index];
          return _buildOfferCard(offer);
        },
      ),
    );
  }

  // Widget pour afficher une carte d'offre
  Widget _buildOfferCard(Offer offer) {
    final locale = EasyLocalization.of(context)?.locale ?? const Locale('fr');
    final timeAgoString = offer.expiresAt.isAfter(DateTime.now())
      ? timeago.format(offer.expiresAt, locale: locale.languageCode)
      : 'my_offers_screen.expired_status'.tr();

    // Vérifier si l'offre est en cours de traitement
    final isProcessing = _processingOffers[offer.id] == true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: offer.producer.profilePicture != null
                      ? CachedNetworkImageProvider(offer.producer.profilePicture!)
                      : null, // Fallback vers l'icône par défaut si pas d'image
                  child: offer.producer.profilePicture == null
                      ? const Icon(Icons.storefront, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.producer.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(offer.getStatusText(), style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: offer.getStatusColor(),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(offer.body, style: Theme.of(context).textTheme.bodyMedium),
            if (offer.discountPercentage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
        child: Text(
                  'Remise : ${offer.discountPercentage!.toStringAsFixed(0)}%',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      offer.expiresAt.isAfter(DateTime.now())
                        ? 'Expire ${timeAgoString}'
                        : 'Expirée',
                       style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
                 Text(
                  'Code: ${offer.offerCode}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                 ),
              ],
            ),
            // Afficher les boutons d'acceptation/rejet pour les offres en attente/envoyées et non expirées
            if (['pending', 'sent'].contains(offer.status) && offer.expiresAt.isAfter(DateTime.now()))
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Bouton Rejeter
                    TextButton.icon(
                      icon: isProcessing 
                          ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[300])) 
                          : const Icon(Icons.close, size: 16, color: Colors.red),
                      label: Text('Rejeter', style: TextStyle(color: Colors.red[700])),
                      onPressed: isProcessing ? null : () => _rejectOffer(offer),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton Accepter
                    ElevatedButton.icon(
                      icon: isProcessing 
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Accepter'),
                      onPressed: isProcessing ? null : () => _acceptOffer(offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
} 