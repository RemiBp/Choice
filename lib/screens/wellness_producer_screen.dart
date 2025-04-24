import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;
import '../utils.dart' show getImageProvider;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessProducer {
  final String id;
  final String name;
  final String? address;
  final String? description;
  final String? category;
  final String? subcategory;
  final String? phone;
  final String? website;
  final String? email;
  final double? rating;
  final int? userRatingsTotal;
  final String? mainPhoto;
  final List<String>? photos;
  final List<Map<String, dynamic>>? services;
  final Map<String, dynamic>? openingHours;
  final List<String>? amenities;

  WellnessProducer({
    required this.id,
    required this.name,
    this.address,
    this.description,
    this.category,
    this.subcategory,
    this.phone,
    this.website,
    this.email,
    this.rating,
    this.userRatingsTotal,
    this.mainPhoto,
    this.photos,
    this.services,
    this.openingHours,
    this.amenities,
  });

  factory WellnessProducer.fromJson(Map<String, dynamic> json) {
    return WellnessProducer(
      id: json['_id'] ?? json['id'],
      name: json['name'] ?? json['nom'] ?? 'Sans nom',
      address: json['address'] ?? json['adresse'],
      description: json['description'] ?? '',
      category: json['category'] ?? json['categorie'],
      subcategory: json['subcategory'] ?? json['sous_categorie'],
      phone: json['phone'] ?? json['telephone'],
      website: json['website'] ?? json['site_web'],
      email: json['email'],
      rating: (json['rating'] ?? json['note_google'])?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] ?? json['userRatingsTotal'] ?? 0,
      mainPhoto: json['main_photo'] ?? (json['photos'] is List && json['photos'].isNotEmpty ? json['photos'][0] : null),
      photos: (json['photos'] is List) ? List<String>.from(json['photos']) : null,
      services: (json['services'] is List)
          ? List<Map<String, dynamic>>.from(json['services'].map((s) => Map<String, dynamic>.from(s)))
          : null,
      openingHours: json['opening_hours'] ?? json['horaires'] ?? {},
      amenities: (json['amenities'] is List) ? List<String>.from(json['amenities']) : null,
    );
  }
}

class WellnessProducerScreen extends StatefulWidget {
  final String producerId;
  const WellnessProducerScreen({Key? key, required this.producerId}) : super(key: key);
  @override
  State<WellnessProducerScreen> createState() => _WellnessProducerScreenState();
}

class _WellnessProducerScreenState extends State<WellnessProducerScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  WellnessProducer? _producer;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProducerData();
  }

  Future<void> _loadProducerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/wellness/${widget.producerId}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        setState(() {
          _producer = WellnessProducer.fromJson(data);
          _isLoading = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Impossible de charger les informations: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Erreur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadProducerData,
                        child: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                      ),
                    ],
                  ),
                )
              : _producer == null
                  ? const Center(child: Text('Aucune information disponible'))
                  : DefaultTabController(
                      length: 3,
                      child: NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          _buildHeader(context),
                          _buildStats(context),
                          SliverPersistentHeader(
                            delegate: _SliverTabBarDelegate(
                              TabBar(
                                controller: _tabController,
                                labelColor: Colors.green[800],
                                unselectedLabelColor: Colors.grey[600],
                                indicatorColor: Colors.green[700],
                                tabs: const [
                                  Tab(icon: Icon(Icons.info_outline), text: 'Aperçu'),
                                  Tab(icon: Icon(Icons.photo_library_outlined), text: 'Photos'),
                                  Tab(icon: Icon(Icons.medical_services_outlined), text: 'Services'),
                                ],
                              ),
                            ),
                            pinned: true,
                          ),
                        ],
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
    );
  }

  SliverAppBar _buildHeader(BuildContext context) {
    final profileImage = getImageProvider(_producer!.mainPhoto ?? '');
    return SliverAppBar(
      expandedHeight: 240.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.green[700],
      elevation: 1,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (profileImage != null)
              CachedNetworkImage(
                imageUrl: _producer!.mainPhoto!,
                fit: BoxFit.cover,
                placeholder: (ctx, url) => Container(color: Colors.green[100]),
                errorWidget: (ctx, url, err) => Container(color: Colors.green[100]),
              )
            else
              Container(color: Colors.green[200]),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _producer!.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [const Shadow(blurRadius: 2, color: Colors.black45)],
                    ),
                  ),
                  if (_producer!.category != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Chip(
                        label: Text(_producer!.category!),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        labelStyle: const TextStyle(color: Colors.white),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildStats(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(Icons.star_half, 'Note', _producer!.rating?.toStringAsFixed(1) ?? '-', extra: _producer!.userRatingsTotal != null ? ' (${_producer!.userRatingsTotal})' : ''),
            _buildStatItem(Icons.favorite_border, 'Favoris', '-'),
            _buildStatItem(Icons.check_circle_outline, 'Choices', '-'),
            _buildStatItem(Icons.visibility_outlined, 'Intérêts', '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, {String extra = ''}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green[700], size: 24),
        const SizedBox(height: 4),
        Text('$value$extra', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_producer!.description != null && _producer!.description!.isNotEmpty) ...[
          Text('À propos', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_producer!.description!),
          const SizedBox(height: 20),
        ],
        if (_producer!.address != null)
          _buildInfoRow(Icons.location_on, _producer!.address!),
        if (_producer!.phone != null)
          _buildInfoRow(Icons.phone, _producer!.phone!),
        if (_producer!.email != null)
          _buildInfoRow(Icons.email, _producer!.email!),
        if (_producer!.website != null)
          _buildInfoRow(Icons.language, _producer!.website!),
        const SizedBox(height: 16),
        if (_producer!.openingHours != null && _producer!.openingHours!.isNotEmpty) ...[
          Text('Horaires', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._producer!.openingHours!.entries.map((e) => _buildInfoRow(Icons.access_time, '${e.key}: ${e.value}')),
          const SizedBox(height: 16),
        ],
        if (_producer!.amenities != null && _producer!.amenities!.isNotEmpty) ...[
          Text('Équipements', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _producer!.amenities!.map((a) => Chip(label: Text(a), backgroundColor: Colors.green.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotosTab(BuildContext context) {
    final photos = _producer!.photos ?? [];
    if (photos.isEmpty) {
      return const Center(child: Text('Aucune photo disponible.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photoUrl = photos[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(color: Colors.green[100]),
            errorWidget: (ctx, url, err) => Container(color: Colors.green[50], child: const Icon(Icons.broken_image)),
          ),
        );
      },
    );
  }

  Widget _buildServicesTab(BuildContext context) {
    final services = _producer!.services ?? [];
    if (services.isEmpty) {
      return const Center(child: Text('Aucun service renseigné.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Text('${service['price'] ?? '-'} €', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${service['duration'] ?? '-'} min', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[700], size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
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