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
import 'wellness_producer_feed_screen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';

class MyWellnessProducerProfileScreen extends StatefulWidget {
  final String producerId;

  const MyWellnessProducerProfileScreen({
    Key? key,
    required this.producerId,
  }) : super(key: key);

  @override
  _MyWellnessProducerProfileScreenState createState() => _MyWellnessProducerProfileScreenState();
}

class _MyWellnessProducerProfileScreenState extends State<MyWellnessProducerProfileScreen> with SingleTickerProviderStateMixin {
  final WellnessService _wellnessService = WellnessService();
  bool _isLoading = true;
  bool _isEditing = false;
  WellnessProducer? _producer;
  String? _error;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/unified/${widget.producerId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final producer = WellnessProducer.fromJson(data);

        setState(() {
          _producer = producer;
          _isLoading = false;
          // Initialiser les contrôleurs avec les données actuelles
          _nameController.text = producer.name;
          _addressController.text = producer.address;
          _phoneController.text = producer.phone ?? '';
          _websiteController.text = producer.website ?? '';
          _emailController.text = producer.email ?? '';
          _descriptionController.text = producer.description ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur lors du chargement du profil: $e';
      });
    }
  }
  
  Future<void> _loadSubcategoryRatings() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/wellness/${widget.producerId}/ratings'),
        headers: await ApiConfig.getAuthHeaders(),
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
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/choices/wellness/status/${widget.producerId}'),
        headers: await ApiConfig.getAuthHeaders(),
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
      final status = _isChoice ? 'remove' : (_isInterest ? 'promote' : 'add');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/choices/wellness/${status}/${widget.producerId}'),
        headers: await ApiConfig.getAuthHeaders(),
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
        
        // Afficher un message de confirmation
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

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _headerHeight = constraints.biggest.height;
          return FlexibleSpaceBar(
            title: _headerHeight < 100 
              ? Text(
                  _producer?.name ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
            background: _producer?.profilePhoto != null
              ? CachedNetworkImage(
                  imageUrl: _producer!.profilePhoto!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.error),
                  ),
                )
              : Container(
                  color: Theme.of(context).primaryColor,
                  child: Icon(
                    Icons.spa,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
          );
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.share),
          onPressed: () {
            // TODO: Implémenter le partage
          },
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        // Informations de base
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _producer?.name ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_producer?.category != null)
                  Chip(
                    label: Text(_producer!.category!),
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                const SizedBox(height: 16),
                if (_producer?.description != null && _producer!.description!.isNotEmpty)
                  Text(
                    _producer!.description!,
                    style: TextStyle(fontSize: 16),
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Informations de contact
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_producer?.address != null && _producer!.address.isNotEmpty)
                  ListTile(
                    leading: Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                    title: Text(_producer!.address),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      // Ouvrir la carte
                      launch('https://maps.google.com/?q=${_producer!.address}');
                    },
                  ),
                if (_producer?.phone != null && _producer!.phone!.isNotEmpty)
                  ListTile(
                    leading: Icon(Icons.phone, color: Theme.of(context).primaryColor),
                    title: Text(_producer!.phone!),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      launch('tel:${_producer!.phone}');
                    },
                  ),
                if (_producer?.email != null && _producer!.email!.isNotEmpty)
                  ListTile(
                    leading: Icon(Icons.email, color: Theme.of(context).primaryColor),
                    title: Text(_producer!.email!),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      launch('mailto:${_producer!.email}');
                    },
                  ),
                if (_producer?.website != null && _producer!.website!.isNotEmpty)
                  ListTile(
                    leading: Icon(Icons.language, color: Theme.of(context).primaryColor),
                    title: Text(_producer!.website!),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      launch(_producer!.website!);
                    },
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Notes par sous-catégorie
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes par catégorie',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRatingBySubcategory(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosTab() {
    if (_producer == null || _producer!.photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Aucune photo disponible'),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _producer!.photos.length,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // Afficher la photo en plein écran
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    body: Container(
                      color: Colors.black,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: _producer!.photos[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: _producer!.photos[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.error),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesTab() {
    // TODO: Implémenter l'affichage des services
    return Center(
      child: Text('Services en cours de développement'),
    );
  }

  Widget _buildReviewsTab() {
    // TODO: Implémenter l'affichage des avis
    return Center(
      child: Text('Avis en cours de développement'),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WellnessProducerFeedScreen(
                      userId: _producer!.id,
                      producerId: _producer!.id,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.feed),
              label: const Text('Voir le Feed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleChoiceInterest,
              icon: Icon(
                _isChoice ? Icons.favorite : (_isInterest ? Icons.star : Icons.add),
              ),
              label: Text(
                _isChoice 
                  ? 'Choisi !' 
                  : (_isInterest ? 'Intéressé !' : 'Ajouter')
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isChoice
                  ? Colors.red
                  : _isInterest
                    ? Colors.orange
                    : Colors.green,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 16),
              Text('Chargement...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Erreur'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadProducerData,
                  child: Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            _buildHeader(),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  tabs: [
                    Tab(text: 'Aperçu'),
                    Tab(text: 'Photos'),
                    Tab(text: 'Services'),
                    Tab(text: 'Avis'),
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
            SingleChildScrollView(child: _buildOverviewTab()),
            SingleChildScrollView(child: _buildPhotosTab()),
            _buildServicesTab(),
            _buildReviewsTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

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
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return false;
  }
}