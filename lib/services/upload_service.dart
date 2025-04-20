import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class UploadService {
  final AuthService _authService = AuthService();

  // Méthode pour obtenir le token (simulée si non disponible)
  Future<String> _getToken() async {
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        return token;
      }
      // Retourner un token fictif en cas d'échec
      return 'dummy_token';
    } catch (e) {
      print('Erreur lors de la récupération du token: $e');
      return 'dummy_token';
    }
  }

  // Méthode pour télécharger un fichier vers le serveur
  Future<String?> uploadFile(File file, String type, String conversationId) async {
    try {
      final token = await _getToken();
      
      // Détecter le type MIME du fichier
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      
      // Créer une requête multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/upload'),
      );
      
      // Ajouter les headers d'authentification
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });
      
      // Ajouter les champs nécessaires
      request.fields['conversationId'] = conversationId;
      request.fields['type'] = type;
      
      // Ajouter le fichier
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: path.basename(file.path),
          contentType: MediaType.parse(mimeType),
        ),
      );
      
      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Fichier téléchargé avec succès: ${data['fileUrl']}');
        return data['fileUrl'];
      } else {
        print('Erreur lors du téléchargement: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur lors du téléchargement: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception lors du téléchargement: $e');
      return null;
    }
  }
  
  // Ajout de la méthode uploadImage pour télécharger une image
  Future<String?> uploadImage(File imageFile) async {
    // Utiliser la méthode générique uploadFile pour télécharger l'image
    // avec le type 'image' pour identifier que c'est une image
    return await uploadFile(imageFile, 'image', 'general');
  }
  
  // Convertir un fichier en base64 (utile pour certains backends)
  Future<String> fileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
} 