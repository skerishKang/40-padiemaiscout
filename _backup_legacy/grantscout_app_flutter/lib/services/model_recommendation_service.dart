import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/llm_model.dart';
import 'model_performance_service.dart';

// 전역 변수 (임시)
final Map<String, ModelPerformanceData> performanceScores = {};

enum UseCaseType {
  grantAnalysis('지원사업 분석'),
  grantMatching('지원사업 매칭'),
  documentCreation('문서 생성'),
  documentReview('문서 검토'),
  dataAnalysis('데이터 분석'),
  reportGeneration('보고서 작성'),
  translation('번역'),
  codeGeneration('코드 생성'),
  qa('질의응답'),
  summarization('요약');

  const UseCaseType(this.displayName);
  final String displayName;
}

class ModelRecommendationService {
  static final ModelRecommendationService _instance = ModelRecommendationService._internal();
  factory ModelRecommendationService() => _instance;
  ModelRecommendationService._internal();

  final ModelPerformanceService _performanceService = ModelPerformanceService();

  // 사용 사례별 모델 추천
  Future<ModelRecommendation> recommendModel({
    required UseCaseType useCase,
    String? specificRequirement,
    Map<String, dynamic>? context,
    int? maxBudget,
    int? maxResponseTime,
    List<String>? preferredProviders,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 사용자 프로필 가져오기
      final userProfile = await _getUserProfile(user.uid);

      // 사용자 이력 기반 선호도 분석
      final userPreferences = await _analyzeUserPreferences(user.uid, useCase);

      // 모든 모델 가져오기
      final allModels = LLMModel.getAllModels();

      // 필터링 조건 적용
      List<LLMModel> candidateModels = _filterModels(
        allModels,
        maxBudget: maxBudget,
        maxResponseTime: maxResponseTime,
        preferredProviders: preferredProviders,
      );

      // 사용 사례별 모델 평가
      final modelScores = <LLMModel, double>{};

      for (final model in candidateModels) {
        final score = await _calculateModelScore(
          model: model,
          useCase: useCase,
          specificRequirement: specificRequirement,
          context: context,
          userProfile: userProfile,
          userPreferences: userPreferences,
        );
        modelScores[model] = score;
      }

      // 점수순 정렬
      final sortedModels = modelScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 추천 결과 생성
      final recommendations = sortedModels.take(5).map((entry) {
        final model = entry.key;
        final score = entry.value;

        return ModelRecommendationItem(
          model: model,
          score: score,
          reasons: _generateRecommendationReasons(model, useCase, score),
          estimatedCost: _estimateCost(model, useCase, context),
          estimatedTime: _estimateResponseTime(model, useCase),
          confidence: _calculateConfidence(model, useCase, score),
        );
      }).toList();

      // 추천 로그 저장
      await _saveRecommendationLog(user.uid, useCase, recommendations);

      return ModelRecommendation(
        useCase: useCase,
        recommendations: recommendations,
        generatedAt: DateTime.now(),
        context: context,
      );
    } catch (e) {
      throw Exception('Failed to generate model recommendation: $e');
    }
  }

