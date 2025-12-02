import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/llm_model.dart';
import '../services/prompt_management_service.dart';
import '../services/model_performance_service.dart';

enum AnalyticsPeriod {
  daily('일간'),
  weekly('주간'),
  monthly('월간'),
  quarterly('분기'),
  yearly('연간');

  const AnalyticsPeriod(this.displayName);
  final String displayName;
}

enum MetricType {
  usage('사용량'),
  cost('비용'),
  performance('성능'),
  efficiency('효율성'),
  satisfaction('만족도');

  const MetricType(this.displayName);
  final String displayName;
}

class AnalyticsData {
  final Map<String, dynamic> data;
  final Map<String, List<double>> timeSeriesData;
  final Map<String, dynamic> insights;
  final List<String> recommendations;
  final DateTime generatedAt;
  final AnalyticsPeriod period;

  const AnalyticsData({
    required this.data,
    required this.timeSeriesData,
    required this.insights,
    required this.recommendations,
    required this.generatedAt,
    required this.period,
  });
}

class UsageAnalytics {
  final String userId;
  final Map<String, int> modelUsageCounts;
  final Map<String, double> modelCosts;
  final Map<String, int> dailyUsage;
  final Map<String, int> categoryUsage;
  final double totalCost;
  final int totalRequests;
  final int totalTokens;
  final double averageResponseTime;
  final Map<String, double> modelPerformance;

  const UsageAnalytics({
    required this.userId,
    required this.modelUsageCounts,
    required this.modelCosts,
    required this.dailyUsage,
    required this.categoryUsage,
    required this.totalCost,
    required this.totalRequests,
    required this.totalTokens,
    required this.averageResponseTime,
    required this.modelPerformance,
  });
}

class CostAnalytics {
  final Map<String, double> costsByModel;
  final Map<String, double> costsByCategory;
  final Map<String, double> costsByDay;
  final double totalCost;
  final double averageCostPerRequest;
  final double averageCostPerToken;
  final List<CostTrend> trends;
  final Map<String, double> projectedCosts;

  const CostAnalytics({
    required this.costsByModel,
    required this.costsByCategory,
    required this.costsByDay,
    required this.totalCost,
    required this.averageCostPerRequest,
    required this.averageCostPerToken,
    required this.trends,
    required this.projectedCosts,
  });
}

class CostTrend {
  final String period;
  final double cost;
  final double changeRate;
  final TrendDirection direction;

  const CostTrend({
    required this.period,
    required this.cost,
    required this.changeRate,
    required this.direction,
  });
}

enum TrendDirection { up, down, stable }

class PerformanceAnalytics {
  final Map<String, double> modelScores;
  final Map<String, double> responseTimes;
  final Map<String, double> errorRates;
  final Map<String, double> userRatings;
  final String bestPerformingModel;
  final String fastestModel;
  final String highestRatedModel;
  final List<PerformanceInsight> insights;

  const PerformanceAnalytics({
    required this.modelScores,
    required this.responseTimes,
    required this.errorRates,
    required this.userRatings,
    required this.bestPerformingModel,
    required this.fastestModel,
    required this.highestRatedModel,
    required this.insights,
  });
}

class PerformanceInsight {
  final String model;
  final String metric;
  final double value;
  final String observation;
  final String recommendation;

  const PerformanceInsight({
    required this.model,
    required this.metric,
    required this.value,
    required this.observation,
    required this.recommendation,
  });
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final PromptManagementService _promptService = PromptManagementService();
  final ModelPerformanceService _performanceService = ModelPerformanceService();

