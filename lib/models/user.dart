class User {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatar;
  final String? bio;
  final String? phoneNumber;
  final List<String> interests;
  final List<String> friends;
  final String? accountType;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? photo_url;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatar,
    this.bio,
    this.phoneNumber,
    this.interests = const [],
    this.friends = const [],
    this.accountType = 'user',
    this.isVerified = false,
    required this.createdAt,
    this.lastLogin,
    this.photo_url,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      avatar: json['avatar'],
      bio: json['bio'],
      phoneNumber: json['phoneNumber'],
      interests: json['interests'] != null
          ? List<String>.from(json['interests'])
          : [],
      friends: json['friends'] != null
          ? List<String>.from(json['friends'])
          : [],
      accountType: json['accountType'] ?? 'user',
      isVerified: json['isVerified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
      photo_url: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'avatar': avatar,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'interests': interests,
      'friends': friends,
      'accountType': accountType,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'photo_url': photo_url,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? avatar,
    String? bio,
    String? phoneNumber,
    List<String>? interests,
    List<String>? friends,
    String? accountType,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? photo_url,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      interests: interests ?? this.interests,
      friends: friends ?? this.friends,
      accountType: accountType ?? this.accountType,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      photo_url: photo_url ?? this.photo_url,
    );
  }

  String? get photoUrl => photo_url;

  // Générer un token JWT pour l'authentification
  String generateToken() {
    // Remarque: cette méthode est simplement ajoutée pour compatibilité avec le backend
    // En pratique, la génération de token se fait côté serveur
    throw UnimplementedError('Cette méthode est juste un placeholder pour le schéma. La vraie implémentation est côté serveur.');
  }
} 