import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/wellness_service.dart';
import '../models/wellness_producer.dart';
import 'wellness_profile_screen.dart';
import '../utils/api_config.dart';

class WellnessListScreen extends StatefulWidget {
  const WellnessListScreen({Key? key}) : super(key: key);

  @override
  _WellnessListScreenState createState() => _WellnessListScreenState();
}

class _WellnessListScreenState extends State<WellnessListScreen> {
  final WellnessService _wellnessService = WellnessService();
  List<WellnessProducer> _producers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadProducers();
  }

  Future<void> _loadProducers() async {
    try {
      final producers = await _wellnessService.getWellnessProducers();
      setState(() {
        _producers = producers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<WellnessProducer> _filterProducers() {
    return _producers.where((producer) {
      if (_searchQuery.isNotEmpty) {
        return producer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               producer.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               producer.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               producer.sousCategory.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      if (_selectedCategory != null) {
        return producer.category == _selectedCategory;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bien-être',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un établissement...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filtres de catégories
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip('Tous'),
                _buildCategoryChip('Soins esthétiques et bien-être'),
                _buildCategoryChip('Coiffure et soins capillaires'),
                _buildCategoryChip('Onglerie et modifications corporelles'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Liste des producteurs
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Erreur: $_error'))
                    : _filterProducers().isEmpty
                        ? Center(
                            child: Text(
                              'Aucun établissement trouvé',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filterProducers().length,
                            itemBuilder: (context, index) {
                              final producer = _filterProducers()[index];
                              return _buildProducerCard(producer);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.deepPurple[100],
        labelStyle: GoogleFonts.poppins(
          color: isSelected ? Colors.deepPurple : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildProducerCard(WellnessProducer producer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(producer.profilePhoto),
          radius: 30,
        ),
        title: Text(producer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${producer.category} - ${producer.sousCategory}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              producer.address,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 16),
            Text(
              producer.rating.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WellnessProfileScreen(producerId: producer.id),
            ),
          );
        },
      ),
    );
  }
} 