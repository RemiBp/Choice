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
  bool _isRestaurantSelected = true;
  final ImagePicker _picker = ImagePicker();
  File? _verificationImage;
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      setState(() {
        _isRestaurantSelected = _tabController!.index == 0;
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
              _isRestaurantSelected = type == 'restaurant';
              _tabController?.animateTo(_isRestaurantSelected ? 0 : 1);
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
    } else {
      return _isRestaurantSelected ? 'RestaurantProducer' : 'LeisureProducer';
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

  // Handle producer selection from search results
  void _handleProducerSelection(Map<String, dynamic> producer) {
    _producerIdController.text = producer['id'];
    setState(() {
      _searchResults = [];
      _searchController.text = producer['name'];
    });
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

    // Extraire le domaine et le protocole de l'URL complète
    final baseUrl = getBaseUrl();
    Uri url = Uri.parse('$baseUrl/api/newuser/register-or-recover');
    
    try {
      // Create request body
      final Map<String, dynamic> requestBody = {
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
        
        // Add image verification will be handled by a separate API call
        // or we could use a multi-part form request in a more advanced implementation
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Détermine le type de compte à partir de l'ID
        final accountType = _determineAccountType(_producerIdController.text);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte producteur récupéré avec succès!')),
        );

        // Naviguer vers MainNavigation avec les bons paramètres
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userId: _producerIdController.text,
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
        title: const Text('Récupérer un compte producteur'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page header
                const Text(
                  'Accédez à votre compte',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Retrouvez votre compte producteur en cherchant par nom ou par identifiant',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 30),

                // Producer type selector
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(20),
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
                          const SizedBox(width: 12),
                          const Text(
                            'Type de compte',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
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
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Search by name card
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
                              child: const Icon(Icons.search, color: Colors.blue),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Rechercher par nom',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
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
                            hintText: 'Nom du producteur...',
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
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                        
                        // Display search results
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            constraints: const BoxConstraints(maxHeight: 300),
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
                                          // Fallback icon if image fails to load
                                          Icon(
                                            result['type'] == 'restaurant' ? Icons.restaurant : Icons.sports,
                                            color: Colors.grey[600],
                                          );
                                        },
                                      )
                                    : CircleAvatar(
                                        backgroundColor: Colors.grey[200],
                                        child: Icon(
                                          result['type'] == 'restaurant' ? Icons.restaurant : Icons.sports,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  title: Text(result['name']),
                                  subtitle: Text(result['address']),
                                  onTap: () => _handleProducerSelection(result),
                                );
                              },
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        const Text(
                          'Ou',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
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
                  child: Padding(
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
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.key, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isRestaurantSelected 
                                    ? 'Identifiant Restaurant' 
                                    : 'Identifiant Loisir',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isRestaurantSelected 
                                ? 'Les identifiants de restaurant commencent généralement par 675' 
                                : 'Les identifiants de loisir commencent généralement par 676',
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
                              prefixIcon: const Icon(Icons.perm_identity_outlined, color: Colors.deepPurple),
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
                              hintText: _isRestaurantSelected ? '675...' : '676...',
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
                                    child: const Text('J\'ai oublié mon identifiant')
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
                                    color: Colors.deepPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.verified_user, color: Colors.deepPurple),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Vérification d\'identité',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
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
                            
                            // Informations personnelles
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Prénom',
                                      prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurple),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
                                prefixIcon: const Icon(Icons.business_center, color: Colors.deepPurple),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) => value!.isEmpty ? 'Veuillez indiquer votre statut' : null,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Email field
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email associé au compte',
                                prefixIcon: const Icon(Icons.email, color: Colors.deepPurple),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) => value!.isEmpty ? 'Email requis' : null,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Justification
                            TextFormField(
                              controller: _justificationController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Motif de récupération',
                                hintText: 'Expliquez pourquoi vous récupérez ce compte',
                                prefixIcon: const Icon(Icons.description, color: Colors.deepPurple),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Upload verification image
                            InkWell(
                              onTap: _pickVerificationImage,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[300]!),
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
                                          const Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Ajouter un justificatif\n(facture, bulletin, pièce d\'identité, etc.)',
                                            style: TextStyle(color: Colors.grey[600]),
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
                              ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                              : ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      recoverProducer();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Récupérer mon compte',
                                    style: TextStyle(fontSize: 16),
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.help_outline, color: Colors.blue[700], size: 24),
                          const SizedBox(width: 10),
                          const Text(
                            'Besoin d\'aide?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
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