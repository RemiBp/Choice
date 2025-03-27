import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final String producerId;
  final bool isLeisureProducer;

  const SubscriptionScreen({
    Key? key, 
    required this.producerId, 
    required this.isLeisureProducer,
  }) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _selectedPlan = 'gratuit';
  bool _isProcessing = false;
  
  // Couleurs thématiques
  late Color _primaryColor;
  late Color _lightColor; 
  late Color _darkColor;

  @override
  void initState() {
    super.initState();
    
    // Définir les couleurs en fonction du type de producteur
    if (widget.isLeisureProducer) {
      // Violet pour les loisirs
      _primaryColor = Colors.deepPurple;
      _lightColor = Colors.deepPurple.shade100;
      _darkColor = Colors.deepPurple.shade700;
    } else {
      // Orange pour les restaurants
      _primaryColor = Colors.orange;
      _lightColor = Colors.orange.shade100;
      _darkColor = Colors.orange.shade700;
    }
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Abonnement Premium',
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Banner Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _lightColor,
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 64,
                      color: _primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Élevez votre expérience',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isLeisureProducer
                          ? 'Obtenez plus de visibilité pour votre lieu de loisirs'
                          : 'Obtenez plus de visibilité pour votre restaurant',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFeatureChip(Icons.bolt, 'Plus de visibilité'),
                        const SizedBox(width: 8),
                        _buildFeatureChip(Icons.analytics, 'Statistiques avancées'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFeatureChip(Icons.star, 'Badge Premium'),
                        const SizedBox(width: 8),
                        _buildFeatureChip(Icons.support_agent, 'Support prioritaire'),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Plan Cards
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildPlanCard(
                      plan: 'gratuit',
                      title: 'Gratuit',
                      price: 0,
                      features: PaymentService.subscriptionTiers['gratuit']!['features'] as List<String>,
                      isRecommended: false,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPlanCard(
                      plan: 'starter',
                      title: 'Starter',
                      price: 5,
                      features: PaymentService.subscriptionTiers['starter']!['features'] as List<String>,
                      isRecommended: false,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPlanCard(
                      plan: 'pro',
                      title: 'Pro',
                      price: 10,
                      features: PaymentService.subscriptionTiers['pro']!['features'] as List<String>,
                      isRecommended: true,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPlanCard(
                      plan: 'legend',
                      title: 'Legend',
                      price: 15,
                      features: PaymentService.subscriptionTiers['legend']!['features'] as List<String>,
                      isRecommended: false,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Payment Options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Méthodes de paiement acceptées',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _darkColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildPaymentMethod('assets/images/visa.png', 'Visa'),
                              _buildPaymentMethod('assets/images/mastercard.png', 'Mastercard'),
                              _buildPaymentMethod('assets/images/applepay.png', 'Apple Pay'),
                              _buildPaymentMethod('assets/images/gpay.png', 'Google Pay'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Secure Payment Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Paiement sécurisé via Stripe',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Vos informations de paiement sont chiffrées et sécurisées. Vous pouvez annuler votre abonnement à tout moment.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _darkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String iconPath, String name) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Image.asset(
              iconPath,
              height: 24,
              errorBuilder: (context, error, stackTrace) => 
                Icon(Icons.credit_card, color: _primaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String plan,
    required String title,
    required int price,
    required List<String> features,
    required bool isRecommended,
  }) {
    final isSelected = _selectedPlan == plan;
    final isFreePlan = plan == 'gratuit';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Plan card
        Container(
          decoration: BoxDecoration(
            color: isSelected ? _lightColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor.withOpacity(0.2) : Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? _primaryColor : Colors.black,
                          ),
                        ),
                        Text(
                          isFreePlan ? 'Fonctionnalités de base' : 'Fonctionnalités avancées',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? _darkColor : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${price}€',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? _primaryColor : Colors.black,
                          ),
                        ),
                        Text(
                          '/mois',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? _darkColor : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Features list
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var feature in features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: isSelected ? _primaryColor : Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected ? _darkColor : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Subscribe button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _subscribe(context, plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? _primaryColor : Colors.grey[200],
                      foregroundColor: isSelected ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: isSelected ? 2 : 0,
                    ),
                    child: _isProcessing && _selectedPlan == plan
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isFreePlan ? 'Activer' : 'S\'abonner',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Recommended badge
        if (isRecommended)
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
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
        Navigator.pop(context);
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
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
} 