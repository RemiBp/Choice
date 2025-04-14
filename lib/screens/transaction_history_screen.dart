import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/payment_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String producerId;

  const TransactionHistoryScreen({Key? key, required this.producerId}) : super(key: key);

  @override
  _TransactionHistoryScreenState createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  Map<String, dynamic> _historyData = {};
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactionHistory();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTransactionHistory() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final historyData = await _paymentService.getTransactionHistory(widget.producerId);
      if (mounted) {
        setState(() {
          _historyData = historyData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement de l\'historique : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique financier'),
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Abonnements'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(),
    );
  }
  
  Widget _buildContent() {
    final transactions = _historyData['transactions'] as List<dynamic>? ?? [];
    final subscriptionHistory = _historyData['subscription_history'] as List<dynamic>? ?? [];
    final currentSubscription = _historyData['current_subscription'] as Map<String, dynamic>? ?? {};
    
    return Column(
      children: [
        // Current subscription banner
        _buildCurrentSubscriptionBanner(currentSubscription),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Transactions tab
              transactions.isEmpty
                ? _buildEmptyState('Aucune transaction trouvée', Icons.receipt_long)
                : _buildTransactionsList(transactions),
              
              // Subscription history tab
              subscriptionHistory.isEmpty
                ? _buildEmptyState('Aucun historique d\'abonnement trouvé', Icons.history)
                : _buildSubscriptionHistoryList(subscriptionHistory),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildCurrentSubscriptionBanner(Map<String, dynamic> subscription) {
    final level = subscription['level']?.toString() ?? 'gratuit';
    final statusText = subscription['status']?.toString() ?? 'active';
    
    Color bannerColor = _paymentService.getSubscriptionColor(level);
    IconData iconData = _paymentService.getSubscriptionIcon(level);
    
    // Format dates
    String startDate = 'N/A';
    String endDate = 'N/A';
    
    if (subscription['start_date'] != null) {
      startDate = _paymentService.formatDate(subscription['start_date']);
    }
    
    if (subscription['end_date'] != null) {
      endDate = _paymentService.formatDate(subscription['end_date']);
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bannerColor.withOpacity(0.7), bannerColor.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abonnement ${_paymentService.formatSubscriptionLevel(level)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusText == 'active' ? 'Actif' : statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date de début',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    startDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Prochain renouvellement',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    endDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionsList(List<dynamic> transactions) {
    // Sort transactions by date (most recent first)
    transactions.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    
    return RefreshIndicator(
      onRefresh: _loadTransactionHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index] as Map<String, dynamic>;
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }
  
  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = transaction['amount']?.toString() ?? '0';
    final currency = transaction['currency']?.toString() ?? 'EUR';
    final status = transaction['status']?.toString() ?? 'pending';
    final type = transaction['type']?.toString() ?? 'unknown';
    final description = transaction['description']?.toString() ?? 'Transaction';
    final dateString = transaction['created_at']?.toString();
    
    final formattedDate = dateString != null 
        ? _paymentService.formatDate(dateString)
        : 'Date inconnue';
    
    final formattedStatus = _paymentService.formatTransactionStatus(status);
    final statusColor = _paymentService.getTransactionStatusColor(status);
    
    // Icon based on transaction type
    IconData transactionIcon = Icons.receipt;
    if (type == 'subscription') {
      transactionIcon = Icons.subscriptions;
    } else if (type == 'refund') {
      transactionIcon = Icons.money_off;
    } else if (type == 'one_time') {
      transactionIcon = Icons.shopping_cart;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(transactionIcon, color: Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '$amount $currency',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'ID: ',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      transaction['transaction_id']?.toString().substring(0, 12) ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formattedStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubscriptionHistoryList(List<dynamic> history) {
    // Sort subscription history by date (most recent first)
    history.sort((a, b) {
      final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    
    return RefreshIndicator(
      onRefresh: _loadTransactionHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index] as Map<String, dynamic>;
          return _buildSubscriptionHistoryCard(item);
        },
      ),
    );
  }
  
  Widget _buildSubscriptionHistoryCard(Map<String, dynamic> historyItem) {
    final previousLevel = historyItem['previous_level']?.toString() ?? 'inconnu';
    final newLevel = historyItem['new_level']?.toString() ?? 'inconnu';
    final reason = historyItem['reason']?.toString() ?? 'modification';
    final dateString = historyItem['date']?.toString();
    
    final formattedDate = dateString != null 
        ? _paymentService.formatDate(dateString)
        : 'Date inconnue';
    
    // Format reason
    String formattedReason = 'Changement d\'abonnement';
    if (reason == 'user_upgrade') {
      formattedReason = 'Modification par l\'utilisateur';
    } else if (reason == 'payment_successful') {
      formattedReason = 'Paiement réussi';
    } else if (reason == 'admin_change') {
      formattedReason = 'Modification par l\'administrateur';
    }
    
    // Colors for levels
    final previousColor = _paymentService.getSubscriptionColor(previousLevel);
    final newColor = _paymentService.getSubscriptionColor(newLevel);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: newColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.upgrade,
                    color: newColor,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedReason,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: previousColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _paymentService.formatSubscriptionLevel(previousLevel),
                        style: TextStyle(
                          color: previousColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Précédent',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.grey,
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: newColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _paymentService.formatSubscriptionLevel(newLevel),
                        style: TextStyle(
                          color: newColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nouveau',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'ID: ${historyItem['subscription_id']?.toString().substring(0, 12) ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 