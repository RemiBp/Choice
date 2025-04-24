import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'myprofile_screen.dart'; // To navigate to user profiles
import '../utils/constants.dart' as constants;
import '../services/auth_service.dart'; // To get token
import 'package:provider/provider.dart' as provider_pkg;

class UserListScreen extends StatefulWidget {
  final String parentId; // ID of the User or Producer whose list this is
  final String listType; // e.g., 'followers', 'following', 'interested', 'choices'
  final List<String> initialUserIds; // Pass initial IDs if already available

  const UserListScreen({
    Key? key,
    required this.parentId,
    required this.listType,
    required this.initialUserIds,
  }) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    // Fetch detailed info for the initial IDs
    _usersFuture = _fetchMultipleUserInfo(widget.initialUserIds);
    // TODO: Implement logic to fetch IDs from backend if initialUserIds is empty or needs pagination
    // This might involve a new backend endpoint like /api/users/:parentId/:listType or /api/producers/:parentId/:listType
    print("UserListScreen initialized for parent ${widget.parentId}, type ${widget.listType}, with ${widget.initialUserIds.length} initial IDs.");
  }

  // Fetch minimal info for multiple users
  Future<List<Map<String, dynamic>>> _fetchMultipleUserInfo(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    if (!mounted) return [];

    print("🔄 Fetching minimal info for ${userIds.length} users...");
    
    // Fetch user info sequentially for now to avoid potential rate limiting
    // TODO: Implement a batch endpoint in the backend for better performance
    List<Map<String, dynamic>> usersInfo = [];
    for (String userId in userIds) {
      if (!mounted) return usersInfo; // Stop if widget is disposed
      final userInfo = await _fetchSingleUserInfo(userId);
      usersInfo.add(userInfo);
      // Small delay between requests
      await Future.delayed(const Duration(milliseconds: 50)); 
    }
    print("✅ Fetched info for ${usersInfo.length} users.");
    return usersInfo;
  }

  // Fetch minimal info for a single user (similar to _fetchMinimalUserInfo in MyProfileScreen)
  Future<Map<String, dynamic>> _fetchSingleUserInfo(String userId) async {
     if (!mounted) return {'_id': userId, 'name': '...', 'profilePicture': null, 'error': true};

     // Use context safely for Provider
     final authService = provider_pkg.Provider.of<AuthService>(context, listen: false);
     final token = await authService.getTokenInstance(forceRefresh: false);
     final baseUrl = constants.getBaseUrlSync(); // Use sync version here

     final headers = {
       'Content-Type': 'application/json',
       if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
     };

     try {
       // Use the /info endpoint
       final url = Uri.parse('$baseUrl/api/users/$userId/info');
       final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 7));

       if (!mounted) return {'_id': userId, 'name': 'Erreur', 'profilePicture': null, 'error': true};

       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         return {
           '_id': data['_id']?.toString() ?? userId,
           'name': data['name'] ?? 'Utilisateur',
           'profilePicture': data['profilePicture'] ?? data['avatar'], // Handle both keys
           'error': false,
         };
       } else {
         print('❌ Erreur récupération info utilisateur $userId (${response.statusCode})');
         return {'_id': userId, 'name': 'Erreur ${response.statusCode}', 'profilePicture': null, 'error': true};
       }
     } catch (e) {
       print('❌ Exception récupération info utilisateur $userId: $e');
       if (!mounted) return {'_id': userId, 'name': 'Erreur réseau', 'profilePicture': null, 'error': true};
       return {'_id': userId, 'name': 'Erreur réseau', 'profilePicture': null, 'error': true};
     }
   }

  @override
  Widget build(BuildContext context) {
    // Determine the title based on listType
    String title = widget.listType;
    switch (widget.listType.toLowerCase()) {
      case 'followers':
        title = 'Abonnés';
        break;
      case 'following':
        title = 'Abonnements';
        break;
      case 'interested':
        title = 'Intéressés';
        break;
      case 'choices':
        title = 'Auteurs des Choices'; // Or just 'Choices'
        break;
      // Add more cases if needed
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Erreur de chargement: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('Cette liste est vide.'),
            );
          } else {
            final users = snapshot.data!;
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final userInfo = users[index];
                final userId = userInfo['_id']?.toString() ?? '';
                final hasError = userInfo['error'] == true;

                Widget leadingWidget;
                Widget titleWidget;
                Widget? subtitleWidget;
                VoidCallback? onTapAction;

                if (hasError) {
                  leadingWidget = const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.error_outline, color: Colors.white));
                  titleWidget = Text('Erreur chargement');
                  subtitleWidget = Text('ID: $userId', style: TextStyle(fontSize: 10, color: Colors.red));
                } else {
                  final profilePic = userInfo['profilePicture'];
                  final userName = userInfo['name'] ?? 'Utilisateur inconnu';
                  leadingWidget = CircleAvatar(
                    radius: 25, // Slightly larger
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (profilePic != null && profilePic is String && profilePic.isNotEmpty)
                        ? CachedNetworkImageProvider(profilePic)
                        : null,
                    child: (profilePic == null || !(profilePic is String) || profilePic.isEmpty)
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  );
                  titleWidget = Text(userName, style: TextStyle(fontWeight: FontWeight.w500));
                  subtitleWidget = null; // Or add user bio/handle if available
                  onTapAction = () {
                    // Navigate to the user's profile
                     if (userId.isNotEmpty) {
                       print("Navigating to profile: $userId");
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           // Assuming the current user ID is accessible via AuthService or similar
                           builder: (context) => MyProfileScreen(
                             userId: userId,
                             // Determine if this is the current user viewing their own list?
                             // isCurrentUser: userId == context.read<AuthService>().userId, // Example
                           ),
                         ),
                       );
                     } else {
                        print("User ID is empty, cannot navigate.");
                     }
                  };
                }

                return ListTile(
                  leading: leadingWidget,
                  title: titleWidget,
                  subtitle: subtitleWidget,
                  trailing: onTapAction != null ? const Icon(Icons.chevron_right) : null,
                  onTap: onTapAction,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                );
              },
            );
          }
        },
      ),
    );
  }
} 