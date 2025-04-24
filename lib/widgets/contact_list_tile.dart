import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // For base64Decode
import '../utils.dart' show getImageProvider, getColorForType, getIconForType, getTextForType; // Assuming utils exist

class ContactListTile extends StatelessWidget {
  final Map<String, dynamic> contact;
  final bool isDarkMode;
  final String currentUserId;
  final VoidCallback onTap; // Called when tile is tapped (usually start conversation)
  final VoidCallback? onProfileTap; // Optional: Called when avatar/name area is tapped

  const ContactListTile({
    Key? key,
    required this.contact,
    required this.isDarkMode,
    required this.currentUserId,
    required this.onTap,
    this.onProfileTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String contactType = contact['type']?.toString().toLowerCase() ?? 'user';
    final IconData typeIcon = getIconForType(contactType); // Util function needed
    final Color typeColor = getColorForType(contactType); // Util function needed
    final String typeText = getTextForType(contactType); // Util function needed

    Widget avatarWidget;
    String avatarUrl = contact['avatar'] ?? '';
    String contactName = contact['name'] ?? 'Contact Inconnu';

    // Prevent interaction if it's the current user (should be filtered out earlier, but safety check)
    final bool isCurrentUser = contact['id'] == currentUserId;

    try {
      if (avatarUrl.startsWith('data:image')) {
        final imageData = base64Decode(avatarUrl.split(',')[1]);
        avatarWidget = CircleAvatar(
          radius: 25,
          backgroundImage: MemoryImage(imageData),
          backgroundColor: Colors.grey[200],
        );
      } else if (avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true) {
        final imageProvider = getImageProvider(avatarUrl); // Util function needed
        avatarWidget = CircleAvatar(
          radius: 25,
          backgroundImage: imageProvider,
          backgroundColor: Colors.grey[200],
          onBackgroundImageError: (exception, stackTrace) {
            print("⚠️ Error loading image: $avatarUrl");
          },
          child: imageProvider == null // Check if provider is null
              ? Icon(typeIcon, size: 25, color: typeColor.withOpacity(0.7))
              : null,
        );
      } else {
        // Generate placeholder avatar
        avatarWidget = CircleAvatar(
          radius: 25,
          backgroundColor: typeColor.withOpacity(0.15),
          child: Text(
            contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
            style: TextStyle(fontSize: 20, color: typeColor, fontWeight: FontWeight.bold),
          ),
        );
      }
    } catch (e) {
      print("❌ Error building avatar: $e");
      avatarWidget = CircleAvatar( // Fallback placeholder
        radius: 25,
        backgroundColor: typeColor.withOpacity(0.15),
        child: Icon(typeIcon, size: 25, color: typeColor.withOpacity(0.7)),
      );
    }

    // Add a border around the avatar
    Widget finalAvatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: typeColor.withOpacity(0.5), width: 1.5),
      ),
      padding: const EdgeInsets.all(2), // Padding inside the border
      child: avatarWidget,
    );

    // Contact Type Chip
    Widget typeChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(typeIcon, size: 12, color: typeColor),
          const SizedBox(width: 4),
          Text(
            typeText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: typeColor,
            ),
          ),
        ],
      ),
    );

    final Color tileColor = isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Material(
      color: tileColor,
      child: InkWell(
        onTap: isCurrentUser ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onProfileTap, // Use dedicated profile tap callback
                child: finalAvatar,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                   onTap: onProfileTap, // Allow tapping name area for profile too
                   child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          typeChip,
                          // Add other relevant info like address if available
                          if (contact['address'] != null && contact['address'].toString().isNotEmpty)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  contact['address'],
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Action button (e.g., Chat icon)
              if (!isCurrentUser)
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline, color: typeColor),
                  tooltip: 'Démarrer la conversation',
                  onPressed: onTap,
                  iconSize: 22,
                )
              else
                 Padding(
                    padding: const EdgeInsets.only(right: 12.0), // Align with icon button space
                    child: Text("(Vous)", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                 )
            ],
          ),
        ),
      ),
    );
  }
} 