class HeatmapData {
  final Producer? producer;
  final String? timeframe;
  final List<ActivityPoint>? activityPoints;
  final List<ActivityPoint>? directActivity;
  final List<Search>? searches;
  final List<HotZone>? hotZones;
  final List<Insight>? insights;
  final Metrics? metrics;
  final DateTime? timestamp;

  HeatmapData({
    this.producer,
    this.timeframe,
    this.activityPoints,
    this.directActivity,
    this.searches,
    this.hotZones,
    this.insights,
    this.metrics,
    this.timestamp,
  });

  factory HeatmapData.fromJson(Map<String, dynamic> json) {
    return HeatmapData(
      producer: json['producer'] != null ? Producer.fromJson(json['producer']) : null,
      timeframe: json['timeframe'],
      activityPoints: json['activityPoints'] != null
          ? List<ActivityPoint>.from(json['activityPoints'].map((x) => ActivityPoint.fromJson(x)))
          : null,
      directActivity: json['directActivity'] != null
          ? List<ActivityPoint>.from(json['directActivity'].map((x) => ActivityPoint.fromJson(x)))
          : null,
      searches: json['searches'] != null
          ? List<Search>.from(json['searches'].map((x) => Search.fromJson(x)))
          : null,
      hotZones: json['hotZones'] != null
          ? List<HotZone>.from(json['hotZones'].map((x) => HotZone.fromJson(x)))
          : null,
      insights: json['insights'] != null
          ? List<Insight>.from(json['insights'].map((x) => Insight.fromJson(x)))
          : null,
      metrics: json['metrics'] != null ? Metrics.fromJson(json['metrics']) : null,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }
}

class Producer {
  final String? id;
  final GeoLocation? location;

  Producer({
    this.id,
    this.location,
  });

  factory Producer.fromJson(Map<String, dynamic> json) {
    return Producer(
      id: json['id'],
      location: json['location'] != null ? GeoLocation.fromJson(json['location']) : null,
    );
  }
}

class GeoLocation {
  final String? type;
  final List<double>? coordinates;

  GeoLocation({
    this.type,
    this.coordinates,
  });

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      type: json['type'],
      coordinates: json['coordinates'] != null
          ? List<double>.from(json['coordinates'].map((x) => x.toDouble()))
          : null,
    );
  }
}

class ActivityPoint {
  final GeoLocation? location;
  final DateTime? timestamp;
  final String? type;
  final double? strength;
  final double? distance;
  final UserInfo? user;

  ActivityPoint({
    this.location,
    this.timestamp,
    this.type,
    this.strength,
    this.distance,
    this.user,
  });

  factory ActivityPoint.fromJson(Map<String, dynamic> json) {
    return ActivityPoint(
      location: json['location'] != null ? GeoLocation.fromJson(json['location']) : null,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      type: json['type'],
      strength: json['strength']?.toDouble(),
      distance: json['distance']?.toDouble(),
      user: json['user'] != null ? UserInfo.fromJson(json['user']) : null,
    );
  }
}

class UserInfo {
  final Demographics? demographics;

  UserInfo({
    this.demographics,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      demographics: json['demographics'] != null ? Demographics.fromJson(json['demographics']) : null,
    );
  }
}

class Demographics {
  final String? gender;
  final String? ageGroup;

  Demographics({
    this.gender,
    this.ageGroup,
  });

  factory Demographics.fromJson(Map<String, dynamic> json) {
    return Demographics(
      gender: json['gender'],
      ageGroup: json['ageGroup'],
    );
  }
}

class Search {
  final String? query;
  final GeoLocation? location;
  final DateTime? timestamp;
  final String? category;
  final double? distance;

  Search({
    this.query,
    this.location,
    this.timestamp,
    this.category,
    this.distance,
  });

  factory Search.fromJson(Map<String, dynamic> json) {
    return Search(
      query: json['query'],
      location: json['location'] != null ? GeoLocation.fromJson(json['location']) : null,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      category: json['category'],
      distance: json['distance']?.toDouble(),
    );
  }
}

class HotZone {
  final GeoLocation? center;
  final double? intensity;
  final int? count;
  final double? radius;
  final List<ActivityDetail>? activities;

  HotZone({
    this.center,
    this.intensity,
    this.count,
    this.radius,
    this.activities,
  });

  factory HotZone.fromJson(Map<String, dynamic> json) {
    return HotZone(
      center: json['center'] != null ? GeoLocation.fromJson(json['center']) : null,
      intensity: json['intensity']?.toDouble(),
      count: json['count'],
      radius: json['radius']?.toDouble(),
      activities: json['activities'] != null
          ? List<ActivityDetail>.from(json['activities'].map((x) => ActivityDetail.fromJson(x)))
          : null,
    );
  }
}

class ActivityDetail {
  final DateTime? timestamp;
  final String? type;
  final double? strength;

  ActivityDetail({
    this.timestamp,
    this.type,
    this.strength,
  });

  factory ActivityDetail.fromJson(Map<String, dynamic> json) {
    return ActivityDetail(
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      type: json['type'],
      strength: json['strength']?.toDouble(),
    );
  }
}

class Insight {
  final String? type;
  final String? title;
  final String? description;
  final int? importance;
  final List<String>? terms;
  final Map<String, dynamic>? demographics;

  Insight({
    this.type,
    this.title,
    this.description,
    this.importance,
    this.terms,
    this.demographics,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      type: json['type'],
      title: json['title'],
      description: json['description'],
      importance: json['importance'],
      terms: json['terms'] != null ? List<String>.from(json['terms']) : null,
      demographics: json['demographics'],
    );
  }
}

class Metrics {
  final int? totalActiveUsers;
  final int? totalDirectInteractions;
  final int? totalNearbyActivity;
  final int? searchVolume;

  Metrics({
    this.totalActiveUsers,
    this.totalDirectInteractions,
    this.totalNearbyActivity,
    this.searchVolume,
  });

  factory Metrics.fromJson(Map<String, dynamic> json) {
    return Metrics(
      totalActiveUsers: json['totalActiveUsers'],
      totalDirectInteractions: json['totalDirectInteractions'],
      totalNearbyActivity: json['totalNearbyActivity'],
      searchVolume: json['searchVolume'],
    );
  }
} 