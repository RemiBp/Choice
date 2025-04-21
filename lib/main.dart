import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Ajout de l'import pour LatLng
import 'theme/theme_manager.dart'; // Import du gestionnaire de thèmes
import 'services/auth_service.dart';
import 'screens/home_screen.dart'; // Page principale
import 'screens/profile_screen.dart'; // Profil utilisateur
import 'screens/map_restaurant_screen.dart' as restaurant;
import 'screens/map_leisure_screen.dart' as leisure;
import 'screens/map_wellness_screen.dart' as wellness;
import 'screens/map_friends_screen.dart' as friends_old; // Ancienne carte des amis
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
import 'screens/reset_password_screen.dart'; // Import de la page de réinitialisation de mot de passe
import 'screens/myprofile_screen.dart'; // Mon profil utilisateur
import 'screens/myproducerleisureprofile_screen.dart'; // Mon profil producer (loisir)
import 'screens/producer_dashboard_ia.dart';
import 'screens/restaurant_producer_feed_screen.dart'; // Feed pour producteurs restauration
import 'screens/leisure_producer_feed_screen.dart'; // Feed pour producteurs loisir
import 'screens/wellness_producer_feed_screen.dart'; // Feed pour producteurs bien-être
import 'screens/heatmap_screen.dart'; // Ancienne page de heatmap (pour historique)
import 'screens/producer_heatmap_screen.dart'; // Nouvelle page de heatmap optimisée pour producteurs
import 'screens/growth_and_reach_screen.dart'; // Nouvelle page de croissance
import 'screens/register_restaurant_producer.dart'; // Inscription producteur restaurant
import 'screens/register_leisure_producer.dart'; // Inscription producteur loisir
import 'screens/myproducerprofile_screen.dart'; // Page producer restauration
import 'screens/register_wellness_producer.dart';
import 'screens/wellness_profile_screen.dart';
import 'screens/wellness_list_screen.dart';
import 'screens/mywellness_producer_profile_screen.dart';
import 'screens/language_selection_screen.dart'; // Import de l'écran de sélection de langue
import 'screens/video_call_screen.dart';
import 'utils.dart' show getImageProvider;

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/producer_screen.dart';
// import 'screens/wellness_producer_screen.dart';
// import 'screens/profil_screen.dart';
import 'services/notification_service.dart';  // Importer le service de notifications
import 'models/user_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/constants.dart' as constants; // Import des constantes pour le test d'URL
import 'firebase_options.dart';  // Importer le nouveau fichier d'options Firebase
import 'package:shared_preferences/shared_preferences.dart';

// Import easy_localization
import 'package:easy_localization/easy_localization.dart';

// ✅ Import Stripe UNIQUEMENT si ce n'est pas Web avec alias pour éviter les conflits
import 'package:flutter_stripe/flutter_stripe.dart' as stripe_pkg if (dart.library.html) 'dummy_stripe.dart';

// Importer flutter_app_badger et contacts_service avec les noms standards
import 'package:flutter_app_badger/flutter_app_badger.dart' as badge;
import 'package:contacts_service/contacts_service.dart' as contacts;

import 'services/badge_service.dart';  // Importer notre nouveau service de badges
import 'services/analytics_service.dart';
import 'services/voice_recognition_service.dart';

