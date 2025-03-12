import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'screens/utils.dart' show getBaseUrl;
import 'theme/theme_manager.dart'; // Import du gestionnaire de thèmes
import 'services/auth_service.dart';
import 'screens/home_screen.dart'; // Page principale
import 'screens/profile_screen.dart'; // Profil utilisateur
import 'screens/map_screen.dart'; // Carte des restaurants
import 'screens/map_leisure_screen.dart'; // Carte des loisirs
import 'screens/producer_search_page.dart'; // Page Recherche Producteurs
import 'screens/copilot_screen.dart'; // Page Copilot
import 'screens/feed_screen.dart'; // Page Feed
import 'screens/producerLeisure_screen.dart'; // Producteurs de loisirs
import 'screens/eventLeisure_screen.dart'; // Événements loisirs
import 'screens/messaging_screen.dart'; // Page Messagerie
import 'screens/landing_page.dart';
import 'screens/register_user.dart';
import 'screens/recover_producer.dart';
import 'screens/login_user.dart'; // Import de la page de connexion
import 'screens/myprofile_screen.dart'; // Mon profil utilisateur
import 'screens/myproducerprofile_screen.dart'; // Mon profil producer (restauration)
import 'screens/myproducerleisureprofile_screen.dart'; // Mon profil producer (loisir)
import 'screens/producer_dashboard_ia.dart';
import 'screens/register_restaurant_producer.dart'; // Inscription producteur restaurant
import 'screens/register_leisure_producer.dart'; // Inscription producteur loisir

// ✅ Import Stripe UNIQUEMENT si ce n'est pas Web avec alias pour éviter les conflits
import 'package:flutter_stripe/flutter_stripe.dart' as stripe_pkg if (dart.library.html) 'dummy_stripe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AuthService
  final authService = AuthService();
  await authService.initializeAuth();

  // ✅ Initialiser Stripe SEULEMENT si ce n'est PAS le Web, en utilisant l'alias stripe_pkg
  if (!kIsWeb) {
    try {
      stripe_pkg.Stripe.publishableKey = "pk_test_51QmFfDLwsHOKmNitM0g9UclfHTAhpEz366Ko7ff0NjoDICwnxT6wi1W4yfC1YV9QhLQUFeRrc0xnwrpCK7OLhYRF00tOrudArz";
      await stripe_pkg.Stripe.instance.applySettings();
    } catch (e) {
      print("❌ Erreur d'initialisation Stripe : $e");
    }
  } else {
    print("⚠️ Stripe désactivé sur Web");
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => authService,
      child: const ChoiceApp(),
    ),
  );
}


class ChoiceApp extends StatefulWidget {
  const ChoiceApp({Key? key}) : super(key: key);

  @override
  State<ChoiceApp> createState() => _ChoiceAppState();
}

class _ChoiceAppState extends State<ChoiceApp> {
  // Contrôle du thème (clair/sombre)
  ThemeMode _themeMode = ThemeMode.light;

  // Méthode pour basculer entre les thèmes
  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light 
          ? ThemeMode.dark 
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return MaterialApp(
      title: 'Choice App',
      // Utilisation des thèmes définis dans ThemeManager
      theme: ThemeManager.lightTheme,     // Thème clair (style Instagram)
      darkTheme: ThemeManager.darkTheme,  // Thème sombre (style X/Twitter)
      themeMode: _themeMode,              // Mode de thème actuel
      debugShowCheckedModeBanner: false,
      home: authService.isAuthenticated
          ? MainNavigation(
              userId: authService.userId!,
              accountType: authService.accountType!,
              toggleTheme: toggleTheme,
            )
          : LandingPage(toggleTheme: toggleTheme),
      routes: {
        '/register': (context) => const RegisterUserPage(),
        '/recover': (context) => const RecoverProducerPage(),
        '/login': (context) => LoginUserPage(),
        '/register-restaurant': (context) => const RegisterRestaurantProducerPage(),
        '/register-leisure': (context) => const RegisterLeisureProducerPage(),
      },
    );
  }
}

class LandingPage extends StatefulWidget {
  final Function toggleTheme;
  
