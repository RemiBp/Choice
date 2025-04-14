class Producer {
  final String id;
  final String name;
  final String type;
  final List<String> category;
  final String photo;

  Producer({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.photo,
  });

  factory Producer.fromJson(Map<String, dynamic> json) {
    return Producer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      category: (json['category'] as List?)?.map((e) => e.toString()).toList() ?? [],
      photo: json['photo'] ?? '',
    );
  }
}

class EngagementStats {
  final int posts;
  final int likes;
  final int comments;
  final int shares;
  final double averagePerPost;

  EngagementStats({
    required this.posts,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.averagePerPost,
  });

  factory EngagementStats.fromJson(Map<String, dynamic> json) {
    return EngagementStats(
      posts: json['posts'] ?? 0,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
      averagePerPost: (json['average_per_post'] ?? 0).toDouble(),
    );
  }
}

class FollowersStats {
  final int total;
  final int new_;
  final double growthRate;

  FollowersStats({
    required this.total,
    required this.new_,
    required this.growthRate,
  });

  factory FollowersStats.fromJson(Map<String, dynamic> json) {
    return FollowersStats(
      total: json['total'] ?? 0,
      new_: json['new'] ?? 0,
      growthRate: (json['growth_rate'] ?? 0).toDouble(),
    );
  }
}

class ReachStats {
  final int mentions;
  final int interestedUsers;
  final int choiceUsers;
  final double conversionRate;

  ReachStats({
    required this.mentions,
    required this.interestedUsers,
    required this.choiceUsers,
    required this.conversionRate,
  });

  factory ReachStats.fromJson(Map<String, dynamic> json) {
    return ReachStats(
      mentions: json['mentions'] ?? 0,
      interestedUsers: json['interested_users'] ?? 0,
      choiceUsers: json['choice_users'] ?? 0,
      conversionRate: (json['conversion_rate'] ?? 0).toDouble(),
    );
  }
}

class AgeDistribution {
  final Map<String, double> distribution;

  AgeDistribution({required this.distribution});

  factory AgeDistribution.fromJson(Map<String, dynamic> json) {
    final distribution = <String, double>{};
    json.forEach((key, value) {
      distribution[key] = (value ?? 0).toDouble();
    });
    return AgeDistribution(distribution: distribution);
  }
}

class GenderDistribution {
  final Map<String, double> distribution;

  GenderDistribution({required this.distribution});

  factory GenderDistribution.fromJson(Map<String, dynamic> json) {
    final distribution = <String, double>{};
    json.forEach((key, value) {
      distribution[key] = (value ?? 0).toDouble();
    });
    return GenderDistribution(distribution: distribution);
  }
}

class LocationDistribution {
  final Map<String, double> distribution;

  LocationDistribution({required this.distribution});

  factory LocationDistribution.fromJson(Map<String, dynamic> json) {
    final distribution = <String, double>{};
    json.forEach((key, value) {
      distribution[key] = (value ?? 0).toDouble();
    });
    return LocationDistribution(distribution: distribution);
  }
}

class Demographics {
  final AgeDistribution age;
  final GenderDistribution gender;
  final LocationDistribution location;

  Demographics({
    required this.age,
    required this.gender,
    required this.location,
  });

  factory Demographics.fromJson(Map<String, dynamic> json) {
    return Demographics(
      age: AgeDistribution.fromJson(json['age'] ?? {}),
      gender: GenderDistribution.fromJson(json['gender'] ?? {}),
      location: LocationDistribution.fromJson(json['location'] ?? {}),
    );
  }
}

class Competitor {
  final String id;
  final String name;
  final String photo;
  final double rating;
  final int followers;
  final int recentPosts;

  Competitor({
    required this.id,
    required this.name,
    required this.photo,
    required this.rating,
    required this.followers,
    required this.recentPosts,
  });

  factory Competitor.fromJson(Map<String, dynamic> json) {
    return Competitor(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      photo: json['photo'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      followers: json['followers'] ?? 0,
      recentPosts: json['recent_posts'] ?? 0,
    );
  }
}

class GrowthOverview {
  final Producer producer;
  final int period;
  final EngagementStats engagement;
  final FollowersStats followers;
  final ReachStats reach;
  final Demographics demographics;
  final List<Competitor> competitors;

  GrowthOverview({
    required this.producer,
    required this.period,
    required this.engagement,
    required this.followers,
    required this.reach,
    required this.demographics,
    required this.competitors,
  });

