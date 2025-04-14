import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SharingService {
  // Singleton
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  // Partager du texte simple
  Future<void> shareText({
    required String text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Erreur lors du partage de texte: $e');
      rethrow;
    }
  }

  // Partager un lien avec une image de prévisualisation
  Future<void> shareLink({
    required String url,
    required String title,
    String? description,
    String? imageUrl,
    Rect? sharePositionOrigin,
  }) async {
    try {
      String textToShare = title;
      
      if (description != null && description.isNotEmpty) {
        textToShare += '\n\n$description';
      }
      
      textToShare += '\n\n$url';
      
      // Si une image est fournie et nous ne sommes pas sur le web, télécharger l'image
      if (imageUrl != null && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final imageBytes = await _downloadImage(imageUrl);
        if (imageBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/share_image.jpg');
          await file.writeAsBytes(imageBytes);
          
          await Share.shareXFiles(
            [XFile(file.path)],
            text: textToShare,
            subject: title,
            sharePositionOrigin: sharePositionOrigin,
          );
          return;
        }
      }
      
      // Partage sans image
      await Share.share(
        textToShare,
        subject: title,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Erreur lors du partage de lien: $e');
      rethrow;
    }
  }
  
  // Partager une image avec du texte
  Future<void> shareImage({
    required String imageUrl,
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      if (kIsWeb) {
        // Sur le web, partager uniquement le texte avec le lien de l'image
        await Share.share(
          '${text ?? ''}\n\n$imageUrl',
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }
      
      // Sur mobile, télécharger et partager l'image
      final imageBytes = await _downloadImage(imageUrl);
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/share_image.jpg');
        await file.writeAsBytes(imageBytes);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: text,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        // Si le téléchargement a échoué, partager uniquement le texte
        await Share.share(
          '${text ?? ''}\n\n$imageUrl',
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors du partage d\'image: $e');
      rethrow;
    }
  }
  
  // Partager un événement
  Future<void> shareEvent({
    required String eventId,
    required String eventName,
    required String eventDate,
    String? eventLocation,
    String? eventImageUrl,
    String? eventDescription,
    Rect? sharePositionOrigin,
  }) async {
    try {
      // Créer le texte à partager
      String text = 'Événement: $eventName\n';
      text += 'Date: $eventDate\n';
      
      if (eventLocation != null && eventLocation.isNotEmpty) {
        text += 'Lieu: $eventLocation\n';
      }
      
      if (eventDescription != null && eventDescription.isNotEmpty) {
        text += '\n$eventDescription\n';
      }
      
      // Ajouter le lien vers l'événement
      final eventUrl = 'https://choice.app/event/$eventId';
      text += '\nVoir les détails: $eventUrl';
      
      // Si une image est fournie et nous ne sommes pas sur le web, télécharger l'image
      if (eventImageUrl != null && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final imageBytes = await _downloadImage(eventImageUrl);
        if (imageBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/event_image.jpg');
          await file.writeAsBytes(imageBytes);
          
          await Share.shareXFiles(
            [XFile(file.path)],
            text: text,
            subject: 'Événement: $eventName',
            sharePositionOrigin: sharePositionOrigin,
          );
          return;
        }
      }
      
      // Partage sans image
      await Share.share(
        text,
        subject: 'Événement: $eventName',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Erreur lors du partage d\'événement: $e');
      rethrow;
    }
  }
  
  // Partager un contact
  Future<void> shareContact({
    required String contactId,
    required String contactName,
    String? contactEmail,
    String? contactPhone,
    String? contactPhotoUrl,
    String? contactDescription,
    Rect? sharePositionOrigin,
  }) async {
    try {
      // Créer le texte à partager
      String text = 'Contact: $contactName\n';
      
      if (contactEmail != null && contactEmail.isNotEmpty) {
        text += 'Email: $contactEmail\n';
      }
      
      if (contactPhone != null && contactPhone.isNotEmpty) {
        text += 'Téléphone: $contactPhone\n';
      }
      
      if (contactDescription != null && contactDescription.isNotEmpty) {
        text += '\n$contactDescription\n';
      }
      
      // Ajouter le lien vers le contact
      final contactUrl = 'https://choice.app/contact/$contactId';
      text += '\nVoir le profil: $contactUrl';
      
      // Si une photo est fournie et nous ne sommes pas sur le web, télécharger l'image
      if (contactPhotoUrl != null && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final imageBytes = await _downloadImage(contactPhotoUrl);
        if (imageBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/contact_photo.jpg');
          await file.writeAsBytes(imageBytes);
          
          await Share.shareXFiles(
            [XFile(file.path)],
            text: text,
            subject: 'Contact: $contactName',
            sharePositionOrigin: sharePositionOrigin,
          );
          return;
        }
      }
      
      // Partage sans image
      await Share.share(
        text,
        subject: 'Contact: $contactName',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Erreur lors du partage de contact: $e');
      rethrow;
    }
  }
  
  // Partager directement sur Facebook (ouvre l'application ou le site web)
  Future<void> shareToFacebook({
    required String url,
    Rect? sharePositionOrigin,
  }) async {
    final fbUrl = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}');
    
    if (await canLaunchUrl(fbUrl)) {
      await launchUrl(fbUrl, mode: LaunchMode.externalApplication);
    } else {
      // Si l'URL ne peut pas être lancée, utiliser le partage standard
      await shareText(
        text: 'Consultez: $url',
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }
  
  // Partager directement sur WhatsApp (ouvre l'application ou le site web)
  Future<void> shareToWhatsApp({
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    final encodedText = Uri.encodeComponent(text);
    Uri whatsappUrl;
    
    if (Platform.isIOS) {
      whatsappUrl = Uri.parse('whatsapp://send?text=$encodedText');
    } else {
      whatsappUrl = Uri.parse('https://wa.me/?text=$encodedText');
    }
    
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      // Si l'URL ne peut pas être lancée, utiliser le partage standard
      await shareText(
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }
  
  // Partager directement sur Twitter/X (ouvre l'application ou le site web)
  Future<void> shareToTwitter({
    required String text,
    String? url,
    String? hashtags,
    Rect? sharePositionOrigin,
  }) async {
    String twitterUrl = 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}';
    
    if (url != null && url.isNotEmpty) {
      twitterUrl += '&url=${Uri.encodeComponent(url)}';
    }
    
    if (hashtags != null && hashtags.isNotEmpty) {
      twitterUrl += '&hashtags=${Uri.encodeComponent(hashtags)}';
    }
    
    final twitterUri = Uri.parse(twitterUrl);
    
    if (await canLaunchUrl(twitterUri)) {
      await launchUrl(twitterUri, mode: LaunchMode.externalApplication);
    } else {
      // Si l'URL ne peut pas être lancée, utiliser le partage standard
      String textToShare = text;
      if (url != null && url.isNotEmpty) {
        textToShare += '\n\n$url';
      }
      if (hashtags != null && hashtags.isNotEmpty) {
        textToShare += '\n\n$hashtags';
      }
      
      await shareText(
        text: textToShare,
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }
  
  // Partager directement sur Instagram (ouvre l'application ou le site web)
  Future<void> shareToInstagram({
    String? imageUrl,
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    // Instagram ne permet pas de partager directement du texte via une URL,
    // mais on peut ouvrir l'application
    final instagramUrl = Uri.parse('instagram://');
    
    if (await canLaunchUrl(instagramUrl)) {
      // Ouvrir Instagram
      await launchUrl(instagramUrl, mode: LaunchMode.externalApplication);
      
      // Afficher un message pour guider l'utilisateur
      debugPrint('Instagram a été ouvert. L\'utilisateur doit partager manuellement le contenu.');
    } else {
      // Si Instagram n'est pas installé, utiliser le partage standard
      String textToShare = text ?? '';
      if (imageUrl != null && imageUrl.isNotEmpty) {
        textToShare += '\n\n$imageUrl';
      }
      
      await shareText(
        text: textToShare,
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }
  
  // Télécharger une image à partir d'une URL
  Future<Uint8List?> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors du téléchargement de l\'image: $e');
      return null;
    }
  }
} 