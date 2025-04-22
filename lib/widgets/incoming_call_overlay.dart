import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils.dart' show getImageProvider; // Assuming getImageProvider exists

class IncomingCallOverlay extends StatelessWidget {
  final String callId;
  final String callerName;
  final String? callerAvatar;
  final String callType; // 'audio' or 'video'
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallOverlay({
    Key? key,
    required this.callId,
    required this.callerName,
    this.callerAvatar,
    required this.callType,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isVideoCall = callType == 'video';
    final Color primaryColor = Theme.of(context).colorScheme.primary; // Or define your primary color

    return Material(
      color: Colors.black.withOpacity(0.6), // Semi-transparent background
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Position at the top
            children: [
              Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Appel ${isVideoCall ? "vidéo" : "audio"} entrant...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: getImageProvider(callerAvatar),
                        backgroundColor: Colors.grey.shade300,
                        child: getImageProvider(callerAvatar) == null
                            ? Icon(Icons.person, size: 40, color: Colors.grey.shade500)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        callerName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Decline Button
                          _buildCallActionButton(
                            icon: Icons.call_end,
                            label: 'Refuser',
                            color: Colors.white,
                            backgroundColor: Colors.redAccent,
                            onPressed: onDecline,
                          ),
                          // Accept Button
                          _buildCallActionButton(
                            icon: isVideoCall ? Icons.videocam : Icons.call,
                            label: 'Accepter',
                            color: Colors.white,
                            backgroundColor: Colors.green,
                            onPressed: onAccept,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label, // Unique heroTag for each button
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
} 