class Conversation {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<Participant> participants;
  final Message? lastMessage;
  final bool isGroup;
  final DateTime? updatedAt;
  final bool isMuted;
  final bool isPinned;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.participants,
    this.lastMessage,
    this.isGroup = false,
    this.updatedAt,
    this.isMuted = false,
    this.isPinned = false,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    List<Participant> participantsList = [];
    if (json['participants'] != null) {
      participantsList = List<Participant>.from(
        json['participants'].map((p) => Participant.fromJson(p)),
      );
    }

    return Conversation(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
      participants: participantsList,
      lastMessage: json['lastMessage'] != null ? Message.fromJson(json['lastMessage']) : null,
      isGroup: json['isGroup'] ?? false,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isMuted: json['isMuted'] ?? false,
      isPinned: json['isPinned'] ?? false,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'participants': participants.map((p) => p.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'isGroup': isGroup,
      'updatedAt': updatedAt?.toIso8601String(),
      'isMuted': isMuted,
      'isPinned': isPinned,
      'unreadCount': unreadCount,
    };
  }
}

class Participant {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isAdmin;

  Participant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isAdmin = false,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
      isAdmin: json['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'isAdmin': isAdmin,
    };
  }
}

class Message {
  final String id;
  final String senderId;
  final String? senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String type;
  final List<String>? mediaUrls;
  final Map<String, dynamic>? metadata;
  final List<Mention>? mentions;

  Message({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.type = 'text',
    this.mediaUrls,
    this.metadata,
    this.mentions,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Parse mentions if they exist
    List<Mention>? mentionsList;
    if (json['mentions'] != null) {
      mentionsList = List<Mention>.from(
        json['mentions'].map((m) => Mention.fromJson(m)),
      );
    }
    
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'],
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp']) 
        : DateTime.now(),
      isRead: json['isRead'] ?? false,
      type: json['type'] ?? 'text',
      mediaUrls: json['mediaUrls'] != null 
        ? List<String>.from(json['mediaUrls']) 
        : null,
      metadata: json['metadata'],
      mentions: mentionsList,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'type': type,
      'mediaUrls': mediaUrls,
      'metadata': metadata,
    };
    
    if (mentions != null) {
      data['mentions'] = mentions!.map((m) => m.toJson()).toList();
    }
    
    return data;
  }
}

class Mention {
  final String userId;
  final String username;
  final String? displayName;
  final int startIndex;
  final int endIndex;
  
  Mention({
    required this.userId,
    required this.username,
    this.displayName,
    required this.startIndex,
    required this.endIndex,
  });
  
  factory Mention.fromJson(Map<String, dynamic> json) {
    return Mention(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'],
      startIndex: json['startIndex'] ?? 0,
      endIndex: json['endIndex'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }
}