  const LandingPage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isRestaurantSelected = true;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Méthode pour rechercher les producteurs
  Future<void> _searchProducers(String query) async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);

      try {
        // Filtrer par type en fonction de l'onglet sélectionné
        final type = _isRestaurantSelected ? 'restaurant' : 'leisureProducer';
        final response = await http.get(
          Uri.parse('${getBaseUrl()}/api/unified/search?query=$query&type=$type'),
        );

        if (response.statusCode == 200) {
          final List<dynamic> results = json.decode(response.body);
          setState(() {
            _searchResults = results
                .where((item) => item['type'] == type)
                .map((item) => {
                      'id': item['_id'],
                      'name': item['name'] ?? item['intitulé'] ?? 'Sans nom',
                      'type': item['type'],
                      'address': item['address'] ?? item['adresse'] ?? 'Adresse non spécifiée',
                      'image': item['image'] ?? item['photo'] ?? item['photo_url'] ?? '',
                    })
                .toList()
                .cast<Map<String, dynamic>>();
          });
        }
      } catch (e) {
        print('Erreur de recherche: $e');
      } finally {
        setState(() => _isSearching = false);
      }
    });
  }

  // Méthode pour gérer la sélection d'un producteur
  void _handleProducerSelection(Map<String, dynamic> producer) {
    Navigator.pushNamed(
      context,
      '/recover',
      arguments: {'producerId': producer['id'], 'type': producer['type']},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = Colors.deepPurple;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with app logo and theme toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu,
                              color: Colors.deepPurple,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Choice App',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
                      onPressed: () => widget.toggleTheme(),
                      tooltip: isDarkMode ? 'Mode clair' : 'Mode sombre',
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),

                // Welcome message
                Text(
                  'Bienvenue !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous ou créez un compte pour découvrir les meilleurs restaurants et loisirs près de chez vous.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 40),

                // Connect as user card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person, color: Colors.blue),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Connexion en tant qu\'utilisateur',
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Connexion', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Pas encore inscrit ?', style: TextStyle(color: Colors.grey[600])),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: const Text('Créer un compte'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // Recover producer account card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.store, color: Colors.deepPurple),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Récupérez votre compte producer',
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Tab selector for restaurant vs leisure
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'Restauration'),
                              Tab(text: 'Loisir'),
                            ],
                            indicator: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey[700],
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            onTap: (index) {
                              setState(() {
                                _isRestaurantSelected = index == 0;
                              });
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Search field for producer name with results
                        Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (value) => _searchProducers(value),
                              decoration: InputDecoration(
                                hintText: _isRestaurantSelected 
                                  ? 'Rechercher un restaurant par nom...' 
                                  : 'Rechercher une activité de loisir par nom...',
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.deepPurple),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            if (_searchResults.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final result = _searchResults[index];
                                    return ListTile(
                                      leading: result['image'] != null && result['image'].toString().isNotEmpty
                                        ? CircleAvatar(
                                            backgroundImage: NetworkImage(result['image']),
                                            onBackgroundImageError: (_, __) {
                                              // Don't return anything from void function
                                              print("Error loading image");
                                            },
                                          )
                                        : CircleAvatar(
                                            backgroundColor: Colors.grey[200],
                                            child: Icon(
                                              result['type'] == 'restaurant' ? Icons.restaurant : Icons.sports,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      title: Text(result['name'] ?? 'Sans nom'),
                                      subtitle: Text(result['address'] ?? 'Adresse non spécifiée'),
                                      onTap: () => _handleProducerSelection(result),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.vpn_key),
                                    label: const Text('Récupérer avec ID'),
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/recover');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Create account button at the bottom (minimal)
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Show modal bottom sheet with account creation options
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _buildCreateAccountBottomSheet(context),
                      );
                    },
                    child: Text(
                      'Créer un nouveau compte',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build account type cards
  Widget _buildAccountTypeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Bottom sheet for account creation options
  Widget _buildCreateAccountBottomSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.account_circle, size: 28, color: Colors.deepPurple),
              SizedBox(width: 12),
              Text(
                'Créer un compte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez le type de compte que vous souhaitez créer :',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          // User account option
          _buildAccountTypeCard(
            context,
            icon: Icons.person,
            title: 'Compte Utilisateur',
            description: 'Pour découvrir restaurants et activités, suivre vos producteurs préférés.',
            color: Colors.blue,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register');
            },
          ),
          const SizedBox(height: 16),
          
          // Restaurant producer account option
          _buildAccountTypeCard(
            context,
            icon: Icons.restaurant,
            title: 'Compte Producteur Restauration',
            description: 'Pour gérer votre restaurant et promouvoir vos offres.',
            color: Colors.orange,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register-restaurant');
            },
          ),
          const SizedBox(height: 16),
          
          // Leisure producer account option
          _buildAccountTypeCard(
            context,
            icon: Icons.sports_volleyball,
            title: 'Compte Producteur Loisir',
            description: 'Pour gérer vos activités de loisir et attirer de nouveaux clients.',
            color: Colors.green,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register-leisure');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final String userId;
  final String accountType;
  final Function? toggleTheme; // Ajouter la fonction de bascule de thème

  const MainNavigation({
    Key? key, 
    required this.userId, 
    required this.accountType,
    this.toggleTheme,
  }) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _selectedIndex = 0; // Onglet actif
  bool _isLeisureMap = false; // État pour basculer entre les cartes
  late final List<Widget> _pages; // Pages principales

  @override
  void initState() {
    super.initState();
    // Add observer for app lifecycle events (background/foreground)
    WidgetsBinding.instance.addObserver(this);

    // Initialisation des pages en fonction du type de compte
    if (widget.accountType == 'user') {
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        const MapScreen(), // Carte des restaurants
        ProducerSearchPage(userId: widget.userId), // Page Recherche Producteurs
        CopilotScreen(userId: widget.userId), // Page Copilot
        MyProfileScreen(userId: widget.userId), // Mon profil utilisateur
      ];
    } else if (widget.accountType == 'RestaurantProducer') {
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        const MapScreen(), // Carte des restaurants
        ProducerSearchPage(userId: widget.userId), // Page Recherche Producteurs
        ProducerDashboardIaPage(userId: widget.userId), // Dashboard IA
        MyProducerProfileScreen(userId: widget.userId), // Mon profil producer (restauration)
      ];
    } else if (widget.accountType == 'LeisureProducer') {
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        const MapLeisureScreen(), // Carte des loisirs
        ProducerSearchPage(userId: widget.userId), // Page Recherche Producteurs
        CopilotScreen(userId: widget.userId), // Page Copilot
        MyProducerLeisureProfileScreen(userId: widget.userId), // Mon profil producer (loisir)
      ];
    } else {
      // Gestion du cas où le type de compte est invalide
      throw Exception('Type de compte inconnu : ${widget.accountType}');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app returns to foreground, validate the session
    if (state == AppLifecycleState.resumed) {
      final authService = Provider.of<AuthService>(context, listen: false);
      authService.validateSession();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  // Met à jour la page sélectionnée
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Bascule entre les cartes des restaurants et loisirs
  void _toggleMap(String mapType) {
    setState(() {
      _isLeisureMap = mapType == 'Loisirs';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (_selectedIndex != 1)
          ? AppBar(
              title: const Text('Choice App'),
              actions: [
                // Bouton de messagerie
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessagingScreen(userId: widget.userId),
                      ),
                    );
                  },
                ),
                // Bouton pour basculer le thème
                if (widget.toggleTheme != null)
                  IconButton(
                    icon: Icon(Theme.of(context).brightness == Brightness.dark 
                        ? Icons.wb_sunny 
                        : Icons.nightlight_round),
                    onPressed: () {
                      if (widget.toggleTheme != null) {
                        widget.toggleTheme!();
                      }
                    },
                  ),
                // Bouton de déconnexion
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    authService.logout().then((_) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => LandingPage(toggleTheme: widget.toggleTheme!),
                        ),
                        (route) => false,
                      );
                    });
                  },
                ),
              ],
            )
          : null, // Pas d'AppBar sur les pages de carte
      body: Stack(
        children: [
          _pages[_selectedIndex], // Affiche la page active
          if (_selectedIndex == 1) // Si l'utilisateur est sur la carte
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.9), // Utilise la couleur de carte du thème actuel
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true, // Permet au bouton de prendre toute la largeur disponible
                    value: _isLeisureMap ? 'Loisirs' : 'Restaurants',
                    items: const [
                      DropdownMenuItem(
                        value: 'Restaurants',
                        child: Text(
                          'Carte des Restaurants',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Loisirs',
                        child: Text(
                          'Carte des Loisirs',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _toggleMap(value);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                _isLeisureMap ? const MapLeisureScreen() : const MapScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Important pour afficher 5 éléments
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Cartes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Recherche',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_objects),
            label: 'Copilot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
