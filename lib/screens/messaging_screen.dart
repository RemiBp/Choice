import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessagingScreen extends StatefulWidget {
  final String userId;
  
  const MessagingScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Temporary sample conversations for UI demonstration
  // Will be replaced with real data from the backend in production
  final List<Map<String, dynamic>> _sampleConversations = [
    {
      'id': '1',
      'name': 'Restaurant Chez Denis',
      'avatar': 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?w=150&h=150&fit=crop',
      'lastMessage': 'Bonjour ! Votre réservation pour ce soir est confirmée. À bientôt !',
      'time': DateTime.now().subtract(const Duration(minutes: 15)),
      'unreadCount': 1,
      'isRestaurant': true,
    },
    {
      'id': '2',
      'name': 'Sophie',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop',
      'lastMessage': 'J\'ai adoré le restaurant que tu m\'as recommandé !',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'unreadCount': 0,
      'isRestaurant': false,
    },
    {
      'id': '3',
      'name': 'Théâtre du Châtelet',
      'avatar': 'https://images.unsplash.com/photo-1578397491951-9de43db8e7bb?w=150&h=150&fit=crop',
      'lastMessage': 'Merci pour votre réservation. Votre billet électronique est joint.',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'unreadCount': 2,
      'isRestaurant': false,
      'isLeisure': true,
    },
    {
      'id': '4',
      'name': 'Thomas',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop',
      'lastMessage': 'On se retrouve à 20h devant le restaurant ?',
      'time': DateTime.now().subtract(const Duration(days: 2)),
      'unreadCount': 0,
      'isRestaurant': false,
    },
    {
      'id': '5',
      'name': 'Le Petit Bistrot',
      'avatar': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=150&h=150&fit=crop',
      'lastMessage': 'Nous avons une nouvelle offre spéciale pour les membres Choice !',
      'time': DateTime.now().subtract(const Duration(days: 3)),
      'unreadCount': 0,
      'isRestaurant': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            color: Colors.deepPurple[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.deepPurple[700]),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.deepPurple[700]),
            onPressed: () {
              // Show filter options
              _showFilterOptions();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Restaurants'),
            Tab(text: 'Loisirs'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher dans les messages...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                // Filter conversations based on search query
                // Implementation will be added when connected to real data
              },
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All messages
                _buildConversationList(_sampleConversations),
                
                // Restaurant messages
                _buildConversationList(_sampleConversations.where((c) => c['isRestaurant'] == true).toList()),
                
                // Leisure messages
                _buildConversationList(_sampleConversations.where((c) => c['isLeisure'] == true).toList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add_comment, color: Colors.white),
        onPressed: () {
          // Show new message dialog
          _showNewMessageDialog();
        },
      ),
    );
  }
  
  // Build conversation list
  Widget _buildConversationList(List<Map<String, dynamic>> conversations) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vos conversations apparaîtront ici',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _buildConversationTile(conversation);
      },
    );
  }
  
  // Build conversation tile
  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final bool hasUnread = (conversation['unreadCount'] ?? 0) > 0;
    final bool isRestaurant = conversation['isRestaurant'] == true;
    final bool isLeisure = conversation['isLeisure'] == true;
    
    // Format time
    final DateTime time = conversation['time'] as DateTime;
    final String formattedTime = _formatConversationTime(time);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: hasUnread ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasUnread 
            ? BorderSide(color: Colors.deepPurple.shade200, width: 1) 
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to conversation detail
          _navigateToConversationDetail(conversation);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with business type indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: CachedNetworkImageProvider(conversation['avatar']),
                  ),
                  if (isRestaurant || isLeisure)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isRestaurant ? Colors.amber : Colors.purple,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          isRestaurant ? Icons.restaurant : Icons.local_activity,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Conversation details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Name
                        Expanded(
                          child: Text(
                            conversation['name'],
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Time
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: hasUnread ? Colors.deepPurple : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Last message
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation['lastMessage'],
                            style: TextStyle(
                              color: hasUnread ? Colors.black87 : Colors.grey[600],
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              conversation['unreadCount'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Format conversation time
  String _formatConversationTime(DateTime time) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24 && now.day == time.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      // Get weekday index (1-7 where 1 is Monday) and adjust to 0-6 for array
      final dayIndex = time.weekday - 1;
      return weekDays[dayIndex];
    } else {
      return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
    }
  }
  
  // Show filter options dialog
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Filtrer les conversations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.deepPurple[700],
                ),
              ),
            ),
            _buildFilterOption(
              title: 'Tous les messages',
              icon: Icons.chat,
              isSelected: _tabController.index == 0,
              onTap: () {
                _tabController.animateTo(0);
                Navigator.pop(context);
              },
            ),
            _buildFilterOption(
              title: 'Restaurants uniquement',
              icon: Icons.restaurant,
              isSelected: _tabController.index == 1,
              onTap: () {
                _tabController.animateTo(1);
                Navigator.pop(context);
              },
            ),
            _buildFilterOption(
              title: 'Loisirs uniquement',
              icon: Icons.local_activity,
              isSelected: _tabController.index == 2,
              onTap: () {
                _tabController.animateTo(2);
                Navigator.pop(context);
              },
            ),
            _buildFilterOption(
              title: 'Messages non lus',
              icon: Icons.mark_email_unread,
              isSelected: false,
              onTap: () {
                // Filter for unread messages
                Navigator.pop(context);
                // Implementation will be added when connected to real data
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Build filter option
  Widget _buildFilterOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.deepPurple : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.deepPurple : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.deepPurple)
          : null,
      onTap: onTap,
    );
  }
  
  // Show new message dialog
  void _showNewMessageDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nouvelle conversation',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.deepPurple[700],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant, activité ou utilisateur...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Récents',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: _sampleConversations.take(3).map((contact) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(contact['avatar']),
                    ),
                    title: Text(contact['name']),
                    subtitle: Text(
                      contact['isRestaurant'] == true
                          ? 'Restaurant'
                          : (contact['isLeisure'] == true ? 'Loisir' : 'Utilisateur'),
                      style: TextStyle(
                        color: contact['isRestaurant'] == true
                            ? Colors.amber[700]
                            : (contact['isLeisure'] == true ? Colors.purple[700] : Colors.blue[700]),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToConversationDetail(contact);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Navigate to conversation detail
  void _navigateToConversationDetail(Map<String, dynamic> conversation) {
    // For now, we'll just show a snackbar indicating this would navigate to a chat
    // In the full implementation, this would navigate to a chat screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conversation avec ${conversation['name']}'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
}