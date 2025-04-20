import 'package:flutter/material.dart';
import 'package:choice_app/models/leisure_venue.dart';
import 'package:choice_app/screens/leisure_venue_detail_screen.dart';
import 'package:choice_app/services/map_service.dart';
import 'package:share_plus/share_plus.dart';

class LeisureVenueCard extends StatefulWidget {
  final LeisureVenue venue;

  const LeisureVenueCard({Key? key, required this.venue}) : super(key: key);

  @override
  _LeisureVenueCardState createState() => _LeisureVenueCardState();
}

class _LeisureVenueCardState extends State<LeisureVenueCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      // ... existing code ...
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () async {
                          await Share.share(
                            'Découvre ce lieu sur Choice: ${widget.venue.name}\nhttps://choiceapp.fr/venue/${widget.venue.id}',
                            subject: widget.venue.name,
                          );
                        },
                      ),
      // ... existing code ...
    );
  }
} 