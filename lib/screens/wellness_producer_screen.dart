import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart' as constants;

class WellnessProducer {
  final String id;
  final String name;
  final String? address;
  final String? description;
  final String? category;
  final String? phone;
  final String? website;
  final double? rating;
  final String? mainPhoto;
  final List<String>? services;

  WellnessProducer({
    required this.id,
    required this.name,
    this.address,
    this.description,
    this.category,
    this.phone,
    this.website,
    this.rating,
    this.mainPhoto,
    this.services,
  });

  factory WellnessProducer.fromJson(Map<String, dynamic> json) {
    return WellnessProducer(
      id: json['_id'],
      name: json['name'] ?? json['nom'] ?? 'Sans nom',
      address: json['address'] ?? json['adresse'],
      description: json['description'],
      category: json['category'] ?? json['categorie'],
      phone: json['phone'] ?? json['telephone'],
      website: json['website'] ?? json['site_web'],
      rating: json['rating']?.toDouble() ?? json['note_google']?.toDouble(),
      mainPhoto: json['main_photo'] ?? json['photos']?[0],
      services: json['services'] != null 
          ? List<String>.from(json['services']) 
          : null,
    );
  }
}

class WellnessProducerScreen extends StatefulWidget {
  final String producerId;
  
  const WellnessProducerScreen({Key? key, required this.producerId}) : super(key: key);
  
  @override
  State<WellnessProducerScreen> createState() => _WellnessProducerScreenState();
}

class _WellnessProducerScreenState extends State<WellnessProducerScreen> {
  bool _isLoading = true;
  WellnessProducer? _producer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducerData();
  }

  Future<void> _loadProducerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${constants.getBaseUrl()}/api/wellness/${widget.producerId}');
      print('🌐 URL de l\'API wellness: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Délai d'attente dépassé"),
      );
      
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
      print('❌ Erreur lors du chargement du lieu bien-être: $e');
      setState(() {
        _errorMessage = 'Impossible de charger les informations: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_producer?.name ?? 'Producteur Bien-être'),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _errorMessage != null 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadProducerData,
                        child: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                )
              : _buildProducerDetails(),
    );
  }

  Widget _buildProducerDetails() {
    if (_producer == null) {
      return const Center(child: Text('Aucune information disponible'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image principale
          if (_producer!.mainPhoto != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(_producer!.mainPhoto!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),
          
          // Nom et catégorie
          Text(
            _producer!.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (_producer!.category != null)
            Chip(
              label: Text(_producer!.category!),
              backgroundColor: Colors.green[100],
            ),
          const SizedBox(height: 16),
          
          // Coordonnées
          if (_producer!.address != null) 
            _buildInfoRow(Icons.location_on, _producer!.address!),
          if (_producer!.phone != null) 
            _buildInfoRow(Icons.phone, _producer!.phone!),
          if (_producer!.website != null) 
            _buildInfoRow(Icons.language, _producer!.website!),
          const SizedBox(height: 16),
          
          // Description
          if (_producer!.description != null) ...[
            const Text(
              'À propos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_producer!.description!),
            const SizedBox(height: 20),
          ],
          
          // Services
          if (_producer!.services != null && _producer!.services!.isNotEmpty) ...[
            const Text(
              'Services proposés',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...(_producer!.services!.map((service) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(service)),
                  ],
                ),
              )
            )),
          ]
        ],
      ),
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