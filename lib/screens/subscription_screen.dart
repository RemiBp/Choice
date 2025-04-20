import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart' as constants;
import '../services/payment_service.dart';
import '../widgets/custom_snackbar.dart';
import 'dart:async';
import 'package:flutter_stripe/flutter_stripe.dart' if (dart.library.html) '../dummy_stripe.dart';

class SubscriptionScreen extends StatefulWidget {
  final String producerId;
  final String? highlightedLevel;

  const SubscriptionScreen({
    Key? key, 
    required this.producerId, 
    this.highlightedLevel,
  }) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  String _currentSubscription = 'gratuit';
  Map<String, dynamic> _subscriptionData = {};
  Map<String, List<Map<String, dynamic>>> _featuresByLevel = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AuthService _authServiceInstance;
  
  // Couleurs pour chaque niveau d'abonnement
  final Map<String, Color> _levelColors = {
    'gratuit': Colors.grey,
    'starter': Colors.blue,
    'pro': Colors.indigo,
    'legend': Colors.amber.shade800,
  };
  
  // Icônes pour chaque niveau d'abonnement
  final Map<String, IconData> _levelIcons = {
    'gratuit': Icons.card_giftcard,
    'starter': Icons.star,
    'pro': Icons.verified,
    'legend': Icons.workspace_premium,
  };

  @override
  void initState() {
    super.initState();
    _authServiceInstance = Provider.of<AuthService>(context, listen: false);
    _loadSubscriptionData();
    
    // Configuration de l'animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Démarrer l'animation après le chargement de la page
    Future.delayed(const Duration(milliseconds: 100), () {
    _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Récupérer l'abonnement actuel du producteur
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/producer/${widget.producerId}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _subscriptionData = data;
          _currentSubscription = data['subscription']?['level'] ?? 'gratuit';
        });
      }
      
      // Récupérer les fonctionnalités par niveau d'abonnement
      await _loadFeaturesForLevel('gratuit');
      await _loadFeaturesForLevel('starter');
      await _loadFeaturesForLevel('pro');
      await _loadFeaturesForLevel('legend');
      