  // 종합 분석 데이터 생성
  Future<AnalyticsData> generateAnalytics({
    required String userId,
    required AnalyticsPeriod period,
    DateTime? startDate,
    DateTime? endDate,
    List<MetricType>? metrics,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? _getStartDate(period, now);
    final end = endDate ?? now;

    final data = <String, dynamic>{};
    final timeSeriesData = <String, List<double>>{};
    final insights = <String, dynamic>{};
    final recommendations = <String>[];

    // 사용량 분석
    if (metrics == null || metrics.contains(MetricType.usage)) {
      final usageAnalytics = await _analyzeUsage(userId, start, end);
      data['usage'] = usageAnalytics;
      timeSeriesData['usage'] = _generateTimeSeries(usageAnalytics.dailyUsage);
      insights.addAll(_generateUsageInsights(usageAnalytics));
      recommendations.addAll(_generateUsageRecommendations(usageAnalytics));
    }

    // 비용 분석
    if (metrics == null || metrics.contains(MetricType.cost)) {
      final costAnalytics = await _analyzeCosts(userId, start, end);
      data['cost'] = costAnalytics;
      timeSeriesData['cost'] = _generateTimeSeries(costAnalytics.costsByDay);
      insights.addAll(_generateCostInsights(costAnalytics));
      recommendations.addAll(_generateCostRecommendations(costAnalytics));
    }

    // 성능 분석
    if (metrics == null || metrics.contains(MetricType.performance)) {
      final performanceAnalytics = await _analyzePerformance(userId, start, end);
      data['performance'] = performanceAnalytics;
      insights.addAll(_generatePerformanceInsights(performanceAnalytics));
      recommendations.addAll(_generatePerformanceRecommendations(performanceAnalytics));
    }

    return AnalyticsData(
      data: data,
      timeSeriesData: timeSeriesData,
      insights: insights,
      recommendations: recommendations,
      generatedAt: now,
      period: period,
    );
  }

  // 사용량 분석
  Future<UsageAnalytics> _analyzeUsage(String userId, DateTime start, DateTime end) async {
    final executions = await _promptService.getExecutions(
      userId: userId,
      startDate: start,
      endDate: end,
    );

    final modelUsageCounts = <String, int>{};
    final modelCosts = <String, double>{};
    final dailyUsage = <String, int>{};
    final categoryUsage = <String, int>{};
    final modelPerformance = <String, double>{};

    double totalCost = 0.0;
    int totalRequests = 0;
    int totalTokens = 0;
    int totalResponseTime = 0;

    for (final execution in executions) {
      // 모델별 사용량
      modelUsageCounts[execution.model.id] =
          (modelUsageCounts[execution.model.id] ?? 0) + 1;

      // 모델별 비용
      modelCosts[execution.model.id] =
          (modelCosts[execution.model.id] ?? 0) + execution.cost;

      // 일별 사용량
      final day = execution.timestamp.toString().substring(0, 10);
      dailyUsage[day] = (dailyUsage[day] ?? 0) + 1;

      // 카테고리별 사용량 (템플릿에서 정보 가져오기)
      final template = await _promptService.getTemplate(execution.templateId);
      if (template != null) {
        categoryUsage[template.category.displayName] =
            (categoryUsage[template.category.displayName] ?? 0) + 1;
      }

      // 누적 계산
      totalCost += execution.cost;
      totalRequests++;
      totalTokens += execution.tokenCount;
      totalResponseTime += execution.responseTime;

      // 모델 성능
      if (execution.userRating > 0) {
        modelPerformance[execution.model.id] = execution.userRating;
      }
    }

    return UsageAnalytics(
      userId: userId,
      modelUsageCounts: modelUsageCounts,
      modelCosts: modelCosts,
      dailyUsage: dailyUsage,
      categoryUsage: categoryUsage,
      totalCost: totalCost,
      totalRequests: totalRequests,
      totalTokens: totalTokens,
      averageResponseTime: totalRequests > 0 ? totalResponseTime / totalRequests : 0.0,
      modelPerformance: modelPerformance,
    );
  }

  // 비용 분석
  Future<CostAnalytics> _analyzeCosts(String userId, DateTime start, DateTime end) async {
    final executions = await _promptService.getExecutions(
      userId: userId,
      startDate: start,
      endDate: end,
    );

    final costsByModel = <String, double>{};
    final costsByCategory = <String, double>{};
    final costsByDay = <String, double>{};
    final trends = <CostTrend>[];

    double totalCost = 0.0;

    for (final execution in executions) {
      // 모델별 비용
      costsByModel[execution.model.id] =
          (costsByModel[execution.model.id] ?? 0) + execution.cost;

      // 일별 비용
      final day = execution.timestamp.toString().substring(0, 10);
      costsByDay[day] = (costsByDay[day] ?? 0) + execution.cost;

      // 카테고리별 비용
      final template = await _promptService.getTemplate(execution.templateId);
      if (template != null) {
        costsByCategory[template.category.displayName] =
            (costsByCategory[template.category.displayName] ?? 0) + execution.cost;
      }

      totalCost += execution.cost;
    }

    // 추세 분석
    final sortedDays = costsByDay.keys.toList()..sort();
    for (int i = 1; i < sortedDays.length; i++) {
      final prevDay = sortedDays[i - 1];
      final currentDay = sortedDays[i];

      final prevCost = costsByDay[prevDay] ?? 0;
      final currentCost = costsByDay[currentDay] ?? 0;

      final changeRate = prevCost > 0 ? ((currentCost - prevCost) / prevCost) * 100 : 0;

      trends.add(CostTrend(
        period: currentDay,
        cost: currentCost,
        changeRate: changeRate,
        direction: changeRate > 5 ? TrendDirection.up :
                changeRate < -5 ? TrendDirection.down : TrendDirection.stable,
      ));
    }

    // 비용 예측
    final projectedCosts = _projectCosts(costsByDay);

    return CostAnalytics(
      costsByModel: costsByModel,
      costsByCategory: costsByCategory,
      costsByDay: costsByDay,
      totalCost: totalCost,
      averageCostPerRequest: executions.isNotEmpty ? totalCost / executions.length : 0,
      averageCostPerToken: totalTokens > 0 ? totalCost / totalTokens : 0,
      trends: trends,
      projectedCosts: projectedCosts,
    );
  }

  // 성능 분석
  Future<PerformanceAnalytics> _analyzePerformance(String userId, DateTime start, DateTime end) async {
    final executions = await _promptService.getExecutions(
      userId: userId,
      startDate: start,
      endDate: end,
    );

    final modelScores = <String, double>{};
    final responseTimes = <String, double>{};
    final errorRates = <String, double>{};
    final userRatings = <String, double>{};
    final insights = <PerformanceInsight>[];

    for (final model in LLMModel.getAllModels()) {
      final modelExecutions = executions.where((e) => e.model.id == model.id).toList();

      if (modelExecutions.isNotEmpty) {
        // 평균 응답 시간
        final avgResponseTime = modelExecutions
            .map((e) => e.responseTime)
            .reduce((a, b) => a + b) / modelExecutions.length;
        responseTimes[model.id] = avgResponseTime;

        // 사용자 평점
        final ratedExecutions = modelExecutions.where((e) => e.userRating > 0);
        if (ratedExecutions.isNotEmpty) {
          final avgRating = ratedExecutions
              .map((e) => e.userRating)
              .reduce((a, b) => a + b) / ratedExecutions.length;
          userRatings[model.id] = avgRating;
        }

        // 성능 점수 (응답 시간 + 사용자 평점)
        final performanceScore = _calculatePerformanceScore(avgResponseTime, userRatings[model.id] ?? 0);
        modelScores[model.id] = performanceScore;

        // 인사이트 생성
        insights.add(PerformanceInsight(
          model: model.name,
          metric: '응답 시간',
          value: avgResponseTime,
          observation: _generateResponseTimeObservation(avgResponseTime),
          recommendation: _generateResponseTimeRecommendation(avgResponseTime),
        ));

        if (userRatings.containsKey(model.id)) {
          insights.add(PerformanceInsight(
            model: model.name,
            metric: '사용자 만족도',
            value: userRatings[model.id]!,
            observation: _generateRatingObservation(userRatings[model.id]!),
            recommendation: _generateRatingRecommendation(userRatings[model.id]!),
          ));
        }
      }
    }

    // 최고 성능 모델 결정
    final bestPerformingModel = modelScores.entries.isNotEmpty
        ? modelScores.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : '';

    final fastestModel = responseTimes.entries.isNotEmpty
        ? responseTimes.entries.reduce((a, b) => a.value < b.value ? a : b).key
        : '';

    final highestRatedModel = userRatings.entries.isNotEmpty
        ? userRatings.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : '';

    return PerformanceAnalytics(
      modelScores: modelScores,
      responseTimes: responseTimes,
      errorRates: errorRates,
      userRatings: userRatings,
      bestPerformingModel: bestPerformingModel,
      fastestModel: fastestModel,
      highestRatedModel: highestRatedModel,
      insights: insights,
    );
  }

  // PDF 보고서 생성
  Future<File> generatePDFReport({
    required AnalyticsData analytics,
    required String userId,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansCyrillic();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                text: 'AI 모델 사용 분석 보고서',
                textStyle: pw.TextStyle(font: font, fontSize: 24),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                '생성일: ${analytics.generatedAt.toString().substring(0, 10)}',
                style: pw.TextStyle(font: font),
              ),
              pw.Text(
                '분석 기간: ${analytics.period.displayName}',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 30),

              // 사용량 분석
              if (analytics.data.containsKey('usage')) ...[
                pw.Header(
                  level: 1,
                  text: '사용량 분석',
                  textStyle: pw.TextStyle(font: font, fontSize: 18),
                ),
                _buildUsageSection(analytics.data['usage'], font),
                pw.SizedBox(height: 20),
              ],

              // 비용 분석
              if (analytics.data.containsKey('cost')) ...[
                pw.Header(
                  level: 1,
                  text: '비용 분석',
                  textStyle: pw.TextStyle(font: font, fontSize: 18),
                ),
                _buildCostSection(analytics.data['cost'], font),
                pw.SizedBox(height: 20),
              ],

              // 성능 분석
              if (analytics.data.containsKey('performance')) ...[
                pw.Header(
                  level: 1,
                  text: '성능 분석',
                  textStyle: pw.TextStyle(font: font, fontSize: 18),
                ),
                _buildPerformanceSection(analytics.data['performance'], font),
                pw.SizedBox(height: 20),
              ],

              // 추천사항
              pw.Header(
                level: 1,
                text: '추천사항',
                textStyle: pw.TextStyle(font: font, fontSize: 18),
              ),
              ...analytics.recommendations.map((rec) => pw.Bullet(
                text: rec,
                style: pw.TextStyle(font: font),
              )),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/analytics_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // --- Helper Methods ---

  DateTime _getStartDate(AnalyticsPeriod period, DateTime now) {
    switch (period) {
      case AnalyticsPeriod.daily:
        return now.subtract(const Duration(days: 1));
      case AnalyticsPeriod.weekly:
        return now.subtract(const Duration(days: 7));
      case AnalyticsPeriod.monthly:
        return now.subtract(const Duration(days: 30));
      case AnalyticsPeriod.quarterly:
        return now.subtract(const Duration(days: 90));
      case AnalyticsPeriod.yearly:
        return now.subtract(const Duration(days: 365));
    }
  }

  List<double> _generateTimeSeries(Map<String, dynamic> data) {
    return data.values.map((value) => (value as num).toDouble()).toList();
  }

  Map<String, dynamic> _generateUsageInsights(UsageAnalytics usage) {
    return {
      'mostUsedModel': usage.modelUsageCounts.entries.isNotEmpty
          ? usage.modelUsageCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : '',
      'averageDailyUsage': usage.dailyUsage.values.isNotEmpty
          ? usage.dailyUsage.values.reduce((a, b) => a + b) / usage.dailyUsage.length
          : 0,
      'peakUsageDay': usage.dailyUsage.entries.isNotEmpty
          ? usage.dailyUsage.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : '',
    };
  }

  List<String> _generateUsageRecommendations(UsageAnalytics usage) {
    final recommendations = <String>[];

    if (usage.totalRequests > 1000) {
      recommendations.add('사용량이 많습니다. 비용 최적화를 고려해보세요.');
    }

    if (usage.averageResponseTime > 2000) {
      recommendations.add('평균 응답 시간이 2초를 초과합니다. 더 빠른 모델을 고려해보세요.');
    }

    final topModel = usage.modelUsageCounts.entries.isNotEmpty
        ? usage.modelUsageCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : '';

    if (topModel.isNotEmpty) {
      recommendations.add('$topModel 모델을 가장 많이 사용하고 있습니다. 전용 플랜을 고려해보세요.');
    }

    return recommendations;
  }

  Map<String, dynamic> _generateCostInsights(CostAnalytics costs) {
    return {
      'mostExpensiveModel': costs.costsByModel.entries.isNotEmpty
          ? costs.costsByModel.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : '',
      'costTrend': costs.trends.isNotEmpty
          ? costs.trends.last.direction
          : TrendDirection.stable,
      'projectedMonthlyCost': costs.projectedCosts['monthly'] ?? 0.0,
    };
  }

  List<String> _generateCostRecommendations(CostAnalytics costs) {
    final recommendations = <String>[];

    if (costs.totalCost > 50) {
      recommendations.add('월 비용이 \$50을 초과했습니다. 비용 최적화가 필요합니다.');
    }

    if (costs.averageCostPerRequest > 0.1) {
      recommendations.add('요청당 평균 비용이 높습니다. 더 효율적인 모델을 사용해보세요.');
    }

    if (costs.trends.length > 7) {
      final recentTrends = costs.trends.take(7).toList();
      final increasingDays = recentTrends.where((t) => t.direction == TrendDirection.up).length;

      if (increasingDays >= 5) {
        recommendations.add('비용이 지속적으로 증가하고 있습니다. 사용 패턴을 검토해보세요.');
      }
    }

    return recommendations;
  }

  Map<String, dynamic> _generatePerformanceInsights(PerformanceAnalytics performance) {
    return {
      'bestOverallModel': performance.bestPerformingModel,
      'fastestModel': performance.fastestModel,
      'highestRatedModel': performance.highestRatedModel,
      'averageScore': performance.modelScores.values.isNotEmpty
          ? performance.modelScores.values.reduce((a, b) => a + b) / performance.modelScores.length
          : 0.0,
    };
  }

  List<String> _generatePerformanceRecommendations(PerformanceAnalytics performance) {
    final recommendations = <String>[];

    if (performance.bestPerformingModel != performance.fastestModel) {
      recommendations.add('성능과 속도 사이에 균형이 필요합니다. 사용 목적에 맞는 모델을 선택하세요.');
    }

    if (performance.userRatings.isNotEmpty) {
      final avgRating = performance.userRatings.values.reduce((a, b) => a + b) / performance.userRatings.length;
      if (avgRating < 3.5) {
        recommendations.add('사용자 만족도가 낮습니다. 프롬프트를 개선하거나 다른 모델을 시도해보세요.');
      }
    }

    return recommendations;
  }

  double _calculatePerformanceScore(double responseTime, double userRating) {
    // 응답 시간이 낮을수록, 사용자 평점이 높을수록 좋은 성능
    final timeScore = responseTime > 0 ? max(0, 10 - (responseTime / 1000)) : 0;
    final ratingScore = userRating * 2;
    return (timeScore + ratingScore) / 3;
  }

  String _generateResponseTimeObservation(double responseTime) {
    if (responseTime < 1000) {
      return '매우 빠른 응답 속도';
    } else if (responseTime < 2000) {
      return '양호한 응답 속도';
    } else if (responseTime < 3000) {
      return '보통 수준의 응답 속도';
    } else {
      return '개선이 필요한 응답 속도';
    }
  }

  String _generateResponseTimeRecommendation(double responseTime) {
    if (responseTime > 3000) {
      return '더 빠른 모델로 전환을 고려해보세요.';
    } else if (responseTime < 1000) {
      return '현재 속도가 매우 우수합니다.';
    } else {
      return '속도가 적절한 수준입니다.';
    }
  }

  String _generateRatingObservation(double rating) {
    if (rating >= 4.5) {
      return '매우 높은 사용자 만족도';
    } else if (rating >= 3.5) {
      return '양호한 사용자 만족도';
    } else if (rating >= 2.5) {
      return '보통 수준의 사용자 만족도';
    } else {
      return '개선이 필요한 사용자 만족도';
    }
  }

  String _generateRatingRecommendation(double rating) {
    if (rating < 3.0) {
      return '프롬프트 개선이나 모델 변경을 고려해보세요.';
    } else if (rating >= 4.5) {
      return '현재 설정이 매우 효과적입니다.';
    } else {
      return '만족도가 적절한 수준입니다.';
    }
  }

  Map<String, double> _projectCosts(Map<String, double> dailyCosts) {
    if (dailyCosts.isEmpty) return {};

    final values = dailyCosts.values.toList();
    final average = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - average, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);

    return {
      'daily': average,
      'weekly': average * 7,
      'monthly': average * 30,
      'yearly': average * 365,
      'volatility': stdDev,
    };
  }

  pw.Widget _buildUsageSection(UsageAnalytics usage, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('총 요청수: ${usage.totalRequests}', style: pw.TextStyle(font: font)),
        pw.Text('총 토큰 수: ${usage.totalTokens}', style: pw.TextStyle(font: font)),
        pw.Text('평균 응답 시간: ${usage.averageResponseTime.toStringAsFixed(0)}ms', style: pw.TextStyle(font: font)),
        pw.SizedBox(height: 10),
        pw.Text('모델별 사용량:', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
        ...usage.modelUsageCounts.entries.map((entry) =>
          pw.Text('${entry.key}: ${entry.value}회', style: pw.TextStyle(font: font))),
      ],
    );
  }

