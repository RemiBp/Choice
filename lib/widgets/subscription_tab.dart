import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class SubscriptionTab extends StatefulWidget {
  final String producerId;
  final String currentSubscription;
  final Map<String, bool> premiumFeaturesAccess;

  const SubscriptionTab({
    Key? key,
    required this.producerId,
    required this.currentSubscription,
    required this.premiumFeaturesAccess,
  }) : super(key: key);

  @override
  State<SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<SubscriptionTab> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedPlan = '';
  
  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.currentSubscription;
    
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
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _subscribe(BuildContext context, String plan) async {
    setState(() {
      _isProcessing = true;
      _selectedPlan = plan;
    });

    try {
      bool success = await PaymentService.processPayment(context, plan, widget.producerId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Abonnement $plan réussi ! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Erreur lors du paiement. Réessayez."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Erreur : $e"),
          backgroundColor: Colors.orange,
        ),
      );
    }

    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isProcessing
      ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
      : FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bannière d'abonnement 
                  _buildSubscriptionBanner(),
                  const SizedBox(height: 20),
                  
                  // Section fonctionnalités premium
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.star, color: Colors.amber),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Fonctionnalités Premium',
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Grille de fonctionnalités premium
                          GridView.count(
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                            childAspectRatio: 3.0,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              _buildPremiumFeatureTeaser(
                                title: 'Analytics Avancés',
                                description: 'Obtenez des données détaillées sur vos clients et votre audience.',
                                featureId: 'advanced_analytics',
                                icon: Icons.analytics,
                                color: Colors.purple,
                              ),
                              _buildPremiumFeatureTeaser(
                                title: 'Placement Premium',
                                description: 'Apparaissez en haut des résultats de recherche et des recommandations.',
                                featureId: 'premium_placement',
                                icon: Icons.trending_up,
                                color: Colors.orange,
                              ),
                              _buildPremiumFeatureTeaser(
                                title: 'Menu Personnalisable',
                                description: 'Options avancées de personnalisation de votre menu avec photos et descriptions détaillées.',
                                featureId: 'customizable_menu',
                                icon: Icons.restaurant_menu,
                                color: Colors.teal,
                              ),
                              _buildPremiumFeatureTeaser(
                                title: 'Carte de Chaleur Détaillée',
                                description: 'Visualisez précisément les mouvements et préférences de vos clients.',
                                featureId: 'detailed_heatmap',
                                icon: Icons.map,
                                color: Colors.blue,
                              ),
                              _buildPremiumFeatureTeaser(
                                title: 'Outils Marketing',
                                description: 'Campagnes marketing avancées et automatisation des promotions.',
                                featureId: 'marketing_tools',
                                icon: Icons.campaign,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Plan Cards
                  _buildPlanCard(
                    plan: 'gratuit',
                    title: 'Gratuit',
                    price: 0,
                    features: _getFeatures('gratuit'),
                    isRecommended: false,
                    isCurrentPlan: widget.currentSubscription == 'gratuit',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildPlanCard(
                    plan: 'starter',
                    title: 'Starter',
                    price: 5,
                    features: _getFeatures('starter'),
                    isRecommended: false,
                    isCurrentPlan: widget.currentSubscription == 'starter',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildPlanCard(
                    plan: 'pro',
                    title: 'Pro',
                    price: 10,
                    features: _getFeatures('pro'),
                    isRecommended: true,
                    isCurrentPlan: widget.currentSubscription == 'pro',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildPlanCard(
                    plan: 'legend',
                    title: 'Legend',
                    price: 15,
                    features: _getFeatures('legend'),
                    isRecommended: false,
                    isCurrentPlan: widget.currentSubscription == 'legend',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Secure Payment Notice
                  Container(
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
                            Icon(Icons.security, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            const Text(
                              "Paiement sécurisé",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Toutes les transactions sont protégées et cryptées. Vous pouvez annuler votre abonnement à tout moment depuis votre profil.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  // Widget pour afficher la bannière d'abonnement
  Widget _buildSubscriptionBanner() {
    final Map<String, Color> levelColors = {
      'gratuit': Colors.grey,
      'starter': Colors.blue,
      'pro': Colors.indigo,
      'legend': Colors.amber.shade800,
    };
    
    final Map<String, IconData> levelIcons = {
      'gratuit': Icons.card_giftcard,
      'starter': Icons.star,
      'pro': Icons.verified,
      'legend': Icons.workspace_premium,
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColors[widget.currentSubscription]!.withOpacity(0.8),
            levelColors[widget.currentSubscription]!.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            levelIcons[widget.currentSubscription] ?? Icons.card_giftcard,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Abonnement ${widget.currentSubscription.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget pour afficher un teaser de fonctionnalité premium
  Widget _buildPremiumFeatureTeaser({
    required String title,
    required String description,
    required String featureId,
    required IconData icon,
    Color? color,
  }) {
    final bool hasAccess = widget.premiumFeaturesAccess[featureId] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: hasAccess ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: hasAccess ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasAccess ? Colors.green : (color ?? Colors.blue)).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: hasAccess ? Colors.green : (color ?? Colors.blue),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                hasAccess ? Icons.check_circle : Icons.lock,
                color: hasAccess ? Colors.green : Colors.grey,
                size: 18,
              ),
            ],
          ),
          if (!hasAccess) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showUpgradePrompt(featureId),
              style: TextButton.styleFrom(
                foregroundColor: color ?? Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(double.infinity, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: color ?? Colors.blue),
                ),
              ),
              child: const Text(
                'Débloquer',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _showUpgradePrompt(String featureId) {
    final requiredLevel = _getRequiredSubscriptionLevel(featureId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fonctionnalité Premium'),
        content: Text('Cette fonctionnalité nécessite un abonnement $requiredLevel ou supérieur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            onPressed: () {
              Navigator.pop(context);
              _subscribe(context, requiredLevel);
            },
            child: Text('Passer au niveau $requiredLevel'),
          ),
        ],
      ),
    );
  }
  
  String _getRequiredSubscriptionLevel(String featureId) {
    switch (featureId) {
      case 'advanced_analytics':
        return 'starter';
      case 'premium_placement':
        return 'starter';
      case 'customizable_menu':
        return 'pro';
      case 'detailed_heatmap':
        return 'pro';
      case 'marketing_tools':
        return 'legend';
      default:
        return 'starter';
    }
  }

  Widget _buildPlanCard({
    required String plan,
    required String title,
    required int price,
    required List<String> features,
    required bool isRecommended,
    required bool isCurrentPlan,
  }) {
    final isPro = plan == 'pro';
    final isGratuit = plan == 'gratuit';
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isCurrentPlan 
                ? Colors.blue.withOpacity(0.05) 
                : (isRecommended ? Colors.deepPurple.withOpacity(0.05) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrentPlan 
                  ? Colors.blue 
                  : (isRecommended ? Colors.deepPurple : Colors.grey.shade300),
              width: isCurrentPlan || isRecommended ? 2 : 1,
            ),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isCurrentPlan ? Colors.blue : (isRecommended ? Colors.deepPurple : Colors.black87),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$price€",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isCurrentPlan ? Colors.blue : (isRecommended ? Colors.deepPurple : Colors.black),
                    ),
                  ),
                  const Text(
                    "/mois",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: isRecommended ? Colors.deepPurple : Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isCurrentPlan 
                      ? null 
                      : () => _subscribe(context, plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isGratuit 
                        ? Colors.grey.shade200 
                        : (isRecommended ? Colors.deepPurple : Colors.purple.shade600),
                    foregroundColor: isGratuit ? Colors.black87 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    disabledBackgroundColor: Colors.blue.shade300,
                    disabledForegroundColor: Colors.white,
                  ),
                  child: Text(isCurrentPlan ? "Abonnement actuel" : "S'abonner"),
                ),
              ),
            ],
          ),
        ),
        if (isRecommended)
          Positioned(
            top: -12,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
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
        if (isCurrentPlan)
          Positioned(
            top: -12,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Actuel',
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
  
  List<String> _getFeatures(String plan) {
    switch (plan) {
      case 'gratuit':
        return [
          'Menu de base',
          'Gestion des avis clients',
          'Profil d\'établissement',
          'Position sur la carte',
        ];
      case 'starter':
        return [
          'Menu de base',
          'Gestion des avis clients',
          'Profil d\'établissement',
          'Position sur la carte',
          'Analytics de base',
          'Placement préférentiel',
        ];
      case 'pro':
        return [
          'Menu personnalisable',
          'Gestion avancée des avis',
          'Profil d\'établissement amélioré',
          'Position prioritaire sur la carte',
          'Analytics avancés',
          'Carte de chaleur détaillée',
          'Placement préférentiel',
          'Données clients détaillées',
        ];
      case 'legend':
        return [
          'Menu entièrement personnalisable',
          'Gestion premium des avis',
          'Profil d\'établissement exclusif',
          'Position prioritaire sur la carte',
          'Analytics avancés',
          'Carte de chaleur détaillée',
          'Placement premium',
          'Données clients détaillées',
          'Outils marketing avancés',
          'Support client dédié',
        ];
      default:
        return [];
    }
  }
} 