  // 실시간 상황 기반 모델 추천
  Future<RealtimeRecommendation> getRealtimeRecommendation({
    required String currentTask,
    required Map<String, dynamic> taskContext,
    List<LLMModel>? availableModels,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // 작업 유형 분석
    final taskType = _analyzeTaskType(currentTask, taskContext);

    // 시간대별 부하 분석
    final currentLoad = await _analyzeCurrentSystemLoad();

    // 긴급도 분석
    final urgency = _analyzeUrgency(taskContext);

    // 동적 모델 선택
    final recommendations = await _getDynamicRecommendations(
      taskType: taskType,
      systemLoad: currentLoad,
      urgency: urgency,
      availableModels: availableModels,
      userContext: taskContext,
    );

    return RealtimeRecommendation(
      taskType: taskType,
      urgency: urgency,
      systemLoad: currentLoad,
      recommendations: recommendations,
      fallbackOption: _getFallbackModel(taskType),
      timestamp: DateTime.now(),
    );
  }

  // 비용 최적화 추천
  Future<CostOptimizationRecommendation> getCostOptimizedRecommendation({
    required UseCaseType useCase,
    required double monthlyBudget,
    int expectedMonthlyUsage = 1000,
  }) async {
    final allModels = LLMModel.getAllModels();
    final costAnalysis = <LLMModel, CostAnalysis>{};

    for (final model in allModels) {
      final analysis = await _analyzeCostEfficiency(
        model: model,
        useCase: useCase,
        monthlyBudget: monthlyBudget,
        expectedUsage: expectedMonthlyUsage,
      );
      costAnalysis[model] = analysis;
    }

    // 비용 효율성순 정렬
    final sortedByCostEfficiency = costAnalysis.entries.toList()
      ..sort((a, b) => b.value.costEfficiencyScore.compareTo(a.value.costEfficiencyScore));

    final recommendations = sortedByCostEfficiency.map((entry) {
      final model = entry.key;
      final analysis = entry.value;

      return CostOptimizationItem(
        model: model,
        costAnalysis: analysis,
        monthlyEstimate: analysis.monthlyCost,
        savingsPotential: analysis.savingsPotential,
        tradeoffs: _generateCostTradeoffs(model, analysis),
      );
    }).toList();

    return CostOptimizationRecommendation(
      useCase: useCase,
      monthlyBudget: monthlyBudget,
      recommendations: recommendations,
      estimatedSavings: _calculateTotalSavings(recommendations),
      generatedAt: DateTime.now(),
    );
  }

  // 학습 기반 추천 시스템
  Future<void> updateRecommendationModel({
    required String userId,
    required LLMModel usedModel,
    required UseCaseType useCase,
    required double userRating,
    required String feedback,
  }) async {
    // 사용자 피드백 저장
    await _saveUserFeedback(
      userId: userId,
      model: usedModel,
      useCase: useCase,
      rating: userRating,
      feedback: feedback,
    );

    // 추천 모델 가중치 업데이트
    await _updateRecommendationWeights(
      model: usedModel,
      useCase: useCase,
      rating: userRating,
    );

    // 사용자 프로필 업데이트
    await _updateUserProfile(userId, usedModel, useCase, userRating);
  }

  // A/B 테스트 기반 추천
  Future<ABTestRecommendation> getABTestBasedRecommendation({
    required UseCaseType useCase,
    required List<LLMModel> testModels,
  }) async {
    // 최근 A/B 테스트 결과 분석
    final recentTests = await _getRecentABTests(useCase, testModels);

    if (recentTests.isEmpty) {
      return ABTestRecommendation(
        useCase: useCase,
        recommendation: _getDefaultRecommendation(testModels),
        confidence: 'low',
        reason: 'No A/B test data available',
      );
    }

    // 통계적 유의성 분석
    final statisticalAnalysis = _analyzeABTestResults(recentTests);

    // 승자 모델 결정
    final winnerModel = _determineWinner(statisticalAnalysis);

    return ABTestRecommendation(
      useCase: useCase,
      recommendation: winnerModel,
      confidence: statisticalAnalysis.confidenceLevel,
      reason: statisticalAnalysis.explanation,
      supportingData: statisticalAnalysis,
    );
  }

  // --- Private Helper Methods ---

  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }

