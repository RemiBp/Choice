import 'package:flutter/material.dart';
import '../utils/translation_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/wellness_service.dart';
import '../models/wellness_producer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class WellnessProducerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> producerData;

  const WellnessProducerProfileScreen({
    Key? key,
    required this.producerData,
  }) : super(key: key);

  @override
  _WellnessProducerProfileScreenState createState() => _WellnessProducerProfileScreenState();
}

class _WellnessProducerProfileScreenState extends State<WellnessProducerProfileScreen> {
  final WellnessService _wellnessService = WellnessService();
  bool _isLoading = true;
  WellnessProducer? _producer;
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
      // If we have producer data provided directly
      if (widget.producerData.isNotEmpty) {
        setState(() {
          _producer = WellnessProducer.fromJson(widget.producerData);
          _isLoading = false;
        });
      } else {
        // Use API as fallback if needed
        final producerId = widget.producerData['_id'] ?? '';
        if (producerId.isNotEmpty) {
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/unified/$producerId'),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            setState(() {
              _producer = WellnessProducer.fromJson(data);
              _isLoading = false;
            });
          }
        } else {
          throw Exception('No producer ID found');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading profile: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Wellness Profile'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Wellness Profile'),
        ),
        body: Center(
          child: Text('Error: $_error'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_producer?.name ?? 'Wellness Profile'),
      ),
      body: _producer == null
          ? Center(child: Text('No data available'))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with profile image
                  Container(
                    height: 200,
                    width: double.infinity,
                    child: _producer!.profilePhoto.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _producer!.profilePhoto,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => Icon(Icons.error),
                          )
                        : Icon(Icons.spa, size: 100),
                  ),
                  
                  // Basic info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _producer!.name,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_producer!.rating > 0)
                              Row(
                                children: [
                                  Text(
                                    _producer!.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.star, color: Colors.amber, size: 20),
                                ],
                              ),
                          ],
                        ),
                        
                        // Category
                        Text(
                          '${_producer!.category} - ${_producer!.sous_categorie}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Description
                        if (_producer!.description.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _producer!.description,
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                          
                        // Contact info
                        Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        if (_producer!.address.isNotEmpty)
                          ListTile(
                            leading: Icon(Icons.location_on),
                            title: Text(_producer!.address),
                            contentPadding: EdgeInsets.zero,
                          ),
                        if (_producer!.phone.isNotEmpty)
                          ListTile(
                            leading: Icon(Icons.phone),
                            title: Text(_producer!.phone),
                            contentPadding: EdgeInsets.zero,
                            onTap: () => launch('tel:${_producer!.phone}'),
                          ),
                        if (_producer!.email.isNotEmpty)
                          ListTile(
                            leading: Icon(Icons.email),
                            title: Text(_producer!.email),
                            contentPadding: EdgeInsets.zero,
                            onTap: () => launch('mailto:${_producer!.email}'),
                          ),
                        if (_producer!.website.isNotEmpty)
                          ListTile(
                            leading: Icon(Icons.language),
                            title: Text(_producer!.website),
                            contentPadding: EdgeInsets.zero,
                            onTap: () => launch(_producer!.website),
                          ),
                          
                        SizedBox(height: 16),
                        
                        // Services
                        if (_producer!.services.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Services',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _producer!.services.map((service) => 
                                  Chip(
                                    label: Text(service),
                                    backgroundColor: Colors.green.shade100,
                                  )
                                ).toList(),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                          
                        // Photos
                        if (_producer!.photos.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gallery',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                height: 150,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _producer!.photos.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: _producer!.photos[index],
                                          width: 150,
                                          height: 150,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}