      // Si un niveau est mis en évidence, faire défiler jusqu'à ce niveau
      if (widget.highlightedLevel != null) {
        // Légèrement décalé pour permettre au widget d'être construit
        Future.delayed(const Duration(milliseconds: 500), () {
          _scrollToLevel(widget.highlightedLevel!);
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des données d\'abonnement: $e');
      showCustomSnackBar(
        context,
        message: 'Impossible de charger les données d\'abonnement',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Méthode pour faire défiler jusqu'à un niveau d'abonnement
  void _scrollToLevel(String level) {
    final Map<String, int> levelIndices = {
      'gratuit': 0,
      'starter': 1,
      'pro': 2,
      'legend': 3,
    };
    
    final index = levelIndices[level] ?? 0;
    
    if (_scrollController.hasClients) {
      // Calculer la position approximative
      final itemHeight = 400.0; // Hauteur approximative d'une carte
      final targetPosition = itemHeight * index;
      
      _scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _loadFeaturesForLevel(String level) async {
    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/features/$level'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _featuresByLevel[level] = List<Map<String, dynamic>>.from(data['features']);
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des fonctionnalités pour $level: $e');
    }
  }
  
  Future<void> _upgradeSubscription(String newLevel) async {
    // --- Added Authentication Check ---
    if (!_authServiceInstance.isAuthenticated || _authServiceInstance.userId == null) {
      showCustomSnackBar(
        context,
        message: 'Session invalide. Veuillez vous reconnecter.',
        isError: true,
      );
      // Optional: Navigate back to login or home
      // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }
    // --- End Check ---

    if (_currentSubscription == newLevel) {
      showCustomSnackBar(
        context,
        message: 'Vous êtes déjà abonné à ce niveau',
        isError: true,
      );
      return;
    }
    
    // Si le nouveau niveau est gratuit, pas besoin de paiement
    if (newLevel == 'gratuit') {
      await _downgradeToFree();
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final auth = _authServiceInstance;
      final currentUserId = auth.userId;
      
      if (currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // --- Temporary Simplification for Testing --- 
      // TODO: Fetch actual user email and name from API (e.g., GET /api/users/me)
      // TODO: Fetch stripeCustomerId from user profile API call
      String? userEmail = "${currentUserId}@example.com"; // Temporary email
      String? userName = "Utilisateur $currentUserId"; // Temporary name
      String? stripeCustomerId = null; // Assume not available for now
      // --- End Temporary Simplification --- 

      // Create or retrieve Stripe customer
      String customerId = stripeCustomerId ?? '';
      
      if (customerId.isEmpty) {
        // Use temporary/placeholder email and name
        final customerResponse = await _paymentService.createCustomer(
          email: userEmail, 
          name: userName,
        );
        customerId = customerResponse['customerId'];
        
        // TODO: Implement backend route and frontend method to save stripeCustomerId
        // // Temporarily commented out:
        // await _authServiceInstance.updateStripeCustomerId(customerId);
        print("⚠️ TODO: Implement saving Stripe Customer ID ($customerId) to user profile.");
      }
      
      // Créer un intent de paiement pour l'abonnement
      final paymentIntentResponse = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/change-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'producerId': widget.producerId,
          'newSubscriptionLevel': newLevel,
          'customerId': customerId,
        }),
      );
      
      if (paymentIntentResponse.statusCode != 200) {
        throw Exception('Erreur lors de la création de l\'intent de paiement');
      }
      
      final paymentIntentData = json.decode(paymentIntentResponse.body);
      
      // Afficher la feuille de paiement Stripe
      if (Stripe != null) {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentData['clientSecret'],
            merchantDisplayName: 'Choice App',
            customerId: customerId,
            customerEphemeralKeySecret: paymentIntentData['ephemeralKey'],
            style: ThemeMode.system,
          ),
        );
        
        await Stripe.instance.presentPaymentSheet();
      } else {
        print("Stripe Payment Sheet not available on this platform.");
        showCustomSnackBar(context, message: "Le paiement Stripe n'est pas disponible sur cette plateforme.", isError: true);
        return;
      }
      
      // Vérifier le statut du paiement et mettre à jour l'interface
      await _loadSubscriptionData();
      
      // Afficher un message de succès et les nouvelles fonctionnalités
      _showUpgradedFeaturesDialog(newLevel);
      
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'abonnement: $e');
      showCustomSnackBar(
        context,
        message: 'Erreur lors du paiement. Veuillez réessayer.',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _downgradeToFree() async {
    // --- Added Authentication Check ---
    if (!_authServiceInstance.isAuthenticated || _authServiceInstance.userId == null) {
      showCustomSnackBar(
        context,
        message: 'Session invalide. Veuillez vous reconnecter.',
        isError: true,
      );
      // Optional: Navigate back to login or home
      return;
    }
    // --- End Check ---
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUserId = _authServiceInstance.userId;
      if (currentUserId == null) {
          throw Exception('Utilisateur non connecté pour downgrade');
      }
      // --- Temporary Simplification for Testing --- 
      // TODO: Fetch stripeCustomerId from user profile API call
      String? stripeCustomerIdForDowngrade = null; 
      // --- End Temporary Simplification --- 

      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/subscription/change-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'producerId': widget.producerId,
          'newSubscriptionLevel': 'gratuit',
          // Use temporary placeholder or empty string for customerId during downgrade test
          'customerId': stripeCustomerIdForDowngrade ?? '', 
        }),
      );
      
      if (response.statusCode == 200) {
        await _loadSubscriptionData();
        showCustomSnackBar(
          context,
          message: 'Votre abonnement a été rétrogradé au niveau gratuit',
          isError: false,
        );
      } else {
        throw Exception('Erreur lors de la rétrogradation de l\'abonnement');
      }
    } catch (e) {
      print('❌ Erreur lors de la rétrogradation de l\'abonnement: $e');
      showCustomSnackBar(
        context,
        message: 'Erreur lors de la mise à jour de l\'abonnement',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showUpgradedFeaturesDialog(String newLevel) {
    final newFeatures = _getNewFeatures(newLevel);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Félicitations !', style: TextStyle(color: _levelColors[newLevel]),),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_levelIcons[newLevel], color: _levelColors[newLevel]),
                  SizedBox(width: 8),
                  Text(
                    'Niveau ${newLevel.toUpperCase()} activé !',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _levelColors[newLevel],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text('Nouvelles fonctionnalités débloquées :'),
              SizedBox(height: 8),
              ...newFeatures.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(feature['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(feature['description'], style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
  
  List<Map<String, dynamic>> _getNewFeatures(String newLevel) {
    // Déterminer les nouvelles fonctionnalités en fonction du niveau actuel et du nouveau niveau
    final levels = ['gratuit', 'starter', 'pro', 'legend'];
    final currentIndex = levels.indexOf(_currentSubscription);
    final newIndex = levels.indexOf(newLevel);
    
    if (currentIndex >= newIndex) {
      return [];
    }
    
    List<Map<String, dynamic>> newFeatures = [];
    
    for (int i = currentIndex + 1; i <= newIndex; i++) {
      final level = levels[i];
      if (_featuresByLevel.containsKey(level)) {
        newFeatures.addAll(_featuresByLevel[level]!);
      }
    }
    
    return newFeatures;
  }
  
  // Controller pour le défilement
  final ScrollController _scrollController = ScrollController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Abonnements Premium'),
        elevation: 2,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurrentSubscriptionCard(),
                    SizedBox(height: 24),
                    _buildSectionHeader('Choisissez votre niveau d\'abonnement'),
                    SizedBox(height: 16),
                    
                    // Niveau Gratuit
                    _buildSubscriptionCard(
                      title: 'Gratuit',
                      price: '0',
                      level: 'gratuit',
                      features: _featuresByLevel['gratuit'] ?? [],
                      isCurrentPlan: _currentSubscription == 'gratuit',
                      isHighlighted: widget.highlightedLevel == 'gratuit',
                      onPressed: () => _upgradeSubscription('gratuit'),
                    ),
                    SizedBox(height: 16),
                    
                    // Niveau Starter
                    _buildSubscriptionCard(
                      title: 'Starter',
                      price: '19,99',
                      level: 'starter',
                      features: _getAllFeaturesUpToLevel('starter'),
                      isCurrentPlan: _currentSubscription == 'starter',
                      isHighlighted: widget.highlightedLevel == 'starter',
                      onPressed: () => _upgradeSubscription('starter'),
                    ),
                    SizedBox(height: 16),
                    
                    // Niveau Pro
                    _buildSubscriptionCard(
                      title: 'Pro',
                      price: '49,99',
                      level: 'pro',
                      features: _getAllFeaturesUpToLevel('pro'),
                      isCurrentPlan: _currentSubscription == 'pro',
                      isHighlighted: widget.highlightedLevel == 'pro',
                      onPressed: () => _upgradeSubscription('pro'),
                      recommended: true,
                    ),
                    SizedBox(height: 16),
                    
                    // Niveau Legend
                    _buildSubscriptionCard(
                      title: 'Legend',
                      price: '99,99',
                      level: 'legend',
                      features: _getAllFeaturesUpToLevel('legend'),
                      isCurrentPlan: _currentSubscription == 'legend',
                      isHighlighted: widget.highlightedLevel == 'legend',
                      onPressed: () => _upgradeSubscription('legend'),
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Informations légales
                    _buildLegalInfo(),
                  ],
                ),
              ),
            ),
    );
  }
  
  List<Map<String, dynamic>> _getAllFeaturesUpToLevel(String level) {
    final levels = ['gratuit', 'starter', 'pro', 'legend'];
    final targetIndex = levels.indexOf(level);
    
    List<Map<String, dynamic>> allFeatures = [];
    
    for (int i = 0; i <= targetIndex; i++) {
      final currentLevel = levels[i];
      if (_featuresByLevel.containsKey(currentLevel)) {
        allFeatures.addAll(_featuresByLevel[currentLevel]!);
      }
    }
    
    return allFeatures;
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Widget _buildCurrentSubscriptionCard() {
    final subscriptionEndDate = _subscriptionData['subscription']?['endDate'] != null
        ? DateTime.parse(_subscriptionData['subscription']['endDate'])
        : null;
    
    final bool isExpired = subscriptionEndDate != null && subscriptionEndDate.isBefore(DateTime.now());
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _levelColors[_currentSubscription]!.withOpacity(0.8),
            _levelColors[_currentSubscription]!.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _levelIcons[_currentSubscription] ?? Icons.card_giftcard,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Votre abonnement',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          if (isExpired)
                    Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Text(
                                'Expiré',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _currentSubscription.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
            SizedBox(height: 20),
            
            if (subscriptionEndDate != null && _currentSubscription != 'gratuit') ...[
              Divider(color: Colors.white.withOpacity(0.3)),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Prochain renouvellement',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${subscriptionEndDate.day}/${subscriptionEndDate.month}/${subscriptionEndDate.year}',
                    style: TextStyle(
        color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
          ),
        ],
      ),
            ],
            
            if (_currentSubscription != 'gratuit') ...[
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
                  OutlinedButton.icon(
                    onPressed: () => _downgradeToFree(),
                    icon: Icon(Icons.cancel, color: Colors.white),
                    label: Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _upgradeSubscription(_currentSubscription),
                    icon: Icon(Icons.refresh),
                    label: Text('Renouveler'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _levelColors[_currentSubscription],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
            ),
          ),
        ],
      ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required String title,
    required String price,
    required String level,
    required List<Map<String, dynamic>> features,
    required bool isCurrentPlan,
    required Function() onPressed,
    bool recommended = false,
    bool isHighlighted = false,
  }) {
    // Timer pour l'animation de surbrillance
    Timer? _highlightTimer;
    
    // Si la carte est mise en évidence, initier une animation de surbrillance
    if (isHighlighted && mounted) {
      // Annuler tout timer existant
      _highlightTimer?.cancel();
      
      // État pour suivre l'animation
      bool isAnimating = true;
      
      // Créer un controller pour l'animation
      AnimationController _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
      
      // Démarrer l'animation
      _pulseController.repeat(reverse: true);
      
      // Arrêter l'animation après 3 secondes
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _pulseController.stop();
          _pulseController.dispose();
        }
      });
    }
    
    Color cardColor = _levelColors[level]!.withOpacity(0.05);
    Color borderColor = _levelColors[level]!.withOpacity(isCurrentPlan ? 0.8 : 0.3);
    
    if (isHighlighted) {
      cardColor = _levelColors[level]!.withOpacity(0.1);
      borderColor = _levelColors[level]!;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
        color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
          color: borderColor,
          width: isHighlighted ? 2 : 1,
            ),
        boxShadow: isHighlighted ? [
                    BoxShadow(
            color: _levelColors[level]!.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // En-tête de la carte
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
              color: _levelColors[level]!.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
                  ),
                ),
                child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _levelIcons[level],
                      color: _levelColors[level],
                      size: 24,
                    ),
                    SizedBox(width: 12),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                        color: _levelColors[level],
                      ),
                    ),
                  ],
                ),
                if (recommended)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Text(
                      'Recommandé',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isCurrentPlan && !recommended)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Text(
                      'Actuel',
                          style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                          ),
                        ),
                      ],
                    ),
          ),
          
          // Prix
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
                      children: [
                        Text(
                  price == '0' ? 'GRATUIT' : '$price €',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                    color: _levelColors[level],
                          ),
                        ),
                if (price != '0')
                        Text(
                    ' /mois',
                          style: TextStyle(
                            fontSize: 14,
                      color: Colors.grey[700],
                          ),
                    ),
                  ],
                ),
              ),
              
          // Liste des fonctionnalités
              Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: features.map((feature) {
                final isNewFeature = feature['isNew'] == true;
                
                return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                        color: isNewFeature ? _levelColors[level] : Colors.green,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                            Expanded(
                              child: Text(
                                    feature['name'],
                                style: TextStyle(
                                      fontWeight: isNewFeature ? FontWeight.bold : FontWeight.normal,
                                      color: isNewFeature ? _levelColors[level] : null,
                                    ),
                                  ),
                                ),
                                if (isNewFeature)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _levelColors[level]!.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _levelColors[level]!),
                                    ),
                                    child: Text(
                                      'NOUVEAU',
                                      style: TextStyle(
                                        color: _levelColors[level],
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (feature['description'] != null && feature['description'].isNotEmpty)
                              Text(
                                feature['description'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  ),
                );
              }).toList(),
                ),
              ),
              
          // Bouton d'action
              Padding(
            padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
              onPressed: isCurrentPlan ? null : onPressed,
                    style: ElevatedButton.styleFrom(
                backgroundColor: _levelColors[level],
                foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 0),
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              ),
              child: Text(
                isCurrentPlan ? 'Abonnement actuel' : 'Choisir ce plan',
                style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
    );
  }
  
  Widget _buildLegalInfo() {
    return Center(
            child: Container(
        padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'Tous les abonnements sont mensuels et renouvelés automatiquement.\nVous pouvez annuler à tout moment.',
              textAlign: TextAlign.center,
                style: TextStyle(
                color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    // Afficher les conditions d'utilisation
                  },
                  child: Text(
                    'Conditions d\'utilisation',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Text('•', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    // Afficher la politique de confidentialité
                  },
                  child: Text(
                    'Politique de confidentialité',
                    style: TextStyle(fontSize: 12),
            ),
          ),
      ],
            ),
          ],
        ),
      ),
    );
  }

  // Méthode pour afficher une notification
  void showCustomSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
    int durationSeconds = 3,
  }) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
} 