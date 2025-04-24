import 'package:flutter/material.dart';
import '../utils/translation_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/wellness_service.dart';
import '../models/wellness_producer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';
import '../utils.dart' show getImageProvider;
import 'package:provider/provider.dart' as provider_pkg;
import '../services/auth_service.dart';
import '../utils/constants.dart' as constants;

class MyWellnessProducerProfileScreen extends StatefulWidget {
  final String producerId;

  const MyWellnessProducerProfileScreen({
    Key? key,
    required this.producerId,
  }) : super(key: key);

  @override
  _MyWellnessProducerProfileScreenState createState() => _MyWellnessProducerProfileScreenState();
}

class _MyWellnessProducerProfileScreenState extends State<MyWellnessProducerProfileScreen> with TickerProviderStateMixin {
  final WellnessService _wellnessService = WellnessService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  WellnessProducer? _producer;
  String? _error;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  // Variables UI
  double _headerHeight = 0.0;
  bool _isScrolled = false;

  // Contrôleurs pour l'édition
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Variables pour le statut choice/interest
  bool _isChoice = false;
  bool _isInterest = false;
  
  // Map pour les notes par sous-catégorie
  Map<String, double> _subcategoryRatings = {};

  // Clé pour le formulaire en mode édition
  final _formKey = GlobalKey<FormState>();

  // Liste temporaire pour les photos/services ajoutés/supprimés en mode édition
  List<XFile> _newPhotos = [];
  List<String> _deletedPhotos = []; // Contient les URLs des photos à supprimer
  List<Map<String, dynamic>> _editedServices = []; // Contient les services modifiés/ajoutés

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    
    _loadProducerData().then((_) {
      if (_producer != null) {
        _checkChoiceInterestStatus();
        _loadSubcategoryRatings();
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.offset > 100 && !_isScrolled) {
      setState(() {
        _isScrolled = true;
      });
    } else if (_scrollController.offset <= 100 && _isScrolled) {
      setState(() {
        _isScrolled = false;
      });
    }
  }

  Future<void> _loadProducerData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String baseUrl = await constants.getBaseUrl();
      final String apiUrl = '$baseUrl/api/unified/${widget.producerId}';
      final headers = await ApiConfig.getAuthHeaders();
      print('>>> MyWellnessProfile: Fetching producer data: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      );

      print('>>> MyWellnessProfile: Fetch response status: \\${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final producer = WellnessProducer.fromJson(data);

        setState(() {
          _producer = producer;
          _initializeControllers();
          _editedServices = List<Map<String, dynamic>>.from(producer.services ?? []);
          _isLoading = false;
        });
      } else {
        print('>>> MyWellnessProfile: Fetch error body: \\${response.body}');
        throw Exception('Failed to load producer data: \\${response.statusCode}');
      }
    } catch (e) {
      print('>>> MyWellnessProfile: Fetch exception: $e');
      setState(() {
        _isLoading = false;
        _error = 'Erreur réseau: Impossible de charger le profil.';
      });
    }
  }
  
  Future<void> _loadSubcategoryRatings() async {
    try {
      final String baseUrl = await constants.getBaseUrl();
      final String apiUrl = '$baseUrl/api/wellness/${widget.producerId}/ratings';
      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _subcategoryRatings = Map<String, double>.from(data['subcategoryRatings'] ?? {});
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des notes par sous-catégorie: $e');
    }
  }

