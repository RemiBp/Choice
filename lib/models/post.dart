import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:choice_app/models/media.dart' as app_media;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'comment.dart';

// Renommer la classe Media en PostMedia pour éviter les conflits
class PostMedia {
  final String url;
  final String type;  // 'image', 'video', etc.
  final String? thumbnailUrl;
  final String? id;

  PostMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.id,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
      thumbnailUrl: json['thumbnailUrl'],
      id: json['id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'id': id,
    };
  }

  PostMedia copyWithUrl(String newUrl) {
    return PostMedia(
      url: newUrl,
      type: this.type,
      thumbnailUrl: this.thumbnailUrl,
      id: this.id,
    );
  }
}

// Classe Post complète avec tous les attributs nécessaires
class Post {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? imageUrl;
  final DateTime createdAt;
  final String? location;
  final String? locationName;
  final String description;
  int likes;
  final List<Comment> comments;
  bool isLiked;
  final String? category;
  final Map<String, dynamic>? metadata;
  
  // Champs supplémentaires pour la compatibilité
  int likesCount;
  int interestedCount;
  final int choiceCount;
  bool? isInterested;
  final bool? isChoice;
  final bool? isProducerPost;
  final bool? isLeisureProducer;
  final bool? isBeautyProducer;  // Ajout du type beauté
  final bool? isRestaurationProducer;  // Ajout du type restauration
  final bool? isAutomated;
  final String? targetId;
  final String? referencedEventId;
  final String title;
  final String? subtitle;
  final String? content;
  final String? authorId;
  final String? authorName;
  final String? authorAvatar;
  final DateTime? postedAt;
  final List<app_media.Media> media;
  
  // Nouveaux champs ajoutés pour corriger les erreurs
  final List<String>? tags;
  final List<String>? mediaUrls;
  final int commentsCount;
  final String? type;
  final dynamic author; // Pour compatibilité avec post.author
  
  // Ajout de la propriété pour le score de pertinence
  double? relevanceScore;

  // Ajout de setters pour permettre la modification de certains champs
  set setIsLiked(bool value) {
    isLiked = value;
  }
  
  set setLikesCount(int value) {
    likesCount = value;
    likes = value; // Synchroniser les deux propriétés
  }
  
  set setIsInterested(bool? value) {
    isInterested = value;
  }
  
  set setInterestedCount(int value) {
    interestedCount = value;
  }

  final String? producerId;
  final String? url;

  Post({
    required this.id,
    this.userId = '',
    this.userName = 'Utilisateur', 
    this.userPhotoUrl,
    this.imageUrl,
    required this.createdAt,
    this.location,
    this.locationName,
    required this.description,
    this.likes = 0,
    this.comments = const [],
    this.isLiked = false,
    this.category,
    this.metadata,
    // Champs supplémentaires
    this.likesCount = 0,
    this.interestedCount = 0,
    this.choiceCount = 0,
    this.isInterested,
    this.isChoice,
    this.isProducerPost,
    this.isLeisureProducer,
    this.isBeautyProducer,
    this.isRestaurationProducer,
    this.isAutomated,
    this.targetId,
    this.referencedEventId,
    this.title = '',
    this.subtitle,
    this.content,
    this.authorId,
    this.authorName,
    this.authorAvatar,
    this.postedAt,
    this.media = const [],
    // Nouveaux champs
    this.tags,
    this.mediaUrls,
    this.commentsCount = 0,
    this.type,
    this.author,
    this.relevanceScore,
    this.producerId,
    this.url,
  });

  // Accesseurs supplémentaires pour assurer la compatibilité
  String get author_id => authorId ?? userId;
  String get author_name => authorName ?? userName;
  String get author_photo => authorAvatar ?? userPhotoUrl ?? '';
  DateTime get posted_at => postedAt ?? createdAt;
  String get post_content => content ?? description;
  
  // Ajouter un getter pour producerType
  String? get producerType {
    if (isBeautyProducer == true) return 'wellness';
    if (isLeisureProducer == true) return 'leisure';
    if (isRestaurationProducer == true || isProducerPost == true) return 'restaurant';
    return type;
  }
  
  // Accesseurs pour déterminer le type de producteur
  bool get isRestaurantProducer => isRestaurationProducer ?? false;
  bool get isBeautyPlace => isBeautyProducer ?? false;
  
