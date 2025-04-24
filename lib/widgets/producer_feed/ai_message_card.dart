import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/dialogic_ai_message.dart';

// Placeholder AI Message Card Widget
class AIMessageCard extends StatelessWidget {
  final DialogicAIMessage message;
  const AIMessageCard({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_outlined, // Or Icons.auto_awesome or other AI icon
                color: Colors.deepPurple.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Message Content
            Expanded(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(
                      'Choice AI Insight', // Title for the card
                       style: GoogleFonts.poppins(
                           fontWeight: FontWeight.bold,
                           fontSize: 15,
                           color: Colors.deepPurple.shade900,
                       ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.content,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.black87,
                      ),
                    ),
                  ]
              )
            ),
          ],
        ),
      ),
    );
  }
} 