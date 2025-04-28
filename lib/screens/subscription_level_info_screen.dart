import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/payment_service.dart';
import '../screens/subscription_screen.dart';
import 'dart:convert';

/// Écran d'information détaillée sur les niveaux d'abonnement
/// Montre les fonctionnalités et avantages de chaque niveau avec un design moderne
class SubscriptionLevelInfoScreen extends StatefulWidget {
  final String producerId;
  final String level;
  
  const SubscriptionLevelInfoScreen({
    Key? key,
    required this.producerId,
    required this.level,
  }) : super(key: key);

  @override
  _SubscriptionLevelInfoScreenState createState() => _SubscriptionLevelInfoScreenState();
}

class _SubscriptionLevelInfoScreenState extends State<SubscriptionLevelInfoScreen> 
    with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  
  Map<String, dynamic>? _levelInfo;
  List<dynamic> _features = [];
  bool _isLoading = true;
  String? _error;
  
  // Information sur les prix
  double _monthlyPrice = 0.0;
  double _yearlyPrice = 0.0;
  double _yearlyDiscount = 0.0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _loadLevelInfo();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadLevelInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Charger les infos du niveau d'abonnement
      final subscriptionLevels = await _paymentService.getSubscriptionLevels();
      
      // Trouver le niveau correspondant
      final levelData = subscriptionLevels.firstWhere(
        (level) => level['level'] == widget.level,
        orElse: () => {'level': widget.level, 'features': [], 'price': {}},
      );
      
      // Charger les fonctionnalités pour ce niveau
      final features = await _paymentService.getFeaturesForLevel(widget.level);
      
      setState(() {
        _levelInfo = levelData;
        _features = features;
        
        // Extraire les informations de prix
        if (_levelInfo != null && _levelInfo!.containsKey('price')) {
          final price = _levelInfo!['price'];
          _monthlyPrice = price['monthly']?.toDouble() ?? 0.0;
          _yearlyPrice = price['yearly']?.toDouble() ?? 0.0;
          
          // Calculer la réduction annuelle
          if (_monthlyPrice > 0) {
            _yearlyDiscount = 100 - ((_yearlyPrice / (_monthlyPrice * 12)) * 100);
          }
        }
        
        _isLoading = false;
      });
      
      // Démarrer l'animation après le chargement
      _animationController.forward();
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // Méthode pour obtenir la couleur associée au niveau d'abonnement
  Color _getLevelColor() {
    switch (widget.level.toLowerCase()) {
      case 'starter':
        return Colors.blue;
      case 'pro':
        return Colors.indigo;
      case 'legend':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }
  
  // Méthode pour obtenir l'icône associée au niveau d'abonnement
  IconData _getLevelIcon() {
    switch (widget.level.toLowerCase()) {
      case 'starter':
        return Icons.star;
      case 'pro':
        return Icons.verified;
      case 'legend':
        return Icons.workspace_premium;
      default:
        return Icons.card_membership;
    }
  }
  
  // Méthode pour obtenir le slogan du niveau d'abonnement
  String _getLevelSlogan() {
    switch (widget.level.toLowerCase()) {
      case 'starter':
        return "Lancez votre activité avec les outils essentiels";
      case 'pro':
        return "Optimisez votre croissance avec des outils avancés";
      case 'legend':
        return "Maximisez votre potentiel avec toutes les fonctionnalités";
      default:
        return "Découvrez nos abonnements premium";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final Color levelColor = _getLevelColor();
    final IconData levelIcon = _getLevelIcon();
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: levelColor,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Niveau ${widget.level.toUpperCase()}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Motif de fond
                  CustomPaint(
                    painter: BackgroundPatternPainter(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  // Icône du niveau
                  Positioned(
                    right: 30,
                    top: 60,
                    child: Icon(
                      levelIcon,
                      size: 80,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  // Gradient pour assurer la lisibilité du texte
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          levelColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  // Partager les informations du niveau
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fonctionnalité de partage à implémenter')),
                  );
                },
              ),
            ],
          ),
          
          if (_isLoading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: levelColor)),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Erreur lors du chargement des données',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(_error!),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadLevelInfo,
                      child: Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: levelColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Slogan du niveau
                      Text(
                        _getLevelSlogan(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: levelColor,
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Options de prix
                      _buildPricingOptions(levelColor),
                      SizedBox(height: 32),
                      
                      // Section des fonctionnalités
                      Text(
                        'Fonctionnalités incluses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildFeaturesList(levelColor),
                      SizedBox(height: 32),
                      
                      // Section des cas d'utilisation
                      Text(
                        'Idéal pour',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildUseCases(levelColor),
                      SizedBox(height: 32),
                      
                      // FAQ
                      Text(
                        'Questions fréquentes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildFAQ(),
                      SizedBox(height: 32),
                      
                      // Bouton de mise à niveau
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubscriptionScreen(
                                  producerId: widget.producerId,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: levelColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Souscrire maintenant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Texte de garantie de remboursement
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Garantie satisfait ou remboursé de 30 jours',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: '. Annulez facilement à tout moment.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPricingOptions(Color levelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carte de prix mensuel
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: levelColor),
                    SizedBox(width: 8),
                    Text(
                      'Mensuel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_monthlyPrice.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '/ mois',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Facturation mensuelle',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        
        // Carte de prix annuel
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: levelColor.withOpacity(0.5), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: levelColor),
                        SizedBox(width: 8),
                        Text(
                          'Annuel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: levelColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: levelColor),
                      ),
                      child: Text(
                        'ÉCONOMIE DE ${_yearlyDiscount.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(_yearlyPrice / 12).toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '/ mois',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Facturation annuelle de ${_yearlyPrice.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFeaturesList(Color levelColor) {
    if (_features.isEmpty) {
      return Center(
        child: Text(
          'Aucune fonctionnalité disponible',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    
    return Column(
      children: _features.map((feature) {
        final String name = feature['name'] ?? 'Fonctionnalité';
        final String description = feature['description'] ?? '';
        
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: levelColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildUseCases(Color levelColor) {
    // Liste des cas d'utilisation selon le niveau
    final List<Map<String, dynamic>> useCases = _getUseCases();
    
    return Column(
      children: useCases.map((useCase) {
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  useCase['icon'],
                  color: levelColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      useCase['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      useCase['description'],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  List<Map<String, dynamic>> _getUseCases() {
    switch (widget.level.toLowerCase()) {
      case 'starter':
        return [
          {
            'icon': Icons.restaurant,
            'title': 'Nouveaux restaurateurs',
            'description': 'Idéal pour les restaurateurs qui débutent et veulent augmenter leur visibilité'
          },
          {
            'icon': Icons.analytics_outlined,
            'title': 'Analyse de base',
            'description': 'Pour ceux qui souhaitent comprendre leurs performances et obtenir des insights'
          },
          {
            'icon': Icons.people_outline,
            'title': 'Petite clientèle',
            'description': 'Parfait pour fidéliser une clientèle locale et améliorer l\'engagement'
          },
        ];
      case 'pro':
        return [
          {
            'icon': Icons.trending_up,
            'title': 'Restaurants en croissance',
            'description': 'Pour les établissements qui cherchent à se développer et optimiser leur activité'
          },
          {
            'icon': Icons.campaign,
            'title': 'Marketing actif',
            'description': 'Pour lancer des campagnes marketing efficaces et ciblées'
          },
          {
            'icon': Icons.insights,
            'title': 'Analyse avancée',
            'description': 'Accès à des données démographiques et prédictives pour votre clientèle'
          },
        ];
      case 'legend':
        return [
          {
            'icon': Icons.star,
            'title': 'Restaurants établis',
            'description': 'Pour les établissements reconnus qui souhaitent maintenir leur leadership'
          },
          {
            'icon': Icons.location_city,
            'title': 'Chaînes de restaurants',
            'description': 'Idéal pour gérer plusieurs établissements avec des besoins marketing avancés'
          },
          {
            'icon': Icons.auto_graph,
            'title': 'Analyse personnalisée',
            'description': 'Accès à toutes les données analytiques et recommandations personnalisées'
          },
          {
            'icon': Icons.support_agent,
            'title': 'Support prioritaire',
            'description': 'Un accompagnement dédié pour maximiser votre réussite sur la plateforme'
          },
        ];
      default:
        return [
          {
            'icon': Icons.business,
            'title': 'Tous types d\'établissements',
            'description': 'Adapté à différentes tailles et types de restaurants selon vos besoins'
          },
        ];
    }
  }
  
  Widget _buildFAQ() {
    // Questions-réponses fréquentes selon le niveau
    final List<Map<String, String>> faqs = _getFAQs();
    
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: EdgeInsets.zero,
      expansionCallback: (index, isExpanded) {
        setState(() {
          faqs[index]['isExpanded'] = (!isExpanded).toString();
        });
      },
      children: faqs.map((faq) {
        bool isExpanded = faq['isExpanded'] == 'true';
        
        return ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(
                faq['question'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faq['answer'] ?? ''),
                SizedBox(height: 16),
              ],
            ),
          ),
          isExpanded: isExpanded,
          canTapOnHeader: true,
        );
      }).toList(),
    );
  }
  
  List<Map<String, String>> _getFAQs() {
    final List<Map<String, String>> commonFaqs = [
      {
        'question': 'Puis-je annuler mon abonnement à tout moment ?',
        'answer': 'Oui, vous pouvez annuler votre abonnement à tout moment. Si vous annulez, vous continuerez à avoir accès à toutes les fonctionnalités premium jusqu\'à la fin de votre période de facturation.',
        'isExpanded': 'false',
      },
      {
        'question': 'Comment fonctionne la facturation ?',
        'answer': 'Vous serez facturé au début de chaque période (mensuelle ou annuelle). Pour les abonnements annuels, vous réalisez une économie significative par rapport au tarif mensuel.',
        'isExpanded': 'false',
      },
      {
        'question': 'Puis-je changer de niveau d\'abonnement ?',
        'answer': 'Oui, vous pouvez passer à un niveau supérieur à tout moment. Lors d\'une mise à niveau, vous ne paierez que la différence de prix au prorata du temps restant de votre abonnement actuel.',
        'isExpanded': 'false',
      },
    ];
    
    // Ajouter des questions spécifiques selon le niveau
    switch (widget.level.toLowerCase()) {
      case 'starter':
        commonFaqs.add({
          'question': 'Quelles sont les limitations du niveau Starter ?',
          'answer': 'Le niveau Starter offre les fonctionnalités essentielles pour commencer, mais avec certaines limites sur les analyses avancées et les campagnes marketing. Vous pouvez passer au niveau Pro à tout moment pour débloquer plus de fonctionnalités.',
          'isExpanded': 'false',
        });
        break;
      case 'pro':
        commonFaqs.add({
          'question': 'Quelle est la différence entre Pro et Legend ?',
          'answer': 'Le niveau Pro offre la plupart des fonctionnalités avancées, tandis que Legend débloque toutes les fonctionnalités sans aucune limitation, y compris le support prioritaire et les recommandations personnalisées par IA.',
          'isExpanded': 'false',
        });
        break;
      case 'legend':
        commonFaqs.add({
          'question': 'Comment fonctionne le support prioritaire ?',
          'answer': 'En tant qu\'abonné Legend, vous bénéficiez d\'un accès prioritaire à notre équipe de support avec un temps de réponse garanti de moins de 4 heures pendant les heures de bureau, et un manager de compte dédié pour vous aider à maximiser votre présence sur la plateforme.',
          'isExpanded': 'false',
        });
        break;
    }
    
    return commonFaqs;
  }
}

/// Peintre personnalisé pour créer un motif de fond
class BackgroundPatternPainter extends CustomPainter {
  final Color color;
  
  BackgroundPatternPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Créer un motif géométrique de fond
    for (int i = 0; i < size.width; i += 20) {
      for (int j = 0; j < size.height; j += 20) {
        if ((i + j) % 40 == 0) {
          canvas.drawCircle(Offset(i.toDouble(), j.toDouble()), 3, paint);
        } else if ((i + j) % 40 == 20) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(i.toDouble(), j.toDouble()),
              width: 6,
              height: 6,
            ),
            paint,
          );
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
} 