  // Méthode pour obtenir la couleur correspondante au type de post
  Color getTypeColor() {
    if (isBeautyProducer == true || isBeautyPlace == true) {
      return Colors.green.shade700;  // Vert pour beauté/bien-être
    } else if (isLeisureProducer == true) {
      return Colors.purple.shade700;  // Violet pour loisir
    } else if (isProducerPost == true || isRestaurationProducer == true) {
      return Colors.amber.shade700;  // Orange/Jaune pour restauration
    } else {
      return Colors.blue.shade700;  // Bleu pour utilisateur standard
    }
  }
  
  // Méthode pour obtenir l'icône correspondante au type de post
  IconData getTypeIcon() {
    if (isBeautyProducer == true) {
      return Icons.spa;  // Icône de spa pour beauté/bien-être
    } else if (isLeisureProducer == true) {
      return Icons.local_activity;  // Icône d'activité pour loisir
    } else if (isRestaurationProducer == true) {
      return Icons.restaurant;  // Icône de restaurant pour restauration
    } else {
      return Icons.person;  // Icône de personne pour utilisateur standard
    }
  }
  
  // Méthode pour obtenir le libellé du type de post
  String getTypeLabel() {
    if (isBeautyProducer == true) {
      return 'Bien-être';
    } else if (isLeisureProducer == true) {
      return 'Loisir';
    } else if (isRestaurationProducer == true) {
      return 'Restaurant';
    } else {
      return 'Utilisateur';
    }
  }

  // Accesseurs pour rendre la classe compatible avec Map
  dynamic operator [](String key) {
    switch (key) {
      case 'id': case '_id': return id;
      case 'userId': case 'user_id': case 'authorId': case 'author_id': return userId;
      case 'userName': case 'user_name': case 'authorName': case 'author_name': return userName;
      case 'userPhotoUrl': case 'user_photo_url': case 'authorAvatar': case 'author_photo': return userPhotoUrl;
      case 'imageUrl': case 'image_url': return imageUrl;
      case 'createdAt': case 'created_at': case 'postedAt': return createdAt;
      case 'location': return location;
      case 'locationName': case 'location_name': return locationName;
      case 'description': case 'content': return description;
      case 'likes': case 'likesCount': case 'likes_count': return likes;
      case 'comments': case 'commentsCount': return comments;
      case 'isLiked': return isLiked;
      case 'category': return category;
      case 'metadata': return metadata;
      case 'interestedCount': case 'entity_interests_count': return interestedCount;
      case 'choiceCount': case 'entity_choices_count': return choiceCount;
      case 'isInterested': case 'interested': return isInterested;
      case 'isChoice': case 'choice': return isChoice;
      case 'isProducerPost': case 'is_producer_post': return isProducerPost;
      case 'isLeisureProducer': case 'is_leisure_producer': return isLeisureProducer;
      case 'isBeautyProducer': case 'is_beauty_producer': case 'beauty_producer': return isBeautyProducer;
      case 'isRestaurationProducer': case 'is_restauration_producer': return isRestaurationProducer;
      case 'isAutomated': case 'is_automated': return isAutomated;
      case 'targetId': case 'target_id': return targetId;
      case 'referencedEventId': case 'referenced_event_id': return referencedEventId;
      case 'title': return title;
      case 'subtitle': return subtitle;
      case 'media': return media;
      case 'posts': return null; // Pour éviter les erreurs containsKey('posts')
      case 'tags': return tags;
      case 'mediaUrls': return mediaUrls;
      case 'commentsCount': return commentsCount;
      case 'type': return type;
      case 'author': return author;
      case 'producerId': return producerId;
      case 'relevanceScore': return relevanceScore;
      case 'url': return url;
      default: return null;
    }
  }

