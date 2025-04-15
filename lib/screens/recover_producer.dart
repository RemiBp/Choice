import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../main.dart';
import 'utils.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class RecoverProducerPage extends StatefulWidget {
  const RecoverProducerPage({Key? key}) : super(key: key);

  @override
  _RecoverProducerPageState createState() => _RecoverProducerPageState();
}

class _RecoverProducerPageState extends State<RecoverProducerPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _producerIdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  // Contrôleurs pour le formulaire de vérification d'identité
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _justificationController = TextEditingController();
  
  bool _isLoading = false;
  bool _showVerificationForm = false;
  TabController? _tabController;
  int _selectedTabIndex = 0;
  final ImagePicker _picker = ImagePicker();
  File? _verificationImage;
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // Variables pour stocker les données du producteur sélectionné
  String? _selectedPlaceId;
  Map<String, dynamic> _selectedProducer = {};

  // Couleurs pour les différents types de producteurs
  final Map<int, Color> _tabColors = {
    0: Colors.orange,   // Restaurant
    1: Colors.purple,   // Loisir
    2: Colors.green,    // Wellness
  };

  // Icônes pour les différents types de producteurs
  final Map<int, IconData> _tabIcons = {
    0: Icons.restaurant,   // Restaurant
    1: Icons.sports_volleyball,   // Loisir
    2: Icons.spa,        // Wellness
  };

  // Noms des types de producteurs
  final Map<int, String> _tabNames = {
    0: 'Restaurant',
    1: 'Loisir & Culture',
    2: 'Bien-être',
  };

  // Préfixes d'ID pour suggestion
  final Map<int, String> _idPrefixes = {
    0: '675',
    1: '676',
    2: '67b',
  };

  // Types d'API pour les recherches
  final Map<int, String> _apiTypes = {
    0: 'restaurant',
    1: 'leisureProducer',
    2: 'wellnessProducer',
  };

  // Getter pour la couleur actuelle
  Color get _currentColor => _tabColors[_selectedTabIndex] ?? Colors.orange;
  
  // Getter pour l'icône actuelle
  IconData get _currentIcon => _tabIcons[_selectedTabIndex] ?? Icons.restaurant;
  
  // Getter pour le nom du type actuel
  String get _currentTabName => _tabNames[_selectedTabIndex] ?? 'Restaurant';
  
  // Getter pour le préfixe d'ID
  String get _currentIdPrefix => _idPrefixes[_selectedTabIndex] ?? '675';
  
  // Getter pour le type d'API
  String get _currentApiType => _apiTypes[_selectedTabIndex] ?? 'restaurant';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController!.index;
        // Vider les résultats de recherche quand on change d'onglet
        _searchResults = [];
        if (_searchController.text.isNotEmpty) {
          _searchProducers(_searchController.text);
        }
      });
    });
    
    // Check if we received info from landing page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        // If we have a producer ID, set it directly
        if (args.containsKey('producerId')) {
          _producerIdController.text = args['producerId'].toString();
          // If we know the type, select the appropriate tab
          if (args.containsKey('type')) {
            final type = args['type'].toString();
            setState(() {
              if (type == 'restaurant') {
                _selectedTabIndex = 0;
                _tabController?.animateTo(0);
              } else if (type == 'leisureProducer') {
                _selectedTabIndex = 1;
                _tabController?.animateTo(1);
              } else if (type == 'wellnessProducer') {
                _selectedTabIndex = 2;
                _tabController?.animateTo(2);
              }
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _producerIdController.dispose();
    _searchController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _positionController.dispose();
    _justificationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Détermine le type de compte en fonction du préfixe de l'ID.
  String _determineAccountType(String producerId) {
    if (producerId.startsWith('675')) {
      return 'RestaurantProducer';
    } else if (producerId.startsWith('676')) {
      return 'LeisureProducer';
    } else if (producerId.startsWith('67b')) {
      return 'WellnessProducer';
    } else {
      if (_selectedTabIndex == 0) {
        return 'RestaurantProducer';
      } else if (_selectedTabIndex == 1) {
        return 'LeisureProducer';
      } else {
        return 'WellnessProducer';
      }
    }
  }

  // Search for producers with debounce
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
        // Await getBaseUrl() before using it
        final baseUrl = await getBaseUrl(); 
        final apiUrl = '$baseUrl/api/unified/search?query=$query&type=$_currentApiType';
        print('🔍 Recherche: $apiUrl');
        
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          // Décodage et gestion du corps de la réponse
          final dynamic responseData = json.decode(response.body);
          List<dynamic> results = [];
          
          // Gérer les deux formats possibles de réponse
          if (responseData is List) {
            // Nouveau format: liste directe
            results = responseData;
            print('✅ Résultats reçus (format direct): ${results.length}');
          } else if (responseData is Map && responseData.containsKey('results')) {
            // Ancien format: objet avec propriété results
            results = responseData['results'];
            print('✅ Résultats reçus (format legacy): ${results.length}');
          } else {
            print('❌ Format de réponse inattendu');
            setState(() => _isSearching = false);
            return;
          }
          
          final filteredResults = results
              .where((item) => item['type'] == _currentApiType)
              .map((item) => {
                    'id': item['_id'] ?? item['id'] ?? '',
                    'name': item['name'] ?? item['intitulé'] ?? 'Sans nom',
                    'type': item['type'],
                    'address': item['address'] ?? item['adresse'] ?? 'Adresse non spécifiée',
                    'image': item['image'] ?? item['photo'] ?? item['photo_url'] ?? item['avatar'] ?? '',
                    'place_id': item['place_id'] ?? '',
                  })
              .toList()
              .cast<Map<String, dynamic>>();
              
          print('🔍 Résultats filtrés: ${filteredResults.length}');
          if (filteredResults.isNotEmpty) {
            print('📋 Premier résultat: ${filteredResults[0]}');
          }
          
          setState(() {
            _searchResults = filteredResults;
          });
        } else {
          print('❌ Erreur API: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('❌ Erreur de recherche: $e');
      } finally {
        setState(() => _isSearching = false);
      }
    });
  }

  // Handle producer selection from search results
  void _handleProducerSelection(Map<String, dynamic> producer) {
    print('🔍 Producteur sélectionné: $producer');
    _producerIdController.text = producer['id'];
    setState(() {
      _searchResults = [];
      _searchController.text = producer['name'];
      _selectedPlaceId = producer['place_id'];
      _selectedProducer = producer;
    });
    
    print('🔍 Données stockées: ID=${_producerIdController.text}, place_id=${_selectedPlaceId}');
  }

  Future<void> _pickVerificationImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _verificationImage = File(image.path);
      });
    }
  }

  void _showVerificationSection() {
    setState(() {
      _showVerificationForm = true;
    });
  }

  Future<void> recoverProducer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Détermine le type de compte à partir de l'ID ou de l'onglet sélectionné
      final accountType = _determineAccountType(_producerIdController.text);
      print('🔍 Récupération de compte type: $accountType');
      
      // Await getBaseUrl() before using it
      final baseUrl = await getBaseUrl();
      
      // URL différente selon le type de producteur
      String url;
      Map<String, dynamic> requestBody;
      
      if (accountType == 'WellnessProducer') {
        // Pour les producteurs wellness
        final producerId = _producerIdController.text; // Utiliser directement l'ID MongoDB
        print('🔍 ID producteur wellness: $producerId');
        
        // Utiliser l'ID MongoDB directement plutôt que le place_id
        url = '$baseUrl/api/wellness/auth/claim-account-by-id/$producerId';
        
        print('🔍 URL de vérification: ${url.replaceAll("claim-account-by-id", "check-account-by-id")}');
        
        // Vérifier d'abord si le compte peut être récupéré
        final checkUrl = url.replaceAll("claim-account-by-id", "check-account-by-id");
        final checkResponse = await http.get(
          Uri.parse(checkUrl),
        );
        
        print('🔍 Réponse de vérification: ${checkResponse.statusCode} - ${checkResponse.body}');
        
        final checkData = jsonDecode(checkResponse.body);
        
        if (!checkData['exists'] || !checkData['canBeReclaimed']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ce compte ne peut pas être récupéré: ${checkData['message']}')),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        // Réclamer le compte
        print('🔍 URL de réclamation: $url');
        requestBody = {
          'email': _emailController.text,
          'password': 'TemporaryPassword123!', // Mot de passe temporaire
          'phone': '',
        };
        print('🔍 Corps de la requête: $requestBody');
      } else {
        // Pour les autres producteurs, utiliser l'endpoint existant
        url = '$baseUrl/api/newuser/register-or-recover';
        
        // Create request body
        requestBody = {
          'producerId': _producerIdController.text,
        };
        
        // Add verification info if available
        if (_showVerificationForm) {
          requestBody['email'] = _emailController.text;
          requestBody['firstName'] = _firstNameController.text;
          requestBody['lastName'] = _lastNameController.text;
          requestBody['position'] = _positionController.text;
          requestBody['justification'] = _justificationController.text;
          requestBody['verification'] = true;
        }
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte producteur récupéré avec succès!')),
        );

        // Pour les producteurs wellness, extraire l'ID du producteur de la réponse
        final data = jsonDecode(response.body);
        final userId = accountType == 'WellnessProducer' 
            ? data['producer']['id'] 
            : _producerIdController.text;

        // Naviguer vers MainNavigation avec les bons paramètres
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userId: userId,
              accountType: accountType,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau : $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Récupérer un compte $_currentTabName', 
          style: TextStyle(color: _currentColor)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        iconTheme: IconThemeData(color: _currentColor),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant, 
                    color: _selectedTabIndex == 0 ? Colors.white : Colors.orange),
                  const SizedBox(width: 4),
                  const Text('Restaurant'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_volleyball, 
                    color: _selectedTabIndex == 1 ? Colors.white : Colors.purple),
                  const SizedBox(width: 4),
                  const Text('Loisir'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.spa, 
                    color: _selectedTabIndex == 2 ? Colors.white : Colors.green),
                  const SizedBox(width: 4),
                  const Text('Bien-être'),
                ],
              ),
            ),
          ],
          indicator: BoxDecoration(
            color: _currentColor,
            borderRadius: BorderRadius.circular(50),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          indicatorSize: TabBarIndicatorSize.tab,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _currentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_currentIcon, color: _currentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Récupérez votre compte $_currentTabName',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _currentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Cherchez par nom ou utilisez votre identifiant pour récupérer votre compte',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Search by name card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _currentColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _currentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.search, color: _currentColor),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Rechercher par nom',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: _currentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Search field
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => _searchProducers(value),
                          decoration: InputDecoration(
                            hintText: 'Nom du $_currentTabName...',
                            prefixIcon: Icon(Icons.search, color: _currentColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: _currentColor.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: _currentColor),
                            ),
                            filled: true,
                            fillColor: _currentColor.withOpacity(0.05),
                          ),
                        ),
                        
                        // Display search results
                        if (_isSearching)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(child: CircularProgressIndicator(color: _currentColor)),
                          )
                        else if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            constraints: const BoxConstraints(maxHeight: 300),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _currentColor.withOpacity(0.3)),
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
                                          // Fallback icon if image fails to load
                                          Icon(_currentIcon, color: Colors.grey[600]);
                                        },
                                      )
                                    : CircleAvatar(
                                        backgroundColor: _currentColor.withOpacity(0.1),
                                        child: Icon(_currentIcon, color: _currentColor),
                                      ),
                                  title: Text(
                                    result['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(result['address']),
                                  onTap: () => _handleProducerSelection(result),
                                  tileColor: index % 2 == 0 ? _currentColor.withOpacity(0.03) : Colors.white,
                                );
                              },
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('Ou'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ID input card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _currentColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _currentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.key, color: _currentColor),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Identifiant $_currentTabName',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _currentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Les identifiants de $_currentTabName commencent généralement par $_currentIdPrefix',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Producer ID input
                          TextFormField(
                            controller: _producerIdController,
                            decoration: InputDecoration(
                              labelText: 'Identifiant Producteur',
                              labelStyle: TextStyle(color: _currentColor),
                              prefixIcon: Icon(Icons.perm_identity_outlined, color: _currentColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: _currentColor.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: _currentColor),
                              ),
                              filled: true,
                              fillColor: _currentColor.withOpacity(0.05),
                              hintText: '$_currentIdPrefix...',
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Veuillez entrer un ID producteur' : null,
                          ),
                          
                          if (!_showVerificationForm)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: _showVerificationSection, 
                                    child: Text(
                                      'J\'ai oublié mon identifiant',
                                      style: TextStyle(color: _currentColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Vérification section (shown when requested)
                          if (_showVerificationForm) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _currentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.verified_user, color: _currentColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Vérification d\'identité',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _currentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Votre compte sera vérifié dans les 24h. Si aucun justificatif n\'est fourni, votre compte pourrait être suspendu.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Email field - toujours nécessaire
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email associé au compte',
                                labelStyle: TextStyle(color: _currentColor),
                                prefixIcon: Icon(Icons.email, color: _currentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: _currentColor.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: _currentColor),
                                ),
                                filled: true,
                                fillColor: _currentColor.withOpacity(0.05),
                              ),
                              validator: (value) => value!.isEmpty ? 'Email requis' : null,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Informations personnelles
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Prénom',
                                      labelStyle: TextStyle(color: _currentColor),
                                      prefixIcon: Icon(Icons.person_outline, color: _currentColor),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: _currentColor.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: _currentColor),
                                      ),
                                      filled: true,
                                      fillColor: _currentColor.withOpacity(0.05),
                                    ),
                                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Nom',
                                      labelStyle: TextStyle(color: _currentColor),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: _currentColor.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: _currentColor),
                                      ),
                                      filled: true,
                                      fillColor: _currentColor.withOpacity(0.05),
                                    ),
                                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Statut / Position
                            TextFormField(
                              controller: _positionController,
                              decoration: InputDecoration(
                                labelText: 'Statut (gérant, employé, etc.)',
                                labelStyle: TextStyle(color: _currentColor),
                                prefixIcon: Icon(Icons.business_center, color: _currentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: _currentColor.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: _currentColor),
                                ),
                                filled: true,
                                fillColor: _currentColor.withOpacity(0.05),
                              ),
                              validator: (value) => value!.isEmpty ? 'Veuillez indiquer votre statut' : null,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Justification
                            TextFormField(
                              controller: _justificationController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Motif de récupération',
                                labelStyle: TextStyle(color: _currentColor),
                                hintText: 'Expliquez pourquoi vous récupérez ce compte',
                                prefixIcon: Icon(Icons.description, color: _currentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: _currentColor.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: _currentColor),
                                ),
                                filled: true,
                                fillColor: _currentColor.withOpacity(0.05),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Upload verification image
                            InkWell(
                              onTap: _pickVerificationImage,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: _currentColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _currentColor.withOpacity(0.3)),
                                ),
                                child: _verificationImage != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              _verificationImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 5,
                                            right: 5,
                                            child: CircleAvatar(
                                              radius: 15,
                                              backgroundColor: Colors.white.withOpacity(0.7),
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                iconSize: 18,
                                                icon: const Icon(Icons.close, color: Colors.black),
                                                onPressed: () {
                                                  setState(() {
                                                    _verificationImage = null;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate, size: 40, color: _currentColor),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Ajouter un justificatif\n(facture, bulletin, pièce d\'identité, etc.)',
                                            style: TextStyle(color: _currentColor),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Recover button
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                              ? Center(child: CircularProgressIndicator(color: _currentColor))
                              : ElevatedButton.icon(
                                  icon: const Icon(Icons.key),
                                  label: const Text('Récupérer mon compte'),
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      recoverProducer();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _currentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Help section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _currentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _currentColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.help_outline, color: _currentColor, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Besoin d\'aide?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _currentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Si vous avez des difficultés à récupérer votre compte, contactez notre support à l\'adresse support@choiceapp.com ou appelez le 01 23 45 67 89.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}