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

class _MyWellnessProducerProfileScreenState extends State<MyWellnessProducerProfileScreen> {
  final WellnessService _wellnessService = WellnessService();
  bool _isLoading = true;
  bool _isEditing = false;
  WellnessProducer? _producer;
  String? _error;

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

  @override
  void initState() {
    super.initState();
    _loadProducerData().then((_) {
      if (_producer != null) {
        _checkChoiceInterestStatus();
      }
    });
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

        await _checkChoiceInterestStatus();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur lors du chargement du profil: $e';
      });
    }
  }

  Future<void> _updateProducer() async {
    try {
      final updatedProducer = await _wellnessService.updateWellnessProducer(
        _producer!.id,
        _producer!.toJson(),
      );
      setState(() {
        _producer = WellnessProducer.fromJson(updatedProducer);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }

  Future<void> _updatePhotos(List<String> newPhotos) async {
    try {
      final updatedProducer = await _wellnessService.updateWellnessProducerPhotos(
        _producer!.id,
        newPhotos,
      );
      setState(() {
        _producer = WellnessProducer.fromJson(updatedProducer);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour des photos: $e')),
      );
    }
  }

  Future<void> _updateProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // TODO: Implémenter l'upload de l'image vers le serveur
      final photoUrl = '/uploads/wellness/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final updatedProducer = await _wellnessService.updateWellnessProducer(
        widget.producerId,
        {
          ..._producer!.toJson(),
          'profilePhoto': photoUrl,
        },
      );

      setState(() {
        _producer = WellnessProducer.fromJson(updatedProducer);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour de la photo: $e')),
      );
    }
  }

  Future<void> _addPhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isEmpty) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // TODO: Implémenter l'upload des images vers le serveur
      final photoUrls = images.map((image) =>
        '/uploads/wellness/${DateTime.now().millisecondsSinceEpoch}.jpg'
      ).toList();

      final updatedProducer = await _wellnessService.updateWellnessProducer(
        widget.producerId,
        {
          ..._producer!.toJson(),
          'photos': [..._producer!.photos, ...photoUrls],
        },
      );

      setState(() {
        _producer = WellnessProducer.fromJson(updatedProducer);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout des photos: $e')),
      );
    }
  }

  Future<void> _deletePhoto(int index) async {
    try {
      final updatedPhotos = List<String>.from(_producer!.photos);
      updatedPhotos.removeAt(index);

      final updatedProducer = await _wellnessService.updateWellnessProducer(
        widget.producerId,
        {
          ..._producer!.toJson(),
          'photos': updatedPhotos,
        },
      );

      setState(() {
        _producer = WellnessProducer.fromJson(updatedProducer);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression de la photo: $e')),
      );
    }
  }

  Widget _buildPhotoCard(String imageUrl, VoidCallback onDelete) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
        if (_isEditing)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: onDelete,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _producer!.photos.length,
      itemBuilder: (context, index) {
        return _buildPhotoCard(
          _producer!.photos[index],
          () => _deletePhoto(index),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                backgroundColor: Colors.green,
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
              onPressed: () {
                _toggleChoiceInterest();
              },
              icon: const Icon(Icons.favorite),
              label: Text(_isChoice ? 'Choisi !' : _isInterest ? 'Intéressé !' : 'Ajouter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isChoice
                    ? Colors.red
                    : _isInterest
                        ? Colors.orange
                        : Colors.green,
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

  void _toggleChoiceInterest() {
    setState(() {
      _isChoice = !_isChoice;
      _isInterest = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profil du Producteur'),
      ),
      body: _isLoading
          ? const CircularProgressIndicator()
          : _error != null
              ? Text('Erreur: $_error')
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Rest of the existing code...
                    ],
                  ),
                ),
    );
  }
}