  // Méthode pour vérifier si une clé existe
  bool containsKey(String key) {
    return [
      'id', '_id', 'userId', 'user_id', 'authorId', 'author_id', 'userName', 'user_name', 'authorName', 'author_name',
      'userPhotoUrl', 'user_photo_url', 'authorAvatar', 'author_photo', 'imageUrl', 'image_url',
      'createdAt', 'created_at', 'postedAt', 'location', 'locationName', 'location_name', 'description', 'content',
      'likes', 'likesCount', 'likes_count', 'comments', 'commentsCount', 'isLiked', 'category', 'metadata',
      'interestedCount', 'entity_interests_count', 'choiceCount', 'entity_choices_count',
      'isInterested', 'interested', 'isChoice', 'choice',
      'isProducerPost', 'is_producer_post', 'isLeisureProducer', 'is_leisure_producer',
      'isBeautyProducer', 'is_beauty_producer', 'beauty_producer',
      'isRestaurationProducer', 'is_restauration_producer',
      'isAutomated', 'is_automated', 'targetId', 'target_id',
      'referencedEventId', 'referenced_event_id', 'title', 'subtitle', 'media', 'posts',
      'tags', 'mediaUrls', 'type', 'author', 'producerId', 'relevanceScore', 'url'
    ].contains(key);
  }

  // --- Add fromJson Factory Constructor --- 
  factory Post.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse lists of strings
    List<String> _parseStringList(dynamic list) {
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
      return [];
    }

    // Helper to safely parse lists of app_media.Media
    List<app_media.Media> _parseMediaList(dynamic list) {
       if (list is List) {
         return list
           .where((item) => item is Map<String, dynamic>)
           .map((item) => app_media.Media.fromJson(item as Map<String, dynamic>))
           .toList();
       } 
       return [];
    }

    // Helper to safely parse lists of Comment
    List<Comment> _parseCommentList(dynamic list) {
       if (list is List) {
         return list
           .where((item) => item is Map<String, dynamic>)
           .map((item) => Comment.fromJson(item as Map<String, dynamic>))
           .toList();
       } 
       return [];
    }

    // Determine author details, preferring specific author fields over producer/user fallbacks
    String determinedAuthorId = json['author_id']?.toString() 
                             ?? json['userId']?.toString() 
                             ?? json['producer_id']?.toString() 
                             ?? '';
    String determinedAuthorName = json['author_name']?.toString() 
                               ?? json['userName']?.toString() 
                               ?? json['producer_name']?.toString() 
                               ?? 'Utilisateur Inconnu';
    String? determinedAuthorAvatar = json['author_avatar']?.toString() 
                                 ?? json['userPhotoUrl']?.toString() 
                                 ?? json['producer_photo']?.toString();

    // Safely parse dates
    DateTime? parsedPostedAt = json['posted_at'] != null 
                               ? DateTime.tryParse(json['posted_at'].toString()) 
                               : null;
    DateTime parsedCreatedAt = json['createdAt'] != null 
                              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() // Fallback to now
                              : parsedPostedAt ?? DateTime.now(); // Fallback to postedAt or now

    // Safely parse counts, allowing for List lengths as fallback
    int parsedLikesCount = (json['likes_count'] as num?)?.toInt() 
                        ?? (json['likes'] as List?)?.length 
                        ?? 0;
    int parsedInterestedCount = (json['interested_count'] as num?)?.toInt() 
                             ?? (json['interestedUsers'] as List?)?.length 
                             ?? (json['interested'] as List?)?.length 
                             ?? 0;
    int parsedChoiceCount = (json['choice_count'] as num?)?.toInt() 
                         ?? (json['choiceUsers'] as List?)?.length 
                         ?? (json['choices'] as List?)?.length 
                         ?? 0;
    int parsedCommentsCount = (json['comments_count'] as num?)?.toInt() 
                           ?? (json['comments'] as List?)?.length 
                           ?? 0;

