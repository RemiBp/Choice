import 'package:flutter/material.dart';
import 'package:choice_app/models/restaurant_item.dart';
import 'package:choice_app/services/map_service.dart';
import 'package:share_plus/share_plus.dart';

class RestaurantItemCard extends StatefulWidget {
  final RestaurantItem item;

  const RestaurantItemCard({Key? key, required this.item}) : super(key: key);

  @override
  _RestaurantItemCardState createState() => _RestaurantItemCardState();
}

class _RestaurantItemCardState extends State<RestaurantItemCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      // ... existing code ...
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () async {
                          await Share.share(
                            'Découvre ce plat sur Choice: ${widget.item.name} au restaurant ${widget.item.restaurantName}\nhttps://choiceapp.fr/item/${widget.item.id}',
                            subject: widget.item.name,
                          );
                        },
                      ),
// ... existing code ...
    );
  }
} 