// Importer les bibliothèques Flutter standard avec leurs noms originaux
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/location_tracking_service.dart'; // Import the new service
import 'package:flutter/material.dart';
import 'package:choice_app/services/notification_service.dart';
import 'utils.dart' show getImageProvider;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser EasyLocalization
  await EasyLocalization.ensureInitialized();
  
  // Test de la configuration d'URL
  try {
    print('\n========== DÉMARRAGE DE L\'APPLICATION ==========');
    constants.testUrlConfiguration(); // Tester la configuration des URLs
    print('===============================================\n');
  } catch (e) {
    print('❌ Erreur lors du test de configuration URL: $e');
  }
  
  // Initialiser Firebase avec les options correctes
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialisé avec succès");
  } catch (e) {
    print("⚠️ Erreur lors de l'initialisation de Firebase: $e");
  }
  
  // Essayer de charger les variables d'environnement avec traitement d'erreur
  try {
    // Essayer d'abord les fichiers dans assets/env
    bool envLoaded = false;
    
    // 1. Essayer d'abord le fichier production.env
    try {
      await dotenv.load(fileName: "assets/env/production.env");
      print("✅ Fichier d'environnement de production chargé avec succès");
      envLoaded = true;
    } catch (prodError) {
      print("⚠️ Le fichier production.env n'a pas pu être chargé: $prodError");
      
      // 2. Puis essayer default.env
      try {
        await dotenv.load(fileName: "assets/env/default.env");
        print("✅ Fichier d'environnement par défaut chargé avec succès");
        envLoaded = true;
      } catch (defaultError) {
        print("⚠️ Le fichier default.env n'a pas pu être chargé: $defaultError");
        
        // 3. Puis essayer le .env à la racine en dernier recours
        try {
          await dotenv.load(fileName: ".env");
          print("✅ Fichier .env chargé avec succès");
          envLoaded = true;
        } catch (rootError) {
          print("⚠️ Le fichier .env à la racine n'a pas pu être chargé: $rootError");
          // Aucun fichier trouvé, continuer vers les valeurs par défaut
        }
      }
    }
    
    // Si aucun fichier d'environnement n'a été chargé, lancer une exception
    if (!envLoaded) {
      throw Exception("Aucun fichier d'environnement n'a pu être chargé");
    }
  } catch (e) {
    print("⚠️ Erreur lors du chargement des fichiers d'environnement: $e");
    print("💡 Utilisation des valeurs codées en dur");
    
    // Définir des valeurs par défaut pour les variables critiques
    Map<String, String> defaultEnvValues = {
      'GOOGLE_MAPS_API_KEY': 'AIzaSyDRvEPM8JZ1Wpn_J6ku4c3r5LQIocFmzOE',
      'API_BASE_URL': 'https://api.choiceapp.fr',
      'WEBSOCKET_URL': 'wss://api.choiceapp.fr',
      'MONGO_URI': '', // Vide car utilisé uniquement côté serveur
      'JWT_SECRET': '', // Vide car utilisé uniquement côté serveur
      'STRIPE_SECRET_KEY': '', // Vide car utilisé uniquement côté serveur
      'OPENAI_API_KEY': '', // Vide car utilisé uniquement côté serveur
    };
    
    // Ajouter toutes les valeurs par défaut à l'environnement
    defaultEnvValues.forEach((key, value) {
      dotenv.env[key] = value;
      print("📍 Défini $key avec une valeur par défaut");
    });
    
    print("✅ Variables d'environnement configurées avec valeurs par défaut");
  }
  
  // Vérifier que les variables essentielles sont présentes
  var envVars = ['GOOGLE_MAPS_API_KEY', 'API_BASE_URL', 'WEBSOCKET_URL'];
  for (var varName in envVars) {
    if (dotenv.env[varName] == null || dotenv.env[varName]!.isEmpty) {
      print("❌ ERREUR: Variable d'environnement $varName manquante ou vide!");
    } else {
      print("✓ Variable d'environnement $varName présente");
    }
  }
  
  // Définir l'orientation du portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  NotificationService? notificationService;
  AuthService? authService;
  BadgeService? badgeService;
  AnalyticsService? analyticsService;
  VoiceRecognitionService? voiceRecognitionService;
  
  try {
    // Initialize AuthService
    authService = AuthService();
    await authService.initialize();
    
    // Initialize NotificationService
    notificationService = NotificationService();
    await notificationService.initialize();

    // ✅ Initialiser Stripe SEULEMENT si ce n'est PAS le Web, en utilisant l'alias stripe_pkg
    if (!kIsWeb) {
      try {
        stripe_pkg.Stripe.publishableKey = "pk_test_51QmFfDLwsHOKmNitM0g9UclfHTAhpEz366Ko7ff0NjoDICwnxT6wi1W4yfC1YV9QhLQUFeRrc0xnwrpCK7OLhYRF00tOrudArz";
        // Configurer Apple Pay pour iOS
        if (Platform.isIOS) {
          stripe_pkg.Stripe.merchantIdentifier = "merchant.fr.choiceapp.app";
          stripe_pkg.Stripe.urlScheme = "choiceapp";
          await stripe_pkg.Stripe.instance.applySettings();
          print("✅ Stripe initialisé avec support Apple Pay");
        } else {
          await stripe_pkg.Stripe.instance.applySettings();
          print("✅ Stripe initialisé sur Android");
        }
      } catch (e) {
        print("❌ Erreur d'initialisation Stripe : $e");
      }
    } else {
      print("⚠️ Stripe désactivé sur Web");
    }

    // Initialiser les services
    badgeService = BadgeService();
    await badgeService.initialize();
    
    analyticsService = AnalyticsService();
    await analyticsService.initialize();
    
    voiceRecognitionService = VoiceRecognitionService();
    await voiceRecognitionService.initialize();

    // Initialize notifications en utilisant la syntaxe adaptée à la version de flutter_local_notifications
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
        FlutterLocalNotificationsPlugin();
    
    final initSettings = InitializationSettings(
      android: AndroidInitializationSettings(),
      iOS: DarwinInitializationSettings(),
    );
    
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    
    // Request notification permissions sans alias
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  } catch (e) {
    print("⚠️ Erreur lors de l'initialisation des services: $e");
    // Créer des services par défaut si l'initialisation échoue
    if (authService == null) authService = AuthService();
    if (notificationService == null) notificationService = NotificationService();
    if (badgeService == null) badgeService = BadgeService();
    if (analyticsService == null) analyticsService = AnalyticsService();
    if (voiceRecognitionService == null) voiceRecognitionService = VoiceRecognitionService();
  }

  // Navigation automatique vers l'écran d'appel lors d'une notification d'appel
  NotificationService().onCallNotification = (callData) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      // Obtain current userId from AuthService
      final selfUserId = Provider.of<AuthService>(nav.context, listen: false).userId ?? '';
      // Use static open method to start the video call screen
      VideoCallScreen.open(
        nav.context,
        selfUserId: selfUserId,
        otherUserId: callData['from'],
        callId: callData['callId'],
        isCaller: false,
        isVideo: callData['isVideo'] ?? true,
      );
    }
  };

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es')
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      child: Builder(
        builder: (context) {
          try {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<UserModel>(create: (_) => UserModel()),
                ChangeNotifierProvider<AuthService>(create: (_) => authService!),
                Provider<NotificationService>(create: (_) => notificationService!),
                ChangeNotifierProvider(create: (_) => badgeService!),
                ChangeNotifierProvider(create: (context) => analyticsService!),
                ChangeNotifierProvider(create: (_) => voiceRecognitionService!),
              ],
              child: const ChoiceApp(),
            );
          } catch (e) {
            print("⚠️ Erreur lors de la création de l'application: $e");
            // Retourner une version simplifiée de l'application en cas d'erreur
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text("Une erreur est survenue: $e"),
                ),
              ),
            );
          }
        }
      ),
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
  final StreamController<double> _userProgressController = StreamController<double>();
  final AnalyticsService _analyticsService = AnalyticsService();
  final RouteObserver<PageRoute> analyticsRouteObserver = RouteObserver<PageRoute>();
  
  // Vérifier si c'est la première ouverture de l'application
  bool _isFirstLaunch = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }
  
  // Vérifier si c'est le premier lancement de l'application
  Future<void> _checkFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isFirstLaunch = !prefs.containsKey('has_selected_language');
        _isChecking = false;
      });
    } catch (e) {
      print("❌ Erreur lors de la vérification du premier lancement: $e");
      setState(() {
        _isFirstLaunch = false;
        _isChecking = false;
      });
    }
  }

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
    
    // Si c'est le premier lancement, afficher l'écran de sélection de langue
    if (_isChecking) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    if (_isFirstLaunch) {
      return MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: LanguageSelectionScreen(
          onLanguageSelected: () {
            setState(() {
              _isFirstLaunch = false;
            });
          },
        ),
      );
    }
    
    return MaterialApp(
      title: 'app_name'.tr(),
      // Utilisation des thèmes définis dans ThemeManager
      theme: ThemeManager.lightTheme,     // Thème clair (style Instagram)
      darkTheme: ThemeManager.darkTheme,  // Thème sombre (style X/Twitter)
      themeMode: _themeMode,              // Mode de thème actuel
      debugShowCheckedModeBanner: false,
      
      // Configuration pour easy_localization
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      
      navigatorKey: navigatorKey,
      home: authService.isAuthenticated && authService.userId != null && authService.accountType != null
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
        '/register-wellness': (context) => const RegisterWellnessProducerPage(),
        '/messaging': (context) {
          final authService = Provider.of<AuthService>(context, listen: false);
          return MessagingScreen(userId: authService.userId ?? '');
        },
        '/profile/me': (context) {
          final authService = Provider.of<AuthService>(context, listen: false);
          return MyProfileScreen(
            userId: authService.userId ?? '',
            isCurrentUser: true,
          );
        },
        '/map/restaurant': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          LatLng? initialPosition = args?['initialPosition'] as LatLng?;
          double? initialZoom = args?['initialZoom'] as double?;
          return restaurant.MapRestaurantScreen(
            initialPosition: initialPosition,
            initialZoom: initialZoom,
          );
        },
        '/map/leisure': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          LatLng? initialPosition = args?['initialPosition'] as LatLng?;
          double? initialZoom = args?['initialZoom'] as double?;
          return leisure.MapLeisureScreen(
            initialPosition: initialPosition,
            initialZoom: initialZoom,
          );
        },
        '/map/wellness': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          LatLng? initialPosition = args?['initialPosition'] as LatLng?;
          double? initialZoom = args?['initialZoom'] as double?;
          return wellness.MapWellnessScreen(
            initialPosition: initialPosition,
            initialZoom: initialZoom,
          );
        },
        '/map/friends': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] as String? ?? Provider.of<AuthService>(context, listen: false).userId;
          LatLng? initialPosition = args?['initialPosition'] as LatLng?;
          double? initialZoom = args?['initialZoom'] as double?;
          return friends_old.MapFriendsScreen(
            userId: userId,
            initialPosition: initialPosition,
            initialZoom: initialZoom,
          );
        },
      },
      onGenerateRoute: (settings) {
        // Gérer les routes dynamiques avec paramètres
        final uri = Uri.parse(settings.name!);
        
        // Route pour la réinitialisation de mot de passe
        if (uri.path == '/reset-password') {
          final token = uri.queryParameters['token'];
          if (token != null) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(token: token),
            );
          }
        }
        
        // Route pour les profils utilisateurs
        if (uri.path == '/profile') {
          // Extraire les paramètres de la route
          final userId = settings.arguments is Map 
              ? (settings.arguments as Map)['userId'] 
              : uri.queryParameters['userId'];
          final viewerId = settings.arguments is Map 
              ? (settings.arguments as Map)['viewerId'] 
              : uri.queryParameters['viewerId'];
              
          if (userId != null) {
            return MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userId: userId.toString(),
              ),
            );
          }
        }
        
        // Route pour les détails des producteurs de restaurant
        if (uri.pathSegments.length == 3 && 
            uri.pathSegments[0] == 'restaurant' && 
            uri.pathSegments[1] == 'details') {
          final producerId = uri.pathSegments[2];
          return MaterialPageRoute(
            builder: (context) => ProducerScreen(producerId: producerId),
          );
        }
        
        // Route pour les détails des producteurs de loisirs
        if (uri.pathSegments.length == 3 && 
            uri.pathSegments[0] == 'leisure' && 
            uri.pathSegments[1] == 'details') {
          final producerId = uri.pathSegments[2];
          return MaterialPageRoute(
            builder: (context) => ProducerScreen(
              producerId: producerId,
            ),
          );
        }
        
        // Route pour les détails des établissements de bien-être
        if (uri.pathSegments.length == 3 && 
            uri.pathSegments[0] == 'wellness' && 
            uri.pathSegments[1] == 'details') {
          final placeId = uri.pathSegments[2];
          return MaterialPageRoute(
            builder: (context) => WellnessProfileScreen(producerId: placeId),
          );
        }
        
        return null;
      },
      navigatorObservers: [
        analyticsRouteObserver,
      ],
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
  final TextEditingController _searchController = TextEditingController();
  String _producerType = 'restaurant'; // Type de producteur sélectionné (restaurant, leisureProducer, wellnessProducer)
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // Couleurs et icônes pour chaque type de compte
  final Map<String, Color> _typeColors = {
    'restaurant': Colors.orange,
    'leisureProducer': Colors.purple,
    'wellnessProducer': Colors.green,
  };
  
  final Map<String, IconData> _typeIcons = {
    'restaurant': Icons.restaurant,
    'leisureProducer': Icons.event_available,
    'wellnessProducer': Icons.spa_outlined,
  };

  final Map<String, String> _typeLabels = {
    'restaurant': 'Restauration',
    'leisureProducer': 'Loisir',
    'wellnessProducer': 'Bien-être',
  };

  @override
  void dispose() {
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
        // Filtrer par type en fonction du type sélectionné
        final response = await http.get(
          Uri.parse('${constants.getBaseUrl()}/api/unified/search?query=$query&type=$_producerType'),
        );

        if (response.statusCode == 200) {
          final List<dynamic> results = json.decode(response.body);
          setState(() {
            _searchResults = results
                .where((item) => item['type'] == _producerType)
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

  void _selectProducerType(String type) {
    setState(() {
      _producerType = type;
      _searchResults = [];
      _searchController.clear();
    });
  }

  // Gérer la sélection d'un producteur
  void _handleProducerSelection(Map<String, dynamic> producer) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await authService.loginWithId(producer['id']);
      
      if (response['success']) {
        // Redirection vers la page principale après connexion réussie
        Navigator.pushReplacement(
      context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userId: producer['id'],
              accountType: producer['type'] == 'restaurant' 
                ? 'RestaurantProducer' 
                : producer['type'] == 'leisureProducer'
                  ? 'LeisureProducer'
                  : 'WellnessProducer',
              toggleTheme: widget.toggleTheme,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de connexion: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                
                // Logo et titre
                Center(
                  child: Column(
                  children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 80,
                        errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.restaurant_menu, size: 80, color: Colors.blue),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                              'Choice App',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                        'Découvrez les meilleurs établissements près de chez vous',
                        textAlign: TextAlign.center,
                  style: TextStyle(
                          fontSize: 16,
                    color: Colors.grey[600],
                  ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),

                // SECTION 1: Récupérez votre compte professionnel
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre de section
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.store, color: Colors.deepPurple, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Récupérer son compte',
                                style: TextStyle(
                                fontSize: 18,
                                  fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Sélecteur de type avec cartes
                        Row(
                          children: [
                            for (final entry in _typeLabels.entries)
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _selectProducerType(entry.key),
                                  child: Card(
                                    elevation: _producerType == entry.key ? 4 : 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: _producerType == entry.key 
                                          ? _typeColors[entry.key]! 
                                          : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                  child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                                          Icon(
                                            _typeIcons[entry.key], 
                                            color: _producerType == entry.key 
                                              ? _typeColors[entry.key]
                                              : Colors.grey,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            entry.value,
                                style: TextStyle(
                                              fontWeight: _producerType == entry.key 
                                                ? FontWeight.bold 
                                                : FontWeight.normal,
                                              color: _producerType == entry.key 
                                                ? _typeColors[entry.key]
                                                : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                            
                            TextField(
                              controller: _searchController,
                              onChanged: (value) => _searchProducers(value),
                              decoration: InputDecoration(
                            hintText: 'Rechercher par nom...',
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _typeColors[_producerType]!),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                        
                            if (_searchResults.isNotEmpty)
                              Container(
                            margin: const EdgeInsets.only(top: 16),
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
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
                                            backgroundImage: getImageProvider(result['image']) ?? const AssetImage('assets/images/default_image.png'),
                                            child: getImageProvider(result['image']) == null ? Icon(Icons.place, color: Colors.grey[400]) : null,
                                          )
                                        : CircleAvatar(
                                            backgroundColor: Colors.grey[200],
                                            child: Icon(
                                          _typeIcons[result['type']] ?? Icons.business,
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
                        
                        // Bouton de récupération avec ID
                        ElevatedButton.icon(
                                    icon: const Icon(Icons.vpn_key),
                          label: const Text('Récupérer'),
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/recover');
                                    },
                                    style: ElevatedButton.styleFrom(
                            backgroundColor: _typeColors[_producerType],
                                      foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                                      ),
                            minimumSize: const Size(double.infinity, 0),
                                  ),
                                ),
                              ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // SECTION 2: Connexion en tant qu'utilisateur
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person, color: Colors.blue, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Connexion en tant qu\'utilisateur',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                            ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Se connecter'),
                              onPressed: () {
                            Navigator.pushNamed(context, '/login');
                              },
                              style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                                ),
                            minimumSize: const Size(double.infinity, 0),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // SECTION 3: Bouton Créer un compte
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Créer un compte'),
                    onPressed: () {
                      _showCreateAccountOptions(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateAccountOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24.0),
          children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Titre
                const Text(
                'Créer un compte',
                style: TextStyle(
                    fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
                const SizedBox(height: 16),
          Text(
            'Choisissez le type de compte que vous souhaitez créer :',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
                const SizedBox(height: 32),
          
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
                const SizedBox(height: 20),
          
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
                const SizedBox(height: 20),
          
          // Leisure producer account option
          _buildAccountTypeCard(
            context,
            icon: Icons.sports_volleyball,
            title: 'Compte Producteur Loisir',
            description: 'Pour gérer vos activités de loisir et attirer de nouveaux clients.',
            color: Colors.purple,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register-leisure');
            },
          ),
                const SizedBox(height: 20),
          
          // Wellness producer account option
          _buildAccountTypeCard(
            context,
            icon: Icons.spa,
            title: 'Compte Producteur Bien-être',
            description: 'Pour gérer votre activité de bien-être et toucher de nouveaux clients.',
            color: Colors.green,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register-wellness');
            },
          ),
          const SizedBox(height: 24),
        ],
            ),
          );
        },
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
  String _mapType = 'restaurant'; // État pour basculer entre les cartes ('restaurant', 'leisure', 'wellness', 'friends')
  late final List<Widget> _pages; // Pages principales
  bool _pagesInitialized = false;
  
  // Méthode pour changer le type de carte depuis l'extérieur (utilisé par les écrans de carte)
  void changeMapType(String mapType) {
    if (_mapType != mapType) {
      setState(() {
        _mapType = mapType;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Add observer for app lifecycle events (background/foreground)
    WidgetsBinding.instance.addObserver(this);
    
    // Set initial tab index: 0 for all users to start on feed
    // Producers will see the producer feed, users will see user feed
    _selectedIndex = 0; // Démarrer sur le feed pour tous les utilisateurs

    try {
      _initializePages();
      _pagesInitialized = true;
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des pages: $e');
      _pagesInitialized = false;
      // Nous gérerons l'erreur dans le build
    }
  }

  // Méthode séparée pour initialiser les pages pour une meilleure gestion des erreurs
  void _initializePages() {
    // Initialisation des pages en fonction du type de compte
    if (widget.accountType == 'user') {
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        _buildMapPage(), // Page carte (restaurant, loisir ou amis)
        ProducerSearchPage(userId: widget.userId), // Page Recherche Producteurs
        CopilotScreen(userId: widget.userId), // Page Copilot
        MyProfileScreen(userId: widget.userId), // Mon profil utilisateur
      ];
    } else if (widget.accountType == 'RestaurantProducer') {
      _pages = [
        RestaurantProducerFeedScreen(userId: widget.userId), // Feed spécifique restaurant
        ProducerHeatmapScreen(producerId: widget.userId), // Carte heatmap des utilisateurs (NOUVEAU)
        ProducerDashboardIaPage(userId: widget.userId), // Copilot IA
        GrowthAndReachScreen(producerId: widget.userId), // Croissance & Rayonnement
        MyProducerProfileScreen(userId: widget.userId), // Mon profil producer (restauration)
      ];
    } else if (widget.accountType == 'LeisureProducer') {
      _pages = [
        LeisureProducerFeedScreen(userId: widget.userId), // Feed spécifique loisir
        ProducerHeatmapScreen(producerId: widget.userId), // Carte heatmap des utilisateurs (NOUVEAU)
        ProducerDashboardIaPage(userId: widget.userId), // Copilot IA
        GrowthAndReachScreen(producerId: widget.userId), // Croissance & Rayonnement
        MyProducerLeisureProfileScreen(userId: widget.userId), // Mon profil producer (loisir)
      ];
    } else if (widget.accountType == 'WellnessProducer') {
      _pages = [
        WellnessProducerFeedScreen(
          userId: widget.userId,
          producerId: widget.userId, // Utiliser userId comme producerId par défaut
        ),
        ProducerHeatmapScreen(producerId: widget.userId), // Carte heatmap des utilisateurs (NOUVEAU)
        ProducerDashboardIaPage(userId: widget.userId), // Copilot IA
        GrowthAndReachScreen(producerId: widget.userId), // Croissance & Rayonnement
        MyWellnessProducerProfileScreen(producerId: widget.userId), // Mon profil producer (bien-être)
      ];
    } else if (widget.accountType == 'guest') {
      // Configuration pour les utilisateurs invités (similaire aux utilisateurs normaux)
      _pages = [
        FeedScreen(userId: widget.userId), // Page Feed
        const restaurant.MapRestaurantScreen(), // Carte des restaurants
        ProducerSearchPage(userId: widget.userId), // Page Recherche Producteurs
        CopilotScreen(userId: widget.userId), // Page Copilot
        MyProfileScreen(userId: widget.userId), // Mon profil utilisateur
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

  // Bascule entre les différentes cartes
  void _toggleMap(String mapType) {
    setState(() {
      _mapType = mapType;
    });
  }

  // Construit la page de carte appropriée en fonction du type sélectionné
  Widget _buildMapPage() {
    Widget mapWidget;
    
    switch (_mapType) {
      case 'leisure':
        mapWidget = const leisure.MapLeisureScreen();
        break;
      case 'wellness':
        mapWidget = const wellness.MapWellnessScreen();
        break;
      case 'friends':
        // Nous utilisons toujours le même écran, en passant le user ID
        mapWidget = friends_old.MapFriendsScreen(userId: widget.userId);
        break;
      case 'restaurant':
      default:
        mapWidget = const restaurant.MapRestaurantScreen();
        break;
    }
    
    // Encapsuler dans un conteneur pour maintenir les dimensions cohérentes
    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints.expand(),
      child: mapWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gestion d'erreur - si les pages n'ont pas été initialisées
    if (!_pagesInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Une erreur est survenue lors du chargement de l\'application',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  try {
                    _initializePages();
                    _pagesInitialized = true;
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    // For user accounts, select the map type on tab 1
    // For producer accounts, always use the pages array (which includes HeatmapScreen for tab 1)
    Widget body;
    
    try {
      if (widget.accountType == 'user' || widget.accountType == 'guest') {
        // For users, use the map page builder for tab 1
        body = _selectedIndex == 1 ? _buildMapPage() : _pages[_selectedIndex];
      } else {
        // For producers, always use the pages array directly
        body = _pages[_selectedIndex];
      }
    } catch (e) {
      print('❌ Erreur lors de la construction du corps: $e');
      // En cas d'erreur, afficher un message
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Erreur lors du chargement de la page: $e',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {}); // Force refresh
              },
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }
    
    return Scaffold(
      body: body, // Affiche la page active
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Important pour afficher 5 éléments
        items: widget.accountType == 'RestaurantProducer' || 
               widget.accountType == 'LeisureProducer' || 
               widget.accountType == 'WellnessProducer'
          ? const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Feed',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Heatmap',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_objects),
                label: 'Copilot',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.trending_up),
                label: 'Croissance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profil',
              ),
            ]
          : const [
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

/// Observateur pour suivre les changements de route dans les analytics
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService analyticsService;
  final GlobalKey<NavigatorState> navigatorKey;

  AnalyticsRouteObserver(this.analyticsService, this.navigatorKey);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _sendAnalytics(
        route.settings.name, 
        previousRoute?.settings.name,
      );
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _sendAnalytics(
        newRoute.settings.name, 
        oldRoute?.settings.name,
      );
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute && route is PageRoute) {
      _sendAnalytics(
        previousRoute.settings.name, 
        route.settings.name,
      );
    }
  }

  void _sendAnalytics(String? routeName, String? previousRouteName) {
    if (routeName == null) return;
    
    // Get analytics service
    final navigatorContext = navigatorKey.currentContext;
    if (navigatorContext == null) return;
    
    final analyticsService = Provider.of<AnalyticsService>(
      navigatorContext, 
      listen: false
    );
    
    analyticsService.logNavigation('Main Navigation');
  }
}

// Ajouter une méthode d'extension sur BuildContext pour accéder à _MainNavigationState
// Cette extension doit être placée en dehors de toute classe, au niveau du fichier
extension NavigationHelper on BuildContext {
  _MainNavigationState? findMainNavigationState() {
    return this.findAncestorStateOfType<_MainNavigationState>();
  }
  
  // Méthode publique pour changer le type de carte
  void changeMapType(String mapType) {
    final state = findMainNavigationState();
    if (state != null) {
      state.changeMapType(mapType);
    }
  }
}