    return Post(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '', 
      userId: json['userId']?.toString() ?? determinedAuthorId, // Ensure userId is populated
      userName: json['userName']?.toString() ?? determinedAuthorName, // Ensure userName is populated
      userPhotoUrl: json['userPhotoUrl']?.toString() ?? determinedAuthorAvatar, // Ensure userPhotoUrl is populated
      imageUrl: json['imageUrl']?.toString() ?? (json['media'] as List?)?.firstWhere((m) => m is Map && m['type'] == 'image', orElse: () => {})?['url']?.toString(), // Fallback image from media
      createdAt: parsedCreatedAt, 
      location: json['location']?.toString(),
      locationName: json['location_name']?.toString() ?? json['location']?.toString(),
      description: json['description']?.toString() ?? json['content']?.toString() ?? '', // Fallback description/content
      likes: parsedLikesCount, // Use parsed count
      comments: _parseCommentList(json['comments']), 
      isLiked: json['isLiked'] as bool? ?? false, // Default to false if null
      category: json['category']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      
      // Additional fields mapping
      likesCount: parsedLikesCount,
      interestedCount: parsedInterestedCount,
      choiceCount: parsedChoiceCount,
      // isInterested/isChoice might depend on user context, often not in the raw post data
      isInterested: json['isInterested'] as bool?, 
      isChoice: json['isChoice'] as bool?,
      isProducerPost: json['isProducerPost'] as bool? ?? (json['producer_id'] != null),
      isLeisureProducer: json['isLeisureProducer'] as bool? ?? json['type'] == 'leisure',
      isBeautyProducer: json['isBeautyProducer'] as bool? ?? json['type'] == 'wellness',
      isRestaurationProducer: json['isRestaurationProducer'] as bool? ?? json['type'] == 'restaurant',
      isAutomated: json['isAutomated'] as bool?,
      targetId: json['target_id']?.toString(),
      referencedEventId: json['referenced_event_id']?.toString(),
      title: json['title']?.toString() ?? json['description']?.toString() ?? '', // Fallback title
      subtitle: json['subtitle']?.toString(),
      content: json['content']?.toString() ?? json['description']?.toString(), // Fallback content
      authorId: determinedAuthorId,
      authorName: determinedAuthorName,
      authorAvatar: determinedAuthorAvatar,
      postedAt: parsedPostedAt, 
      media: _parseMediaList(json['media']), 
      
      // New fields mapping
      tags: _parseStringList(json['tags']), 
      mediaUrls: _parseStringList((json['media'] as List?)?.map((m) => m is Map ? m['url'] : null).where((url) => url != null)), // Extract URLs if needed
      commentsCount: parsedCommentsCount,
      type: json['type']?.toString(),
      author: json['author'], // Keep raw author if needed
      
      relevanceScore: (json['relevanceScore'] as num?)?.toDouble(), // Parse relevance score

      producerId: json['producer_id']?.toString(),
        url: json['url']?.toString(),
      );
  }
  // --- End fromJson Factory --- 

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'userId': userId,
      'user_id': userId,
      'authorId': userId,
      'author_id': userId,
      'userName': userName,
      'user_name': userName,
      'authorName': userName,
      'author_name': userName,
      'userPhotoUrl': userPhotoUrl,
      'user_photo_url': userPhotoUrl,
      'authorAvatar': userPhotoUrl,
      'author_photo': userPhotoUrl,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'postedAt': createdAt.toIso8601String(),
      'location': location,
      'locationName': locationName,
      'location_name': locationName,
      'description': description,
      'content': description,
      'likes': likes,
      'likesCount': likesCount,
      'likes_count': likesCount,
      'comments': comments.map((c) => c.toJson()).toList(),
      'commentsCount': commentsCount,
      'isLiked': isLiked,
      'category': category,
      'metadata': metadata,
      'interestedCount': interestedCount,
      'entity_interests_count': interestedCount,
      'choiceCount': choiceCount,
      'entity_choices_count': choiceCount,
      'isInterested': isInterested,
      'interested': isInterested,
      'isChoice': isChoice,
      'choice': isChoice,
      'isProducerPost': isProducerPost,
      'is_producer_post': isProducerPost,
      'isLeisureProducer': isLeisureProducer,
      'is_leisure_producer': isLeisureProducer,
      'isBeautyProducer': isBeautyProducer,
      'is_beauty_producer': isBeautyProducer,
      'beauty_producer': isBeautyProducer,
      'isRestaurationProducer': isRestaurationProducer,
      'is_restauration_producer': isRestaurationProducer,
      'isAutomated': isAutomated,
      'is_automated': isAutomated,
      'targetId': targetId,
      'target_id': targetId,
      'referencedEventId': referencedEventId,
      'referenced_event_id': referencedEventId,
      'title': title,
      'subtitle': subtitle,
      'media': media.map((m) => m.toJson()).toList(),
      'tags': tags,
      'mediaUrls': mediaUrls,
      'type': type,
      'author': author,
      'relevanceScore': relevanceScore,
      'producerId': producerId,
      'url': url,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? imageUrl,
    DateTime? createdAt,
    String? location,
    String? locationName,
    String? description,
    int? likes,
    List<Comment>? comments,
    bool? isLiked,
    String? category,
    Map<String, dynamic>? metadata,
    int? likesCount,
    int? interestedCount,
    int? choiceCount,
    bool? isInterested,
    bool? isChoice,
    bool? isProducerPost,
    bool? isLeisureProducer,
    bool? isBeautyProducer,
    bool? isRestaurationProducer,
    bool? isAutomated,
    String? targetId,
    String? referencedEventId,
    String? title,
    String? subtitle,
    String? content,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    DateTime? postedAt,
    List<app_media.Media>? media,
    List<String>? tags,
    List<String>? mediaUrls,
    int? commentsCount,
    String? type,
    dynamic author,
    double? relevanceScore,
    String? producerId,
    String? url,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      description: description ?? this.description,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      category: category ?? this.category,
      metadata: metadata ?? this.metadata,
      likesCount: likesCount ?? this.likesCount,
      interestedCount: interestedCount ?? this.interestedCount,
      choiceCount: choiceCount ?? this.choiceCount,
      isInterested: isInterested ?? this.isInterested,
      isChoice: isChoice ?? this.isChoice,
      isProducerPost: isProducerPost ?? this.isProducerPost,
      isLeisureProducer: isLeisureProducer ?? this.isLeisureProducer,
      isBeautyProducer: isBeautyProducer ?? this.isBeautyProducer,
      isRestaurationProducer: isRestaurationProducer ?? this.isRestaurationProducer,
      isAutomated: isAutomated ?? this.isAutomated,
      targetId: targetId ?? this.targetId,
      referencedEventId: referencedEventId ?? this.referencedEventId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      postedAt: postedAt ?? this.postedAt,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      commentsCount: commentsCount ?? this.commentsCount,
      type: type ?? this.type,
      author: author ?? this.author,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      producerId: producerId ?? this.producerId,
      url: url ?? this.url,
    );
  }

  // Méthode pour formater la date de création
  String getFormattedDate() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      }
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else {
      return DateFormat('dd/MM/yyyy').format(createdAt);
    }
  }
}

