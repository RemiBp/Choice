import 'package:flutter/foundation.dart' show kIsWeb; // Pour détecter le Web
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/utils.dart';
import 'screens/home_screen.dart'; // Page principale
import 'screens/profile_screen.dart'; // Profil utilisateur
import 'screens/map_screen.dart'; // Carte des restaurants
import 'screens/map_leisure_screen.dart'; // Carte des loisirs
import 'screens/producer_search_page.dart'; // Page Découvrir (Recherche Producteurs)
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
import 'package:flutter_stripe/flutter_stripe.dart';
import 'screens/producer_dashboard_ia.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey = "pk_test_51QmFfDLwsHOKmNitM0g9UclfHTAhpEz366Ko7ff0NjoDICwnxT6wi1W4yfC1YV9QhLQUFeRrc0xnwrpCK7OLhYRF00tOrudArz"; // Remplace par ta clé Stripe
  runApp(const ChoiceApp());
} 

class ChoiceApp extends StatelessWidget {
  const ChoiceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Choice App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const LandingPage(), // Page d'accueil initiale
      routes: {
        '/register': (context) => const RegisterUserPage(),
        '/recover': (context) => const RecoverProducerPage(),
        '/login': (context) => LoginUserPage(), // Ajout de la route pour se connecter
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choice App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register'); // Navigue vers RegisterUserPage
              },
              child: const Text('Créer un compte utilisateur'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/recover'); // Navigue vers RecoverProducerPage
              },
              child: const Text('Récupérer un compte producer'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login'); // Navigue vers LoginUserPage
              },
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final String userId;
  final String accountType; // Ajout du type de compte

  const MainNavigation({Key? key, required this.userId, required this.accountType}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0; // Onglet actif
  bool _isLeisureMap = false; // État pour basculer entre les cartes
  late final List<Widget> _pages; // Pages principales

  @override
  void initState() {
    super.initState();

    // Initialisation des pages en fonction du type de compte
    if (widget.accountType == 'user') {
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        const MapScreen(), // Carte des restaurants
        ProducerSearchPage(userId: widget.userId), // Page Découvrir
        MyProfileScreen(userId: widget.userId), // Mon profil utilisateur
      ];
    } else if (widget.accountType == 'RestaurantProducer') {
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        const MapScreen(), // Carte des restaurants
        ProducerDashboardIaPage(userId: widget.userId),
        MyProducerProfileScreen(userId: widget.userId), // Mon profil producer (restauration)
      ];
    } else if (widget.accountType == 'LeisureProducer') {
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        const MapLeisureScreen(), // Carte des loisirs
        ProducerSearchPage(userId: widget.userId), // Page Découvrir
        MyProducerLeisureProfileScreen(userId: widget.userId), // Mon profil producer (loisir)
      ];
    } else {
      // Gestion du cas où le type de compte est invalide
      throw Exception('Type de compte inconnu : ${widget.accountType}');
    }
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
                    color: Colors.white.withOpacity(0.9), // Fond blanc semi-transparent
                    borderRadius: BorderRadius.circular(8), // Coins arrondis
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Découvrir',
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
