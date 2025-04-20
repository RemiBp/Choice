import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync_service.dart';

class OfflineSyncScreen extends StatefulWidget {
  const OfflineSyncScreen({Key? key}) : super(key: key);

  @override
  _OfflineSyncScreenState createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends State<OfflineSyncScreen> {
  bool _isOnline = true;
  bool _isSyncing = false;
  bool _autoSync = true;
  DateTime? _lastSyncTime;
  List<Map<String, dynamic>> _pendingActions = [];
  late SyncService _syncService;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _syncService = SyncService();
    _loadSettings();
    _checkConnectivity();

    // Souscrire aux changements de connectivité
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Charger les paramètres sauvegardés
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSync = prefs.getBool('autoSync') ?? true;
      final lastSyncTimeStr = prefs.getString('lastSyncTime');
      _lastSyncTime = lastSyncTimeStr != null 
          ? DateTime.parse(lastSyncTimeStr) 
          : null;
    });
    
    // Charger les actions en attente
    await _loadPendingActions();
  }

  // Sauvegarder les paramètres
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSync', _autoSync);
    if (_lastSyncTime != null) {
      await prefs.setString('lastSyncTime', _lastSyncTime!.toIso8601String());
    }
  }

  // Vérifier l'état de la connectivité
  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
  }

  // Mettre à jour l'état de la connectivité
  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
    
    // Si connexion rétablie et auto-sync activé, lancer une synchronisation
    if (_isOnline && _autoSync && _pendingActions.isNotEmpty) {
      _syncData();
    }
  }

  // Charger les actions en attente de synchronisation
  Future<void> _loadPendingActions() async {
    final actions = await _syncService.getPendingActions();
    setState(() {
      _pendingActions = actions;
    });
  }

  // Synchroniser les données
  Future<void> _syncData() async {
    if (!_isOnline || _isSyncing || _pendingActions.isEmpty) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await _syncService.syncPendingActions();
      await _loadPendingActions(); // Recharger les actions restantes
      setState(() {
        _lastSyncTime = DateTime.now();
      });
      await _saveSettings(); // Sauvegarder le moment de la dernière synchro
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronisation réussie'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de synchronisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  // Effacer toutes les actions en attente
  Future<void> _clearPendingActions() async {
    // Demander confirmation
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer toutes les actions en attente ? '
          'Ces modifications seront perdues définitivement.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _syncService.clearPendingActions();
      await _loadPendingActions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Actions en attente supprimées'),
          ),
        );
      }
    }
  }

  // Formater le type d'action pour l'affichage
  String _formatActionType(String type) {
    switch (type) {
      case 'create':
        return 'Création';
      case 'update':
        return 'Modification';
      case 'delete':
        return 'Suppression';
      default:
        return type;
    }
  }

  // Formater la date pour l'affichage
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Aujourd\'hui à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return 'Hier à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isOnline && !_isSyncing ? _syncData : null,
            tooltip: 'Synchroniser maintenant',
          ),
        ],
      ),
      body: Column(
        children: [
          // Bannière d'état de connexion
          Container(
            color: _isOnline ? Colors.green : Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                ),
                const SizedBox(width: 8.0),
                Text(
                  _isOnline ? 'En ligne' : 'Hors ligne',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Statut de synchronisation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dernière synchronisation',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      _lastSyncTime != null 
                          ? _formatDate(_lastSyncTime!.toIso8601String())
                          : 'Jamais',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Switch(
                  value: _autoSync,
                  onChanged: (value) {
                    setState(() {
                      _autoSync = value;
                    });
                    _saveSettings();
                  },
                  activeColor: Colors.teal,
                ),
              ],
            ),
          ),
          
          // Divider
          const Divider(),
          
          // Paramètres de synchronisation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Synchronisation automatique',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Switch(
                  value: _autoSync,
                  onChanged: (value) {
                    setState(() {
                      _autoSync = value;
                    });
                    _saveSettings();
                  },
                  activeColor: Colors.teal,
                ),
              ],
            ),
          ),
          
          // Actions en attente
          Expanded(
            child: _pendingActions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64.0,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'Aucune action en attente',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Actions en attente (${_pendingActions.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 20.0),
                              label: const Text('Tout effacer'),
                              onPressed: _clearPendingActions,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _pendingActions.length,
                          itemBuilder: (context, index) {
                            final action = _pendingActions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  action['type'] == 'create'
                                      ? Icons.add_circle_outline
                                      : action['type'] == 'update'
                                          ? Icons.edit
                                          : Icons.delete_outline,
                                  color: action['type'] == 'create'
                                      ? Colors.green
                                      : action['type'] == 'update'
                                          ? Colors.blue
                                          : Colors.red,
                                ),
                                title: Text(
                                  action['entity'] ?? 'Entité inconnue',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatActionType(action['type']),
                                    ),
                                    Text(
                                      _formatDate(action['timestamp']),
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await _syncService.removePendingAction(index);
                                    await _loadPendingActions();
                                  },
                                  tooltip: 'Supprimer cette action',
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _isOnline && _pendingActions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSyncing ? null : _syncData,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Synchronisation...' : 'Synchroniser'),
              backgroundColor: _isSyncing ? Colors.grey : Colors.teal,
            )
          : null,
    );
  }
} 