// Extensions pour simplifier l'accès aux propriétés
extension PostExtension on Post {
  List<app_media.Media> get mediaList => media;
}

// Classe utilitaire pour émuler l'objet Author
class _Author {
  final String id;
  final String name;
  String avatar;

  _Author({
    required this.id,
    required this.name,
    required this.avatar,
  });
}

class PostLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final String? name;
  final List<double>? coordinates;

  PostLocation({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.address,
    this.name,
    this.coordinates,
  });

  factory PostLocation.fromJson(Map<String, dynamic> json) {
    // Handle case where JSON might have coordinates in different formats
    double lat = 0.0;
    double lng = 0.0;
    
    // Try to extract coordinates from different possible formats
    if (json['latitude'] is num) {
      lat = (json['latitude'] as num).toDouble();
    } else if (json['coordinates'] is List && json['coordinates'].length >= 2) {
      // Some APIs return [longitude, latitude] format
      lng = (json['coordinates'][0] as num).toDouble();
      lat = (json['coordinates'][1] as num).toDouble();
    }
    
    if (json['longitude'] is num) {
      lng = (json['longitude'] as num).toDouble();
    } else if (json['coordinates'] is List && json['coordinates'].length >= 2 && lng == 0.0) {
      // Only set from coordinates array if not already set
      lng = (json['coordinates'][0] as num).toDouble();
    }
    
    List<double>? coordList;
    if (json['coordinates'] is List) {
      try {
        coordList = (json['coordinates'] as List).map<double>((e) => (e as num).toDouble()).toList();
      } catch (e) {
        // If conversion fails, create a new list with the values we have
        coordList = [lng, lat];
      }
    } else {
      // If no coordinates array, create one from lat/lng
      coordList = [lng, lat];
    }
    
    return PostLocation(
      latitude: lat,
      longitude: lng,
      address: json['address'],
      name: json['name'],
      coordinates: coordList,
    );
  }
}

class Media {
  final String url;
  final String type;
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  Media({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
      thumbnailUrl: json['thumbnailUrl'] ?? json['thumbnail_url'],
      width: json['width'],
      height: json['height'],
    );
  }
}