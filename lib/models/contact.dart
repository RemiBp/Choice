class Contact {
  final String? id;
  final String? name;
  final String? avatar;
  final String? email;
  final String? type;
  final String? producerType;
  final bool isOnline;
  final String? lastSeen;
  final String? phone;
  final String? address;

  Contact({
    this.id,
    this.name,
    this.avatar,
    this.email,
    this.type,
    this.producerType,
    this.isOnline = false,
    this.lastSeen,
    this.phone,
    this.address,
  });

  // Créer un Contact à partir d'un Map
  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] ?? map['_id'] ?? '',
      name: map['name'] ?? map['username'] ?? map['businessName'] ?? 'Sans nom',
      avatar: map['avatar'] ?? map['profilePicture'] ?? map['photo_url'] ?? '',
      email: map['email'] ?? '',
      type: map['type'] ?? 'user',
      producerType: map['producerType'] ?? map['type'] ?? 'user',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'],
      phone: map['phone'] ?? map['phoneNumber'] ?? '',
      address: map['address'] ?? map['adresse'] ?? '',
    );
  }

  // Convertir un Contact en Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'email': email,
      'type': type,
      'producerType': producerType,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'phone': phone,
      'address': address,
    };
  }
} 