  Future<void> _checkChoiceInterestStatus() async {
    try {
      final String baseUrl = await constants.getBaseUrl();
      final String apiUrl = '$baseUrl/api/choices/wellness/status/${widget.producerId}';
      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isChoice = data['isChoice'] ?? false;
          _isInterest = data['isInterest'] ?? false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la vérification du statut choice/interest: $e';
      });
    }
  }

  void _toggleChoiceInterest() async {
    try {
      final String baseUrl = await constants.getBaseUrl();
      final status = _isChoice ? 'remove' : (_isInterest ? 'promote' : 'add');
      final String apiUrl = '$baseUrl/api/choices/wellness/$status/${widget.producerId}';
      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          if (status == 'promote') {
            _isChoice = true;
            _isInterest = false;
          } else if (status == 'add') {
            _isInterest = true;
          } else {
            _isChoice = false;
            _isInterest = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'promote' 
                ? 'Ajouté à vos Choices !' 
                : (status == 'add' ? 'Ajouté à vos Intérêts !' : 'Retiré de vos favoris')
            ),
            backgroundColor: status == 'remove' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  Widget _buildRatingBySubcategory() {
    if (_subcategoryRatings.isEmpty) {
      return Center(
        child: Text('Aucune note disponible pour le moment'),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _subcategoryRatings.length,
      itemBuilder: (context, index) {
        final subcategory = _subcategoryRatings.keys.elementAt(index);
        final rating = _subcategoryRatings[subcategory] ?? 0.0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subcategory,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  RatingBar.builder(
                    initialRating: rating,
                    minRating: 0,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemSize: 24,
                    ignoreGestures: true,
                    itemBuilder: (context, _) => Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (_) {},
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isScrolled) {
    ImageProvider? profileImage = getImageProvider(_producer!.profilePhoto);

    return SliverAppBar(
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      elevation: isScrolled ? 2 : 0,
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
        title: isScrolled
            ? Text(
                _producer!.name,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold),
              )
            : null,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (profileImage != null)
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: profileImage,
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                  ),
                ),
              )
            else
              Container(color: Colors.teal.shade700),

            Padding(
              padding: EdgeInsets.only(
                  bottom: 60 + MediaQuery.of(context).padding.bottom,
                  top: MediaQuery.of(context).padding.top + kToolbarHeight - 30,
                  left: 20,
                  right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.teal.shade50,
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? Icon(Icons.spa_outlined, size: 40, color: Colors.teal.shade600)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _isEditing
                      ? TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                             isDense: true,
                             border: InputBorder.none,
                             hintText: 'Nom de l\'établissement',
                             hintStyle: TextStyle(color: Colors.white70)
                          ),
                          validator: (value) => value!.isEmpty ? 'Nom requis' : null,
                        )
                      : Text(
                        _producer!.name,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [const Shadow(blurRadius: 2, color: Colors.black45)]
                        ),
                        textAlign: TextAlign.center,
                      ),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text('${_producer!.category} - ${_producer!.sous_categorie}', style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.white),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                   const SizedBox(height: 8),
                  if (!_isEditing && _producer!.description.isNotEmpty)
                     Text(
                        _producer!.description,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  if (_isEditing)
                     TextFormField(
                        controller: _descriptionController,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        decoration: const InputDecoration(
                           isDense: true,
                           border: InputBorder.none,
                           hintText: 'Description...',
                           hintStyle: TextStyle(color: Colors.white70)
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isEditing)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier le profil',
            onPressed: () => setState(() => _isEditing = true),
          ),
        if (!_isEditing)
           IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => _showMainMenu(context),
          ),
      ],
    );
  }

  Widget _buildStats(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(Icons.star_half, 'Note', '${_producer!.rating.toStringAsFixed(1)} (${_producer!.userRatingsTotal} avis)'),
             _buildStatItem(Icons.favorite_border, 'Favoris', _producer!.favoriteCountFromData.toString()),
            _buildStatItem(Icons.check_circle_outline, 'Choices', _producer!.choiceCountFromData.toString()),
            _buildStatItem(Icons.visibility_outlined, 'Intérêts', _producer!.interestCountFromData.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.teal, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isEditing || _producer!.description.isEmpty)
           _buildEditableSectionTitle('Description'),
         if (_isEditing)
            TextFormField(
                controller: _descriptionController,
                maxLines: null,
                decoration: _editableInputDecoration(hint: 'Décrivez votre établissement...')
            )
         else if (_producer!.description.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(bottom: 16.0),
               child: Text(_producer!.description, style: const TextStyle(fontSize: 15, height: 1.4)),
             ),
        
        _buildEditableSectionTitle('Coordonnées'),
        _buildEditableContactInfo(context),
        
        _buildEditableSectionTitle('Adresse'),
        _buildEditableLocationInfo(context),
        
        _buildEditableSectionTitle('Horaires d\'ouverture'),
        _buildEditableOpeningHours(context),
        
        _buildEditableSectionTitle('Équipements & Services'),
        _buildEditableAmenities(context),
      ],
    );
  }

  Widget _buildPhotosTab(BuildContext context) {
    List<String> currentPhotos = _producer?.photos ?? [];
    List<dynamic> displayedItems = [
       ...currentPhotos.where((url) => !_deletedPhotos.contains(url)),
       ..._newPhotos,
      if (_isEditing) 'add_button'
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayedItems.length,
      itemBuilder: (context, index) {
        var item = displayedItems[index];

        if (item == 'add_button') {
          return InkWell(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
              ),
              child: Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.grey[600])),
            ),
          );
        }

        ImageProvider? imageProvider;
        bool isNew = false;
        String? imageUrl;

        if (item is XFile) {
          imageProvider = FileImage(File(item.path));
          isNew = true;
        } else if (item is String) {
          imageProvider = getImageProvider(item);
          imageUrl = item;
        }

        bool markedForDeletion = imageUrl != null && _deletedPhotos.contains(imageUrl);

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageProvider != null)
                Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                )
              else
                Container(color: Colors.grey[300], child: const Icon(Icons.error_outline)),

              if (_isEditing && !isNew && imageUrl != null)
                Positioned.fill(
                  child: Container(
                    color: markedForDeletion ? Colors.black.withOpacity(0.6) : Colors.transparent,
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          markedForDeletion ? Icons.refresh : Icons.delete_outline,
                          color: markedForDeletion ? Colors.white : Colors.red.withOpacity(0.8),
                        ),
                        onPressed: () => _markPhotoForDeletion(imageUrl!),
                        tooltip: markedForDeletion ? 'Annuler suppression' : 'Supprimer',
                      ),
                    ),
                  ),
                ),
              if (isNew)
                Positioned(
                  top: 4, right: 4,
                  child: Chip(label: const Text('Nouveau'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, backgroundColor: Colors.green.withOpacity(0.8)),
                ),
              if (_isEditing && isNew)
                 Positioned(
                    top: 0, left: 0,
                    child: IconButton(
                       icon: const Icon(Icons.cancel, color: Colors.red),
                       iconSize: 20,
                       padding: EdgeInsets.zero,
                       constraints: const BoxConstraints(),
                       onPressed: () => setState(() => _newPhotos.remove(item)),
                    ),
                 )
            ],
          ),
        );
      },
    );
  }

  Widget _buildServicesTab(BuildContext context) {
    List<Map<String, dynamic>> services = _editedServices;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length + (_isEditing ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isEditing && index == services.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un service'),
              onPressed: _addNewService,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
            ),
          );
        }

        final service = services[index];
        final nameController = TextEditingController(text: service['name'] ?? '');
        final descController = TextEditingController(text: service['description'] ?? '');
        final priceController = TextEditingController(text: service['price']?.toString() ?? '');
        final durationController = TextEditingController(text: service['duration']?.toString() ?? '');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 if (_isEditing) ...[
                   TextFormField(
                      controller: nameController,
                      decoration: _editableInputDecoration(label: 'Nom du service'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      validator: (v) => v!.isEmpty ? 'Nom requis' : null,
                      onChanged: (value) => service['name'] = value,
                   ),
                   const SizedBox(height: 8),
                   TextFormField(
                      controller: descController,
                      decoration: _editableInputDecoration(label: 'Description', hint: 'Décrivez le service...'),
                      maxLines: null,
                      onChanged: (value) => service['description'] = value,
                   ),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       Expanded(
                         child: TextFormField(
                           controller: priceController,
                           decoration: _editableInputDecoration(label: 'Prix (€)', hint: 'ex: 50'),
                           keyboardType: TextInputType.number,
                           onChanged: (value) => service['price'] = double.tryParse(value),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: TextFormField(
                           controller: durationController,
                           decoration: _editableInputDecoration(label: 'Durée (min)', hint: 'ex: 60'),
                           keyboardType: TextInputType.number,
                           onChanged: (value) => service['duration'] = int.tryParse(value),
                         ),
                       ),
                     ],
                   ),
                    const SizedBox(height: 12),
                   Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                         icon: const Icon(Icons.delete_outline, color: Colors.red),
                         tooltip: 'Supprimer ce service',
                         onPressed: () => _deleteService(index),
                      ),
                   ),
                 ] else ...[
                   Text(service['name'] ?? 'Service sans nom', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   if (service['description'] != null && service['description'].isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(top: 4.0),
                       child: Text(service['description'], style: TextStyle(color: Colors.grey[700])),
                     ),
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           '${service['price'] ?? '-'} €',
                           style: const TextStyle(fontWeight: FontWeight.w500),
                         ),
                         Text(
                           '${service['duration'] ?? '-'} min',
                           style: TextStyle(color: Colors.grey[600]),
                         ),
                       ],
                     ),
                   ),
                 ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _addNewService() {
    setState(() {
      _editedServices.add({
        'name': '',
        'description': '',
        'price': null,
        'duration': null,
        '_isNew': true
      });
    });
  }

  void _deleteService(int index) {
    setState(() {
      _editedServices.removeAt(index);
    });
  }

  Widget _buildEditableSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.teal.shade800,
        ),
      ),
    );
  }

  InputDecoration _editableInputDecoration({String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildEditableContactInfo(BuildContext context) {
     if (_isEditing) {
       return Column(
         children: [
           TextFormField(
             controller: _phoneController,
             decoration: _editableInputDecoration(label: 'Téléphone'),
             keyboardType: TextInputType.phone,
           ),
           const SizedBox(height: 12),
           TextFormField(
             controller: _emailController,
             decoration: _editableInputDecoration(label: 'Email'),
             keyboardType: TextInputType.emailAddress,
           ),
           const SizedBox(height: 12),
           TextFormField(
             controller: _websiteController,
             decoration: _editableInputDecoration(label: 'Site Web', hint: 'https://...'),
             keyboardType: TextInputType.url,
           ),
         ],
       );
     } else {
       return Column(
         children: [
           _buildInfoTile(Icons.phone_outlined, _producer!.phone, onTap: () => _launchUrl('tel:${_producer!.phone}')),
           _buildInfoTile(Icons.email_outlined, _producer!.email, onTap: () => _launchUrl('mailto:${_producer!.email}')),
           _buildInfoTile(Icons.language_outlined, _producer!.website, onTap: () => _launchUrl(_producer!.website)),
           _buildSocialMediaLinks(_producer!.location['contact']?['social_media']),
         ],
       );
     }
  }
  
  Widget _buildEditableLocationInfo(BuildContext context) {
     if (_isEditing) {
        return TextFormField(
           controller: _addressController,
           decoration: _editableInputDecoration(label: 'Adresse complète'),
           maxLines: null,
           validator: (v) => v!.isEmpty ? 'Adresse requise' : null,
        );
     } else {
        return Column(
           children: [
             _buildInfoTile(Icons.location_on_outlined, _producer!.address, onTap: () => _openMap(_producer!.address)),
           ],
        );
     }
  }

  Widget _buildEditableOpeningHours(BuildContext context) {
     if (_isEditing) {
        return const Text('Édition des horaires non implémentée.', style: TextStyle(color: Colors.orange));
     } else {
        if (_producer!.openingHours.isEmpty) {
           return const Text('Horaires non disponibles.');
        }
        return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: _producer!.openingHours.entries.map((entry) {
              final day = entry.key;
              final hours = entry.value;
              final String displayHours = (hours is Map && hours['open'] != null && hours['close'] != null)
                  ? '${hours['open']} - ${hours['close']}'
                  : (hours == 'Fermé' || hours == 'Closed' ? 'Fermé' : 'Non spécifié');
              return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 4.0),
                 child: Row(
                    children: [
                       SizedBox(width: 80, child: Text(day.capitalize(), style: const TextStyle(fontWeight: FontWeight.w500))),
                       Text(displayHours),
                    ],
                 ),
              );
           }).toList(),
        );
     }
  }

  Widget _buildEditableAmenities(BuildContext context) {
     List<String> amenities = _producer!.location['amenities']?.cast<String>() ?? [];
     if (_isEditing) {
        return const Text('Édition des équipements non implémentée.', style: TextStyle(color: Colors.orange));
     } else {
        if (amenities.isEmpty) {
           return const Text('Aucun équipement spécifié.');
        }
        return Wrap(
           spacing: 8,
           runSpacing: 4,
           children: amenities.map((amenity) => Chip(
              label: Text(amenity),
              backgroundColor: Colors.teal.withOpacity(0.1),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
           )).toList(),
        );
     }
  }
  
  Widget _buildSocialMediaLinks(Map<String, dynamic>? socialMedia) {
      if (socialMedia == null || socialMedia.isEmpty) {
         return const SizedBox.shrink();
      }

      List<Widget> links = [];
      socialMedia.forEach((key, value) {
         if (value != null && value.toString().isNotEmpty) {
            IconData icon;
            switch (key.toLowerCase()) {
               case 'facebook': icon = Icons.facebook; break;
               case 'instagram': icon = Icons.camera_alt_outlined; break;
               case 'twitter': icon = Icons.flutter_dash_outlined; break;
               default: icon = Icons.link;
            }
            links.add(
               IconButton(
                  icon: Icon(icon, color: Colors.blueGrey),
                  tooltip: '${key.capitalize()}: ${value.toString()}',
                  onPressed: () => _launchUrl(value.toString()),
               )
            );
         }
      });

      if (links.isEmpty) return const SizedBox.shrink();

      return Padding(
         padding: const EdgeInsets.only(top: 8.0),
         child: Wrap(
            spacing: 4,
            children: links,
         ),
      );
   }

  Widget _buildInfoTile(IconData icon, String? text, {VoidCallback? onTap}) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon, color: Colors.teal, size: 20),
      title: Text(text, style: const TextStyle(fontSize: 15)),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      onTap: onTap != null && text.isNotEmpty ? onTap : null,
    );
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    if (!urlString.startsWith('http') && !urlString.startsWith('mailto:') && !urlString.startsWith('tel:')) {
       urlString = 'https://$urlString';
    }
    final Uri? url = Uri.tryParse(urlString);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print('Could not launch $urlString');
      _showErrorSnackbar('Impossible d\'ouvrir le lien.');
    }
  }
  
  Future<void> _openMap(String address) async {
    String query = Uri.encodeComponent(address);
    String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$query';
    String appleUrl = 'https://maps.apple.com/?q=$query';

    try {
       if (Platform.isIOS) {
          final appleUri = Uri.parse(appleUrl);
          if (await canLaunchUrl(appleUri)) {
             await launchUrl(appleUri);
             return;
          }
       }
       final googleUri = Uri.parse(googleUrl);
       if (await canLaunchUrl(googleUri)) {
          await launchUrl(googleUri);
       } else {
          throw 'Could not launch any map URI';
       }
    } catch (e) {
       print('Could not launch map: $e');
       _showErrorSnackbar('Impossible d\'ouvrir l\'application de carte.');
    }
  }

  Widget _buildEditControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: _cancelEditing,
            child: const Text('Annuler'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700]),
          ),
          ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Sauvegarde...' : 'Enregistrer'),
            onPressed: _isSaving ? null : _saveProfileChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/loading.json',
                width: 150,
                height: 150,
                errorBuilder: (ctx, err, st) => const CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              const Text('Chargement du profil...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadProducerData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_producer == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Profil Introuvable')),
          body: const Center(child: Text('Impossible de charger les données du profil.')));
    }

    return Scaffold(
      body: Form(
        key: _formKey,
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              _buildHeader(context, innerBoxIsScrolled),
              _buildStats(context),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.teal,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: Colors.teal,
                    tabs: const [
                      Tab(icon: Icon(Icons.info_outline), text: 'Aperçu'),
                      Tab(icon: Icon(Icons.photo_library_outlined), text: 'Photos'),
                      Tab(icon: Icon(Icons.medical_services_outlined), text: 'Services'),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context),
              _buildPhotosTab(context),
              _buildServicesTab(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isEditing ? _buildEditControls(context) : null,
    );
  }

  void _initializeControllers() {
    if (_producer != null) {
      _nameController.text = _producer!.name;
      _addressController.text = _producer!.address;
      _phoneController.text = _producer!.phone;
      _websiteController.text = _producer!.website;
      _emailController.text = _producer!.email;
      _descriptionController.text = _producer!.description;
    }
  }

  void _showMainMenu(BuildContext context) {
    // À implémenter selon le besoin (menu bottom sheet, etc.)
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newPhotos.addAll(pickedFiles);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Erreur lors de la sélection d\'images.');
    }
  }

  void _markPhotoForDeletion(String url) {
    setState(() {
      if (_deletedPhotos.contains(url)) {
        _deletedPhotos.remove(url);
      } else {
        _deletedPhotos.add(url);
      }
    });
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _newPhotos.clear();
      _deletedPhotos.clear();
      _initializeControllers();
      _editedServices = List<Map<String, dynamic>>.from(_producer?.services ?? []);
    });
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final String baseUrl = await constants.getBaseUrl();
    final headers = await ApiConfig.getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    try {
      // 1. Supprimer les photos marquées
      for (final url in _deletedPhotos) {
        final encodedUrl = Uri.encodeComponent(url);
        final apiUrl = '$baseUrl/api/wellness/${widget.producerId}/photos/$encodedUrl';
        await http.delete(
          Uri.parse(apiUrl),
          headers: headers,
        );
      }

      // 2. Uploader les nouvelles photos (stub pour l'instant)
      List<String> newPhotoUrls = await uploadImages(_newPhotos);

      // 3. Ajouter les nouvelles photos via l'API
      if (newPhotoUrls.isNotEmpty) {
        final apiUrl = '$baseUrl/api/wellness/${widget.producerId}/photos';
        await http.post(
          Uri.parse(apiUrl),
          headers: headers,
          body: json.encode({'photoUrls': newPhotoUrls}),
        );
      }

      // 4. Mettre à jour les services
      final apiUrlServices = '$baseUrl/api/wellness/${widget.producerId}/services';
      await http.put(
        Uri.parse(apiUrlServices),
        headers: headers,
        body: json.encode({'services': _editedServices}),
      );

      // 5. Mettre à jour les infos générales
      final updatedData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'contact': {
          'phone': _phoneController.text,
          'email': _emailController.text,
          'website': _websiteController.text,
        },
        'location': {
          'address': _addressController.text,
        },
      };
      final apiUrlGeneral = '$baseUrl/api/wellness/${widget.producerId}';
      final response = await http.put(
        Uri.parse(apiUrlGeneral),
        headers: headers,
        body: json.encode(updatedData),
      );

      if (response.statusCode == 200) {
        await _loadProducerData();
        setState(() {
          _isEditing = false;
          _newPhotos.clear();
          _deletedPhotos.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !'), backgroundColor: Colors.green),
        );
      } else {
        _showErrorSnackbar('Erreur \\${response.statusCode} lors de la sauvegarde.');
      }
    } catch (e) {
      _showErrorSnackbar('Erreur réseau lors de la sauvegarde.');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<List<String>> uploadImages(List<XFile> images) async {
    // TODO: Implémenter l'upload réel (Cloudinary, S3, backend, etc.)
    // Pour l'instant, retourne une liste vide (pas d'upload)
    return [];
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return "";
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}