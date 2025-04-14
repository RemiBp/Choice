import 'package:flutter/material.dart';

class CardItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData leadingIcon;

  const CardItem({
    Key? key,
    required this.title,
    required this.subtitle,
    this.leadingIcon = Icons.place, // Icône par défaut
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        leading: Icon(leadingIcon, color: Colors.blue),
      ),
    );
  }
}