  pw.Widget _buildCostSection(CostAnalytics costs, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('총 비용: \$${costs.totalCost.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
        pw.Text('요청당 평균 비용: \$${costs.averageCostPerRequest.toStringAsFixed(4)}', style: pw.TextStyle(font: font)),
        pw.SizedBox(height: 10),
        pw.Text('모델별 비용:', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
        ...costs.costsByModel.entries.map((entry) =>
          pw.Text('${entry.key}: \$${entry.value.toStringAsFixed(2)}', style: pw.TextStyle(font: font))),
      ],
    );
  }

  pw.Widget _buildPerformanceSection(PerformanceAnalytics performance, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (performance.bestPerformingModel.isNotEmpty)
          pw.Text('최고 성능 모델: ${performance.bestPerformingModel}', style: pw.TextStyle(font: font)),
        if (performance.fastestModel.isNotEmpty)
          pw.Text('가장 빠른 모델: ${performance.fastestModel}', style: pw.TextStyle(font: font)),
        if (performance.highestRatedModel.isNotEmpty)
          pw.Text('최고 평점 모델: ${performance.highestRatedModel}', style: pw.TextStyle(font: font)),
        pw.SizedBox(height: 10),
        pw.Text('성능 인사이트:', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
        ...performance.insights.take(5).map((insight) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${insight.model} - ${insight.metric}: ${insight.value.toStringAsFixed(2)}',
                   style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
              pw.Text(insight.observation, style: pw.TextStyle(font: font, fontSize: 10)),
            ],
          ),
        )),
      ],
    );
  }
}