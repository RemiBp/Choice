import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/producer.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import '../screens/producer_screen.dart';
import 'package:provider/provider.dart';
import '../utils.dart' show getImageProvider;

class ProducerDetailScreen extends StatefulWidget {
  final String producerId;
  final String producerType;

  const ProducerDetailScreen({
    Key? key,
    required this.producerId,
    required this.producerType,
  }) : super(key: key);

  @override
  _ProducerDetailScreenState createState() => _ProducerDetailScreenState();
}

class _ProducerDetailScreenState extends State<ProducerDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _producerData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducerData();
  }

  Future<void> _loadProducerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ApiService apiService = ApiService();
      final response = await apiService.get('/api/producers/${widget.producerId}?type=${widget.producerType}');
      
      if (response.statusCode == 200) {
        setState(() {
          _producerData = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur lors du chargement des détails: ${response.statusMessage}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_producerData?['name'] ?? 'producer.details'.tr()),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildProducerDetails(),
    );
  }

  Widget _buildProducerDetails() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec image
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              image: _producerData?['photos'] != null && _producerData!['photos'].isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_producerData!['photos'][0]),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              child: Text(
                _producerData?['name'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Informations de base
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type et catégorie
                Row(
                  children: [
                    Chip(
                      label: Text(widget.producerType.tr()),
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    ),
                    const SizedBox(width: 8),
                    if (_producerData?['category'] != null)
                      Chip(
                        label: Text(_producerData!['category']),
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Adresse
                if (_producerData?['address'] != null)
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(_producerData!['address']),
                    contentPadding: EdgeInsets.zero,
                  ),

                // Téléphone
                if (_producerData?['phone'] != null)
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: Text(_producerData!['phone']),
                    onTap: () {
                      // Ouvrir l'application téléphone
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                // Site web
                if (_producerData?['website'] != null)
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(_producerData!['website']),
                    onTap: () {
                      // Ouvrir le site web
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                const Divider(),

                // Description
                if (_producerData?['description'] != null) ...[
                  const Text(
                    'À propos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_producerData!['description']),
                  const SizedBox(height: 16),
                ],

                // Galerie photos
                if (_producerData?['photos'] != null && _producerData!['photos'].length > 1) ...[
                  const Text(
                    'Photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _producerData!['photos'].length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Builder(
                              builder: (context) {
                                final imageUrl = _producerData!['photos'][index];
                                final imageProvider = getImageProvider(imageUrl);
                                
                                return Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey[300],
                                  child: imageProvider != null 
                                    ? Image(
                                        image: imageProvider,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print("❌ Error loading image: $error");
                                          return Center(child: Icon(Icons.broken_image, color: Colors.grey[600])); 
                                        },
                                      )
                                    : Center(child: Icon(Icons.photo_library, color: Colors.grey[600])),
                                );
                              }
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 