    return _createDefaultProfile();
  }

  Map<String, dynamic> _createDefaultProfile() {
    return {
      'industry': 'general',
      'companySize': 'small',
      'preferredLanguage': 'korean',
      'budgetTier': 'medium',
      'technicalLevel': 'intermediate',
      'usageFrequency': 'regular',
    };
  }

  Future<UserPreferences> _analyzeUserPreferences(String userId, UseCaseType useCase) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('model_usage_history')
        .where('userId', isEqualTo: userId)
        .where('useCase', isEqualTo: useCase.name)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    final usage = snapshot.docs.map((doc) => doc.data()).toList();

    return UserPreferences.fromUsageData(usage);
  }

  List<LLMModel> _filterModels(
    List<LLMModel> models, {
    int? maxBudget,
    int? maxResponseTime,
    List<String>? preferredProviders,
  }) {
    return models.where((model) {
      if (maxBudget != null && model.costPerToken * 1000 > maxBudget) {
        return false;
      }

      if (maxResponseTime != null && model.averageResponseTime > maxResponseTime) {
        return false;
      }

      if (preferredProviders != null &&
          !preferredProviders.contains(model.provider.name)) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<double> _calculateModelScore({
    required LLMModel model,
    required UseCaseType useCase,
    String? specificRequirement,
    Map<String, dynamic>? context,
    Map<String, dynamic>? userProfile,
    UserPreferences? userPreferences,
  }) async {
    double score = 0.0;

    // 1. 성능 점수 (40%)
    final performanceData = await _performanceService.getModelPerformance(
      modelId: model.id,
      useCase: useCase.name,
    );
    score += performanceData.overallScore * 0.4;

    // 2. 사용 사례 적합도 (25%)
    score += _calculateUseCaseFit(model, useCase, specificRequirement) * 0.25;

    // 3. 비용 효율성 (15%)
    score += _calculateCostEfficiency(model, useCase) * 0.15;

    // 4. 사용자 선호도 (10%)
    if (userPreferences != null) {
      score += _calculatePreferenceFit(model, userPreferences) * 0.1;
    }

    // 5. 언어 지원 (한국어) (10%)
    score += _calculateLanguageSupport(model, 'korean') * 0.1;

    return score.clamp(0.0, 10.0);
  }

  double _calculateUseCaseFit(LLMModel model, UseCaseType useCase, String? specificRequirement) {
    double fitScore = 5.0; // 기본 점수

    switch (useCase) {
      case UseCaseType.grantAnalysis:
        if (model.capabilities.contains('analysis')) fitScore += 2.0;
        if (model.capabilities.contains('korean')) fitScore += 1.5;
        if (model.provider == LLMProvider.gemini) fitScore += 0.5; // Google 생태계
        break;

      case UseCaseType.documentCreation:
        if (model.capabilities.contains('text')) fitScore += 2.0;
        if (model.capabilities.contains('korean')) fitScore += 1.5;
        if (model.maxTokens > 4000) fitScore += 0.5;
        break;

      case UseCaseType.translation:
        if (model.capabilities.contains('korean')) fitScore += 3.0;
        if (model.provider == LLMProvider.clova) fitScore += 1.0; // NAVER 전문성
        break;

      case UseCaseType.codeGeneration:
        if (model.capabilities.contains('code')) fitScore += 3.0;
        if (model.provider == LLMProvider.openai) fitScore += 0.5;
        break;

      case UseCaseType.dataAnalysis:
        if (model.capabilities.contains('analysis')) fitScore += 2.5;
        if (model.capabilities.contains('code')) fitScore += 1.0;
        break;

      default:
        fitScore += model.capabilities.contains(useCase.name) ? 2.0 : 0.0;
    }

    // 특정 요구사항 반영
    if (specificRequirement != null) {
      if (specificRequirement.contains('빠른') && model.averageResponseTime < 1.5) {
        fitScore += 0.5;
      }
      if (specificRequirement.contains('정확') && performanceScores[model.id]?.accuracy ?? 0 > 0.9) {
        fitScore += 0.5;
      }
    }

    return fitScore.clamp(0.0, 10.0);
  }

  double _calculateCostEfficiency(LLMModel model, UseCaseType useCase) {
    // 비용 대비 성능 비율 계산
    final performanceScore = performanceScores[model.id]?.overallScore ?? 5.0;
    final costScore = (1.0 / model.costPerToken) * 100; // 비용이 낮을수록 높은 점수

    return (performanceScore * costScore / 100).clamp(0.0, 10.0);
  }

  double _calculatePreferenceFit(LLMModel model, UserPreferences preferences) {
    double fitScore = 5.0;

    // 제공업체 선호도
    if (preferences.preferredProviders.contains(model.provider.name)) {
      fitScore += 2.0;
    }

    // 이전 사용 경험
    final pastUsage = preferences.pastUsage[model.id];
    if (pastUsage != null && pastUsage['avgRating'] != null) {
      fitScore += (pastUsage['avgRating'] - 3.0) * 0.5; // 3점 기준으로 조정
    }

    return fitScore.clamp(0.0, 10.0);
  }

  double _calculateLanguageSupport(LLMModel model, String language) {
    switch (language) {
      case 'korean':
        if (model.provider == LLMProvider.clova) return 10.0;
        if (model.provider == LLMProvider.gemini) return 9.0;
        if (model.provider == LLMProvider.openai) return 8.0;
        if (model.provider == LLMProvider.anthropic) return 7.5;
        break;
    }
    return 5.0;
  }

  List<String> _generateRecommendationReasons(LLMModel model, UseCaseType useCase, double score) {
    final reasons = <String>[];

    if (score >= 8.0) {
      reasons.add('우수한 성능 점수 (${score.toStringAsFixed(1)})');
    }

    if (model.capabilities.contains(useCase.name)) {
      reasons.add('${useCase.displayName} 작업에 최적화');
    }

    if (model.capabilities.contains('korean')) {
      reasons.add('한국어 지원 우수');
    }

    if (model.costPerToken < 0.001) {
      reasons.add('비용 효율적');
    }

    if (model.averageResponseTime < 1.5) {
      reasons.add('빠른 응답 속도');
    }

    if (model.maxTokens > 4000) {
      reasons.add('긴 문서 처리 가능');
    }

    return reasons.isEmpty ? ['균형 잡힌 성능'] : reasons;
  }

  double _estimateCost(LLMModel model, UseCaseType useCase, Map<String, dynamic>? context) {
    // 예상 토큰 수 계산
    int estimatedTokens = _estimateTokens(useCase, context);

    return (estimatedTokens * model.costPerToken * 1000).roundToDouble();
  }

  int _estimateTokens(UseCaseType useCase, Map<String, dynamic>? context) {
    switch (useCase) {
      case UseCaseType.grantAnalysis:
        return 1500 + (context?['documentLength'] ?? 0) ~/ 2;
      case UseCaseType.documentCreation:
        return 2000 + (context?['targetLength'] ?? 1000);
      case UseCaseType.translation:
        return (context?['sourceLength'] ?? 500) * 2;
      default:
        return 1000;
    }
  }

  double _estimateResponseTime(LLMModel model, UseCaseType useCase) {
    double baseTime = model.averageResponseTime;

    switch (useCase) {
      case UseCaseType.grantAnalysis:
        return baseTime * 1.5;
      case UseCaseType.documentCreation:
        return baseTime * 1.2;
      default:
        return baseTime;
    }
  }

  double _calculateConfidence(LLMModel model, UseCaseType useCase, double score) {
    double confidence = score / 10.0; // 기본 신뢰도

    // 데이터 양에 따른 신뢰도 조정
    final dataAvailability = _getDataAvailability(model.id, useCase);
    confidence *= dataAvailability;

    return confidence.clamp(0.0, 1.0);
  }

  double _getDataAvailability(String modelId, UseCaseType useCase) {
    // 실제로는 Firestore에서 데이터 양을 확인
    return 0.8; // 임시값
  }

  UseCaseType _analyzeTaskType(String task, Map<String, dynamic> context) {
    final taskLower = task.toLowerCase();

    if (taskLower.contains('지원사업') || taskLower.contains('분석')) {
      return UseCaseType.grantAnalysis;
    } else if (taskLower.contains('매칭') || taskLower.contains('찾기')) {
      return UseCaseType.grantMatching;
    } else if (taskLower.contains('생성') || taskLower.contains('작성')) {
      return UseCaseType.documentCreation;
    } else if (taskLower.contains('검토') || taskLower.contains('검사')) {
      return UseCaseType.documentReview;
    } else if (taskLower.contains('번역')) {
      return UseCaseType.translation;
    } else if (taskLower.contains('코드') || taskLower.contains('프로그래밍')) {
      return UseCaseType.codeGeneration;
    } else if (taskLower.contains('분석')) {
      return UseCaseType.dataAnalysis;
    } else if (taskLower.contains('보고서')) {
      return UseCaseType.reportGeneration;
    } else if (taskLower.contains('요약')) {
      return UseCaseType.summarization;
    } else {
      return UseCaseType.qa;
    }
  }

  Future<SystemLoad> _analyzeCurrentSystemLoad() async {
    // 실제 시스템은 부하 모니터링 데이터 사용
    return SystemLoad(
      cpuUsage: 0.3 + Random().nextDouble() * 0.4,
      memoryUsage: 0.4 + Random().nextDouble() * 0.3,
      activeRequests: Random().nextInt(100),
      timestamp: DateTime.now(),
    );
  }

  Urgency _analyzeUrgency(Map<String, dynamic> context) {
    final priority = context['priority'] as String?;
    final deadline = context['deadline'] as DateTime?;

    if (priority == 'urgent' || (deadline != null && deadline.difference(DateTime.now()).inHours < 2)) {
      return Urgency.high;
    } else if (priority == 'normal' || (deadline != null && deadline.difference(DateTime.now()).inHours < 24)) {
      return Urgency.medium;
    } else {
      return Urgency.low;
    }
  }

  Future<List<DynamicRecommendation>> _getDynamicRecommendations({
    required UseCaseType taskType,
    required SystemLoad systemLoad,
    required Urgency urgency,
    List<LLMModel>? availableModels,
    Map<String, dynamic>? userContext,
  }) async {
    final models = availableModels ?? LLMModel.getAllModels();
    final recommendations = <DynamicRecommendation>[];

    for (final model in models) {
      final score = _calculateDynamicScore(
        model: model,
        taskType: taskType,
        systemLoad: systemLoad,
        urgency: urgency,
      );

      if (score > 3.0) { // 최소 점수 이상만 추천
        recommendations.add(DynamicRecommendation(
          model: model,
          score: score,
          reasoning: _generateDynamicReasoning(model, taskType, urgency, systemLoad),
          estimatedTime: _estimateDynamicResponseTime(model, systemLoad),
        ));
      }
    }

    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations.take(3).toList();
  }

  double _calculateDynamicScore({
    required LLMModel model,
    required UseCaseType taskType,
    required SystemLoad systemLoad,
    required Urgency urgency,
  }) {
    double score = 5.0;

    // 긴급도에 따른 가중치
    if (urgency == Urgency.high) {
      // 빠른 응답 시간 중요
      score += (2.0 - model.averageResponseTime) * 2;
    } else if (urgency == Urgency.low) {
      // 비용 효율성 중요
      score += (1.0 / model.costPerToken) * 10;
    }

    // 시스템 부하에 따른 조정
    if (systemLoad.cpuUsage > 0.8) {
      // 고부하 상황에서는 가벼운 모델 선호
      score -= model.averageResponseTime;
    }

    // 작업 유형 적합도
    score += _calculateUseCaseFit(model, taskType, null) * 0.3;

    return score.clamp(0.0, 10.0);
  }

  LLMModel _getFallbackModel(UseCaseType taskType) {
    // 항상 사용 가능한 안정적인 모델
    return LLMModel.geminiPro();
  }
}

// 데이터 클래스들
class ModelRecommendation {
  final UseCaseType useCase;
  final List<ModelRecommendationItem> recommendations;
  final DateTime generatedAt;
  final Map<String, dynamic>? context;

  const ModelRecommendation({
    required this.useCase,
    required this.recommendations,
    required this.generatedAt,
    this.context,
  });
}

class ModelRecommendationItem {
  final LLMModel model;
  final double score;
  final List<String> reasons;
  final double estimatedCost;
  final double estimatedTime;
  final double confidence;

  const ModelRecommendationItem({
    required this.model,
    required this.score,
    required this.reasons,
    required this.estimatedCost,
    required this.estimatedTime,
    required this.confidence,
  });
}

class UserPreferences {
  final List<String> preferredProviders;
  final Map<String, Map<String, dynamic>> pastUsage;
  final Map<String, double> featureWeights;

  const UserPreferences({
    required this.preferredProviders,
    required this.pastUsage,
    required this.featureWeights,
  });

  factory UserPreferences.fromUsageData(List<Map<String, dynamic>> usageData) {
    final preferredProviders = <String>[];
    final pastUsage = <String, Map<String, dynamic>>{};

    // 사용 데이터 분석 로직
    final providerCounts = <String, int>{};
    double totalRating = 0.0;
    int ratingCount = 0;

    for (final usage in usageData) {
      final provider = usage['provider'] as String?;
      final modelId = usage['modelId'] as String?;
      final rating = usage['rating'] as double?;

      if (provider != null) {
        providerCounts[provider] = (providerCounts[provider] ?? 0) + 1;
      }

      if (modelId != null && rating != null) {
        pastUsage[modelId] ??= {'ratings': <double>[], 'count': 0};
        pastUsage[modelId]!['ratings'].add(rating);
        pastUsage[modelId]!['count'] = pastUsage[modelId]!['count'] + 1;

        totalRating += rating;
        ratingCount++;
      }
    }

    // 가장 많이 사용한 제공업체
    if (providerCounts.isNotEmpty) {
      final sortedProviders = providerCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      preferredProviders.addAll(sortedProviders.take(3).map((e) => e.key));
    }

    // 평균 평점 계산
    for (final entry in pastUsage.entries) {
      final ratings = entry.value['ratings'] as List<double>;
      if (ratings.isNotEmpty) {
        entry.value['avgRating'] = ratings.reduce((a, b) => a + b) / ratings.length;
      }
    }

    return UserPreferences(
      preferredProviders: preferredProviders,
      pastUsage: pastUsage,
      featureWeights: {
        'performance': 0.4,
        'cost': 0.2,
        'speed': 0.2,
        'language': 0.2,
      },
    );
  }
}

class RealtimeRecommendation {
  final UseCaseType taskType;
  final Urgency urgency;
  final SystemLoad systemLoad;
  final List<DynamicRecommendation> recommendations;
  final LLMModel fallbackOption;
  final DateTime timestamp;

  const RealtimeRecommendation({
    required this.taskType,
    required this.urgency,
    required this.systemLoad,
    required this.recommendations,
    required this.fallbackOption,
    required this.timestamp,
  });
}

class DynamicRecommendation {
  final LLMModel model;
  final double score;
  final String reasoning;
  final double estimatedTime;

  const DynamicRecommendation({
    required this.model,
    required this.score,
    required this.reasoning,
    required this.estimatedTime,
  });
}

enum Urgency { low, medium, high }

class SystemLoad {
  final double cpuUsage;
  final double memoryUsage;
  final int activeRequests;
  final DateTime timestamp;

  const SystemLoad({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.activeRequests,
    required this.timestamp,
  });
}

class CostOptimizationRecommendation {
  final UseCaseType useCase;
  final double monthlyBudget;
  final List<CostOptimizationItem> recommendations;
  final double estimatedSavings;
  final DateTime generatedAt;

  const CostOptimizationRecommendation({
    required this.useCase,
    required this.monthlyBudget,
    required this.recommendations,
    required this.estimatedSavings,
    required this.generatedAt,
  });
}

class CostOptimizationItem {
  final LLMModel model;
  final CostAnalysis costAnalysis;
  final double monthlyEstimate;
  final double savingsPotential;
  final List<String> tradeoffs;

  const CostOptimizationItem({
    required this.model,
    required this.costAnalysis,
    required this.monthlyEstimate,
    required this.savingsPotential,
    required this.tradeoffs,
  });
}

class CostAnalysis {
  final double costEfficiencyScore;
  final double monthlyCost;
  final double savingsPotential;
  final Map<String, dynamic> breakdown;

  const CostAnalysis({
    required this.costEfficiencyScore,
    required this.monthlyCost,
    required this.savingsPotential,
    required this.breakdown,
  });
}

class ABTestRecommendation {
  final UseCaseType useCase;
  final LLMModel recommendation;
  final String confidence;
  final String reason;
  final Map<String, dynamic>? supportingData;

  const ABTestRecommendation({
    required this.useCase,
    required this.recommendation,
    required this.confidence,
    required this.reason,
    this.supportingData,
  });
}

// 전역 변수 (임시)
final Map<String, ModelPerformanceData> performanceScores = {};

// 임시 헬퍼 메서드들
List<String> _generateCostTradeoffs(LLMModel model, CostAnalysis analysis) {
  final tradeoffs = <String>[];

  if (model.costPerToken > 0.001) {
    tradeoffs.add('높은 비용이지만 우수한 성능');
  }

  if (model.averageResponseTime > 2.0) {
    tradeoffs.add('응답 시간이 느리지만 비용 효율적');
  }

  if (!model.capabilities.contains('korean')) {
    tradeoffs.add('한국어 지원이 제한적일 수 있음');
  }

  return tradeoffs.isEmpty ? ['균형 잡힌 옵션'] : tradeoffs;
}

double _calculateTotalSavings(List<CostOptimizationItem> recommendations) {
  return recommendations.fold(0.0, (sum, item) => sum + item.savingsPotential);
}

Future<CostAnalysis> _analyzeCostEfficiency({
  required LLMModel model,
  required UseCaseType useCase,
  required double monthlyBudget,
  required int expectedUsage,
}) async {
  // 비용 분석 로직
  final monthlyCost = expectedUsage * model.costPerToken;
  final efficiencyScore = (monthlyBudget - monthlyCost) / monthlyBudget;

  return CostAnalysis(
    costEfficiencyScore: efficiencyScore.clamp(0.0, 1.0),
    monthlyCost: monthlyCost,
    savingsPotential: max(0.0, monthlyBudget - monthlyCost),
    breakdown: {
      'tokens': expectedUsage,
      'costPerToken': model.costPerToken,
      'overage': max(0.0, monthlyCost - monthlyBudget),
    },
  );
}

Future<void> _saveRecommendationLog(String userId, UseCaseType useCase, List<ModelRecommendationItem> recommendations) async {
  await FirebaseFirestore.instance.collection('recommendation_logs').add({
    'userId': userId,
    'useCase': useCase.name,
    'recommendations': recommendations.map((r) => {
      'modelId': r.model.id,
      'score': r.score,
      'confidence': r.confidence,
    }).toList(),
    'timestamp': Timestamp.now(),
  });
}

String _generateDynamicReasoning(LLMModel model, UseCaseType taskType, Urgency urgency, SystemLoad systemLoad) {
  final reasoning = <String>[];

  if (urgency == Urgency.high && model.averageResponseTime < 1.5) {
    reasoning.add('빠른 응답 시간으로 긴급 작업에 적합');
  }

  if (systemLoad.cpuUsage > 0.8 && model.averageResponseTime < 1.0) {
    reasoning.add('시스템 부하가 높은 상황에서 안정적인 성능');
  }

  if (model.capabilities.contains(taskType.name)) {
    reasoning.add('${taskType.displayName} 작업에 특화');
  }

  return reasoning.isNotEmpty ? reasoning.join(', ') : '균형 잡힌 성능';
}

double _estimateDynamicResponseTime(LLMModel model, SystemLoad systemLoad) {
  double baseTime = model.averageResponseTime;

  // 시스템 부하에 따른 시간 조정
  if (systemLoad.cpuUsage > 0.8) {
    baseTime *= 1.5;
  } else if (systemLoad.cpuUsage > 0.6) {
    baseTime *= 1.2;
  }

  return baseTime;
}

LLMModel _getDefaultRecommendation(List<LLMModel> testModels) {
  return testModels.isNotEmpty ? testModels.first : LLMModel.geminiPro();
}

Future<List<Map<String, dynamic>>> _getRecentABTests(UseCaseType useCase, List<LLMModel> testModels) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('ab_test_results')
      .where('useCase', isEqualTo: useCase.name)
      .where('modelId', whereIn: testModels.map((m) => m.id).toList())
      .orderBy('timestamp', descending: true)
      .limit(100)
      .get();

  return snapshot.docs.map((doc) => doc.data()).toList();
}

ABTestStatisticalAnalysis _analyzeABTestResults(List<Map<String, dynamic>> testResults) {
  // A/B 테스트 결과 통계 분석
  return ABTestStatisticalAnalysis(
    confidenceLevel: 'medium',
    explanation: '충분한 데이터가 축적되면 통계적 유의성이 높아집니다',
    sampleSize: testResults.length,
    winner: 'gemini-pro',
  );
}

LLMModel _determineWinner(ABTestStatisticalAnalysis analysis) {
  return LLMModel.geminiPro(); // 임시
}

Future<void> _saveUserFeedback({
  required String userId,
  required LLMModel model,
  required UseCaseType useCase,
  required double rating,
  required String feedback,
}) async {
  await FirebaseFirestore.instance.collection('user_feedback').add({
    'userId': userId,
    'modelId': model.id,
    'useCase': useCase.name,
    'rating': rating,
    'feedback': feedback,
    'timestamp': Timestamp.now(),
  });
}

Future<void> _updateRecommendationWeights({
  required LLMModel model,
  required UseCaseType useCase,
  required double rating,
}) async {
  // 추천 모델 가중치 업데이트 로직
  await FirebaseFirestore.instance.collection('recommendation_weights').doc('${model.id}_${useCase.name}').set({
    'weight': rating / 5.0,
    'lastUpdated': Timestamp.now(),
  }, SetOptions(merge: true));
}

Future<void> _updateUserProfile(String userId, LLMModel model, UseCaseType useCase, double rating) async {
  // 사용자 프로필 업데이트
  await FirebaseFirestore.instance.collection('user_profiles').doc(userId).set({
    'lastUsedModel': model.id,
    'lastUseCase': useCase.name,
    'lastRating': rating,
    'updatedAt': Timestamp.now(),
  }, SetOptions(merge: true));
}

class ABTestStatisticalAnalysis {
  final String confidenceLevel;
  final String explanation;
  final int sampleSize;
  final String winner;

  const ABTestStatisticalAnalysis({
    required this.confidenceLevel,
    required this.explanation,
    required this.sampleSize,
    required this.winner,
  });
}