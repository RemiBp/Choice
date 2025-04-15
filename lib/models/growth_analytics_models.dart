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

class KpiValue {
  final double current;
  final double change;
  final double changePercent;
  final String? label;

  KpiValue({
    required this.current,
    required this.change,
    required this.changePercent,
    this.label,
  });

  factory KpiValue.fromJson(Map<String, dynamic> json) {
    return KpiValue(
      current: (json['current'] ?? 0.0).toDouble(),
      change: (json['change'] ?? 0.0).toDouble(),
      changePercent: (json['changePercent'] ?? 0.0).toDouble(),
      label: json['label'],
    );
  }

  bool get isPositiveChange => change >= 0;
}

class EngagementSummary {
  final int posts;
  final int likes;
  final int comments;

  EngagementSummary({
    required this.posts,
    required this.likes,
    required this.comments,
  });

  factory EngagementSummary.fromJson(Map<String, dynamic> json) {
    return EngagementSummary(
      posts: json['posts'] ?? 0,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
    );
  }
}

class GrowthOverview {
  final String period;
  final Map<String, KpiValue> kpis;
  final EngagementSummary engagementSummary;

  GrowthOverview({
    required this.period,
    required this.kpis,
    required this.engagementSummary,
  });

  factory GrowthOverview.fromJson(Map<String, dynamic> json) {
    final Map<String, KpiValue> kpiMap = {};
    if (json['kpis'] != null && json['kpis'] is Map) {
      (json['kpis'] as Map<String, dynamic>).forEach((key, value) {
        if (value is Map<String, dynamic>) {
          kpiMap[key] = KpiValue.fromJson(value);
        }
      });
    }

    return GrowthOverview(
      period: json['period'] ?? '30d',
      kpis: kpiMap,
      engagementSummary: EngagementSummary.fromJson(json['engagementSummary'] ?? {}),
    );
  }

  KpiValue? getKpi(String key) => kpis[key];
}

class TimePoint {
  final String date;
  final double value;

  TimePoint({required this.date, required this.value});

  factory TimePoint.fromJson(Map<String, dynamic> json) {
    return TimePoint(
      date: json['date'] ?? '',
      value: (json['value'] ?? 0.0).toDouble(),
    );
  }
}

class GrowthTrends {
  final String period;
  final String interval;
  final Map<String, List<TimePoint>> trends;

  GrowthTrends({
    required this.period,
    required this.interval,
    required this.trends,
  });

  factory GrowthTrends.fromJson(Map<String, dynamic> json) {
    final Map<String, List<TimePoint>> trendsMap = {};
    if (json['trends'] != null && json['trends'] is Map) {
      (json['trends'] as Map<String, dynamic>).forEach((key, value) {
        if (value is List) {
          trendsMap[key] = value.map((e) => TimePoint.fromJson(e)).toList();
        }
      });
    }

    return GrowthTrends(
      period: json['period'] ?? '30d',
      interval: json['interval'] ?? 'day',
      trends: trendsMap,
    );
  }

  List<TimePoint>? getTrend(String metric) => trends[metric];
}

class RecommendationAction {
  final String type;
  final String? postId;
  final String? section;

  RecommendationAction({
    required this.type,
    this.postId,
    this.section,
  });

  factory RecommendationAction.fromJson(Map<String, dynamic> json) {
    return RecommendationAction(
      type: json['type'] ?? 'info',
      postId: json['postId'],
      section: json['section'],
    );
  }
}

class Recommendation {
  final String id;
  final String title;
  final String description;
  final String priority;
  final RecommendationAction action;

  Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.action,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'low',
      action: RecommendationAction.fromJson(json['action'] ?? {}),
    );
  }
}

class GrowthRecommendations {
  final List<Recommendation> recommendations;

  GrowthRecommendations({required this.recommendations});

  factory GrowthRecommendations.fromJson(Map<String, dynamic> json) {
    return GrowthRecommendations(
      recommendations: (json['recommendations'] as List? ?? [])
          .map((e) => Recommendation.fromJson(e))
          .toList(),
    );
  }
}

class DemographicsData {
  final Map<String, double> ageDistribution;
  final Map<String, double> genderDistribution;
  final List<Map<String, dynamic>> topLocations;

  DemographicsData({
    required this.ageDistribution,
    required this.genderDistribution,
    required this.topLocations,
  });

  factory DemographicsData.fromJson(Map<String, dynamic> json) {
    return DemographicsData(
      ageDistribution: Map<String, double>.from(json['ageDistribution'] ?? {}),
      genderDistribution: Map<String, double>.from(json['genderDistribution'] ?? {}),
      topLocations: List<Map<String, dynamic>>.from(json['topLocations'] ?? []),
    );
  }
}

class PredictionValue {
  final double value;
  final String confidence;

  PredictionValue({required this.value, required this.confidence});

  factory PredictionValue.fromJson(Map<String, dynamic> json) {
    return PredictionValue(
      value: (json['value'] ?? 0.0).toDouble(),
      confidence: json['confidence'] ?? 'low',
    );
  }
}

class GrowthPredictions {
  final Map<String, PredictionValue> predictions;

  GrowthPredictions({required this.predictions});

  factory GrowthPredictions.fromJson(Map<String, dynamic> json) {
    final Map<String, PredictionValue> predictionsMap = {};
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        predictionsMap[key] = PredictionValue.fromJson(value);
      }
    });
    return GrowthPredictions(predictions: predictionsMap);
  }
}

class CompetitorMetrics {
  final double followers;
  final double engagementRate;

  CompetitorMetrics({required this.followers, required this.engagementRate});

  factory CompetitorMetrics.fromJson(Map<String, dynamic> json) {
    return CompetitorMetrics(
      followers: (json['followers'] ?? 0.0).toDouble(),
      engagementRate: (json['engagementRate'] ?? 0.0).toDouble(),
    );
  }
}

class CompetitorInfo {
  final String id;
  final String name;
  final double followers;
  final double engagementRate;

  CompetitorInfo({
    required this.id,
    required this.name,
    required this.followers,
    required this.engagementRate,
  });

  factory CompetitorInfo.fromJson(Map<String, dynamic> json) {
    return CompetitorInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      followers: (json['followers'] ?? 0.0).toDouble(),
      engagementRate: (json['engagementRate'] ?? 0.0).toDouble(),
    );
  }
}

class CompetitorAnalysis {
  final CompetitorMetrics yourMetrics;
  final CompetitorMetrics averageCompetitorMetrics;
  final List<CompetitorInfo> topCompetitors;

  CompetitorAnalysis({
    required this.yourMetrics,
    required this.averageCompetitorMetrics,
    required this.topCompetitors,
  });

  factory CompetitorAnalysis.fromJson(Map<String, dynamic> json) {
    return CompetitorAnalysis(
      yourMetrics: CompetitorMetrics.fromJson(json['yourMetrics'] ?? {}),
      averageCompetitorMetrics: CompetitorMetrics.fromJson(json['averageCompetitorMetrics'] ?? {}),
      topCompetitors: (json['topCompetitors'] as List? ?? [])
          .map((e) => CompetitorInfo.fromJson(e))
          .toList(),
    );
  }
} 