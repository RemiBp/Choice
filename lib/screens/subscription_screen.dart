import 'package:flutter/material.dart';
import '../services/payment_service.dart'; // Assurez-vous que ce service existe et est correctement configuré

class SubscriptionScreen extends StatefulWidget {
  final String producerId;

  const SubscriptionScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedPlan = 'gratuit'; // Garder une trace du plan pour le feedback

  @override
  void initState() {
    super.initState();
    print("📢 SubscriptionScreen chargé avec producerId: ${widget.producerId}");
    
    // Initialiser les animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward(); // Démarrer l'animation d'entrée
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Gère la logique de souscription
  void _subscribe(BuildContext context, String plan) async {
    // Empêcher les clics multiples pendant le traitement
    if (_isProcessing) return; 
    
    setState(() {
      _isProcessing = true;
      _selectedPlan = plan; // Mémoriser le plan sélectionné
    });
    
    try {
      // Appel au service de paiement
      bool success = await PaymentService.processPayment(context, plan, widget.producerId);

      if (!mounted) return; // Vérifier si le widget est toujours monté

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Abonnement $plan réussi ! 🎉"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Optionnel: Attendre un peu avant de revenir pour que l'utilisateur voie le message
        await Future.delayed(const Duration(seconds: 1)); 
        if (mounted) {
            Navigator.pop(context, true); // Retourner true pour indiquer le succès
        }
      } else {
        // Le service de paiement devrait gérer les messages d'erreur spécifiques (ex: paiement refusé)
        // Si processPayment retourne false sans exception, c'est une erreur gérée (ex: annulé par user)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
                content: Text("Abonnement annulé ou non complété."),
                backgroundColor: Colors.orange,
             ),
          );
        }
      }
    } catch (e) {
      print("❌ Erreur lors de la souscription: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Erreur inattendue: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Réactiver les boutons même en cas d'erreur
       if (mounted) {
      setState(() {
             _isProcessing = false;
      });
    }
  }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Abonnement Premium"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
          opacity: _fadeAnimation, // Appliquer l'animation de fondu
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Bannière Héro
                      _buildHeroBanner(),
                      
                      const SizedBox(height: 24),
                      
                      // Cartes des Plans
                      // Récupérer les détails des plans depuis PaymentService
                      ...PaymentService.subscriptionTiers.entries.map((entry) {
                          final planId = entry.key;
                          final details = entry.value;
                          bool isRecommended = planId == 'pro'; // Mettre en avant le plan 'pro'
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildPlanCard(
                                plan: planId,
                                title: details['name'] as String? ?? planId.capitalize(),
                                price: details['price'] as int? ?? 0,
                                features: details['features'] as List<String>? ?? [],
                                isRecommended: isRecommended,
                                buttonText: details['buttonText'] as String?,
                                theme: theme,
                              ),
                          );
                      }).toList(),
                      
                      const SizedBox(height: 24),
                      
                      // Notice Paiement Sécurisé
                      _buildSecurePaymentNotice(theme),
                      
                      // Espace pour éviter que le contenu soit caché par l'indicateur de chargement
                      if (_isProcessing) const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              // Indicateur de chargement flottant
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               CircularProgressIndicator(color: Colors.deepPurple),
                               SizedBox(height: 16),
                               Text("Traitement en cours...", style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                    ),
                  ),
                ),
            ],
          ),
      ),
    );
  }
  
  // Widget pour la bannière Héro
  Widget _buildHeroBanner() {
    return Container(
        padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 10,
              offset: const Offset(0, 5),
          ),
        ],
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 24,
                  child: Icon(Icons.star, color: Colors.deepPurple.shade700, size: 30),
                ),
                const SizedBox(width: 16),
                const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Premium",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Choisissez le forfait adapté à vos besoins",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Paiement sécurisé via Stripe",
                    style: TextStyle(
        color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  // Widget pour une carte de plan d'abonnement
  Widget _buildPlanCard({
    required String plan,
    required String title,
    required int price,
    required List<String> features,
    required bool isRecommended,
    String? buttonText, // Texte optionnel pour le bouton
    required ThemeData theme,
  }) {
    final bool isFree = price == 0;
    
    return Stack(
      clipBehavior: Clip.none, // Permet au badge "Recommandé" de déborder
      children: [
        Container(
          decoration: BoxDecoration(
            color: isRecommended ? Colors.deepPurple.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecommended ? Colors.deepPurple : Colors.grey.shade300,
              width: isRecommended ? 2 : 1,
            ),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                     BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom du plan
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isRecommended ? Colors.deepPurple : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // Prix
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                  children: [
                        Text(
                    "${price}€",
                    style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                      color: isRecommended ? Colors.deepPurple : theme.colorScheme.onSurface,
                    ),
                  ),
                   if (!isFree)
                     const Text(
                       " / mois",
                          style: TextStyle(
                         fontSize: 16,
                         color: Colors.grey,
                         fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 16),
              // Liste des fonctionnalités
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                      color: isRecommended ? Colors.deepPurple : Colors.green.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                        feature,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
          // Bouton d'action
              SizedBox(
                width: double.infinity,
                  child: ElevatedButton(
                  // Désactiver le bouton si le traitement est en cours
                  onPressed: _isProcessing ? null : () => _subscribe(context, plan),
                    style: ElevatedButton.styleFrom(
                    backgroundColor: isFree 
                        ? Colors.grey.shade300
                        : (isRecommended ? Colors.deepPurple : Colors.purple.shade600),
                    foregroundColor: isFree ? Colors.black87 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: isRecommended ? 4 : 2,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  // Utiliser buttonText si fourni, sinon texte par défaut
                  child: Text(buttonText ?? (isFree ? "Plan Actuel" : "Choisir ce Plan")),
                ),
              ),
            ],
          ),
        ),
        // Badge "Recommandé"
        if (isRecommended)
          Positioned(
            top: -14,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: Offset(0, 2))]
              ),
              child: const Text(
                'Recommandé',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Widget pour la notice de paiement sécurisé
  Widget _buildSecurePaymentNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 12),
              Text(
                "Paiement Sécurisé",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Toutes les transactions sont traitées de manière sécurisée par Stripe. Vous pouvez gérer ou annuler votre abonnement à tout moment depuis votre profil.",
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// Extension pour capitaliser la première lettre d'une chaîne
extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return "";
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
} 