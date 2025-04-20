import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'feed_screen.dart';

class HomeScreen extends StatelessWidget {
  final String userId; // Ajoutez un paramètre pour passer l'utilisateur connecté.

  const HomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FeedScreen(userId: userId); // Charge directement le feed en tant que page principale.
  }
}
