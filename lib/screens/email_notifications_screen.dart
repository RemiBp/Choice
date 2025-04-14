import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart' as constants;
import '../services/auth_service.dart';
import '../utils/utils.dart';

class EmailNotificationsScreen extends StatefulWidget {
  final String userId;

  const EmailNotificationsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<EmailNotificationsScreen> createState() => _EmailNotificationsScreenState();
}

class _EmailNotificationsScreenState extends State<EmailNotificationsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  
  // Préférences de notifications
  bool _newMessages = true;
  bool _newFollowers = true;
  bool _eventReminders = true;
  bool _marketingEmails = false;
  bool _appUpdates = true;
  
  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }
  
  // Charger les préférences de notifications de l'utilisateur
  Future<void> _loadNotificationPreferences() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getTokenInstance();
      
      if (token == null || token.isEmpty) {
        throw Exception("Vous devez être connecté pour accéder à ces paramètres");
      }
      
      final baseUrl = await constants.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/${widget.userId}/notification-preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          // Si l'API renvoie des préférences existantes, les utiliser
          _newMessages = data['new_messages'] ?? true;
          _newFollowers = data['new_followers'] ?? true;
          _eventReminders = data['event_reminders'] ?? true;
          _marketingEmails = data['marketing_emails'] ?? false;
          _appUpdates = data['app_updates'] ?? true;
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // Si les préférences n'existent pas encore, utiliser les valeurs par défaut
        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception("Erreur lors du chargement des préférences: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      print('❌ Erreur lors du chargement des préférences: $e');
    }
  }
  
  // Sauvegarder les préférences de notifications
  Future<void> _saveNotificationPreferences() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getTokenInstance();
      
      if (token == null || token.isEmpty) {
        throw Exception("Vous devez être connecté pour modifier ces paramètres");
      }
      
      final baseUrl = await constants.getBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/${widget.userId}/notification-preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({
          'new_messages': _newMessages,
          'new_followers': _newFollowers,
          'event_reminders': _eventReminders,
          'marketing_emails': _marketingEmails,
          'app_updates': _appUpdates,
        }),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _isLoading = false;
        });
        
        // Afficher un message de confirmation
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.notifications_saved'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception("Erreur lors de la sauvegarde des préférences: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      // Afficher un message d'erreur
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.error_saving'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      
      print('❌ Erreur lors de la sauvegarde des préférences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile.notifications'.tr()),
        actions: [
          TextButton(
            onPressed: _saveNotificationPreferences,
            child: Text(
              'profile.save'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorView()
              : _buildNotificationSettings(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'profile.error_loading'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'profile.unknown_error'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadNotificationPreferences,
              child: Text('profile.try_again'.tr()),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotificationSettings() {
    return ListView(
      children: [
        const SizedBox(height: 12),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'profile.email_notifications'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        
        SwitchListTile(
          title: Text('profile.new_messages'.tr()),
          subtitle: Text('profile.new_messages_desc'.tr()),
          value: _newMessages,
          onChanged: (value) {
            setState(() {
              _newMessages = value;
            });
          },
        ),
        
        SwitchListTile(
          title: Text('profile.new_followers'.tr()),
          subtitle: Text('profile.new_followers_desc'.tr()),
          value: _newFollowers,
          onChanged: (value) {
            setState(() {
              _newFollowers = value;
            });
          },
        ),
        
        SwitchListTile(
          title: Text('profile.event_reminders'.tr()),
          subtitle: Text('profile.event_reminders_desc'.tr()),
          value: _eventReminders,
          onChanged: (value) {
            setState(() {
              _eventReminders = value;
            });
          },
        ),
        
        const Divider(),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'profile.marketing_preferences'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        
        SwitchListTile(
          title: Text('profile.marketing_emails'.tr()),
          subtitle: Text('profile.marketing_emails_desc'.tr()),
          value: _marketingEmails,
          onChanged: (value) {
            setState(() {
              _marketingEmails = value;
            });
          },
        ),
        
        SwitchListTile(
          title: Text('profile.app_updates'.tr()),
          subtitle: Text('profile.app_updates_desc'.tr()),
          value: _appUpdates,
          onChanged: (value) {
            setState(() {
              _appUpdates = value;
            });
          },
        ),
        
        const SizedBox(height: 20),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'profile.notifications_note'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _saveNotificationPreferences,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text('profile.save_preferences'.tr()),
          ),
        ),
      ],
    );
  }
}

// Écran d'historique des emails
class EmailHistoryScreen extends StatefulWidget {
  final String userId;

  const EmailHistoryScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<EmailHistoryScreen> createState() => _EmailHistoryScreenState();
}

class _EmailHistoryScreenState extends State<EmailHistoryScreen> {
  List<dynamic> _emailLogs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmailHistory();
  }

  // Charger l'historique des emails
  Future<void> _loadEmailHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/api/email/logs?userId=${widget.userId}&limit=50'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _emailLogs = data['data'] ?? [];
        });
      } else {
        setState(() {
          _error = 'Erreur lors du chargement de l\'historique: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Obtenir les en-têtes d'authentification
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('userToken');
    
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // Convertir le type d'email en texte lisible
  String _getEmailTypeLabel(String type) {
    switch (type) {
      case 'confirmation':
        return 'Confirmation';
      case 'password_reset':
        return 'Réinitialisation de mot de passe';
      case 'friend_requests':
        return 'Demandes d\'amitié';
      case 'nearby_events':
        return 'Événements à proximité';
      case 'restaurant_reco':
        return 'Recommandations de restaurants';
      case 'inactivity_reminder':
        return 'Rappel d\'inactivité';
      case 'activity_digest':
        return 'Digest bien-être';
      case 'marketing':
        return 'Marketing';
      case 'notification':
        return 'Notification';
      default:
        return type;
    }
  }

  // Obtenir une couleur en fonction du type d'email
  Color _getEmailTypeColor(String type) {
    switch (type) {
      case 'confirmation':
        return Colors.green;
      case 'password_reset':
        return Colors.red;
      case 'friend_requests':
        return Colors.blue;
      case 'nearby_events':
        return Colors.purple;
      case 'restaurant_reco':
        return Colors.orange;
      case 'inactivity_reminder':
        return Colors.amber;
      case 'activity_digest':
        return Colors.teal;
      case 'marketing':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  // Obtenir une icône en fonction du type d'email
  IconData _getEmailTypeIcon(String type) {
    switch (type) {
      case 'confirmation':
        return Icons.check_circle;
      case 'password_reset':
        return Icons.lock_reset;
      case 'friend_requests':
        return Icons.people;
      case 'nearby_events':
        return Icons.event;
      case 'restaurant_reco':
        return Icons.restaurant;
      case 'inactivity_reminder':
        return Icons.calendar_today;
      case 'activity_digest':
        return Icons.spa;
      case 'marketing':
        return Icons.local_offer;
      default:
        return Icons.email;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Emails'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmailHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _emailLogs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun email envoyé',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Les emails que vous recevrez apparaîtront ici',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _emailLogs.length,
                      itemBuilder: (context, index) {
                        final email = _emailLogs[index];
                        final String type = email['type'] ?? 'unknown';
                        final String subject = email['subject'] ?? 'Sans sujet';
                        final String status = email['status'] ?? 'sent';
                        final DateTime sentAt = DateTime.parse(email['sentAt'] ?? DateTime.now().toIso8601String());
                        final bool opened = email['opened'] ?? false;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getEmailTypeColor(type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getEmailTypeIcon(type),
                                color: _getEmailTypeColor(type),
                              ),
                            ),
                            title: Text(
                              subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getEmailTypeColor(type).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getEmailTypeLabel(type),
                                    style: TextStyle(
                                      color: _getEmailTypeColor(type),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Envoyé le ${sentAt.day}/${sentAt.month}/${sentAt.year} à ${sentAt.hour}:${sentAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: status == 'sent'
                                ? Icon(
                                    opened ? Icons.visibility : Icons.visibility_off,
                                    color: opened ? Colors.green : Colors.grey,
                                  )
                                : const Icon(Icons.error_outline, color: Colors.red),
                          ),
                        );
                      },
                    ),
    );
  }
} 
