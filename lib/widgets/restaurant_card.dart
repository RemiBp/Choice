import 'package:flutter/material.dart';
import 'package:choice_app/models/restaurant.dart';
import 'package:choice_app/screens/restaurant_detail_screen.dart';
import 'package:choice_app/services/map_service.dart';
import 'package:share_plus/share_plus.dart';

class RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantCard({Key? key, required this.restaurant}) : super(key: key);

  @override
  _RestaurantCardState createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      // ... existing code ...
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () async {
                          await Share.share(
                            'Découvre ce restaurant sur Choice: ${widget.restaurant.name}\nhttps://choiceapp.fr/restaurant/${widget.restaurant.id}',
                            subject: widget.restaurant.name,
                          );
                        },
                      ),
      // ... existing code ...
    );
  }
} 