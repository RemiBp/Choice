class Tag {
  final String id;
  final String name;
  final String? displayName;
  final String type; // 'user', 'place', 'hashtag'
  final String? avatarUrl;
  final Map<String, dynamic>? metadata;
  
  Tag({
    required this.id,
    required this.name,
    this.displayName,
    required this.type,
    this.avatarUrl,
    this.metadata,
  });
  
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'],
      type: json['type'] ?? 'hashtag',
      avatarUrl: json['avatarUrl'],
      metadata: json['metadata'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'type': type,
      'avatarUrl': avatarUrl,
      'metadata': metadata,
    };
  }
  
  // Create a user mention tag
  factory Tag.user(String id, String username, {String? displayName, String? avatarUrl}) {
    return Tag(
      id: id,
      name: username,
      displayName: displayName,
      type: 'user',
      avatarUrl: avatarUrl,
    );
  }
  
  // Create a place tag
  factory Tag.place(String id, String name, {String? displayName, Map<String, dynamic>? metadata}) {
    return Tag(
      id: id,
      name: name,
      displayName: displayName,
      type: 'place',
      metadata: metadata,
    );
  }
  
  // Create a hashtag
  factory Tag.hashtag(String name) {
    return Tag(
      id: name,
      name: name,
      type: 'hashtag',
    );
  }
  
  // Get the display format for the tag
  String get displayText {
    switch (type) {
      case 'user':
        return '@${displayName ?? name}';
      case 'place':
        return '@${displayName ?? name}';
      case 'hashtag':
        return '#$name';
      default:
        return name;
    }
  }
  
  // Convert tag to a mention for saving in a message
  Mention toMention(int startIndex, int endIndex) {
    return Mention(
      userId: id,
      username: name,
      displayName: displayName,
      startIndex: startIndex,
      endIndex: endIndex,
    );
  }
}