  factory GrowthOverview.fromJson(Map<String, dynamic> json) {
    return GrowthOverview(
      producer: Producer.fromJson(json['producer'] ?? {}),
      period: json['period'] ?? 30,
      engagement: EngagementStats.fromJson(json['engagement'] ?? {}),
      followers: FollowersStats.fromJson(json['followers'] ?? {}),
      reach: ReachStats.fromJson(json['reach'] ?? {}),
      demographics: Demographics.fromJson(json['demographics'] ?? {}),
      competitors: (json['competitors'] as List?)
          ?.map((e) => Competitor.fromJson(e))
          .toList() ?? [],
    );
  }
}

class EngagementPoint {
  final String date;
  final int posts;
  final int likes;
  final int comments;
  final int shares;

  EngagementPoint({
    required this.date,
    required this.posts,
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory EngagementPoint.fromJson(Map<String, dynamic> json) {
    return EngagementPoint(
      date: json['date'] ?? '',
      posts: json['posts'] ?? 0,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
    );
  }
}

class PostEngagement {
  final int likes;
  final int comments;
  final int shares;

  PostEngagement({
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory PostEngagement.fromJson(Map<String, dynamic> json) {
    return PostEngagement(
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
    );
  }
}

class TopPost {
  final String id;
  final String content;
  final String postedAt;
  final String? media;
  final PostEngagement engagement;
  final int score;

  TopPost({
    required this.id,
    required this.content,
    required this.postedAt,
    this.media,
    required this.engagement,
    required this.score,
  });

  factory TopPost.fromJson(Map<String, dynamic> json) {
    return TopPost(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      postedAt: json['posted_at'] ?? '',
      media: json['media'],
      engagement: PostEngagement.fromJson(json['engagement'] ?? {}),
      score: json['score'] ?? 0,
    );
  }
}

class PeakTime {
  final int hour;
  final int posts;
  final double averageEngagement;

  PeakTime({
    required this.hour,
    required this.posts,
    required this.averageEngagement,
  });

  factory PeakTime.fromJson(Map<String, dynamic> json) {
    return PeakTime(
      hour: json['hour'] ?? 0,
      posts: json['posts'] ?? 0,
      averageEngagement: (json['average_engagement'] ?? 0).toDouble(),
    );
  }
}

class WeekdayDistribution {
  final String day;
  final int posts;
  final double averageEngagement;

  WeekdayDistribution({
    required this.day,
    required this.posts,
    required this.averageEngagement,
  });

  factory WeekdayDistribution.fromJson(Map<String, dynamic> json) {
    return WeekdayDistribution(
      day: json['day'] ?? '',
      posts: json['posts'] ?? 0,
      averageEngagement: (json['average_engagement'] ?? 0).toDouble(),
    );
  }
}

class GrowthTrends {
  final List<EngagementPoint> engagement;
  final List<TopPost> topPosts;
  final List<PeakTime> peakTimes;
  final List<WeekdayDistribution> weeklyDistribution;

  GrowthTrends({
    required this.engagement,
    required this.topPosts,
    required this.peakTimes,
    required this.weeklyDistribution,
  });

  factory GrowthTrends.fromJson(Map<String, dynamic> json) {
    return GrowthTrends(
      engagement: (json['engagement'] as List?)
          ?.map((e) => EngagementPoint.fromJson(e))
          .toList() ?? [],
      topPosts: (json['top_posts'] as List?)
          ?.map((e) => TopPost.fromJson(e))
          .toList() ?? [],
      peakTimes: (json['peak_times'] as List?)
          ?.map((e) => PeakTime.fromJson(e))
          .toList() ?? [],
      weeklyDistribution: (json['weekly_distribution'] as List?)
          ?.map((e) => WeekdayDistribution.fromJson(e))
          .toList() ?? [],
    );
  }
}

class Recommendation {
  final String title;
  final String description;
  final String action;

  Recommendation({
    required this.title,
    required this.description,
    required this.action,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      action: json['action'] ?? '',
    );
  }
}

class GrowthRecommendations {
  final List<Recommendation> contentStrategy;
  final List<Recommendation> engagementTactics;
  final List<Recommendation> growthOpportunities;

  GrowthRecommendations({
    required this.contentStrategy,
    required this.engagementTactics,
    required this.growthOpportunities,
  });

  factory GrowthRecommendations.fromJson(Map<String, dynamic> json) {
    return GrowthRecommendations(
      contentStrategy: (json['content_strategy'] as List?)
          ?.map((e) => Recommendation.fromJson(e))
          .toList() ?? [],
      engagementTactics: (json['engagement_tactics'] as List?)
          ?.map((e) => Recommendation.fromJson(e))
          .toList() ?? [],
      growthOpportunities: (json['growth_opportunities'] as List?)
          ?.map((e) => Recommendation.fromJson(e))
          .toList() ?? [],
    );
  }
} 